param(
 [Parameter(Mandatory=$true)][string]$Stage,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [string]$Project='radar_unified_bcd',
 [string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64'
)
$ErrorActionPreference='Stop'
$outputPath=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force $outputPath | Out-Null
$stagePath=[IO.Path]::GetFullPath($Stage)
$toolOutput=Join-Path $stagePath 'p5_postfit_evidence'
New-Item -ItemType Directory -Force $toolOutput | Out-Null
# Copy Tcl into the ASCII project stage to avoid Quartus 9.1 path encoding limits.
Copy-Item -LiteralPath "$PSScriptRoot/postfit.tcl" -Destination "$Stage/p5_postfit.tcl" -Force
Push-Location -LiteralPath $Stage
try {
 & "$QuartusBin/quartus_sta.exe" -t p5_postfit.tcl $Project $toolOutput *> "$toolOutput/postfit_execution.log"
 $staExit=$LASTEXITCODE
} finally {Pop-Location}
if($toolOutput -ne $outputPath){Copy-Item "$toolOutput/*" -Destination $outputPath -Force}
& python "$PSScriptRoot/summarize_postfit.py" $outputPath
if($LASTEXITCODE -ne 0){throw 'Postfit report parse failed'}
if($staExit -ne 0){throw "Postfit assertions failed; see $outputPath"}
