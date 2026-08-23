param(
    [string]$ManifestPath = "docs/resource_manifest.json",
    [string]$ReferencesPath = "docs/resource_references.json",
    [string]$OutputPath = "docs/resource_validation.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

$ManifestPath = Join-Path $repoRoot $ManifestPath
$ReferencesPath = Join-Path $repoRoot $ReferencesPath
$OutputPath = Join-Path $repoRoot $OutputPath

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$references = Get-Content -LiteralPath $ReferencesPath -Raw -Encoding UTF8 | ConvertFrom-Json

$manifestResources = @($manifest.resources)
$manifestByPath = @{}
foreach ($item in $manifestResources) {
    $path = $item.path
    if (-not $manifestByPath.ContainsKey($path)) {
        $manifestByPath[$path] = New-Object System.Collections.ArrayList
    }
    [void]$manifestByPath[$path].Add($item)
}

$referenceList = @($references.references)
$referencedResourcePaths = @($referenceList | Where-Object {
    $_.type -and $_.reference -and
    ($_.reference -like "art/*" -or $_.reference -like "font/*") -and
    $_.reference -notlike "*/"
} | ForEach-Object { $_.reference } | Sort-Object -Unique)

$missing = @()
$orphan = @()
$inconsistency = @()

foreach ($resourcePath in $referencedResourcePaths) {
    if (-not $manifestByPath.ContainsKey($resourcePath)) {
        $missing += [PSCustomObject]@{
            path     = $resourcePath
            detail   = "reference without manifest entry"
            category = "missing"
        }
    }
}

foreach ($manifestItem in $manifestResources) {
    $path = $manifestItem.path
    $isReferenced = [System.Linq.Enumerable]::Contains([string[]]$referencedResourcePaths, $path)
    if (-not $isReferenced) {
        $orphan += [PSCustomObject]@{
            path     = $path
            category = $manifestItem.category
            detail   = "manifest entry without reference"
        }
    }
}

$duplicatePaths = @($manifestResources | Group-Object path | Where-Object { $_.Count -gt 1 })
foreach ($group in $duplicatePaths) {
    $inconsistency += [PSCustomObject]@{
        path     = $group.Name
        category = "manifest"
        detail   = "duplicate manifest entry ($($group.Count) times)"
    }
}

foreach ($item in $manifestResources) {
    $path = $item.path
    $importPath = "$path.import"
    $importFile = Join-Path $repoRoot $importPath
    if ($item.has_import -eq $true -and -not (Test-Path -LiteralPath $importFile)) {
        $inconsistency += [PSCustomObject]@{
            path     = $path
            category = "manifest"
            detail   = "has_import=true but .import file missing"
        }
    }
}

$typeSuffixMap = @{
    png  = @("png", "jpg", "jpeg", "webp", "svg")
    jpg  = @("png", "jpg", "jpeg", "webp", "svg")
    font = @("ttf", "otf", "woff", "woff2")
}
foreach ($reference in $referenceList) {
    if (-not $reference.type -or -not $reference.reference) {
        continue
    }
    if ($reference.reference -match '[<>:"|?*]') {
        continue
    }
    $ext = [System.IO.Path]::GetExtension($reference.reference).TrimStart(".").ToLowerInvariant()
    if (-not $typeSuffixMap.ContainsKey($reference.type)) {
        continue
    }
    $expectedSuffixes = $typeSuffixMap[$reference.type]
    if ($ext -and $expectedSuffixes -notcontains $ext) {
        $inconsistency += [PSCustomObject]@{
            path     = $reference.reference
            category = "reference"
            detail   = "type=$($reference.type) but extension=$ext"
        }
    }
}

$summary = [PSCustomObject]@{
    manifest_count = $manifestResources.Count
    reference_count = $referenceList.Count
    missing_count   = $missing.Count
    orphan_count    = $orphan.Count
    inconsistency_count = $inconsistency.Count
}

$result = [PSCustomObject]@{
    generated_at  = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    input_manifest = (Split-Path -Leaf $ManifestPath)
    input_references = (Split-Path -Leaf $ReferencesPath)
    summary        = $summary
    missing        = @($missing)
    orphan         = @($orphan)
    inconsistency  = @($inconsistency)
}

$json = $result | ConvertTo-Json -Depth 6
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

$orphanPaths = @($orphan | ForEach-Object { $_.path })
$mustNotBeOrphan = @(
    "art/icon/flowericon.png",
    "art/shilin2.png",
    "art/icon/moneyicon.png",
    "art/1.png",
    "art/jianshan2.png",
    "art/wife.png",
    "font/HYZIKUTANGJINGJIEKAITIW.TTF"
)

$checksOk = $true
if ($missing.Count -ne 0) {
    Write-Warning "Unexpected missing count: $($missing.Count) (expected 0)"
    $checksOk = $false
}
if ($orphan.Count -ne 13) {
    Write-Warning "Unexpected orphan count: $($orphan.Count) (expected 13)"
    $checksOk = $false
}
foreach ($path in $mustNotBeOrphan) {
    if ($orphanPaths -contains $path) {
        Write-Warning "Referenced resource reported as orphan: $path"
        $checksOk = $false
    }
}

Write-Output "wrote $OutputPath"
Write-Output "summary: manifest=$($summary.manifest_count) references=$($summary.reference_count) missing=$($summary.missing_count) orphan=$($summary.orphan_count) inconsistency=$($summary.inconsistency_count)"

if (-not $checksOk) {
    exit 1
}
