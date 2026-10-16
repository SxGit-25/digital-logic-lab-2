param([string]$SourceDir='', [string]$RunName='step4_busy_stop')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$SourceDir){$SourceDir="$root/radar/p5a/design/step4_source"}
$out="$PSScriptRoot/runs/$RunName"
if(Test-Path $out){throw "Output exists: $out"}
$py='C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$bin="$root/数电实验2/radar/sim/tools/iverilog/app/bin"
foreach($mode in 'basic','continuous'){
 $stage=Join-Path 'C:/Users/Metro/AppData/Local/Temp' ('p5_busy_'+[guid]::NewGuid().ToString('N'))
 $dest="$out/$mode";New-Item -ItemType Directory -Force $stage,$dest | Out-Null
 Copy-Item "$SourceDir/*.v","$PSScriptRoot/lcd_ram_bfm.v","$PSScriptRoot/tb_busy_stop.v","$root/radar/p5a/background/base/background.mem" $stage
 & $py "$PSScriptRoot/prepare_busy_stop.py" $stage --mode $mode --background "$root/radar/p5a/background/base/background_bytes.mem"
 if($LASTEXITCODE){throw 'Busy stop reference preparation failed'}
 $env:TEMP=$stage;$env:TMP=$stage
 Push-Location $stage
 try{
  $sources=@(Get-ChildItem *.v | ForEach-Object Name)
  & "$bin/iverilog.exe" -g2005-sv -Wall -DP5_BUSY_STOP_TEST -s tb_busy_stop -o test.vvp @sources *> "$dest/compile.log"
  if($LASTEXITCODE){throw 'Busy stop compile failed'}
  & "$bin/vvp.exe" test.vvp *> "$dest/simulation.log"
  if($LASTEXITCODE){throw 'Busy stop simulation failed'}
  Get-Content "$dest/simulation.log" -Tail 8
 }finally{
  Pop-Location
  Get-ChildItem "$stage/*.v" | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$dest/sources_sha256.csv" -NoTypeInformation -Encoding utf8
  Write-Output "Busy stop stage retained: $stage"
 }
}
