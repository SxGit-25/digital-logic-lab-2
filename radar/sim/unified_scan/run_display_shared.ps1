param([string]$ToolDirectory='')
$ErrorActionPreference='Stop'
$radar=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$ToolDirectory){$ToolDirectory=Join-Path (Split-Path $radar -Parent) '数电实验2/radar/sim/tools/iverilog/app/bin'}
$out=Join-Path $radar 'unified_scan/results/display_shared'
$work=Join-Path ([IO.Path]::GetTempPath()) ('shared_display_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $out,$work | Out-Null
Copy-Item "$radar/rtl/radar_display_shared.v","$radar/rtl/display_compose.v","$PSScriptRoot/tb_display_shared.v" $work
Push-Location $work
try {
    & "$ToolDirectory/iverilog.exe" -g2012 -s tb_display_shared -o test.vvp radar_display_shared.v display_compose.v tb_display_shared.v *> compile.log
    if($LASTEXITCODE){Get-Content compile.log;throw 'Icarus compile failed'}
    & "$ToolDirectory/vvp.exe" test.vvp *> simulation.log
    $rc=$LASTEXITCODE
    Get-Content simulation.log
    Copy-Item simulation.log,compile.log,tb_display_shared.v "$out/"
    if($rc){throw 'Shared display regression failed'}
} finally {Pop-Location}
