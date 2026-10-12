param([string]$QuartusBin = 'E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference = 'Stop'
$output = Join-Path $PSScriptRoot 'output'
$stage = Join-Path ([IO.Path]::GetTempPath()) ('servo_sweep_' + [Guid]::NewGuid().ToString('N'))
$exe = Join-Path $QuartusBin 'quartus_sh.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "Quartus not found: $exe" }
New-Item -ItemType Directory -Force "$stage/continuous_scan", "$stage/radar/rtl", $output | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/rtl" -Destination "$stage/continuous_scan/rtl" -Recurse
Copy-Item -LiteralPath "$PSScriptRoot/constraints" -Destination "$stage/continuous_scan/constraints" -Recurse
$shared = Join-Path (Split-Path $PSScriptRoot -Parent) 'radar/rtl'
foreach ($name in 'reset_ctrl','timebase','switch_filter') {
    Copy-Item -LiteralPath "$shared/$name.v" -Destination "$stage/radar/rtl/$name.v"
}
$drive = $null
foreach ($letter in 'R','S','T','U','V','W','X','Y','Z') {
    if (!(Test-Path "${letter}:\")) { $drive = "${letter}:"; break }
}
if (!$drive) { throw 'No free temporary drive letter.' }
$mapped = $false
$pushed = $false
try {
    & subst.exe $drive $stage
    if ($LASTEXITCODE -ne 0) { throw 'SUBST failed.' }
    $mapped = $true
    Push-Location "$drive/continuous_scan/constraints"
    $pushed = $true
    & $exe --flow compile continuous_scan *> compile.log
    $compileExit = $LASTEXITCODE
    Get-Content compile.log -Tail 16
    Pop-Location
    $pushed = $false
    Get-ChildItem -LiteralPath "$stage/continuous_scan/constraints" -File |
        Where-Object { $_.Extension -in '.rpt','.summary','.pof','.pin','.log' } |
        Copy-Item -Destination $output -Force
    Get-ChildItem "$stage/continuous_scan/rtl/*.v", "$stage/radar/rtl/*.v" |
        Get-FileHash -Algorithm SHA256 |
        Select-Object @{n='File';e={Split-Path $_.Path -Leaf}}, Hash |
        Export-Csv -LiteralPath "$output/rtl_sha256.csv" -NoTypeInformation
    if ($compileExit -ne 0) { throw "Quartus failed ($compileExit); see $output/compile.log" }
    Write-Host "Build artifacts: $output"
} finally {
    if ($pushed) { Pop-Location }
    if ($mapped) { & subst.exe $drive /D }
    Write-Host "Temporary build: $stage"
}
