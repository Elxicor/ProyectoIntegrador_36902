$ErrorActionPreference='Stop'; Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot/backend-http.ps1"
$jwt=(Invoke-BackendRest -Method Post -Uri 'https://localhost:3001/api/auth/login' -ContentType 'application/json' -Body '{"identity":"analyst","password":"Analyst-Pass-2026!"}').access_token
if(!$jwt){throw 'No se obtuvo JWT'}
$before=(& docker compose exec -T stego node -e "const D=require('better-sqlite3'); console.log(new D('/app/data/stego.db').prepare('select count(*) n from analyses').get().n)").Trim()
$cases=@(
 @('oversized.png','image/png',413),
 @('corrupt.png','image/png',422),
 @('excessive-pixels.png','image/png',422),
 @('unsupported.gif','image/gif',415),
 @('jpeg-named-png.png','image/png',415)
)
foreach($case in $cases){
 $file="samples/invalid/$($case[0])"
 $status=& curl.exe --silent --show-error --max-time 20 -o NUL -w '%{http_code}' -H "Authorization: Bearer $jwt" -F "file=@${file};type=$($case[1])" http://localhost:3002/api/steganography/analyze
 if($LASTEXITCODE -ne 0){throw "Falló conexión para $file"}
 Write-Host "T10 $($case[0]) : $status (esperado $($case[2]))"
 if([int]$status -ne [int]$case[2]){throw "HTTP inesperado para $file"}
}
$after=(& docker compose exec -T stego node -e "const D=require('better-sqlite3'); console.log(new D('/app/data/stego.db').prepare('select count(*) n from analyses').get().n)").Trim()
Write-Host "T10 análisis persistidos: $before -> $after"
if($before -ne $after){throw 'Se almacenó un archivo rechazado'}
