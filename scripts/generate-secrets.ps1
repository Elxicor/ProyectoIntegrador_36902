# Generacion reproducible de claves JWT y certificados TLS para la demostracion.
# Compatible con PowerShell 5.1 y 7. No depende del OPENSSL_CONF del equipo.
# Si una ejecucion anterior se interrumpio, completa los archivos faltantes.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$jwt = Join-Path $root 'secrets/jwt'
$tls = Join-Path $root 'secrets/tls'
New-Item -ItemType Directory -Force -Path $jwt, $tls | Out-Null

function Has-File([string]$relative) {
  $path = Join-Path $root $relative
  return ((Test-Path -LiteralPath $path -PathType Leaf) -and ((Get-Item -LiteralPath $path).Length -gt 0))
}

$serviceFile = Join-Path $root 'secrets/service.env'
if (!(Test-Path -LiteralPath $serviceFile)) {
  $buffer = New-Object 'System.Byte[]' 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
  $token = [BitConverter]::ToString($buffer).Replace('-', '').ToLowerInvariant()
  [IO.File]::WriteAllText($serviceFile, "STEGO_SERVICE_TOKEN=$token`n")
}
$serviceValue = ([IO.File]::ReadAllText($serviceFile)).Trim()
if ($serviceValue -cnotmatch '^STEGO_SERVICE_TOKEN=[0-9a-f]{64}$') {
  throw 'secrets/service.env tiene formato invalido. Revise el archivo.'
}

$required = @(
  'secrets/jwt/private.pem', 'secrets/jwt/public.pem',
  'secrets/tls/ca.key', 'secrets/tls/ca.crt',
  'secrets/tls/auth.key', 'secrets/tls/auth.crt'
)
if (@($required | Where-Object { !(Has-File $_) }).Count -eq 0) {
  Write-Host 'Claves y certificados presentes: se conserva la configuracion existente.'
  exit 0
}

$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (!$openssl) {
  $opensslPath = @(
    'C:\Program Files\Git\usr\bin\openssl.exe',
    'C:\Program Files\Git\mingw64\bin\openssl.exe'
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if ($opensslPath) { $openssl = @{ Source = $opensslPath } }
}

function Run-OpenSSL([string[]]$argsList) {
  if ($script:openssl) {
    & $script:openssl.Source @argsList
  } else {
    # Si no hay openssl local, usar un contenedor temporal (requiere Docker).
    $mount = "type=bind,source=$root,target=/work"
    & docker run --rm --mount $mount -w /work alpine:3.20 sh -c 'apk add --no-cache openssl >/dev/null && exec openssl "$@"' -- @argsList
  }
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL fallo con $($argsList[0])" }
}

# OpenSSL para Windows puede heredar OPENSSL_CONF de PostgreSQL/psqlODBC,
# apuntando a un openssl.cnf inexistente. -config evita depender de esa variable.
$configRelative = 'secrets/tls/openssl-req.cnf'
$configFile = Join-Path $root $configRelative
[IO.File]::WriteAllText($configFile, "[req]`ndistinguished_name = dn`nprompt = no`nx509_extensions = v3_ca`n[dn]`nCN = Local Dev CA`n[v3_ca]`nbasicConstraints = critical, CA:TRUE`nkeyUsage = critical, keyCertSign, cRLSign`nsubjectKeyIdentifier = hash`n")
$ext = Join-Path $tls 'auth.ext'
try {
  if (!(Has-File 'secrets/jwt/private.pem')) {
    Write-Host '[1/4] Generando clave privada JWT RS256...'
    Run-OpenSSL @('genpkey','-algorithm','RSA','-pkeyopt','rsa_keygen_bits:3072','-out','secrets/jwt/private.pem')
  }
  if (!(Has-File 'secrets/jwt/public.pem')) {
    Write-Host '[1/4] Extrayendo clave publica JWT...'
    Run-OpenSSL @('pkey','-in','secrets/jwt/private.pem','-pubout','-out','secrets/jwt/public.pem')
  }
  if (!(Has-File 'secrets/tls/ca.key')) {
    if (Has-File 'secrets/tls/ca.crt') {
      throw 'Existe ca.crt pero falta ca.key. Restaure la clave CA o regenere el par de certificados TLS.'
    }
    Write-Host '[2/4] Generando CA local...'
    Run-OpenSSL @('req','-x509','-newkey','rsa:3072','-nodes','-days','365',
      '-keyout','secrets/tls/ca.key','-out','secrets/tls/ca.crt',
      '-subj','/CN=Proyecto Integrador Dev CA','-config',$configRelative)
  } elseif (!(Has-File 'secrets/tls/ca.crt')) {
    # Recuperacion de una ejecucion interrumpida: la clave CA ya existe.
    Write-Host '[2/4] Recuperando certificado CA a partir de ca.key...'
    Run-OpenSSL @('req','-new','-x509','-key','secrets/tls/ca.key','-days','365',
      '-out','secrets/tls/ca.crt','-subj','/CN=Proyecto Integrador Dev CA',
      '-config',$configRelative)
  }

  if (!(Has-File 'secrets/tls/auth.key') -and (Has-File 'secrets/tls/auth.crt')) {
    throw 'Existe auth.crt pero falta auth.key. Restaure la clave TLS o regenere el par de certificados TLS.'
  }
  if (!(Has-File 'secrets/tls/auth.crt')) {
    Write-Host '[3/4] Generando certificado HTTPS para auth y localhost...'
    [IO.File]::WriteAllText($ext, "subjectAltName=DNS:auth,DNS:localhost,IP:127.0.0.1`nextendedKeyUsage=serverAuth`n")
    if (Has-File 'secrets/tls/auth.key') {
      Run-OpenSSL @('req','-new','-key','secrets/tls/auth.key','-out','secrets/tls/auth.csr',
        '-subj','/CN=auth','-config',$configRelative)
    } else {
      Run-OpenSSL @('req','-new','-newkey','rsa:3072','-nodes','-keyout','secrets/tls/auth.key',
        '-out','secrets/tls/auth.csr','-subj','/CN=auth','-config',$configRelative)
    }
    Run-OpenSSL @('x509','-req','-in','secrets/tls/auth.csr','-CA','secrets/tls/ca.crt',
      '-CAkey','secrets/tls/ca.key','-CAcreateserial','-days','365',
      '-extfile','secrets/tls/auth.ext','-out','secrets/tls/auth.crt')
  }
  Write-Host '[4/4] Comprobando archivos generados...'
  $missing = @($required | Where-Object { !(Has-File $_) })
  if ($missing.Count -gt 0) { throw "Faltan certificados: $($missing -join ', ')" }
  Run-OpenSSL @('verify','-CAfile','secrets/tls/ca.crt','secrets/tls/auth.crt')
  Write-Host 'Certificados y claves listos para Docker Compose.'
} finally {
  Remove-Item -LiteralPath $configFile,$ext,(Join-Path $tls 'auth.csr'),(Join-Path $tls 'ca.srl') -ErrorAction SilentlyContinue
}
