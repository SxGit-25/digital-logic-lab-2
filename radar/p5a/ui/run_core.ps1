param([string]$IverilogBin='', [string]$CoreSource='', [string]$ResultName='core_results')
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../../..").Path
if(!$IverilogBin){$IverilogBin=(Get-ChildItem $root -Filter iverilog.exe -Recurse | Select-Object -First 1).DirectoryName}
if(!$CoreSource){$CoreSource="$root/radar/p5a/design/radar_lcd_micro_ui.v"}
$out=Join-Path $PSScriptRoot $ResultName
New-Item -ItemType Directory $out -Force | Out-Null
$stage=Join-Path ([IO.Path]::GetTempPath()) ('p5_ui_core_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
Copy-Item -LiteralPath $CoreSource -Destination "$stage/radar_lcd_micro_ui.v"
Copy-Item "$root/radar/rtl/minsky_serial_datapath.v","$root/radar/rtl/p5_ui_columns.v","$PSScriptRoot/tb_p5_ui_core.v" $stage
Push-Location $stage
try {
    foreach($flags in @('111','110','101','100','011','010','001','000')) {
        & "$IverilogBin/iverilog.exe" -g2005-sv -s tb_p5_ui_core "-Ptb_p5_ui_core.P5_DIGITS=$($flags[0])" "-Ptb_p5_ui_core.P5_MODE=$($flags[1])" "-Ptb_p5_ui_core.P5_LEVEL=$($flags[2])" -o test.vvp radar_lcd_micro_ui.v minsky_serial_datapath.v p5_ui_columns.v tb_p5_ui_core.v *> "$out/$flags.compile.log"
        if($LASTEXITCODE){throw "$flags compilation failed"}
        & "$IverilogBin/vvp.exe" test.vvp *> "$out/$flags.simulation.log"
        if($LASTEXITCODE){throw "$flags simulation failed"}
        python "$PSScriptRoot/check_core_stream.py" "$out/$flags.simulation.log" $flags *> "$out/$flags.reference.log"
        if($LASTEXITCODE){throw "$flags Python comparison failed"}
        Get-Content "$out/$flags.simulation.log" -Tail 2
        Get-Content "$out/$flags.reference.log"
    }
} finally {Pop-Location}
