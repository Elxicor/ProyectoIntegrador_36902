$ErrorActionPreference='Stop'; Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot/backend-http.ps1"
$jwt=(Invoke-BackendRest -Method Post -Uri 'https://localhost:3001/api/auth/login' -ContentType 'application/json' -Body '{"identity":"analyst","password":"Analyst-Pass-2026!"}').access_token
$files=@(
 'samples/original/reference.png','samples/original/checkerboard.png','samples/original/noisy-unmodified.png',
 'samples/stego/lsb-random-payload.png','samples/stego/lsb-sparse-payload.png','samples/stego/lsb-inconclusive-pattern.png'
)
foreach($file in $files){
 $response=& curl.exe --silent --show-error --max-time 25 -H "Authorization: Bearer $jwt" -F "file=@${file};type=image/png" http://localhost:3002/api/steganography/analyze
 if($LASTEXITCODE -ne 0){throw "No se pudo analizar $file"}
 $result=($response -join '')|ConvertFrom-Json
 if(!$result.indicators){throw "Sin indicadores para $file"}
 [pscustomobject]@{Archivo=$file;Clasificacion=$result.status;Score=$result.indicators.anomaly_score;LSBunos=$result.indicators.lsb_one_ratio;Transiciones=$result.indicators.transition_rate}
 if($file -eq 'samples/original/reference.png' -and $result.status -ne 'sin_indicios'){throw "T09: la referencia original fue clasificada como $($result.status)"}
 if($file -eq 'samples/stego/lsb-random-payload.png' -and $result.status -ne 'sospechoso'){throw "T09: la muestra LSB aleatoria fue clasificada como $($result.status)"}
}
Write-Host 'T09: referencia original y modificación LSB diferenciadas correctamente.'
