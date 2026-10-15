param([string]$ToolDirectory='', [switch]$Quick, [switch]$ProductionOnly)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(!$ToolDirectory){$ToolDirectory=Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')}
$results=Join-Path $root 'radar\unified_scan\results\scan_engine'
$work=Join-Path ([IO.Path]::GetTempPath()) ('codex_unified_scan_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $results,$work | Out-Null
$oldTemp=$env:TEMP;$oldTmp=$env:TMP
try{
 Copy-Item (Join-Path $root 'radar\rtl\radar_unified_scan.v') $work
 Copy-Item (Join-Path $PSScriptRoot 'tb_scan_*.v') $work
 $verified=Get-Content -Raw (Join-Path $results 'source\verified_degree1.v')
 $verified=$verified -replace 'module radar_unified_scan #','module radar_unified_scan_verified_degree1 #'
 [IO.File]::WriteAllText((Join-Path $work 'radar_unified_scan_verified_degree1.v'),$verified,[Text.Encoding]::ASCII)
 foreach($module in @('radar_ctrl','servo_pwm')){
  $baseline=& git -C $root show "f4507a8:radar/rtl/$module.v"
  if($LASTEXITCODE){throw "Cannot read f4507a8 $module"}
  $source=($baseline -join "`n") -replace "module $module\b","module ${module}_legacy"
  [IO.File]::WriteAllText((Join-Path $work "${module}_legacy.v"),$source,[Text.Encoding]::ASCII)
 }
 $env:TEMP=$work;$env:TMP=$work
 Push-Location $work
 try{
  $cases=@(
   @{name='basic';args=@()},
   @{name='control';args=@();tb='tb_scan_control'},
   @{name='bcd_ablation';args=@();tb='tb_scan_bcd'},
   @{name='basic_dense';args=@('-Ptb_scan_engine.DENSE=1')},
   @{name='continuous';args=@('-Ptb_scan_engine.MODE=1')},
   @{name='continuous_degree2';args=@('-Ptb_scan_engine.MODE=1','-Ptb_scan_engine.DEGREE=2')},
   @{name='basic_degree2';args=@('-Ptb_scan_engine.DEGREE=2')},
   @{name='skew_hold';args=@('-Ptb_scan_engine.SKEW=1')},
   @{name='skew_direct';args=@('-Ptb_scan_engine.SKEW=1','-Ptb_scan_engine.HOLD=0')}
  )
  if(!$Quick){$cases+=@(
   @{name='production_basic';args=@('-Ptb_scan_engine.PRODUCTION=1')},
   @{name='production_continuous';args=@('-Ptb_scan_engine.PRODUCTION=1','-Ptb_scan_engine.MODE=1')}
  )}
  if($ProductionOnly){$cases=@($cases | Where-Object {$_.name -like 'production_*'})}
  foreach($case in $cases){
   $name=$case.name;$argsForCase=$case.args
   $tb='tb_scan_engine';if($case.tb){$tb=$case.tb}
   $compile=& (Join-Path $ToolDirectory 'iverilog.exe') -g2005-sv -Wall -s $tb @argsForCase -o "$name.vvp" radar_unified_scan.v radar_unified_scan_verified_degree1.v radar_ctrl_legacy.v servo_pwm_legacy.v tb_scan_engine.v tb_scan_control.v tb_scan_bcd.v 2>&1
   $code=$LASTEXITCODE
   (@("compile_exit_code=$code")+@($compile)) | Set-Content (Join-Path $results "$name.compile.log")
   if($code){throw "$name compile failed"}
   $simulation=& (Join-Path $ToolDirectory 'vvp.exe') "$name.vvp" 2>&1
   $code=$LASTEXITCODE
   $simulation | Tee-Object -FilePath (Join-Path $results "$name.simulation.log")
   if($code -or ($simulation -join "`n") -notmatch "PASS $tb"){throw "$name simulation failed ($code)"}
   "simulation_exit_code=$code" | Add-Content (Join-Path $results "$name.compile.log")
  }
  Get-ChildItem -Filter '*.v' | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv -NoTypeInformation (Join-Path $results 'sources_sha256.csv')
 }finally{Pop-Location}
}finally{
 $env:TEMP=$oldTemp;$env:TMP=$oldTmp
 $resolved=[IO.Path]::GetFullPath($work);$parent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($work))
 if($resolved.StartsWith($parent+[IO.Path]::DirectorySeparatorChar) -and [IO.Path]::GetFileName($resolved) -match '^codex_unified_scan_[0-9a-f]{32}$'){
  Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}
