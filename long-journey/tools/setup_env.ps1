param(
    [string]$Destination = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ".local-tools/godot-4.7")
)
$ErrorActionPreference = "Stop"
$version = "4.7"
$archiveName = "Godot_v${version}-stable_win64.exe.zip"
$url = "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/$archiveName"
# Official SHA512-SUMS.txt for 4.7-stable.
$sha512 = "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) {
    throw "Destination already exists; choose a new directory: $Destination"
}
New-Item -ItemType Directory -Path $Destination | Out-Null
$archive = Join-Path $Destination $archiveName
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash.ToLowerInvariant() -ne $sha512) {
    throw "Godot archive checksum mismatch: $archive"
}
Expand-Archive -LiteralPath $archive -DestinationPath $Destination
$godot = Join-Path $Destination "Godot_v${version}-stable_win64_console.exe"
$actual = & $godot --version
if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne "4.7.stable.official.5b4e0cb0f") {
    throw "Unexpected Godot version: $actual"
}
Write-Output $godot
