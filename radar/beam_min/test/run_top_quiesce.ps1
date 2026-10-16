param([string]$IverilogBin='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
$out=Join-Path $PSScriptRoot 'top_quiesce_results'
New-Item -ItemType Directory $out -Force | Out-Null
$source=Join-Path $root 'radar/beam_min/design/byte_a_source'
Get-ChildItem "$source/*.v" | ForEach-Object {
 [pscustomobject]@{Name=$_.Name;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
} | ConvertTo-Json | Set-Content "$out/source_manifest.json" -Encoding UTF8
$stage=Join-Path ([IO.Path]::GetTempPath()) ('beam_top_quiesce_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item "$source/*.v","$PSScriptRoot/tb_top_quiesce.v","$root/radar/p5a/background/base/background.mem" $stage
Push-Location $stage
try {
 $sources=@(Get-ChildItem "$stage/*.v" | ForEach-Object FullName)
 & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_top_quiesce -o test.vvp @sources *> "$out/compile.log"
 if($LASTEXITCODE){throw 'top quiesce compilation failed'}
 & "$IverilogBin/vvp.exe" test.vvp *> "$out/simulation.log"
 if($LASTEXITCODE){throw 'top quiesce simulation failed'}
 Get-Content "$out/simulation.log"
} finally {Pop-Location}
