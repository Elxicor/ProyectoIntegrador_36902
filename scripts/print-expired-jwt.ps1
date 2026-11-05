$ErrorActionPreference='Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot/backend-http.ps1"
$jwt=(Invoke-BackendRest -Method Post -Uri 'https://localhost:3001/api/auth/login' -ContentType 'application/json' -Body '{"identity":"analyst","password":"Analyst-Pass-2026!"}').access_token
$part=$jwt.Split('.')[1].Replace('-','+').Replace('_','/')
while($part.Length % 4){$part+='='}
$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
& docker compose exec -T auth node scripts/create-expired-token.mjs $p.sub $p.username $p.tokenVersion
if($LASTEXITCODE -ne 0){throw 'No se pudo generar el token expirado'}
