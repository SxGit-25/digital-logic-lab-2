param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference='Stop'
$exe=Join-Path $QuartusBin 'quartus_sh.exe'
if(!(Test-Path -LiteralPath $exe)){throw "Quartus not found: $exe"}
$radar=Split-Path $PSScriptRoot -Parent
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar_p3_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/rtl","$stage/p3_modes","$stage/constraints" | Out-Null
foreach($name in 'reset_ctrl','timebase','switch_filter','servo_pwm','ultrasonic','radar_ctrl','bin12_to_bcd','display_compose','seg_scan','matrix_scan','alarm_ctrl','radar_top','radar_mode_top') {
    Copy-Item "$radar/rtl/$name.v" "$stage/rtl"
}
Copy-Item "$PSScriptRoot/radar_modes.qpf","$PSScriptRoot/radar_modes.qsf","$PSScriptRoot/radar_modes.sdc" "$stage/p3_modes"
Copy-Item "$radar/constraints/radar.qpf","$radar/constraints/radar.qsf","$radar/constraints/radar.sdc" "$stage/constraints"
$drive=$null
foreach($letter in 'R','S','T','U','V','W','X','Y','Z') {
    if(!(Test-Path "${letter}:\")){$drive="${letter}:";break}
}
if(!$drive){throw 'No free SUBST drive'}
$mapped=$false;$pushed=$false;$failed=@()
try {
    & subst.exe $drive $stage
    if($LASTEXITCODE -ne 0){throw 'SUBST failed'}
    $mapped=$true
    foreach($variant in 'modes','basic') {
        $dir=if($variant -eq 'modes'){'p3_modes'}else{'constraints'}
        $project=if($variant -eq 'modes'){'radar_modes'}else{'radar'}
        $output=Join-Path $PSScriptRoot "results/$variant"
        New-Item -ItemType Directory -Force $output | Out-Null
        Push-Location "$drive/$dir";$pushed=$true
        & $exe --flow compile $project *> "$project.compile.log"
        $code=$LASTEXITCODE
        Get-Content "$project.compile.log" -Tail 12
        if($code -eq 0 -and (Select-String -Path "$project.sta.rpt" -Pattern 'Critical Warning|Ignored assignment|could not be matched' -Quiet)){$code=1}
        Pop-Location;$pushed=$false
        Get-ChildItem "$stage/$dir/$project*" -File |
            Where-Object {$_.Extension -in '.rpt','.summary','.pof','.pin','.log'} |
            Copy-Item -Destination $output -Force
        $snapshot=Join-Path $output 'source'
        New-Item -ItemType Directory -Force "$snapshot/rtl","$snapshot/$dir" | Out-Null
        Copy-Item "$stage/rtl/*.v" "$snapshot/rtl"
        Copy-Item "$stage/$dir/$project.qpf","$stage/$dir/$project.qsf","$stage/$dir/$project.sdc" "$snapshot/$dir"
        Get-ChildItem -LiteralPath $snapshot -Recurse -File | Sort-Object FullName | ForEach-Object {
            [PSCustomObject]@{File=$_.FullName.Substring($snapshot.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        } | Export-Csv "$output/source_sha256.csv" -NoTypeInformation -Encoding utf8
        if($code -ne 0){$failed+=$variant}
    }
    if($failed.Count){throw "Compile/timing failed: $($failed -join ', ')"}
} finally {
    if($pushed){Pop-Location}
    if($mapped){& subst.exe $drive /D}
    Write-Output "Build evidence retained: $stage"
}
