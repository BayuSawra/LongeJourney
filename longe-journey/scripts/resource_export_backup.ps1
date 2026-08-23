[CmdletBinding()]
param(
    [string]$ManifestPath = "docs/resource_manifest.json",
    [string]$BackupRoot = "backups/resources",
    [string]$GodotExe = "E:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe",
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

function Resolve-ProjectPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
}

function Get-ManifestEntries {
    param($Manifest)

    if ($null -eq $Manifest) {
        return @()
    }
    if ($Manifest -is [System.Array]) {
        return @($Manifest)
    }

    $names = @($Manifest.PSObject.Properties.Name)
    if ($names -contains "resources") {
        return @($Manifest.resources)
    }
    if ($names -contains "files") {
        return @($Manifest.files)
    }
    if ($names -contains "paths") {
        return @($Manifest.paths)
    }
    if ($names -contains "categories") {
        $result = @()
        foreach ($property in $Manifest.categories.PSObject.Properties) {
            $value = $property.Value
            if ($value -is [System.Array]) {
                $result += @($value)
            }
            elseif ($null -ne $value) {
                $result += $value
            }
        }
        return $result
    }
    return @($Manifest)
}

function Get-EntryPath {
    param($Entry)

    $names = @($Entry.PSObject.Properties.Name)
    foreach ($name in @("path", "resource_path", "file", "relative_path", "resource")) {
        if ($names -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Entry.$name)) {
            return ([string]$Entry.$name).Trim()
        }
    }
    return $null
}

function Get-EntryCategory {
    param($Entry)

    $names = @($Entry.PSObject.Properties.Name)
    foreach ($name in @("category", "group", "kind")) {
        if ($names -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Entry.$name)) {
            return ([string]$Entry.$name).Trim()
        }
    }
    return $null
}

function Add-CopiedFile {
    param(
        [string]$SourceRelative,
        [string]$DestinationRelative,
        [string]$Category,
        [string]$Kind
    )

    $sourcePath = Join-Path $ProjectRoot ($SourceRelative -replace "/", "\")
    $destinationPath = Join-Path $BackupDir ($DestinationRelative -replace "/", "\")

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing source file: $SourceRelative"
    }

    $destinationDir = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force

    $hash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    return [pscustomobject]@{
        path = $SourceRelative
        backup_path = $DestinationRelative.Replace("\", "/")
        category = $Category
        kind = $Kind
        sha256 = $hash
    }
}

$ManifestPath = Resolve-ProjectPath $ManifestPath
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest not found: $ManifestPath"
}

$ManifestData = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
$Entries = @(Get-ManifestEntries $ManifestData)
if ($Entries.Count -eq 0) {
    throw "No resource entries found in manifest: $ManifestPath"
}

$BackupRoot = Resolve-ProjectPath $BackupRoot
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $BackupRoot $Stamp
if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$CopiedFiles = @()
$AllowedCategories = @("art", "art/icon", "font")

foreach ($Entry in $Entries) {
    $entryPath = Get-EntryPath $Entry
    if ([string]::IsNullOrWhiteSpace($entryPath)) {
        continue
    }

    $category = Get-EntryCategory $Entry
    if ($null -ne $category -and $AllowedCategories -notcontains $category) {
        continue
    }

    $sourceRelative = $entryPath
    $CopiedFiles += Add-CopiedFile $sourceRelative $sourceRelative $category "resource"

    $includeImport = $true
    if ($Entry.PSObject.Properties.Name -contains "has_import") {
        $hasImport = $Entry.has_import
        if ($hasImport -is [bool]) {
            $includeImport = $hasImport
        }
        else {
            $includeImport = ("$hasImport").ToLowerInvariant() -notin @("0", "false", "no")
        }
    }

    if (-not $includeImport) {
        continue
    }

    $importSource = $null
    if ($Entry.PSObject.Properties.Name -contains "import_path" -and -not [string]::IsNullOrWhiteSpace([string]$Entry.import_path)) {
        $importSource = ([string]$Entry.import_path).Trim()
    }
    else {
        $importSource = "$entryPath.import"
    }

    $importLive = Join-Path $ProjectRoot ($importSource -replace "/", "\")
    if (Test-Path -LiteralPath $importLive -PathType Leaf) {
        $CopiedFiles += Add-CopiedFile $importSource $importSource $category "import"
    }
}

if ($CopiedFiles.Count -eq 0) {
    throw "No files exported from manifest: $ManifestPath"
}

$BackupManifest = [ordered]@{
    format_version = 1
    generated_by = "scripts/resource_export_backup.ps1"
    created_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    project_root = $ProjectRoot
    backup_root = $BackupDir
    resources = $Entries.Count
    files = @($CopiedFiles)
}

$BackupManifestJson = $BackupManifest | ConvertTo-Json -Depth 10
$BackupManifestPath = Join-Path $BackupDir "backup_manifest.json"
[System.IO.File]::WriteAllText($BackupManifestPath, $BackupManifestJson, (New-Object System.Text.UTF8Encoding($false)))

$RoundtripFailures = @()
$Staging = Join-Path ([System.IO.Path]::GetTempPath()) ("resource_export_backup_" + [Guid]::NewGuid().ToString("N"))

try {
    Copy-Item -LiteralPath $BackupDir -Destination $Staging -Recurse
    foreach ($Record in $CopiedFiles) {
        $livePath = Join-Path $ProjectRoot ($Record.path -replace "/", "\")
        $restoredPath = Join-Path $Staging ($Record.backup_path -replace "/", "\")
        $liveHash = (Get-FileHash -LiteralPath $livePath -Algorithm SHA256).Hash
        $restoredHash = (Get-FileHash -LiteralPath $restoredPath -Algorithm SHA256).Hash
        if ($liveHash -ne $Record.sha256 -or $restoredHash -ne $Record.sha256) {
            $RoundtripFailures += "Hash mismatch: $($Record.path)"
        }
    }
}
finally {
    if (Test-Path -LiteralPath $Staging) {
        Remove-Item -LiteralPath $Staging -Recurse -Force
    }
}

if ($RoundtripFailures.Count -gt 0) {
    $RoundtripFailures | ForEach-Object { Write-Error $_ }
    throw "Round-trip validation failed for $($RoundtripFailures.Count) file(s)"
}

if (-not $SkipGodot) {
    if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
        throw "Godot executable not found: $GodotExe"
    }
    Write-Host "Running Godot headless import validation..."
    try {
        & $GodotExe --headless --path $ProjectRoot --import | Out-Null
    } catch {
        throw "Godot headless --import failed: $_"
    }
}

$Validation = if ($SkipGodot) { "skipped" } else { "passed" }
Write-Host "exported=$($CopiedFiles.Count) resources=$($Entries.Count) roundtrip=passed validation=$Validation"
Write-Host "backup=$BackupDir"
