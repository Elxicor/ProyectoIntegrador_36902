$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot/backend-http.ps1"
function Login {
 param([string]$Identity='analyst',[string]$Password='Analyst-Pass-2026!')
 (Invoke-BackendRest -Method Post -Uri 'https://localhost:3001/api/auth/login' -ContentType 'application/json' -Body (@{identity=$Identity;password=$Password}|ConvertTo-Json -Compress)).access_token
}
$token=Login
$variantsJson = & docker compose exec -T auth node scripts/create-jwt-variants.mjs $token
if($LASTEXITCODE -ne 0){throw 'No se pudieron preparar variantes de JWT dentro de AUTH'}
$variants=($variantsJson -join '')|ConvertFrom-Json
$rows=@()
foreach($name in @('tamperedUsername','tamperedSub','fakeRoles','wrongIssuer','wrongAudience','algNone')) {
  $candidate=$variants.$name
  $http=& curl.exe --silent --show-error -o NUL -w '%{http_code}' -H "Authorization: Bearer $candidate" http://localhost:3002/api/steganography/results/x
  if($LASTEXITCODE -ne 0){throw "Error de conexión en $name"}
  $rows += [pscustomobject]@{Caso=$name;HTTP=[int]$http}
  if([int]$http -ne 401){throw "La variante $name respondió $http y no 401"}
}
$userToken=Login 'user' 'User-Secure-2026!'
$userVariantsJson=& docker compose exec -T auth node scripts/create-jwt-variants.mjs $userToken
if($LASTEXITCODE -ne 0){throw 'No se pudo preparar el JWT USER con rol falsificado'}
$signedFakeRoles=(($userVariantsJson -join '')|ConvertFrom-Json).signedFakeRoles
$fakeRoleHTTP=& curl.exe --silent --show-error -o NUL -w '%{http_code}' -H "Authorization: Bearer $signedFakeRoles" -F 'file=@samples/original/reference.png;type=image/png' http://localhost:3002/api/steganography/analyze
if($LASTEXITCODE -ne 0 -or [int]$fakeRoleHTTP -ne 403){throw "Rol falsificado firmado: esperado 403, obtenido $fakeRoleHTTP"}
$rows += [pscustomobject]@{Caso='signedFakeRoles';HTTP=[int]$fakeRoleHTTP}
$logoutToken=Login
Invoke-BackendRest -Uri 'https://localhost:3001/api/auth/logout' -Method Post -Headers @{Authorization="Bearer $logoutToken"} | Out-Null
$logoutHTTP=& curl.exe --silent --show-error -o NUL -w '%{http_code}' -H "Authorization: Bearer $logoutToken" -F 'file=@samples/original/reference.png;type=image/png' http://localhost:3002/api/steganography/analyze
if([int]$logoutHTTP -ne 401){throw "Logout: esperado 401, obtenido $logoutHTTP"}
$rows|Format-Table -AutoSize
Write-Host "JWT anterior después de logout: $logoutHTTP"
Write-Host 'Todos los casos especiales de JWT fueron rechazados correctamente.'
