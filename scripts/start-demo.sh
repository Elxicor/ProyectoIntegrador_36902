#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p secrets/jwt secrets/tls

if [[ ! -f secrets/service.env ]]; then
  TOKEN=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
  printf 'STEGO_SERVICE_TOKEN=%s\n' "$TOKEN" > secrets/service.env
fi
if ! grep -Eq '^STEGO_SERVICE_TOKEN=[a-f0-9]{64}$' secrets/service.env; then
  echo 'Formato invalido de secrets/service.env' >&2
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  ossl() { openssl "$@"; }
else
  ossl() {
    docker run --rm --mount "type=bind,source=$PWD,target=/work" -w /work alpine:3.20 \
      sh -c 'apk add --no-cache openssl >/dev/null && exec openssl "$@"' -- "$@"
  }
fi

# No usar el OPENSSL_CONF externo del equipo. Forzar configuracion local para req.
cat > secrets/tls/openssl-req.cnf <<'CONF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca
[dn]
CN = Local Dev CA
[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
CONF
cleanup() {
  rm -f secrets/tls/openssl-req.cnf secrets/tls/auth.ext secrets/tls/auth.csr secrets/tls/ca.srl
}
trap cleanup EXIT

valid_file() { [[ -s "$1" ]]; }
if ! valid_file secrets/jwt/private.pem; then
  echo '[1/4] Generando clave privada JWT RS256...'
  ossl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out secrets/jwt/private.pem
fi
if ! valid_file secrets/jwt/public.pem; then
  ossl pkey -in secrets/jwt/private.pem -pubout -out secrets/jwt/public.pem
fi
if ! valid_file secrets/tls/ca.key; then
  if valid_file secrets/tls/ca.crt; then
    echo 'Existe ca.crt pero falta ca.key. Restaure la clave CA antes de continuar.' >&2
    exit 1
  fi
  echo '[2/4] Generando CA local...'
  ossl req -x509 -newkey rsa:3072 -nodes -days 365 \
    -keyout secrets/tls/ca.key -out secrets/tls/ca.crt \
    -subj '/CN=Proyecto Integrador Dev CA' -config secrets/tls/openssl-req.cnf
elif ! valid_file secrets/tls/ca.crt; then
  echo '[2/4] Recuperando certificado CA...'
  ossl req -new -x509 -key secrets/tls/ca.key -days 365 \
    -out secrets/tls/ca.crt -subj '/CN=Proyecto Integrador Dev CA' \
    -config secrets/tls/openssl-req.cnf
fi

if ! valid_file secrets/tls/auth.key && valid_file secrets/tls/auth.crt; then
  echo 'Existe auth.crt pero falta auth.key. Restaure la clave TLS antes de continuar.' >&2
  exit 1
fi
if ! valid_file secrets/tls/auth.crt; then
  echo '[3/4] Generando certificado HTTPS de AUTH...'
  printf 'subjectAltName=DNS:auth,DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' > secrets/tls/auth.ext
  if valid_file secrets/tls/auth.key; then
    ossl req -new -key secrets/tls/auth.key -out secrets/tls/auth.csr \
      -subj /CN=auth -config secrets/tls/openssl-req.cnf
  else
    ossl req -new -newkey rsa:3072 -nodes -keyout secrets/tls/auth.key \
      -out secrets/tls/auth.csr -subj /CN=auth -config secrets/tls/openssl-req.cnf
  fi
  ossl x509 -req -in secrets/tls/auth.csr -CA secrets/tls/ca.crt -CAkey secrets/tls/ca.key \
    -CAcreateserial -days 365 -extfile secrets/tls/auth.ext -out secrets/tls/auth.crt
fi
printf '[4/4] Verificando la cadena TLS...\n'
ossl verify -CAfile secrets/tls/ca.crt secrets/tls/auth.crt

# Evitar puertos de otro proyecto: cambie AUTH_PORT, STEGO_PORT, AUTH_DB_PORT si hace falta.
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 240
docker compose exec -T auth node scripts/setup-demo.mjs
docker compose ps
printf '\nAUTH: https://localhost:3001/docs\nSTEGO: http://localhost:3002/docs\n'
