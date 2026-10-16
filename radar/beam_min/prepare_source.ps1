$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../..").Path
$dest=Join-Path $PSScriptRoot 'design/byte_a_source'
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$root/radar/rtl/*.v" -Destination $dest
Copy-Item "$root/radar/unified_scan/radar_unified_variants.v" -Destination $dest
Write-Output "Prepared simulation sources: $dest"
