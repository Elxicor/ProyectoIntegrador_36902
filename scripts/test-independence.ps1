$ErrorActionPreference='Stop'; $root=Split-Path -Parent $PSScriptRoot; Set-Location -LiteralPath $root
& docker compose stop stego | Out-Null
if($LASTEXITCODE -ne 0){throw 'T01: no se pudo detener STEGO'}
try {
  $code=& curl.exe --max-time 5 -s -o NUL -w '%{http_code}' --ssl-no-revoke --cacert .\secrets\tls\ca.crt https://localhost:3001/health
  if($LASTEXITCODE -ne 0 -or [int]$code -ne 200){throw "T01: AUTH no permaneció operativo; HTTP=$code"}
  Write-Output "T01 auth_with_stego_stopped=$code"
} finally {
  & docker compose start stego | Out-Null
  if($LASTEXITCODE -ne 0){throw 'T01: no se pudo restaurar STEGO'}
}
& docker compose up -d --wait --wait-timeout 60 stego | Out-Null
if($LASTEXITCODE -ne 0){throw 'T01: STEGO no volvió a estado saludable'}
Write-Host 'T01: independencia y restauración verificadas.'
