param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
$out=Join-Path $PSScriptRoot 'shared_results'
New-Item -ItemType Directory $out -Force | Out-Null
$stage=Join-Path ([IO.Path]::GetTempPath()) ('p5_ufm_shared_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$root/radar/p5a/design/p5_ufm_reader_shared.v","$PSScriptRoot/tb_p5_ufm_reader.v","$PSScriptRoot/tb_p5_ufm_phases.v","$root/radar/p5a/background/base/background.mem" $stage
Push-Location $stage
try {
    foreach($test in @('tb_p5_ufm_reader','tb_p5_ufm_phases')) {
        & "$IverilogBin/iverilog.exe" -g2005-sv -s $test -o test.vvp p5_ufm_reader_shared.v "$test.v" *> "$out/$test.compile.log"
        if($LASTEXITCODE){throw "$test compilation failed"}
        & "$IverilogBin/vvp.exe" test.vvp *> "$out/$test.simulation.log"
        if($LASTEXITCODE){throw "$test simulation failed"}
        Get-Content "$out/$test.simulation.log"
    }
} finally {Pop-Location}
