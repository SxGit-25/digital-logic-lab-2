param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('matrix_latency_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $root 'radar/unified_scan/results/matrix_latency'
New-Item -ItemType Directory -Force $stage,$out | Out-Null
Copy-Item "$root/radar/rtl/display_compose.v","$root/radar/rtl/matrix_scan.v","$PSScriptRoot/tb_matrix_latency.v" $stage
Push-Location $stage
try{
 & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_matrix_latency -o test.vvp *.v *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Compile failure'}
 & "$IverilogBin/vvp.exe" test.vvp *> "$out/simulation.log"
 $code=$LASTEXITCODE;Get-Content "$out/simulation.log"
 Get-ChildItem *.v | ForEach-Object {[PSCustomObject]@{File=$_.Name;SHA256=(Get-FileHash $_.FullName).Hash}} | Export-Csv "$out/source_sha256.csv" -NoTypeInformation
 if($code){throw 'Simulation failure'}
}finally{Pop-Location}
