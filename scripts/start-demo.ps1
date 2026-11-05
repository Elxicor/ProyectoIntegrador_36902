$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
& "$PSScriptRoot/generate-secrets.ps1"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar la configuracion local' }
& docker compose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'docker-compose.yml no es valido' }
& docker compose up -d --build --wait --wait-timeout 240
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron iniciar los contenedores' }
& "$PSScriptRoot/setup-demo.ps1"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar la demostracion' }
& docker compose ps
Write-Host 'AUTH:  https://localhost:3001/docs'
Write-Host 'STEGO: http://localhost:3002/docs'
