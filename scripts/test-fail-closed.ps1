$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
function Get-T08Token {
  for($attempt=1;$attempt -le 2;$attempt++){
    $responseFile=[IO.Path]::GetTempFileName()
    $requestFile=[IO.Path]::GetTempFileName()
    try {
      $requestBody=@{identity='analyst';password='Analyst-Pass-2026!'} | ConvertTo-Json -Compress
      [IO.File]::WriteAllText($requestFile,$requestBody,(New-Object System.Text.UTF8Encoding($false)))
      $status=& curl.exe --silent --show-error --max-time 10 --ssl-no-revoke --cacert .\secrets\tls\ca.crt -o $responseFile -w '%{http_code}' -H 'Content-Type: application/json' --data-binary "@$requestFile" https://localhost:3001/api/auth/login
      if($LASTEXITCODE -ne 0){throw "T08: curl falló al obtener JWT (salida $LASTEXITCODE)"}
      Write-Host "T08 login previo: HTTP $status (intento $attempt/2)"
      if([int]$status -eq 201){
        $login=Get-Content -LiteralPath $responseFile -Raw | ConvertFrom-Json
        if(!$login.access_token){throw 'T08: AUTH respondió 201 sin access_token'}
        return $login.access_token
      }
      if([int]$status -eq 429 -and $attempt -lt 2){
        Write-Host 'T08: rate limit activo; reintento único después de 65 s.'
        Start-Sleep -Seconds 65
        continue
      }
      $body=Get-Content -LiteralPath $responseFile -Raw
      throw "T08: no se pudo obtener el JWT previo; HTTP $status; respuesta: $body"
    } finally {
      Remove-Item -LiteralPath $responseFile -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $requestFile -ErrorAction SilentlyContinue
    }
  }
}
$token=Get-T08Token
& docker compose stop auth | Out-Null
if($LASTEXITCODE -ne 0){throw 'T08: no se pudo detener AUTH'}
try {
  $code = & curl.exe --max-time 8 --silent --show-error -o NUL -w '%{http_code}' -H "Authorization: Bearer $token" -F 'file=@samples/original/reference.png;type=image/png' http://localhost:3002/api/steganography/analyze
  if($LASTEXITCODE -ne 0 -or [int]$code -ne 503){throw "T08: esperado 503 con AUTH detenido, obtenido $code"}
  Write-Output "T08 auth_down=$code"
} finally {
  & docker compose start auth | Out-Null
  if($LASTEXITCODE -ne 0){throw 'T08: no se pudo restaurar AUTH'}
}
& docker compose up -d --wait --wait-timeout 60 auth | Out-Null
if($LASTEXITCODE -ne 0){throw 'T08: AUTH no volvió a estado saludable'}
$health = & curl.exe --max-time 5 -s -o NUL -w '%{http_code}' --ssl-no-revoke --cacert .\secrets\tls\ca.crt https://localhost:3001/health
if($LASTEXITCODE -ne 0 -or [int]$health -ne 200){throw "T08: AUTH no fue restaurado; HTTP=$health"}
Write-Output "AUTH restored=$health"
Write-Host 'T08: fallo cerrado y restauración verificados.'
