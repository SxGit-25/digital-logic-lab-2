param([Parameter(Mandatory=$true)][string]$RunName,[string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin="$root/数电实验2/radar/sim/tools/iverilog/app/bin"}
$python='C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$out="$PSScriptRoot/../runs/$RunName"
if(Test-Path $out){throw "Output exists: $out"}
New-Item -ItemType Directory -Force $out | Out-Null
foreach($mode in 'basic','continuous','pending') {
 $stage=Join-Path ([IO.Path]::GetTempPath()) ('p5_step1_'+[guid]::NewGuid().ToString('N'))
 $dest="$out/$mode";New-Item -ItemType Directory -Force $stage,$dest | Out-Null
 Copy-Item "$root/radar/rtl/*.v","$root/radar/sim/lcd/st7565_model.v" $stage
 if($mode -eq 'pending'){Copy-Item "$PSScriptRoot/tb_step1_pending.v" $stage;$top='tb_step1_pending';$argsForCase=@()}
 else {
  & $python "$PSScriptRoot/prepare_step1.py" $stage --mode $mode
  if($LASTEXITCODE){throw 'Fixture generation failed'}
  $top='tb_minsky_draw';$argsForCase=@('-Ptb_minsky_draw.F=15','-Ptb_minsky_draw.K=7','-Ptb_minsky_draw.PHASE_BITS=6','-Ptb_minsky_draw.PHASE_INITIAL=63','-Ptb_minsky_draw.MICRO_BASE=2')
 }
 Push-Location $stage
 try {
  $sources=@(Get-ChildItem *.v | ForEach-Object Name)
  & "$IverilogBin/iverilog.exe" -g2005-sv -Wall -s $top @argsForCase -o test.vvp @sources *> "$dest/compile.log"
  if($LASTEXITCODE){throw "$mode compilation failed"}
  & "$IverilogBin/vvp.exe" test.vvp *> "$dest/simulation.log"
  $rc=$LASTEXITCODE;Get-Content "$dest/simulation.log" -Tail 5
  Get-ChildItem -File | Where-Object {$_.Extension -in '.v','.vh','.hex','.csv','.json','.pbm'} | Copy-Item -Destination $dest
  Get-ChildItem *.v | Get-FileHash | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$dest/sources_sha256.csv" -NoTypeInformation
  if($rc){throw "$mode simulation failed"}
 }finally{Pop-Location;Write-Output "Work retained: $stage"}
}
