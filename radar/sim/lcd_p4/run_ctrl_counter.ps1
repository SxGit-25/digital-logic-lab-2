param(
    [string]$ToolDirectory = ''
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(!$ToolDirectory){$ToolDirectory=Join-Path $root ((Split-Path $root -Leaf)+'\radar\sim\tools\iverilog\app\bin')}
$results = Join-Path $root 'radar\lcd_p4_opt\results\ctrl_counter'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) ('codex_p4_ctrl_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$ascii = [Text.Encoding]::ASCII
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $baseline = & git -C $root show 'f4507a8:radar/rtl/radar_ctrl.v'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read immutable f4507a8 baseline' }
    $baselineText = ($baseline -join "`n") -replace 'module radar_ctrl #', 'module radar_ctrl_counter_legacy #'
    [IO.File]::WriteAllText((Join-Path $work 'radar_ctrl_counter_legacy.v'), $baselineText, $ascii)
    Copy-Item (Join-Path $root 'radar\rtl\*.v') $work
    Copy-Item (Join-Path $root 'radar\sim\p3_modes\tb_continuous_ctrl.v') $work
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tb_ctrl_counter_integration.v') -Destination (Join-Path $work 'tb_ctrl_counter_integration.v')
    $env:TEMP = $work
    $env:TMP = $work
    Push-Location $work
    try {
        $compile = & (Join-Path $ToolDirectory 'iverilog.exe') '-g2005-sv' '-Wall' '-s' 'tb_ctrl_counter_integration' '-o' 'ctrl_counter.vvp' 'radar_ctrl_counter_legacy.v' 'radar_ctrl.v' 'tb_ctrl_counter_integration.v' 2>&1
        $compileCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $results 'compile.log'),
            ((@("compile_exit_code=$compileCode") + @($compile)) -join "`r`n"))
        if ($compileCode -ne 0) { throw "iverilog failed: $compileCode" }
        $simulation = & (Join-Path $ToolDirectory 'vvp.exe') 'ctrl_counter.vvp' 2>&1
        $simulationCode = $LASTEXITCODE
        $simulation | Tee-Object -FilePath (Join-Path $results 'simulation.log')
        if ($simulationCode -ne 0) { throw "vvp failed: $simulationCode" }
        if (($simulation -join "`n") -notmatch 'PASS tb_ctrl_counter_integration') { throw 'Missing completion marker' }
        $allRtl=@(Get-ChildItem -Filter '*.v' | Where-Object {$_.Name -notlike 'tb_*'} | ForEach-Object Name)
        $p3Compile=& (Join-Path $ToolDirectory 'iverilog.exe') -g2005-sv -Wall -s tb_continuous_ctrl -o p3_ctrl.vvp @allRtl tb_continuous_ctrl.v 2>&1
        if($LASTEXITCODE){throw ($p3Compile -join "`n")}
        $p3=& (Join-Path $ToolDirectory 'vvp.exe') p3_ctrl.vvp 2>&1
        $p3Code=$LASTEXITCODE
        $p3 | Tee-Object -FilePath (Join-Path $results 'p3_ctrl.log')
        if($p3Code -or ($p3 -join "`n") -notmatch 'PASS') {throw 'P3 controller regression failed'}
        @(
            'baseline_commit=f4507a8',
            "compile_exit_code=$compileCode",
            "simulation_exit_code=$simulationCode",
            ('radar_ctrl_sha256=' + (Get-FileHash (Join-Path $work 'radar_ctrl.v') -Algorithm SHA256).Hash),
            ('testbench_sha256=' + (Get-FileHash (Join-Path $work 'tb_ctrl_counter_integration.v') -Algorithm SHA256).Hash)
        ) | Set-Content -LiteralPath (Join-Path $results 'verification.txt')
    } finally { Pop-Location }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $resolvedWork = [IO.Path]::GetFullPath($work)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($work))
    if (($resolvedWork.StartsWith($resolvedTemp + [IO.Path]::DirectorySeparatorChar)) -and
        ([IO.Path]::GetFileName($resolvedWork) -match '^codex_p4_ctrl_[0-9a-f]{32}$')) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}




