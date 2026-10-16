param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64',[string]$RunName='unified1',[string[]]$Variants=@('read','safe','noend'),[switch]$Compact,[switch]$Area,[switch]$PwmSettle,[string]$ScanSource='', [int]$Seed=1)
$ErrorActionPreference='Stop'
$exe=Join-Path $QuartusBin 'quartus_sh.exe'
if(!(Test-Path -LiteralPath $exe)){throw "Quartus not found: $exe"}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_p4_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/rtl","$stage/lcd_p4" | Out-Null
$radar=Split-Path $PSScriptRoot -Parent
$names=@('radar_global_timebase_alarm','alarm_global','switch_pair_sampled','radar_display_gated','radar_global_timebase','radar_display_shared','reset_ctrl','timebase','switch_filter','ultrasonic','bin12_to_bcd','display_compose','seg_scan','matrix_scan','alarm_ctrl','radar_unified_scan','radar_unified_top','minsky_serial_datapath','radar_minsky_draw_compact','radar_minsky_draw_compact_v2','ultrasonic_bcd_experiment','ultrasonic_bcd_budget','ultrasonic_bcd_budget_compact','radar_lcd_micro','lcd_bus_phase','lcd_bus','lcd_init')
$names+=@('p5_ufm_reader')
foreach($name in $names){Copy-Item "$radar/rtl/$name.v" "$stage/rtl"}
if($ScanSource){Copy-Item -LiteralPath $ScanSource -Destination "$stage/rtl/radar_unified_scan.v" -Force}
Copy-Item "$PSScriptRoot/*.qpf","$PSScriptRoot/*.qsf","$PSScriptRoot/*.sdc","$PSScriptRoot/radar_unified_variants.v" "$stage/lcd_p4"
Copy-Item "$radar/lcd_p2/timing_details.tcl" "$stage/lcd_p4"
Get-ChildItem "$PSScriptRoot/background.*" -File -ErrorAction SilentlyContinue | Copy-Item -Destination "$stage/lcd_p4"
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
    if($Compact){
        Get-ChildItem "$stage/lcd_p4/*.qsf" | ForEach-Object {
            Add-Content -LiteralPath $_.FullName -Value 'set_global_assignment -name STATE_MACHINE_PROCESSING "USER-ENCODED"' -Encoding ascii
            Add-Content -LiteralPath $_.FullName -Value 'set_global_assignment -name OPTIMIZATION_TECHNIQUE AREA' -Encoding ascii
        }
    }
    if($Area){
        Get-ChildItem "$stage/lcd_p4/*.qsf" | ForEach-Object {
            Add-Content -LiteralPath $_.FullName -Value 'set_global_assignment -name MAXII_OPTIMIZATION_TECHNIQUE AREA' -Encoding ascii
            Add-Content -LiteralPath $_.FullName -Value 'set_global_assignment -name AUTO_RESOURCE_SHARING ON' -Encoding ascii
            Add-Content -LiteralPath $_.FullName -Value 'set_global_assignment -name MUX_RESTRUCTURE ON' -Encoding ascii
        }
    }
    if($Seed -ne 1){
        Get-ChildItem "$stage/lcd_p4/*.qsf" | ForEach-Object {
            Add-Content -LiteralPath $_.FullName -Value "set_global_assignment -name SEED $Seed" -Encoding ascii
        }
    }
    if($PwmSettle){
        Get-ChildItem "$stage/lcd_p4/*.qsf" | ForEach-Object {
            Add-Content -LiteralPath $_.FullName -Value 'set_parameter -name SETTLE_FROM_PWM 1' -Encoding ascii
        }
    }
    foreach($variant in $Variants){
        $project="radar_unified_$variant"
        $out=Join-Path $PSScriptRoot "results/$RunName/$variant"
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
        Get-ChildItem "$stage/lcd_p4/background.*" -File -ErrorAction SilentlyContinue | Copy-Item -Destination "$snapshot/lcd_p4"
        Copy-Item "$stage/lcd_p4/radar_unified_variants.v","$stage/lcd_p4/timing_details.tcl","$stage/lcd_p4/$project.qpf","$stage/lcd_p4/$project.qsf","$stage/lcd_p4/$project.sdc" "$snapshot/lcd_p4"
        Get-ChildItem -LiteralPath $snapshot -Recurse -File | Sort-Object FullName | ForEach-Object{
            [PSCustomObject]@{File=$_.FullName.Substring($snapshot.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        } | Export-Csv "$out/source_sha256.csv" -NoTypeInformation -Encoding utf8
        $status+=[PSCustomObject]@{Variant=$variant;CompileExit=$code}
        if($code -ne 0){$failed+=$variant}
    }
    $status | Export-Csv "$PSScriptRoot/results/$RunName/build_status.csv" -NoTypeInformation -Encoding utf8
    if($failed.Count){throw "Compile/timing failed: $($failed -join ', '); all reports retained."}
} finally{
    if($pushed){Pop-Location}
    if($mapped){& subst.exe $drive /D}
    Write-Output "Build evidence retained: $stage"
}
