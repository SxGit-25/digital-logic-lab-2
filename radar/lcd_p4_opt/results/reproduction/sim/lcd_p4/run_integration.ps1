param([string]$ToolDirectory='', [string]$ResultsDirectory='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if (!$ToolDirectory) {
 $candidates=@((Join-Path $root 'radar/sim/tools/iverilog/app/bin'),(Join-Path $root ((Split-Path $root -Leaf)+'/radar/sim/tools/iverilog/app/bin')))
 $ToolDirectory=$candidates | Where-Object {Test-Path (Join-Path $_ 'iverilog.exe')} | Select-Object -First 1
 if(!$ToolDirectory){throw 'Provide -ToolDirectory containing iverilog.exe and vvp.exe'}
}
$results=if($ResultsDirectory){$ResultsDirectory}else{Join-Path $root 'radar\lcd_p4\results\integration'}
$work=Join-Path ([IO.Path]::GetTempPath()) ('codex_p4_integration_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $results,$work | Out-Null
$oldTemp=$env:TEMP;$oldTmp=$env:TMP
try {
 Copy-Item (Join-Path $root 'radar\rtl\*.v') $work
 Copy-Item (Join-Path $PSScriptRoot 'tb_*integration.v') $work
 Copy-Item (Join-Path $root 'radar\sim\lcd\st7565_model.v') $work
 $baseline=& git -C $root show 'ca8ec99:radar/rtl/radar_mode_top.v'
 if($LASTEXITCODE){throw 'Missing ca8ec99 baseline'}
 $text=($baseline -join "`n") -replace 'module radar_mode_top #','module radar_mode_legacy #'
 [IO.File]::WriteAllText((Join-Path $work 'radar_mode_legacy.v'),$text,[Text.Encoding]::ASCII)
 $env:TEMP=$work;$env:TMP=$work
 Push-Location $work
 try {
  $rtl=@(Get-ChildItem -Filter '*.v' | Where-Object {$_.Name -notlike 'tb_*'} | ForEach-Object Name)
  foreach($name in @('bridge','lcd','lcd_serial','top','top_readback','top_serial_readback')) {
   $tb='tb_'+$name+'_integration'
   $extra=@()
   if($name -eq 'top_readback'){$tb='tb_top_integration';$extra=@('-Ptb_top_integration.READBACK=1')}
   if($name -eq 'lcd_serial'){$tb='tb_lcd_integration';$extra=@('-Ptb_lcd_integration.SERIAL_ACCUMULATE=1')}
   if($name -eq 'top_serial_readback'){$tb='tb_top_integration';$extra=@('-Ptb_top_integration.READBACK=1','-Ptb_top_integration.SERIAL_ACCUMULATE=1')}
   $compile=& (Join-Path $ToolDirectory 'iverilog.exe') -g2005-sv -Wall -s $tb @extra -o "$name.vvp" @rtl "$tb.v" 2>&1
   $code=$LASTEXITCODE
   (@("compile_exit_code=$code")+@($compile)) | Set-Content (Join-Path $results "$name.compile.log")
   if($code){throw "$name compilation failed"}
   $simulation=& (Join-Path $ToolDirectory 'vvp.exe') "$name.vvp" 2>&1
   $code=$LASTEXITCODE
   $simulation | Tee-Object -FilePath (Join-Path $results "$name.simulation.log")
   if($code -or ($simulation -join "`n") -notmatch "PASS $tb"){throw "$name simulation failed"}
  }
  Get-ChildItem -Filter '*.v' | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{n='File';e={Split-Path $_.Path -Leaf}} | Export-Csv -NoTypeInformation (Join-Path $results 'sources_sha256.csv')
  @('baseline_commit=ca8ec99','bridge=PASS','lcd=PASS','lcd_serial=PASS','top=PASS','top_readback=PASS','top_serial_readback=PASS') | Set-Content (Join-Path $results 'verification.txt')
 } finally {Pop-Location}
} finally {
 $env:TEMP=$oldTemp;$env:TMP=$oldTmp
 $resolved=[IO.Path]::GetFullPath($work);$parent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($work))
 if($resolved.StartsWith($parent+[IO.Path]::DirectorySeparatorChar) -and [IO.Path]::GetFileName($resolved) -match '^codex_p4_integration_[0-9a-f]{32}$') {
  Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}


