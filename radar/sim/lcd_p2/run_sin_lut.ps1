param([string]$IverilogBin = '')
$ErrorActionPreference = 'Stop'
$radarRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$repoRoot = Split-Path $radarRoot -Parent
if (!$IverilogBin) {
    $candidates=@("$repoRoot/radar/sim/tools/iverilog/app/bin")
    $candidates+=Get-ChildItem -LiteralPath $repoRoot -Directory | ForEach-Object {
        Join-Path $_.FullName 'radar/sim/tools/iverilog/app/bin'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath "$candidate/iverilog.exe") {
            $IverilogBin=$candidate
            break
        }
    }
}
if (!(Test-Path -LiteralPath "$IverilogBin/iverilog.exe")) {
    throw 'Provide -IverilogBin pointing to the directory containing iverilog.exe and vvp.exe.'
}
$IverilogBin=$IverilogBin.Replace('\','/')
$stage=Join-Path ([IO.Path]::GetTempPath()) ('lcd_p2_lut_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item "$radarRoot/rtl/lcd_sin_lut.v", "$PSScriptRoot/tb_sin_lut.v" $stage
$output=Join-Path $radarRoot 'lcd_p2/results/sin_lut'
New-Item -ItemType Directory -Force $output | Out-Null
Push-Location $stage
try {
    & python -c "import math;from pathlib import Path;Path('sin_reference.hex').write_text(''.join(f'{int(math.sin(math.radians(a))*256+0.5):03x}'+chr(10) for a in range(91)),encoding='ascii')"
    if ($LASTEXITCODE -ne 0) { throw 'Python reference generation failed.' }
    & "$IverilogBin/iverilog.exe" -g2012 -s tb_sin_lut -o sin_lut.vvp lcd_sin_lut.v tb_sin_lut.v
    if ($LASTEXITCODE -ne 0) { throw 'Icarus compile failed.' }
    & "$IverilogBin/vvp.exe" sin_lut.vvp | Tee-Object -FilePath "$output/sin_lut.log"
    if ($LASTEXITCODE -ne 0) { throw 'LUT verification failed.' }
} finally {
    Pop-Location
    Write-Host "Verification stage: $stage"
}
