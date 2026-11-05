$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot/backend-http.ps1"
function Login($identity,$password) {
  (Invoke-BackendRest -Uri 'https://localhost:3001/api/auth/login' -Method Post -ContentType 'application/json' -Body (@{identity=$identity;password=$password}|ConvertTo-Json)).access_token
}
function HttpCode([string[]]$arguments) {
  $code = & curl.exe @arguments
  if ($LASTEXITCODE -ne 0) { throw "curl falló: $($arguments -join ' ')" }
  return [int]$code
}
$bad=0
try { Invoke-BackendRest -Method Post -Uri 'https://localhost:3001/api/auth/login' -ContentType 'application/json' -Body '{"identity":"admin","password":"invalid-password"}' | Out-Null }
catch { $bad=[int]$_.Exception.Data['StatusCode'] }
$admin = Login 'admin' 'ChangeMe-Admin-2026!'
$analyst = Login 'analyst' 'Analyst-Pass-2026!'
$user = Login 'user' 'User-Secure-2026!'
Write-Host "T02: login correcto=JWT, contraseña incorrecta=$bad"
$claims = $analyst.Split('.')[1].Replace('-','+').Replace('_','/'); while($claims.Length % 4){$claims+='='}
$payload=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($claims)) | ConvertFrom-Json
$expired=(& docker compose exec -T auth node scripts/create-expired-token.mjs $payload.sub $payload.username $payload.tokenVersion).Trim()
if ($LASTEXITCODE -ne 0 -or !$expired) { throw 'No se pudo generar el JWT expirado desde AUTH' }
$api='http://localhost:3002/api/steganography'
$without=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}',"$api/results/x")
$altered=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $($analyst.Substring(0,$analyst.Length-2))xx","$api/results/x")
$expiredStatus=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $expired","$api/results/x")
Write-Host "T03: sin JWT=$without; alterado=$altered; expirado=$expiredStatus"
$denied=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $user",'-F','file=@samples/original/reference.png;type=image/png',"$api/analyze")
Write-Host "T04: USER intenta analizar=$denied"
$relations= & docker compose exec -T auth-db psql -U auth -d auth -At -F ',' -c 'select u.username,r.name from user_roles ur join users u on u.id=ur.user_id join roles r on r.id=ur.role_id order by 1,2'
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron consultar las asignaciones en PostgreSQL' }
Write-Host "T05: relaciones N:M: $($relations -join '; ')"
$ids=(& docker compose exec -T auth-db psql -U auth -d auth -At -F ',' -c "select u.id,r.id,ur.id from users u cross join roles r left join user_roles ur on ur.user_id=u.id and ur.role_id=r.id where u.username='analyst' and r.name='ANALYST'").Trim().Split(',')
if ($ids.Length -lt 3 -or !$ids[2]) { throw 'Falta la asignacion ANALYST para la demostracion' }
$body=@{userId=$ids[0];roleId=$ids[1]}|ConvertTo-Json -Compress
$duplicate=0
try { Invoke-BackendRest -Uri 'https://localhost:3001/api/user-roles' -Method Post -Headers @{Authorization="Bearer $admin"} -ContentType 'application/json' -Body $body | Out-Null }
catch { $duplicate=[int]$_.Exception.Data['StatusCode'] }
Write-Host "T06: asignación duplicada=$duplicate"
$before=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $analyst",'-F','file=@samples/original/reference.png;type=image/png',"$api/analyze")
try {
  Invoke-BackendRest -Uri "https://localhost:3001/api/user-roles/$($ids[2])" -Method Delete -Headers @{ Authorization="Bearer $admin" } | Out-Null
  $after=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $analyst",'-F','file=@samples/original/reference.png;type=image/png',"$api/analyze")
  Write-Host "T07: antes=$before; después con MISMO JWT=$after"
} finally {
  try { Invoke-BackendRest -Uri 'https://localhost:3001/api/user-roles' -Method Post -Headers @{ Authorization="Bearer $admin" } -ContentType 'application/json' -Body $body | Out-Null } catch { Write-Warning 'No se pudo restaurar ANALYST; ejecute setup-demo.ps1' }
}
$result=(& curl.exe -s -H "Authorization: Bearer $admin" -F 'file=@samples/original/reference.png;type=image/png' "$api/analyze") | ConvertFrom-Json
if (!$result.id) { throw 'No se generó un análisis ADMIN para la prueba horizontal' }
$horizontal=HttpCode -arguments @('--silent','-o','NUL','-w','%{http_code}','-H',"Authorization: Bearer $analyst","$api/results/$($result.id)")
Write-Host "T11: resultado ajeno=$horizontal"
$authEvents=(@(docker compose logs --no-color --since 3m auth | Select-String 'authentication_|authorization_decision')).Count
$stegoEvents=(@(docker compose logs --no-color --since 3m stego | Select-String 'analysis_|request_denied')).Count
Write-Host "T12: auth_eventos=$authEvents; stego_eventos=$stegoEvents"
if($authEvents -lt 1 -or $stegoEvents -lt 1){throw 'T12: no se encontraron eventos de auditoría en ambos servicios'}
$observed=@($bad,$without,$altered,$expiredStatus,$denied,$duplicate,$before,$after,$horizontal)
$expected=@(401,401,401,401,403,409,201,403,403)
for($i=0;$i -lt $expected.Count;$i++){if($observed[$i] -ne $expected[$i]){throw "Prueba ${i}: esperado $($expected[$i]), obtenido $($observed[$i])"}}
Write-Host 'T02-T07, T11 y T12: escenarios HTTP principales correctos.'
