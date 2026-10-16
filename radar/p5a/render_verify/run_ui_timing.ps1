param([string]$RunName='ui_real_timing',[string]$CoreSource='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$CoreSource){$CoreSource="$root/radar/p5a/design/radar_lcd_micro_ui_specialized.v"}
$out="$PSScriptRoot/runs/$RunName"
if(Test-Path $out){throw "Output exists: $out"}
New-Item -ItemType Directory -Force $out | Out-Null
$stage=Join-Path 'C:/Users/Metro/AppData/Local/Temp' ('p5_ui_real_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item $CoreSource "$stage/radar_lcd_micro.v"
Copy-Item "$root/radar/rtl/minsky_serial_datapath.v","$root/radar/rtl/lcd_bus_phase.v","$root/radar/rtl/p5_ui_columns.v","$root/radar/p5a/design/step3_source/p5_ufm_reader.v","$root/radar/p5a/background/base/background.mem","$PSScriptRoot/tb_p5_ui_timing.v" $stage
$bin="$root/数电实验2/radar/sim/tools/iverilog/app/bin"
$py='C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$env:TEMP=$stage;$env:TMP=$stage
Push-Location $stage
try{
 foreach($flags in '100','010','001'){
  $params=@("-Ptb_p5_ui_timing.P5_DIGITS=$($flags[0])","-Ptb_p5_ui_timing.P5_MODE=$($flags[1])","-Ptb_p5_ui_timing.P5_LEVEL=$($flags[2])")
  & "$bin/iverilog.exe" -g2005-sv -Wall -s tb_p5_ui_timing @params -o test.vvp radar_lcd_micro.v minsky_serial_datapath.v lcd_bus_phase.v p5_ui_columns.v p5_ufm_reader.v tb_p5_ui_timing.v *> "$out/$flags.compile.log"
  if($LASTEXITCODE){throw "UI timing compile $flags failed"}
  & "$bin/vvp.exe" test.vvp *> "$out/$flags.simulation.log"
  if($LASTEXITCODE){throw "UI timing simulation $flags failed"}
  & $py "$root/radar/p5a/ui/check_core_stream.py" "$out/$flags.simulation.log" $flags *> "$out/$flags.reference.log"
  if($LASTEXITCODE){throw "UI timing reference $flags failed"}
  Get-Content "$out/$flags.simulation.log" | Select-String 'UI_TIMING|PASS'
 }
}finally{
 Pop-Location
 Get-ChildItem "$stage/*.v" | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$out/sources_sha256.csv" -NoTypeInformation -Encoding utf8
 Write-Output "UI timing stage retained: $stage"
}
