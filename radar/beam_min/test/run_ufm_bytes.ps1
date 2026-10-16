param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('beam_min_ufm_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$PSScriptRoot/tb_p5_ufm_byte_reader.v","$root/radar/p5a/background/base/background.mem" $stage
Push-Location $stage
try {
 foreach($variant in @('a','b')) {
  $file=if($variant -eq 'a'){'p5_ufm_byte_reader.v'}else{'p5_ufm_byte_reader_shared.v'}
  Copy-Item "$root/radar/beam_min/design/$file" "$stage/reader.v"
  $out=Join-Path $PSScriptRoot "ufm_$variant"
  New-Item -ItemType Directory $out -Force | Out-Null
  & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_p5_ufm_byte_reader -o test.vvp reader.v tb_p5_ufm_byte_reader.v *> "$out/compile.log"
  if($LASTEXITCODE){throw "$variant compilation failed"}
  & "$IverilogBin/vvp.exe" test.vvp *> "$out/simulation.log"
  if($LASTEXITCODE){throw "$variant simulation failed"}
  Get-Content "$out/simulation.log"
 }
} finally {Pop-Location}
