$ErrorActionPreference='Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host 'Verificando Docker Compose y preparando usuarios...'
& docker compose ps
if($LASTEXITCODE -ne 0){throw 'Docker Compose no está disponible'}
& "$PSScriptRoot/setup-demo.ps1"
# El arranque inicial también realiza login. Esperar al inicio permite ejecutar
# la batería sin que el Throttle de 5 intentos/min de AUTH produzca falsos 429.
Write-Host 'Sincronizando ventana de rate limit de login (65 s)...'
Start-Sleep -Seconds 65
Write-Host 'T02-T07, T11, T12: usuarios, contraseña, JWT y permisos'
& "$PSScriptRoot/test-core-security.ps1"
Write-Host 'T09: muestras originales, modificadas y no concluyentes'
& "$PSScriptRoot/test-detector.ps1"
Write-Host 'Segunda pausa para respetar límite de cinco logins/min (65 s)...'
Start-Sleep -Seconds 65
Write-Host 'T10: archivos rechazados sin persistencia'
& "$PSScriptRoot/test-t10.ps1"
Write-Host 'JWT especiales y logout'
& "$PSScriptRoot/test-jwt-special.ps1"
Write-Host 'T01 y T08: separación y fallo seguro'
& "$PSScriptRoot/test-independence.ps1"

Write-Host "Respetando ventana de rate limit antes de T08..."
Start-Sleep -Seconds 65

& "$PSScriptRoot/test-fail-closed.ps1"
Write-Host 'Estado final:'
& docker compose ps
Write-Host 'Suite completa terminada. Revise los mensajes de cada caso.'
