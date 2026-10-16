param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
python "$PSScriptRoot/reference.py"
if($LASTEXITCODE){throw 'Python reference generation failed'}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('p5_ui_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$root/radar/rtl/p5_ui_columns.v","$PSScriptRoot/tb_p5_ui_columns.v","$PSScriptRoot/vectors.mem","$PSScriptRoot/vectors_count.vh" $stage
Push-Location $stage
try {
    & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_p5_ui_columns -o test.vvp p5_ui_columns.v tb_p5_ui_columns.v *> "$PSScriptRoot/compile.log"
    if($LASTEXITCODE){throw 'UI test compilation failed'}
    & "$IverilogBin/vvp.exe" test.vvp *> "$PSScriptRoot/simulation.log"
    if($LASTEXITCODE){throw 'UI simulation failed'}
    Get-Content "$PSScriptRoot/simulation.log"
} finally {Pop-Location}
