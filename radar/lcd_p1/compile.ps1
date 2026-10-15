param([string]$QuartusBin = 'E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference = 'Stop'
$exe = Join-Path $QuartusBin 'quartus_sh.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "Quartus not found: $exe" }
$stage = Join-Path ([IO.Path]::GetTempPath()) ('lcd_p1_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/lcd_p1", "$stage/rtl" | Out-Null
Copy-Item "$PSScriptRoot/*.q*", "$PSScriptRoot/*.sdc", "$PSScriptRoot/lcd_p1_top.v" "$stage/lcd_p1"
foreach ($name in 'reset_ctrl','lcd_bus','lcd_init','lcd_p1_pattern','lcd_p1_core') {
 Copy-Item "$PSScriptRoot/../rtl/$name.v" "$stage/rtl"
}
$drive = $null
foreach ($letter in 'R','S','T','U','V','W','X','Y','Z') {
 if (!(Test-Path "${letter}:\")) { $drive="${letter}:"; break }
}
if (!$drive) { throw 'No free drive letter for SUBST.' }
$mapped=$false; $pushed=$false
try {
 & subst.exe $drive $stage
 if ($LASTEXITCODE -ne 0) { throw 'SUBST failed.' }
 $mapped=$true
 foreach ($variant in 'write','read') {
  $project="lcd_p1_$variant"
  $output=Join-Path $PSScriptRoot "results/$variant"
  New-Item -ItemType Directory -Force $output | Out-Null
  Push-Location "$drive/lcd_p1"; $pushed=$true
  & $exe --flow compile $project *> "$project.compile.log"
  $code=$LASTEXITCODE
  Get-Content "$project.compile.log" -Tail 20
  Pop-Location; $pushed=$false
  Get-ChildItem "$stage/lcd_p1/$project*" -File |
   Where-Object { $_.Extension -in '.rpt','.summary','.pof','.sof','.pin','.log' } |
   Copy-Item -Destination $output -Force
  Get-ChildItem "$stage/rtl/*.v","$stage/lcd_p1/*.v","$stage/lcd_p1/$project.qsf","$stage/lcd_p1/$project.sdc" |
   Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash |
   Export-Csv "$output/source_sha256.csv" -NoTypeInformation
  if ($code -ne 0) { throw "Compile failed: $project. Return results including logs." }
 }
 Write-Host 'Return the complete radar/lcd_p1/results folder. Read variant needs electrical approval before programming.'
} finally {
 if ($pushed) { Pop-Location }
 if ($mapped) { & subst.exe $drive /D }
 Write-Host "Build evidence retained: $stage"
}
