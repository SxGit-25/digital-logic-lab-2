param([string]$IverilogBin = '', [string]$RtlDir = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$RtlDir) { $RtlDir = Join-Path $root 'rtl' }
if (!$IverilogBin) { $IverilogBin = Join-Path $PSScriptRoot 'tools\iverilog\app\bin' }
$iv = Join-Path $IverilogBin 'iverilog.exe'
$vvp = Join-Path $IverilogBin 'vvp.exe'
if (!(Test-Path $iv)) { throw "Icarus missing; use -IverilogBin <directory containing iverilog.exe and vvp.exe>" }
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$rtl = @(Get-ChildItem -LiteralPath $RtlDir -Filter '*.v' | ForEach-Object FullName)
$tests = @('servo_pwm', 'ultrasonic', 'radar_ctrl', 'radar_top', 'alarm_ctrl')
$defines = @()
$baseline = Join-Path $root 'verification\baseline\rtl'
if (Test-Path $baseline) {
    foreach ($name in @('timebase','switch_filter','seg_scan','matrix_scan','ultrasonic','radar_ctrl')) {
        $source = Get-Content -Raw -LiteralPath (Join-Path $baseline "$name.v")
        $source = $source -replace "module\s+$name\b", "module ${name}_baseline"
        $dest = Join-Path $build "${name}_baseline.v"
        Set-Content -LiteralPath $dest -Value $source -Encoding ascii
        $rtl += $dest
    }
    $tests += 'counter_equivalence'
    $defines += '-DBASELINE_COMPARE'
}
foreach ($name in $tests) {
    $out = Join-Path $build "$name.vvp"
    & $iv -g2005-sv -Wall @defines -s "tb_$name" -o $out @rtl (Join-Path $PSScriptRoot "tb_$name.v")
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $name" }
    & $vvp $out
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $name" }
}
Write-Output "PASS all $($tests.Count) regression suites"
