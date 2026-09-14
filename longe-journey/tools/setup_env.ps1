param(
    [string]$Destination = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ".local-tools/godot-4.6.2")
)
$ErrorActionPreference = "Stop"
$version = "4.6.2"
$archiveName = "Godot_v${version}-stable_win64.exe.zip"
$url = "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/$archiveName"
# Official SHA512-SUMS.txt for 4.6.2-stable.
$sha512 = "01c3bc0ede0f8771e810832fb92ce52a3a4352af7b7ac32a81a8edf05bb30760f56a6ab7e17cebc80b81c4f609a95c24c2fdbbe6929ac4e0285cb8f654b56d78"
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
if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne "4.6.2.stable.official.71f334935") {
    throw "Unexpected Godot version: $actual"
}
Write-Output $godot
