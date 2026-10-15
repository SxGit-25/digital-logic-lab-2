param(
    [string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64',
    [ValidateSet('case','ufm','safe')][string[]]$Variants=@('case','ufm','safe')
)
$ErrorActionPreference='Stop'
$exe=Join-Path $QuartusBin 'quartus_sh.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "Quartus not found: $exe" }
$stage=Join-Path ([IO.Path]::GetTempPath()) ('lcd_p2_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/lcd_p2","$stage/rtl" | Out-Null
Copy-Item "$PSScriptRoot/*.qpf","$PSScriptRoot/*.qsf","$PSScriptRoot/*.sdc","$PSScriptRoot/*.mif","$PSScriptRoot/lcd_p2_top.v" "$stage/lcd_p2"
Copy-Item "$PSScriptRoot/timing_details.tcl" "$stage/lcd_p2"
$modules=@('reset_ctrl','lcd_bus','lcd_init','lcd_sin_lut','ray_engine','radar_lcd_ctrl','lcd_p2_core')
foreach($name in $modules) { Copy-Item "$PSScriptRoot/../rtl/$name.v" "$stage/rtl" }
$drive=$null
foreach($letter in 'R','S','T','U','V','W','X','Y','Z') {
    if(!(Test-Path "${letter}:\")) { $drive="${letter}:";break }
}
if(!$drive) { throw 'No free drive letter for SUBST.' }
$mapped=$false;$pushed=$false;$failed=@()
try {
    & subst.exe $drive $stage
    if($LASTEXITCODE -ne 0) { throw 'SUBST failed.' }
    $mapped=$true
    foreach($variant in $Variants) {
        $project="lcd_p2_$variant"
        $output=Join-Path $PSScriptRoot "results/$variant"
        New-Item -ItemType Directory -Force $output | Out-Null
        Push-Location "$drive/lcd_p2";$pushed=$true
        & $exe --flow compile $project *> "$project.compile.log"
        $code=$LASTEXITCODE
        Get-Content "$project.compile.log" -Tail 12
        if($code -eq 0) {
            & (Join-Path $QuartusBin 'quartus_sta.exe') -t timing_details.tcl $project *> "$project.timing_details.log"
            if($LASTEXITCODE -ne 0) { $code=$LASTEXITCODE }
            # Quartus returns success even when timing fails. Treat those reports as failures.
            if(Select-String -Path "$project.sta.rpt" -Pattern 'Critical Warning|could not be matched|Ignored assignment' -Quiet) { $code=1 }
        }
        Pop-Location;$pushed=$false
        Get-ChildItem "$stage/lcd_p2/$project*" -File |
            Where-Object { $_.Extension -in '.rpt','.summary','.pof','.sof','.pin','.log' } |
            Copy-Item -Destination $output -Force
        $snapshot=Join-Path $output 'source'
        New-Item -ItemType Directory -Force "$snapshot/rtl","$snapshot/lcd_p2" | Out-Null
        Copy-Item "$stage/rtl/*.v" "$snapshot/rtl"
        Copy-Item "$stage/lcd_p2/lcd_p2_top.v","$stage/lcd_p2/timing_details.tcl","$stage/lcd_p2/*.mif","$stage/lcd_p2/$project.qpf","$stage/lcd_p2/$project.qsf","$stage/lcd_p2/$project.sdc" "$snapshot/lcd_p2"
        Get-ChildItem -LiteralPath $snapshot -Recurse -File | Sort-Object FullName | ForEach-Object {
            [PSCustomObject]@{File=$_.FullName.Substring($snapshot.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        } | Export-Csv "$output/source_sha256.csv" -NoTypeInformation -Encoding utf8
        if($code -ne 0) { $failed+=$project }
    }
    if($failed.Count) { throw "Compile failed: $($failed -join ', '). Evidence retained in results." }
    Write-Output 'Complete P2 results retained. Read test programming still requires electrical approval.'
} finally {
    if($pushed) { Pop-Location }
    if($mapped) { & subst.exe $drive /D }
    Write-Output "Build evidence retained: $stage"
}
