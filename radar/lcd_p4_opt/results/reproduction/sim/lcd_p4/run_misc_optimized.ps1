param([Parameter(Mandatory=$true)][string]$ToolDirectory)
$ErrorActionPreference='Stop'
$radar=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$work=Join-Path ([IO.Path]::GetTempPath()) ('lcd_misc_'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $radar 'lcd_p4_opt/results/misc'
New-Item -ItemType Directory -Force $work,$out | Out-Null
Copy-Item "$radar/rtl/lcd_init.v","$radar/rtl/lcd_bus.v","$radar/rtl/reset_ctrl.v","$radar/sim/lcd/st7565_model.v","$PSScriptRoot/tb_init_coarse.v","$PSScriptRoot/tb_reset_compact.v" $work
Push-Location $work
try {
 foreach($name in 'init_coarse','reset_compact'){
  & "$ToolDirectory/iverilog.exe" -g2012 -s "tb_$name" -o "$name.vvp" lcd_init.v lcd_bus.v reset_ctrl.v st7565_model.v "tb_$name.v" *> "$out/$name.compile.log"
  if($LASTEXITCODE){throw "compile $name"}
  & "$ToolDirectory/vvp.exe" "$name.vvp" *> "$out/$name.simulation.log"
  if($LASTEXITCODE){throw "simulation $name"}
  Get-Content "$out/$name.simulation.log"
 }
 Get-ChildItem *.v | ForEach-Object {[PSCustomObject]@{File=$_.Name;SHA256=(Get-FileHash $_.FullName).Hash}} | Export-Csv "$out/source_sha256.csv" -NoTypeInformation
} finally {Pop-Location}
