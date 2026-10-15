param([string]$ToolDirectory='')
$ErrorActionPreference='Stop'
$radar=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$ToolDirectory){$ToolDirectory=Join-Path (Split-Path $radar -Parent) '数电实验2/radar/sim/tools/iverilog/app/bin'}
$out=Join-Path $radar 'unified_scan/results/scan_engine'
$work=Join-Path ([IO.Path]::GetTempPath()) ('scan_settle_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $out,$work | Out-Null
Copy-Item "$radar/rtl/radar_unified_scan.v","$PSScriptRoot/tb_scan_settle_modes.v" $work
Push-Location $work
try {
    & "$ToolDirectory/iverilog.exe" -g2012 -s tb_scan_settle_modes -o test.vvp radar_unified_scan.v tb_scan_settle_modes.v *> compile.log
    if($LASTEXITCODE){Get-Content compile.log;throw 'Icarus compile failed'}
    & "$ToolDirectory/vvp.exe" test.vvp *> simulation.log
    $rc=$LASTEXITCODE
    Get-Content simulation.log
    Copy-Item simulation.log "$out/settle_modes.log"
    Copy-Item compile.log "$out/settle_modes.compile.log"
    if($rc){throw 'PWM settle comparison failed'}
} finally {Pop-Location}
