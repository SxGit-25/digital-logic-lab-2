param(
    [string]$ToolDirectory = 'E:\codex\数电实验2\数电实验2\radar\sim\tools\iverilog\app\bin',
    [int]$Unit5 = 1
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$results = Join-Path $root 'radar\lcd_p4_opt\results\servo_optimized'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) ('codex_p4_servo_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$ascii = [Text.Encoding]::ASCII
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $baseline = & git -C $root show 'f4507a8:radar/rtl/servo_pwm.v'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read immutable f4507a8 baseline' }
    $baselineText = ($baseline -join "`n") -replace 'module servo_pwm #', 'module servo_pwm_legacy #'
    [IO.File]::WriteAllText((Join-Path $work 'servo_pwm_legacy.v'), $baselineText, $ascii)
    Copy-Item -LiteralPath (Join-Path $root 'radar\rtl\servo_pwm.v') -Destination (Join-Path $work 'servo_pwm.v')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tb_servo_optimized.v') -Destination (Join-Path $work 'tb_servo_optimized.v')
    $env:TEMP = $work
    $env:TMP = $work
    Push-Location $work
    try {
        $compile = & (Join-Path $ToolDirectory 'iverilog.exe') '-g2005-sv' '-Wall' '-s' 'tb_servo_optimized' "-Ptb_servo_optimized.UNIT5=$Unit5" '-o' 'servo_optimized.vvp' 'servo_pwm_legacy.v' 'servo_pwm.v' 'tb_servo_optimized.v' 2>&1
        $compileCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $results 'compile.log'),
            ((@("compile_exit_code=$compileCode") + @($compile)) -join "`r`n"))
        if ($compileCode -ne 0) { throw "iverilog failed: $compileCode" }
        $simulation = & (Join-Path $ToolDirectory 'vvp.exe') 'servo_optimized.vvp' 2>&1
        $simulationCode = $LASTEXITCODE
        $simulation | Tee-Object -FilePath (Join-Path $results 'simulation.log')
        if ($simulationCode -ne 0) { throw "vvp failed: $simulationCode" }
        if (($simulation -join "`n") -notmatch 'PASS tb_servo_optimized') { throw 'Missing completion marker' }
        @(
            'baseline_commit=f4507a8',
            "unit5=$Unit5",
            "compile_exit_code=$compileCode",
            "simulation_exit_code=$simulationCode",
            ('servo_pwm_sha256=' + (Get-FileHash (Join-Path $work 'servo_pwm.v') -Algorithm SHA256).Hash),
            ('testbench_sha256=' + (Get-FileHash (Join-Path $work 'tb_servo_optimized.v') -Algorithm SHA256).Hash)
        ) | Set-Content -LiteralPath (Join-Path $results 'verification.txt')
    } finally { Pop-Location }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $resolvedWork = [IO.Path]::GetFullPath($work)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($work))
    if (($resolvedWork.StartsWith($resolvedTemp + [IO.Path]::DirectorySeparatorChar)) -and
        ([IO.Path]::GetFileName($resolvedWork) -match '^codex_p4_servo_[0-9a-f]{32}$')) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}


