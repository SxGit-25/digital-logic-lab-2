param(
 [Parameter(Mandatory=$true)][string]$RunName,
 [string]$SourceDir='',
 [string]$Background='',
 [switch]$Smoke,
 [switch]$RealTiming,
 [switch]$ProductionInit,
 [switch]$Beam,
 [ValidateSet('basic','continuous')][string[]]$Modes=@('basic','continuous'),
 [string]$IverilogBin=''
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$SourceDir){$SourceDir="$root/radar/rtl"}
if(!$Background){$Background="$root/radar/p5a/background/base/background_bytes.mem"}
if(!$IverilogBin){$IverilogBin="$root/数电实验2/radar/sim/tools/iverilog/app/bin"}
$python='C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$out="$PSScriptRoot/runs/$RunName"
if(Test-Path $out){throw "Output exists: $out"}
New-Item -ItemType Directory -Force $out | Out-Null
foreach($mode in $Modes){
 $stage=Join-Path 'C:/Users/Metro/AppData/Local/Temp' ('p5_render_'+[guid]::NewGuid().ToString('N'))
 $dest="$out/$mode"
 New-Item -ItemType Directory -Force $stage,$dest | Out-Null
 $env:TEMP=$stage;$env:TMP=$stage
 Copy-Item "$SourceDir/*.v","$PSScriptRoot/lcd_ram_bfm.v","$PSScriptRoot/tb_render.v" -Destination $stage
 # Behavior UFM model and its initialization words share exactly the image used
 # by synthesis. Production model naming is left unmodified.
 $backgroundDir=Split-Path -Parent $Background
 Copy-Item "$backgroundDir/background.mem" -Destination "$stage/background.mem"
 Copy-Item "$backgroundDir/background.mif" -Destination "$stage/background.mif"
 $options=@();if($Smoke){$options+='--smoke'};if($Beam){$options+='--beam'}
 & $python "$PSScriptRoot/reference.py" prepare $stage --background $Background --mode $mode @options
 if($LASTEXITCODE){throw 'Reference preparation failed'}
 Push-Location $stage
 try{
  $sources=@(Get-ChildItem *.v | ForEach-Object Name)
  $real=[int]$RealTiming.IsPresent
  $production=[int]$ProductionInit.IsPresent
  & "$IverilogBin/iverilog.exe" -g2005-sv -Wall -s tb_render "-Ptb_render.REAL_TIMING=$real" "-Ptb_render.PRODUCTION_INIT=$production" -o test.vvp @sources *> "$dest/compile.log"
  if($LASTEXITCODE){throw "Compile failed: $dest/compile.log"}
  & "$IverilogBin/vvp.exe" test.vvp *> "$dest/simulation.log"
  $simExit=$LASTEXITCODE
  Get-Content "$dest/simulation.log" -Tail 10
  if($simExit){throw 'RAM simulation failed'}
  & $python "$PSScriptRoot/reference.py" compare $stage *> "$dest/comparison.log"
  if($LASTEXITCODE){throw 'Python byte comparison failed'}
 }finally{
  Pop-Location
  Get-ChildItem $stage -File | Where-Object {$_.Extension -in '.v','.vh','.mem','.json','.png','.csv'} | Copy-Item -Destination $dest
  Get-ChildItem "$stage/*.v" | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$dest/sources_sha256.csv" -NoTypeInformation -Encoding utf8
  Write-Output "Simulation stage retained: $stage"
 }
}
