param(
    [string]$ToolDirectory = 'E:\codex\数电实验2\数电实验2\radar\sim\tools\iverilog\app\bin'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$results = Join-Path $root 'radar\lcd_p4_opt\results\radius'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) ('codex_p4_radius_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$ascii = [Text.Encoding]::ASCII
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $baseline = & git -C $root show 'ca8ec99:radar/rtl/ultrasonic.v'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read immutable ca8ec99 baseline' }
    $baselineText = ($baseline -join "`n") -replace 'module ultrasonic #', 'module ultrasonic_legacy #'
    [IO.File]::WriteAllText((Join-Path $work 'ultrasonic_legacy.v'), $baselineText, $ascii)
    Copy-Item -LiteralPath (Join-Path $root 'radar\rtl\ultrasonic.v') -Destination (Join-Path $work 'ultrasonic.v')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tb_ultrasonic_radius.v') -Destination (Join-Path $work 'tb_ultrasonic_radius.v')
    $env:TEMP = $work
    $env:TMP = $work
    Push-Location $work
    try {
        $compile = & (Join-Path $ToolDirectory 'iverilog.exe') '-g2005-sv' '-Wall' '-s' 'tb_ultrasonic_radius' '-o' 'radius.vvp' 'ultrasonic_legacy.v' 'ultrasonic.v' 'tb_ultrasonic_radius.v' 2>&1
        $compileCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $results 'compile.log'),
            ((@("compile_exit_code=$compileCode") + @($compile)) -join "`r`n"))
        if ($compileCode -ne 0) { throw "iverilog failed: $compileCode" }
        $simulation = & (Join-Path $ToolDirectory 'vvp.exe') 'radius.vvp' 2>&1
        $simulationCode = $LASTEXITCODE
        $simulation | Tee-Object -FilePath (Join-Path $results 'simulation.log')
        if ($simulationCode -ne 0) { throw "vvp failed: $simulationCode" }
        if (($simulation -join "`n") -notmatch 'PASS tb_ultrasonic_radius') { throw 'Missing completion marker' }
        @(
            'baseline_commit=ca8ec99',
            "compile_exit_code=$compileCode",
            "simulation_exit_code=$simulationCode",
            ('ultrasonic_sha256=' + (Get-FileHash (Join-Path $work 'ultrasonic.v') -Algorithm SHA256).Hash),
            ('testbench_sha256=' + (Get-FileHash (Join-Path $work 'tb_ultrasonic_radius.v') -Algorithm SHA256).Hash)
        ) | Set-Content -LiteralPath (Join-Path $results 'verification.txt')
    } finally { Pop-Location }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $resolvedWork = [IO.Path]::GetFullPath($work)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($work))
    if (($resolvedWork.StartsWith($resolvedTemp + [IO.Path]::DirectorySeparatorChar)) -and
        ([IO.Path]::GetFileName($resolvedWork) -match '^codex_p4_radius_[0-9a-f]{32}$')) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
