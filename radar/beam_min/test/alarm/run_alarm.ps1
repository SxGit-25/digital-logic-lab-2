param([string]$SourceDir='', [string]$RunName='beam_byte_a_alarm')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../../..").Path
if(!$SourceDir){$SourceDir="$root/radar/beam_min/design/byte_a_source"}
$stage=Join-Path 'C:/Users/Metro/AppData/Local/Temp' ('p5_alarm_'+[guid]::NewGuid().ToString('N'))
$out="$PSScriptRoot/runs/$RunName"
if(Test-Path $out){throw "Output exists: $out"}
New-Item -ItemType Directory -Force $stage,$out | Out-Null
Copy-Item "$SourceDir/*.v","$PSScriptRoot/lcd_ram_bfm.v","$PSScriptRoot/tb_alarm_inverse.v","$root/radar/p5a/background/base/background.mem" $stage
$py='C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $py "$PSScriptRoot/prepare_alarm.py" $stage "$root/radar/p5a/background/base/background_bytes.mem"
if($LASTEXITCODE){throw 'Alarm concurrent fixtures failed'}
$env:TEMP=$stage;$env:TMP=$stage
$bin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName
Push-Location $stage
try{
 $sources=@(Get-ChildItem *.v | ForEach-Object Name)
 & "$bin/iverilog.exe" -g2005-sv -Wall -s tb_alarm_inverse -o test.vvp @sources *> "$out/compile.log"
 if($LASTEXITCODE){throw 'Alarm TB compile failed'}
 & "$bin/vvp.exe" test.vvp *> "$out/simulation.log"
 if($LASTEXITCODE){throw 'Alarm TB failed'}
 Get-Content "$out/simulation.log" -Tail 5
}finally{
 Pop-Location
 Get-ChildItem "$stage/*.v" | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv "$out/sources_sha256.csv" -NoTypeInformation -Encoding utf8
 Write-Output "Alarm stage retained: $stage"
}
