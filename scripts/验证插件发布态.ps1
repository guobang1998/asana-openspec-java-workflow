param(
    [string]$CacheRoot = (Join-Path $env:USERPROFILE '.codex\plugins\cache\personal\asana-openspec-java-workflow')
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourceManifestPath = Join-Path $RepoRoot '.codex-plugin\plugin.json'
$SourceManifest = Get-Content -LiteralPath $SourceManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$InstalledRoot = Join-Path $CacheRoot $SourceManifest.version
$InstalledManifestPath = Join-Path $InstalledRoot '.codex-plugin\plugin.json'
$RequiredSkills = @(
    'skills\setup-workflow\SKILL.md',
    'skills\wayfinder-workflow\SKILL.md',
    'skills\asana-openspec-delivery\SKILL.md'
)
$Errors = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $InstalledManifestPath)) {
    $Errors.Add("Missing installed plugin version: $($SourceManifest.version)")
} else {
    $InstalledManifest = Get-Content -LiteralPath $InstalledManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($InstalledManifest.version -ne $SourceManifest.version) {
        $Errors.Add("Installed version differs from source: $($InstalledManifest.version) != $($SourceManifest.version)")
    }
}

foreach ($RelativePath in $RequiredSkills) {
    if (-not (Test-Path -LiteralPath (Join-Path $InstalledRoot $RelativePath))) {
        $Errors.Add("Missing installed skill: $RelativePath")
    }
}

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Plugin release state: PASS ($($SourceManifest.version))"
