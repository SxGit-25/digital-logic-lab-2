param([string[]]$Variants=@('compact_v2_f15'),[string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'\radar\sim\tools\iverilog\app\bin')}
$python='C:\Users\Metro\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$resultRoot=Join-Path $root 'radar\unified_scan\results\draw_sim_v2'
New-Item -ItemType Directory -Force $resultRoot | Out-Null
$summary=@()
foreach($name in $Variants) {
 $stage=Join-Path ([IO.Path]::GetTempPath()) ('minsky_draw_'+[guid]::NewGuid().ToString('N'))
 $out=Join-Path $resultRoot $name;New-Item -ItemType Directory -Force $stage,$out | Out-Null
 $oldTemp=$env:TEMP;$oldTmp=$env:TMP
 try {
  foreach($file in @('radar_minsky_draw','radar_minsky_draw_compact','radar_minsky_draw_compact_v2','minsky_serial_datapath','lcd_init','lcd_bus')) {Copy-Item (Join-Path $root "radar\rtl\$file.v") $stage}
  Copy-Item (Join-Path $root 'radar\sim\lcd\st7565_model.v'),(Join-Path $PSScriptRoot 'tb_minsky_draw.v') $stage
  $tbPath=Join-Path $stage 'tb_minsky_draw.v'
  [IO.File]::WriteAllText($tbPath,([IO.File]::ReadAllText($tbPath).Replace('radar_minsky_draw_compact','radar_minsky_draw_compact_v2')),[Text.Encoding]::ASCII)
  $candidate=if($name -like '*f15*'){'f15'}else{'f17'}
  $fixture=@('prepare',$stage,'--candidate',$candidate)
  if($name -like '*smoke*'){$fixture+='--smoke'}
  & $python (Join-Path $PSScriptRoot 'minsky_draw_fixtures.py') @fixture
  if($LASTEXITCODE){throw 'Fixture generation failed'}
  $parameters=@()
  if($candidate -eq 'f15'){$parameters=@('-Ptb_minsky_draw.F=15','-Ptb_minsky_draw.K=7','-Ptb_minsky_draw.PHASE_BITS=6','-Ptb_minsky_draw.PHASE_INITIAL=63','-Ptb_minsky_draw.MICRO_BASE=2')}
  if($name -like 'compact*'){$parameters+='-DCOMPACT_DRAW'}
  $env:TEMP=$stage;$env:TMP=$stage
  Push-Location $stage
  try {
   $rtl=@(Get-ChildItem -Filter '*.v' | ForEach-Object Name)
   $compile=& (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -Wall -s tb_minsky_draw @parameters -o draw.vvp @rtl 2>&1
   $compileCode=$LASTEXITCODE;$compile | Set-Content (Join-Path $out 'compile.log')
   if($compileCode){throw "Draw compile failed $name"}
   $sim=& (Join-Path $IverilogBin 'vvp.exe') draw.vvp 2>&1
   $code=$LASTEXITCODE;$sim | Tee-Object -FilePath (Join-Path $out 'simulation.log')
   & $python (Join-Path $PSScriptRoot 'minsky_draw_fixtures.py') images $stage
   foreach($pattern in @('*.csv','*.json','*.pbm','*.png','*.hex','*.vh')) {Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Copy-Item -Destination $out}
   Get-ChildItem -Filter '*.v' | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv -NoTypeInformation (Join-Path $out 'sources_sha256.csv')
   $functional=($sim -join "`n") -match 'PASS_FUNCTIONAL'
   $deadline=($sim -join "`n") -match 'DEADLINE_FAIL'
   $summary+=[pscustomobject]@{Variant=$name;SimulationExit=$code;FunctionalPass=$functional;DeadlineFail=$deadline}
  } finally {Pop-Location}
 } finally {
  $env:TEMP=$oldTemp;$env:TMP=$oldTmp
  $resolved=[IO.Path]::GetFullPath($stage);$parent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($stage))
  if($resolved.StartsWith($parent+[IO.Path]::DirectorySeparatorChar) -and [IO.Path]::GetFileName($resolved) -match '^minsky_draw_[0-9a-f]{32}$') {Remove-Item -LiteralPath $resolved -Recurse -Force}
 }
}
$summary | Export-Csv -NoTypeInformation (Join-Path $resultRoot 'status.csv')
$summary | Format-Table | Out-String | Write-Output
if($summary | Where-Object {$_.SimulationExit -ne 0}) {throw 'Minsky drawing verification failed; functional and deadline statuses are reported separately, all evidence retained'}
