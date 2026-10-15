param(
 [string]$IverilogBin='',
 [string]$Stage='',
 [string]$Results=''
)
$ErrorActionPreference='Stop'
$radar=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$IverilogBin){
 $candidates=@((Join-Path $radar 'sim/tools/iverilog/app/bin'))
 $candidates+=@(Get-ChildItem -LiteralPath (Split-Path $radar -Parent) -Directory | ForEach-Object {
  Join-Path $_.FullName 'radar/sim/tools/iverilog/app/bin'
 })
 foreach($candidate in $candidates){
  if(Test-Path -LiteralPath (Join-Path $candidate 'iverilog.exe')){$IverilogBin=$candidate;break}
 }
}
if(!$IverilogBin -or !(Test-Path -LiteralPath (Join-Path $IverilogBin 'iverilog.exe'))){throw 'Provide -IverilogBin containing iverilog.exe and vvp.exe'}
if(!$Stage){$Stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_p2_verify_'+[Guid]::NewGuid().ToString('N'))}
if(!$Results){$Results=Join-Path $radar 'lcd_p2\results\simulation'}
if($Stage -match '[^\x00-\x7f]'){throw 'Stage must use an ASCII path'}
New-Item -ItemType Directory -Force $Stage,$Results | Out-Null
Copy-Item (Join-Path $radar 'rtl\*.v') $Stage
Copy-Item (Join-Path $PSScriptRoot '*') $Stage
Copy-Item (Join-Path $radar 'sim\lcd\st7565_model.v') $Stage
Push-Location $Stage
try {
 python verify_p2.py prepare . | Out-File -Encoding utf8 prepare.log
 if($LASTEXITCODE){throw 'Fixture generation failed'}
 $common=@('ray_engine.v','lcd_sin_lut.v')
 & (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -I . -s tb_ray_engine -o ray.vvp @common tb_ray_engine.v
 if($LASTEXITCODE){throw 'Ray compilation failed'}
 & (Join-Path $IverilogBin 'vvp.exe') ray.vvp | Tee-Object ray.log
 if($LASTEXITCODE){throw 'Ray simulation failed'}
 & (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -I . -s tb_lcd_p2 -o lcd.vvp @common lcd_p2_core.v radar_lcd_ctrl.v lcd_bus.v lcd_init.v st7565_model.v tb_lcd_p2.v
 if($LASTEXITCODE){throw 'LCD compilation failed'}
 & (Join-Path $IverilogBin 'vvp.exe') lcd.vvp | Tee-Object lcd.log
 if($LASTEXITCODE){throw 'LCD simulation failed'}
 New-Item -ItemType Directory -Force ufm | Out-Null
 Copy-Item scenario.hex,pixels.hex,*_expected.hex ufm
 & (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -I . -s tb_lcd_p2 '-Ptb_lcd_p2.USE_UFM=1' -o lcd_ufm.vvp @common lcd_p2_core.v radar_lcd_ctrl.v lcd_bus.v lcd_init.v st7565_model.v tb_lcd_p2.v
 if($LASTEXITCODE){throw 'UFM LCD compilation failed'}
 Push-Location ufm
 try {
  & (Join-Path $IverilogBin 'vvp.exe') ../lcd_ufm.vvp | Tee-Object lcd_ufm.log
  if($LASTEXITCODE){throw 'UFM LCD simulation failed'}
 } finally {Pop-Location}
 foreach($image in @('outbound.pbm','full_scan.pbm','multiple_targets_turnaround.pbm')) {
  if((Get-FileHash $image).Hash -ne (Get-FileHash (Join-Path ufm $image)).Hash){throw "Case/UFM image mismatch: $image"}
 }
 & (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -s tb_lcd_alias -o alias.vvp @common lcd_p2_core.v radar_lcd_ctrl.v lcd_bus.v lcd_init.v st7565_model.v tb_lcd_alias.v
 if($LASTEXITCODE){throw 'Alias reproduction compilation failed'}
 & (Join-Path $IverilogBin 'vvp.exe') alias.vvp | Tee-Object alias.log
 if($LASTEXITCODE){throw 'Alias reproduction failed'}
 python verify_p2.py analyze . | Tee-Object geometry.log
 if($LASTEXITCODE){throw 'Coordinate/image validation failed'}
 foreach($pattern in @('*.json','*.csv','*.pbm','*.png','*.log','*_expected.hex')) {
  Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Copy-Item -Destination $Results
 }
 New-Item -ItemType Directory -Force (Join-Path $Results 'ufm') | Out-Null
 Copy-Item ufm/*.pbm,ufm/*.log (Join-Path $Results 'ufm')
} finally {Pop-Location}
