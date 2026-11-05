$ErrorActionPreference='Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$required=@(
 'README.md','docker-compose.yml','.gitignore','.env.example',
 'auth/Dockerfile','auth/.env.example','auth/package-lock.json','auth/src/main.ts','auth/src/migrations/1793740000000-InitialIdentity.ts',
 'stego/Dockerfile','stego/.env.example','stego/package-lock.json','stego/src/main.ts',
 'scripts/start-demo.ps1','scripts/setup-demo.ps1','scripts/test-all.ps1',
 'samples/original/reference.png','samples/stego/lsb-random-payload.png',
 'postman_collection.json','postman_environment.json',
 'documentacion/main.tex','documentacion/main.pdf',
 'documentacion/openapi/auth.openapi.yaml','documentacion/openapi/stego.openapi.yaml'
)
$missing=@($required | Where-Object { !(Test-Path -LiteralPath $_) })
if($missing.Count -gt 0){throw "Faltan archivos: $($missing -join ', ')"}
& docker compose config --quiet
if($LASTEXITCODE -ne 0){throw 'Docker Compose no valido; antes de verificar prepare secrets con generate-secrets.ps1'}
Write-Host 'Archivos y configuración Docker Compose verificados.'
