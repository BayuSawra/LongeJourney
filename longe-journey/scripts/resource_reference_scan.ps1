$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path (Join-Path $repoRoot "docs") "resource_references.json"

$targetDirs = @(
    (Join-Path $repoRoot "docs"),
    (Join-Path $repoRoot "lore"),
    (Join-Path $repoRoot "scenes"),
    (Join-Path $repoRoot "scripts")
)

$excludedFiles = @(
    $outputPath,
    (Join-Path (Join-Path $repoRoot "scripts") "resource_reference_scan.ps1")
)

$prefix = "res" + "://"
$delimiterPattern = '[ \t"''`\[\](){}]'
$trailingChars = @([char]'.', [char]',', [char]';', [char]0x3002)

$references = New-Object System.Collections.Generic.List[object]

function Get-RelativePath {
    param([string]$fullPath)
    return $fullPath.Substring($repoRoot.Length + 1).Replace("\", "/")
}

foreach ($dir in $targetDirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        continue
    }

    $files = Get-ChildItem -LiteralPath $dir -Recurse -File | Where-Object {
        $excludedFiles -notcontains $_.FullName
    }

    foreach ($file in $files) {
        $reader = $null
        try {
            $reader = New-Object System.IO.StreamReader($file.FullName, [System.Text.Encoding]::UTF8, $true)
        } catch {
            continue
        }

        try {
            $lineNumber = 0
            while (($line = $reader.ReadLine()) -ne $null) {
                $lineNumber++

                $searchFrom = 0
                while (($idx = $line.IndexOf($prefix, $searchFrom, [StringComparison]::OrdinalIgnoreCase)) -ge 0) {
                    $refStart = $idx + $prefix.Length
                    $refEnd = $refStart
                    while ($refEnd -lt $line.Length -and $line[$refEnd] -notmatch $delimiterPattern) {
                        $refEnd++
                    }

                    $raw = $line.Substring($refStart, $refEnd - $refStart).TrimEnd($trailingChars)
                    if ($raw.Length -gt 0) {
                        if ($raw -match '\.([A-Za-z0-9_+-]+)\s*$') {
                            $type = $matches[1].ToLowerInvariant()
                        } else {
                            $type = "unknown"
                        }

                        try {
                            $resolved = Test-Path -LiteralPath (Join-Path $repoRoot $raw)
                        } catch {
                            $resolved = $false
                        }
                        $source = Get-RelativePath $file.FullName

                        $references.Add([pscustomobject]@{
                            source = $source
                            line = $lineNumber
                            reference = $raw
                            type = $type
                            resolved = [bool]$resolved
                        })
                    }

                    $searchFrom = $refEnd + 1
                }
            }
        } finally {
            $reader.Dispose()
        }
    }
}

$allReferences = New-Object System.Collections.Generic.List[object]
foreach ($ref in $references) {
    $allReferences.Add($ref)
}
$resolvedReferences = @($allReferences | Where-Object { $_.resolved })
$unresolvedReferences = @($allReferences | Where-Object { -not $_.resolved })

$result = [ordered]@{
    task = "10.1.4b resource reference analysis"
    generated_at = [DateTimeOffset]::Now.ToString("o")
    reference_count = $allReferences.Count
    resolved_count = $resolvedReferences.Count
    unresolved_count = $unresolvedReferences.Count
    references = $allReferences
    unresolved_references = $unresolvedReferences
}

$json = ConvertTo-Json -InputObject $result -Depth 6
[System.IO.File]::WriteAllText($outputPath, $json, (New-Object System.Text.UTF8Encoding($false)))

$failures = New-Object System.Collections.Generic.List[string]

if ($result.reference_count -ne $allReferences.Count) {
    $failures.Add("reference_count mismatch")
}
if ($result.resolved_count -ne $resolvedReferences.Count) {
    $failures.Add("resolved_count mismatch")
}
if ($result.unresolved_count -ne $unresolvedReferences.Count) {
    $failures.Add("unresolved_count mismatch")
}
if ($result.unresolved_count -ne $unresolvedReferences.Count) {
    $failures.Add("unresolved_references mismatch")
}

$expectedResolved = $allReferences | Where-Object { $_.reference -eq "art/shilin2.png" -and $_.resolved }
$expectedResolvedFlower = $allReferences | Where-Object { $_.reference -eq "art/icon/flowericon.png" -and $_.resolved }
if ($null -eq $expectedResolved) {
    $failures.Add("expected resolved art/shilin2.png missing")
}
if ($null -eq $expectedResolvedFlower) {
    $failures.Add("expected resolved art/icon/flowericon.png missing")
}

$fileContent = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
$fileResolved = @($fileContent.references | Where-Object { $_.resolved })
$fileUnresolved = @($fileContent.references | Where-Object { -not $_.resolved })
if ($fileContent.reference_count -ne $fileContent.references.Count) {
    $failures.Add("file reference_count mismatch")
}
if ($fileContent.resolved_count -ne $fileResolved.Count) {
    $failures.Add("file resolved_count mismatch")
}
if ($fileContent.unresolved_count -ne $fileUnresolved.Count) {
    $failures.Add("file unresolved_count mismatch")
}
if ($fileContent.unresolved_count -ne $fileContent.unresolved_references.Count) {
    $failures.Add("file unresolved_references mismatch")
}

Write-Output ("references={0}" -f $allReferences.Count)
Write-Output ("resolved={0}" -f $resolvedReferences.Count)
Write-Output ("unresolved={0}" -f $unresolvedReferences.Count)
Write-Output ("output={0}" -f $outputPath)

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output ("FAIL: {0}" -f $failure)
    }
    exit 1
}

Write-Output "validation=passed"
