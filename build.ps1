param([string]$QuartusBin='E:\quartus\QuartusII91\quartus\bin64')
$ErrorActionPreference='Stop'
$exe=Join-Path $QuartusBin 'quartus_sh.exe'
if(!(Test-Path -LiteralPath $exe)){throw "Quartus not found: $exe"}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('radar1270_'+[Guid]::NewGuid().ToString('N'))
$out=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force -Path $stage,$out | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rtl') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'quartus') -Destination $stage -Recurse
$drive=$null
foreach($letter in 'R','S','T','U','V','W','X','Y','Z'){
    if(!(Test-Path "${letter}:\")){$drive="${letter}:";break}
}
if(!$drive){throw 'No free drive for Quartus ASCII path mapping'}
$mapped=$false
$pushed=$false
try{
    & subst.exe $drive $stage
    if($LASTEXITCODE -ne 0){throw 'SUBST failed'}
    $mapped=$true
    Push-Location "$drive/quartus"
    $pushed=$true
    & $exe --flow compile radar_unified_bcd *> (Join-Path $out 'compile.log')
    $code=$LASTEXITCODE
    Get-ChildItem -LiteralPath "$stage/quartus" -File |
        Where-Object {$_.Extension -in '.rpt','.summary','.pof','.pin'} |
        Copy-Item -Destination $out -Force
    Get-Content -LiteralPath (Join-Path $out 'compile.log') -Tail 12
    if($code -ne 0){throw "Compile failed ($code); see build/compile.log"}
    Write-Output 'Compile passed. Reports and rebuilt POF: build/'
}finally{
    if($pushed){Pop-Location}
    if($mapped){& subst.exe $drive /D}
    $resolvedStage=[IO.Path]::GetFullPath($stage)
    $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if(!$resolvedStage.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
       !(Split-Path $resolvedStage -Leaf).StartsWith('radar1270_')){throw 'Unexpected temp path'}
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
