param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference='Stop'
$exe=Join-Path $QuartusBin 'quartus_sh.exe'
if(!(Test-Path -LiteralPath $exe)){throw "Quartus not found: $exe"}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_p4_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/rtl","$stage/lcd_p4" | Out-Null
$radar=Split-Path $PSScriptRoot -Parent
$names=@('reset_ctrl','timebase','switch_filter','servo_pwm','ultrasonic','radar_ctrl','bin12_to_bcd','display_compose','seg_scan','matrix_scan','alarm_ctrl','lcd_bus','lcd_init','lcd_sin_lut','ray_engine','radar_lcd_ctrl','radar_lcd_bridge','lcd_p4_core','radar_lcd_top')
foreach($name in $names){Copy-Item "$radar/rtl/$name.v" "$stage/rtl"}
Copy-Item "$PSScriptRoot/*.qpf","$PSScriptRoot/*.qsf","$PSScriptRoot/*.sdc","$PSScriptRoot/*.mif","$PSScriptRoot/radar_p4_variants.v" "$stage/lcd_p4"
Copy-Item "$radar/lcd_p2/timing_details.tcl" "$stage/lcd_p4"
$drive=$null
foreach($letter in 'R','S','T','U','V','W','X','Y','Z'){
    if(!(Test-Path "${letter}:\")){$drive="${letter}:";break}
}
if(!$drive){throw 'No free SUBST drive'}
$mapped=$false;$pushed=$false;$failed=@();$status=@()
try {
    & subst.exe $drive $stage
    if($LASTEXITCODE -ne 0){throw 'SUBST failed'}
    $mapped=$true
    foreach($variant in 'ufm8','case8','ufm7','case7','safe'){
        $project="radar_p4_$variant"
        $out=Join-Path $PSScriptRoot "results/$variant"
        New-Item -ItemType Directory -Force $out | Out-Null
        Push-Location "$drive/lcd_p4";$pushed=$true
        & $exe --flow compile $project *> "$project.compile.log"
        $code=$LASTEXITCODE
        Get-Content "$project.compile.log" -Tail 10
        if($code -eq 0){
            & (Join-Path $QuartusBin 'quartus_sta.exe') -t timing_details.tcl $project *> "$project.timing_details.log"
            if($LASTEXITCODE -ne 0){$code=$LASTEXITCODE}
            if(Select-String -Path "$project.sta.rpt" -Pattern 'Critical Warning|Ignored assignment|could not be matched' -Quiet){$code=1}
        }
        Pop-Location;$pushed=$false
        Get-ChildItem "$stage/lcd_p4/$project*" -File |
            Where-Object {$_.Extension -in '.rpt','.summary','.pof','.pin','.log'} |
            Copy-Item -Destination $out -Force
        $snapshot=Join-Path $out 'source'
        New-Item -ItemType Directory -Force "$snapshot/rtl","$snapshot/lcd_p4" | Out-Null
        Copy-Item "$stage/rtl/*.v" "$snapshot/rtl"
        Copy-Item "$stage/lcd_p4/radar_p4_variants.v","$stage/lcd_p4/*.mif","$stage/lcd_p4/timing_details.tcl","$stage/lcd_p4/$project.qpf","$stage/lcd_p4/$project.qsf","$stage/lcd_p4/$project.sdc" "$snapshot/lcd_p4"
        Get-ChildItem -LiteralPath $snapshot -Recurse -File | Sort-Object FullName | ForEach-Object{
            [PSCustomObject]@{File=$_.FullName.Substring($snapshot.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        } | Export-Csv "$out/source_sha256.csv" -NoTypeInformation -Encoding utf8
        $status+=[PSCustomObject]@{Variant=$variant;CompileExit=$code}
        if($code -ne 0){$failed+=$variant}
    }
    $status | Export-Csv "$PSScriptRoot/results/build_status.csv" -NoTypeInformation -Encoding utf8
    if($failed.Count){throw "Compile/timing failed: $($failed -join ', '); all reports retained."}
} finally{
    if($pushed){Pop-Location}
    if($mapped){& subst.exe $drive /D}
    Write-Output "Build evidence retained: $stage"
}
