$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
& docker compose exec -T auth node scripts/setup-demo.mjs
if ($LASTEXITCODE -ne 0) { throw 'Fallo la preparacion de usuarios de demostracion' }
