param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('p5_ufm_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$root/radar/rtl/p5_ufm_reader.v","$PSScriptRoot/tb_p5_ufm_reader.v","$root/radar/p5a/background/base/background.mem" $stage
Push-Location $stage
try {
    & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_p5_ufm_reader -o test.vvp p5_ufm_reader.v tb_p5_ufm_reader.v *> "$PSScriptRoot/compile.log"
    if($LASTEXITCODE){throw 'UFM test compilation failed'}
    & "$IverilogBin/vvp.exe" test.vvp *> "$PSScriptRoot/simulation.log"
    if($LASTEXITCODE){throw 'UFM simulation failed'}
    Get-Content "$PSScriptRoot/simulation.log"
} finally {Pop-Location}
