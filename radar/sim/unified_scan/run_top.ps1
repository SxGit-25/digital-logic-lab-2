param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('unified_top_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $root 'radar/unified_scan/results/top_integration'
New-Item -ItemType Directory -Force $stage,$out | Out-Null
Copy-Item "$root/radar/rtl/*.v","$root/radar/sim/lcd/st7565_model.v","$PSScriptRoot/tb_unified_top.v" $stage
Push-Location $stage
try{
 $rtl=@(Get-ChildItem *.v | ForEach-Object Name)
 & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_unified_top -o top.vvp @rtl *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Top compile failed'}
 & "$IverilogBin/vvp.exe" top.vvp *> "$out/simulation.log"
 $code=$LASTEXITCODE;Get-Content "$out/simulation.log" -Tail 8
 Get-ChildItem *.v | ForEach-Object {[PSCustomObject]@{File=$_.Name;SHA256=(Get-FileHash $_.FullName).Hash}} | Export-Csv "$out/source_sha256.csv" -NoTypeInformation
 if($code){throw "Top simulation failed $code"}
}finally{Pop-Location}
