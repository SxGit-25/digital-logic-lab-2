param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(!$IverilogBin){$IverilogBin=Join-Path $root ((Split-Path $root -Leaf)+'\radar\sim\tools\iverilog\app\bin')}
$out=Join-Path $root 'radar\unified_scan\results\bcd_experiment\simulation'
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_bcd_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $out,$stage | Out-Null
$oldTemp=$env:TEMP;$oldTmp=$env:TMP
try {
 foreach($name in @('ultrasonic','bin12_to_bcd')) {
  $text=(& git -C $root show "f4507a8:radar/rtl/$name.v") -join "`n"
  if($LASTEXITCODE){throw "Cannot read baseline $name"}
  $text=$text.Replace("module $name", "module ${name}_bcd_legacy")
  [IO.File]::WriteAllText((Join-Path $stage "${name}_bcd_legacy.v"),$text,[Text.Encoding]::ASCII)
 }
 Copy-Item (Join-Path $root 'radar\rtl\ultrasonic_bcd_experiment.v') $stage
 Copy-Item (Join-Path $PSScriptRoot 'tb_ultrasonic_bcd_experiment.v') $stage
 $env:TEMP=$stage;$env:TMP=$stage
 Push-Location $stage
 try {
  $rtl=@('ultrasonic_bcd_experiment.v','ultrasonic_bcd_legacy.v','bin12_to_bcd_bcd_legacy.v','tb_ultrasonic_bcd_experiment.v')
  $compile=& (Join-Path $IverilogBin 'iverilog.exe') -g2005-sv -Wall -s tb_ultrasonic_bcd_experiment -o bcd.vvp @rtl 2>&1
  $code=$LASTEXITCODE;$compile | Set-Content (Join-Path $out 'compile.log')
  if($code){throw "BCD compilation failed $code"}
  $sim=& (Join-Path $IverilogBin 'vvp.exe') bcd.vvp 2>&1
  $code=$LASTEXITCODE;$sim | Tee-Object -FilePath (Join-Path $out 'simulation.log')
  Copy-Item bcd_samples.csv $out
  if($code -or ($sim -join "`n") -notmatch 'PASS tb_ultrasonic_bcd_experiment'){throw 'BCD simulation failed'}
  Get-ChildItem -Filter '*.v' | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv -NoTypeInformation (Join-Path $out 'sources_sha256.csv')
 } finally {Pop-Location}
} finally {
 $env:TEMP=$oldTemp;$env:TMP=$oldTmp
 $resolved=[IO.Path]::GetFullPath($stage);$parent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($stage))
 if($resolved.StartsWith($parent+[IO.Path]::DirectorySeparatorChar) -and [IO.Path]::GetFileName($resolved) -match '^radar_bcd_[0-9a-f]{32}$') {Remove-Item -LiteralPath $resolved -Recurse -Force}
}
