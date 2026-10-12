param(
    [string]$QuartusBin = 'E:\quartus\QuartusII91\quartus\bin64',
    [switch]$Baseline
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = if ($Baseline) { Join-Path $PSScriptRoot 'baseline' } else { $root }
$label = if ($Baseline) { 'baseline' } else { 'optimized' }
$output = Join-Path $PSScriptRoot "$label/constraints"
$stage = Join-Path ([IO.Path]::GetTempPath()) ('radar_compile_' + [Guid]::NewGuid().ToString('N'))
$exe = Join-Path $QuartusBin 'quartus_sh.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "Quartus not found: $exe" }
New-Item -ItemType Directory -Force "$stage/constraints", $output | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'rtl') -Destination "$stage/rtl" -Recurse
foreach ($file in 'radar.qpf', 'radar.qsf', 'radar.sdc') {
    Copy-Item -LiteralPath (Join-Path $source "constraints/$file") -Destination "$stage/constraints/$file"
}
# Old Quartus Tcl misnormalizes hidden/Unicode path components. SUBST exposes
# only an ASCII drive and relative project paths; no global install is needed.
$drive = $null
foreach ($letter in 'R','S','T','U','V','W','X','Y','Z') {
    if (!(Test-Path "${letter}:\")) { $drive = "${letter}:"; break }
}
if (!$drive) { throw 'No free drive letter for the temporary Quartus build.' }
$mapped = $false
$pushed = $false
try {
    & subst.exe $drive $stage
    if ($LASTEXITCODE -ne 0) { throw 'SUBST failed.' }
    $mapped = $true
    Push-Location "$drive/constraints"
    $pushed = $true
    & $exe --flow compile radar *> compile.log
    $compileExit = $LASTEXITCODE
    Get-Content compile.log -Tail 16
    Pop-Location
    $pushed = $false
    Get-ChildItem -LiteralPath "$stage/constraints" -File |
        Where-Object { $_.Extension -in '.rpt','.summary','.pof','.pin','.log' } |
        Copy-Item -Destination $output -Force
    Get-ChildItem -LiteralPath (Join-Path $source 'rtl') -Filter '*.v' |
        Get-FileHash -Algorithm SHA256 |
        Select-Object @{n='File';e={Split-Path $_.Path -Leaf}}, Hash |
        Export-Csv -LiteralPath (Join-Path $output 'rtl_sha256.csv') -NoTypeInformation
    if ($compileExit -ne 0) { throw "Quartus failed ($compileExit); see $output/compile.log" }
    Write-Host "Build artifacts: $output"
} finally {
    if ($pushed) { Pop-Location }
    if ($mapped) { & subst.exe $drive /D }
    # Keep the staging directory as compile/debug evidence; never remove user files.
    Write-Host "Temporary build: $stage"
}
