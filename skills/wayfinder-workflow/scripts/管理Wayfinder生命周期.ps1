param(
    [Parameter(Mandatory)]
    [string]$MapPath,

    [Parameter(Mandatory)]
    [ValidateSet('PrepareHandoff', 'Close')]
    [string]$Operation,

    [ValidateSet('prd', 'openspec', 'rfc', 'done')]
    [string]$HandoffStage,

    [string]$HandoffTarget,

    [ValidateRange(100, 30000)]
    [int]$LockTimeoutMs = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$MapFile = Get-Item -LiteralPath $MapPath
if ($MapFile.PSIsContainer -or ($MapFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Map path must be a regular file: $($MapFile.FullName)"
}
$MapDirectory = $MapFile.Directory.FullName
$Selector = Join-Path $PSScriptRoot '解析Frontier指针.ps1'
$LockPath = Join-Path $MapDirectory '.wayfinder-state.lock'
$HandoffPath = Join-Path $MapDirectory '交接.md'

function Enter-WayfinderLock {
    $Deadline = [DateTime]::UtcNow.AddMilliseconds($LockTimeoutMs)
    while ([DateTime]::UtcNow -lt $Deadline) {
        try {
            return [System.IO.FileStream]::new(
                $LockPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None,
                1,
                [System.IO.FileOptions]::DeleteOnClose
            )
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 50
        }
    }
    throw "Timed out acquiring Wayfinder state lock: $LockPath"
}

function Get-Frontmatter([string]$Content) {
    $Match = [regex]::Match($Content, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $Match.Success) {
        throw 'Map has incomplete YAML frontmatter'
    }
    return $Match.Groups['yaml'].Value
}

function Get-YamlValue([string]$Yaml, [string]$Name, [bool]$Required = $true) {
    $Matches = [regex]::Matches($Yaml, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if ($Matches.Count -eq 0 -and -not $Required) {
        return ''
    }
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one YAML key $Name"
    }
    return $Matches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Set-YamlValue([string]$Content, [string]$Name, [string]$Value) {
    $Frontmatter = [regex]::Match($Content, '(?s)\A(?<prefix>---\r?\n)(?<yaml>.*?)(?<suffix>\r?\n---(?:\r?\n|\z).*)\z')
    if (-not $Frontmatter.Success) {
        throw 'Map has incomplete YAML frontmatter'
    }
    $Yaml = $Frontmatter.Groups['yaml'].Value
    $Pattern = "(?m)^$([regex]::Escape($Name)):[^\r\n]*$"
    $Matches = [regex]::Matches($Yaml, $Pattern)
    if ($Matches.Count -gt 1) {
        throw "Expected at most one YAML key $Name"
    }
    if ($Matches.Count -eq 1) {
        $UpdatedYaml = [regex]::Replace(
            $Yaml,
            $Pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($Match) "$Name`: $Value" },
            1
        )
    } else {
        $UpdatedYaml = $Yaml.TrimEnd() + "`n$Name`: $Value"
    }
    return $Frontmatter.Groups['prefix'].Value + $UpdatedYaml + $Frontmatter.Groups['suffix'].Value
}

function Write-Atomic([string]$Path, [string]$Content) {
    $TemporaryPath = "$Path.tmp.$([Guid]::NewGuid().ToString('N'))"
    $BackupPath = "$Path.bak.$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($TemporaryPath, $Content, [System.Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($TemporaryPath, $Path, $BackupPath, $true)
        } else {
            [System.IO.File]::Move($TemporaryPath, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
        if (Test-Path -LiteralPath $BackupPath) {
            Remove-Item -LiteralPath $BackupPath -Force
        }
    }
}

function Write-MapIfUnchanged([string]$Content, [string]$ExpectedHash) {
    $TemporaryPath = "$($MapFile.FullName).tmp.$([Guid]::NewGuid().ToString('N'))"
    $BackupPath = "$($MapFile.FullName).bak.$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($TemporaryPath, $Content, [System.Text.UTF8Encoding]::new($false))
        $ActualHash = (Get-FileHash -LiteralPath $MapFile.FullName -Algorithm SHA256).Hash
        if ($ActualHash -ne $ExpectedHash) {
            throw "Wayfinder state changed during lifecycle transition: $($MapFile.FullName)"
        }
        [System.IO.File]::Replace($TemporaryPath, $MapFile.FullName, $BackupPath, $true)
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
        if (Test-Path -LiteralPath $BackupPath) {
            Remove-Item -LiteralPath $BackupPath -Force
        }
    }
}

function Get-MapSection([string]$Content, [string]$Name) {
    $Escaped = [regex]::Escape($Name)
    $Matches = [regex]::Matches($Content, "(?m)^## $Escaped[ \t]*$")
    if ($Matches.Count -ne 1) {
        throw "Map must contain exactly one $Name section"
    }
    return [regex]::Match($Content, "(?ms)^## $Escaped[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)").Groups['body'].Value.Trim()
}

function Get-MapTitle([string]$Content) {
    $Body = [regex]::Match($Content, '(?s)\A---\r?\n.*?\r?\n---(?:\r?\n|\z)(?<body>.*)\z').Groups['body'].Value
    $Titles = [regex]::Matches($Body, '(?m)^#[ \t]+(?!#)(?<title>.+?)[ \t]*$')
    if ($Titles.Count -ne 1) {
        throw 'Map must contain exactly one level-one title'
    }
    return $Titles[0].Groups['title'].Value.Trim()
}

function Get-Snapshot($Audit) {
    $Hashes = [ordered]@{}
    $Hashes[$MapFile.FullName] = (Get-FileHash -LiteralPath $MapFile.FullName -Algorithm SHA256).Hash
    foreach ($Ticket in @($Audit.tickets)) {
        $Hashes[$Ticket.path] = (Get-FileHash -LiteralPath $Ticket.path -Algorithm SHA256).Hash
    }
    return $Hashes
}

function Assert-SnapshotUnchanged($Hashes) {
    foreach ($Entry in $Hashes.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $Entry.Key) -or (Get-FileHash -LiteralPath $Entry.Key -Algorithm SHA256).Hash -ne $Entry.Value) {
            throw "Wayfinder state changed during lifecycle transition: $($Entry.Key)"
        }
    }
}

function Read-StableMap {
    $Before = (Get-FileHash -LiteralPath $MapFile.FullName -Algorithm SHA256).Hash
    $Content = Get-Content -LiteralPath $MapFile.FullName -Raw -Encoding UTF8
    $After = (Get-FileHash -LiteralPath $MapFile.FullName -Algorithm SHA256).Hash
    if ($Before -ne $After) {
        throw "Wayfinder map changed while being read: $($MapFile.FullName)"
    }
    return [pscustomobject]@{ content = $Content; hash = $After }
}

function Get-StableAudit([string]$ExpectedMapHash) {
    $FirstAudit = (& $Selector -MapPath $MapFile.FullName -Mode Audit) | ConvertFrom-Json
    $Snapshot = Get-Snapshot $FirstAudit
    if ($Snapshot[$MapFile.FullName] -ne $ExpectedMapHash) {
        throw "Wayfinder state changed during lifecycle transition: $($MapFile.FullName)"
    }
    $SecondAudit = (& $Selector -MapPath $MapFile.FullName -Mode Audit) | ConvertFrom-Json
    Assert-SnapshotUnchanged $Snapshot
    return [pscustomobject]@{ audit = $SecondAudit; snapshot = $Snapshot }
}

function Assert-HandoffFile([string]$MapId, [string]$Stage) {
    if (-not (Test-Path -LiteralPath $HandoffPath -PathType Leaf)) {
        throw "Map $MapId has no valid handoff file"
    }
    $Item = Get-Item -LiteralPath $HandoffPath
    if (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Map $MapId handoff file cannot be a junction or symbolic link"
    }
    $HandoffYaml = Get-Frontmatter (Get-Content -LiteralPath $HandoffPath -Raw -Encoding UTF8)
    if ((Get-YamlValue $HandoffYaml 'map_id') -ne $MapId -or
        (Get-YamlValue $HandoffYaml 'status') -ne 'ready_for_handoff' -or
        (Get-YamlValue $HandoffYaml 'handoff_stage') -ne $Stage) {
        throw "Map $MapId has an invalid handoff file"
    }
}

function New-HandoffContent([string]$MapContent, [string]$MapId, [string]$Stage) {
    $Title = Get-MapTitle $MapContent
    $Destination = Get-MapSection $MapContent 'Destination'
    $Decisions = Get-MapSection $MapContent 'Decisions so far'
    $AssetLines = [System.Collections.Generic.List[string]]::new()
    $ResearchDirectory = Join-Path $MapDirectory 'research'
    if (Test-Path -LiteralPath $ResearchDirectory) {
        foreach ($Asset in @(Get-ChildItem -LiteralPath $ResearchDirectory -File -Filter '*-研究.md' | Sort-Object Name)) {
            $AssetLines.Add("- [$($Asset.BaseName)](research/$($Asset.Name))")
        }
    }
    if ($AssetLines.Count -eq 0) {
        $AssetLines.Add('-')
    }
    $GeneratedAt = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [System.Globalization.CultureInfo]::InvariantCulture)
    return @"
---
map_id: $MapId
status: ready_for_handoff
handoff_stage: $Stage
generated_at: $GeneratedAt
---

# $Title 交接

## Destination

$Destination

## Decision pointers

$Decisions

## Research assets

$([string]::Join("`n", $AssetLines))
"@
}

$Lock = Enter-WayfinderLock
try {
    $InitialMap = Read-StableMap
    $MapContent = $InitialMap.content
    $InitialMapHash = $InitialMap.hash
    $MapYaml = Get-Frontmatter $MapContent
    $MapId = Get-YamlValue $MapYaml 'id'
    $Status = Get-YamlValue $MapYaml 'status'

    if ($Operation -eq 'PrepareHandoff') {
        if ([string]::IsNullOrWhiteSpace($HandoffStage)) {
            throw 'PrepareHandoff requires HandoffStage'
        }
        if ($Status -eq 'closed') {
            throw "Closed map $MapId cannot prepare another handoff"
        }
        if ($Status -eq 'ready_for_handoff') {
            $ExistingStage = Get-YamlValue $MapYaml 'handoff_stage'
            if ($ExistingStage -ne $HandoffStage) {
                throw "Map $MapId already targets handoff stage $ExistingStage"
            }
        } elseif ($Status -ne 'active') {
            throw "Map $MapId has invalid lifecycle status: $Status"
        }

        $Stable = Get-StableAudit $InitialMapHash
        $Audit = $Stable.audit
        if (@($Audit.missing).Count -gt 0 -or $Audit.live_count -ne 0 -or $Audit.has_fog) {
            throw "Map $MapId is not ready for handoff"
        }
        $Snapshot = $Stable.snapshot
        $Handoff = New-HandoffContent $MapContent $MapId $HandoffStage
        Assert-SnapshotUnchanged $Snapshot
        Write-Atomic $HandoffPath $Handoff

        $Retry = $Status -eq 'ready_for_handoff'
        if (-not $Retry) {
            Assert-SnapshotUnchanged $Snapshot
            $Now = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [System.Globalization.CultureInfo]::InvariantCulture)
            $Updated = Set-YamlValue $MapContent 'status' 'ready_for_handoff'
            $Updated = Set-YamlValue $Updated 'handoff_path' '交接.md'
            $Updated = Set-YamlValue $Updated 'handoff_stage' $HandoffStage
            $Updated = Set-YamlValue $Updated 'ready_at' $Now
            $Updated = Set-YamlValue $Updated 'updated_at' $Now
            Write-MapIfUnchanged $Updated $Snapshot[$MapFile.FullName]
        }

        if ($Retry) {
            Assert-SnapshotUnchanged $Snapshot
        }
        Assert-HandoffFile $MapId $HandoffStage
        $VerifiedMap = Get-Frontmatter (Get-Content -LiteralPath $MapFile.FullName -Raw -Encoding UTF8)
        $VerifiedHandoff = Get-Frontmatter (Get-Content -LiteralPath $HandoffPath -Raw -Encoding UTF8)
        if ((Get-YamlValue $VerifiedMap 'status') -ne 'ready_for_handoff' -or
            (Get-YamlValue $VerifiedMap 'handoff_stage') -ne $HandoffStage -or
            (Get-YamlValue $VerifiedHandoff 'map_id') -ne $MapId -or
            (Get-YamlValue $VerifiedHandoff 'handoff_stage') -ne $HandoffStage) {
            throw 'PrepareHandoff terminal verification failed'
        }
        [pscustomobject]@{ map_id = $MapId; status = 'ready_for_handoff'; handoff_stage = $HandoffStage; handoff_path = $HandoffPath; retry = $Retry } | ConvertTo-Json -Compress
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($HandoffTarget) -or $HandoffTarget -match '[\r\n]' -or $HandoffTarget -match '^<.*>$') {
        throw 'Close requires a concrete HandoffTarget'
    }
    if ($Status -eq 'active') {
        throw "Active map $MapId must prepare handoff before close"
    }
    $Stable = Get-StableAudit $InitialMapHash
    $Audit = $Stable.audit
    $Snapshot = $Stable.snapshot
    if (@($Audit.missing).Count -gt 0 -or $Audit.live_count -ne 0 -or $Audit.has_fog) {
        throw "Map $MapId is not ready to close"
    }
    $RecordedPath = Get-YamlValue $MapYaml 'handoff_path'
    $RecordedStage = Get-YamlValue $MapYaml 'handoff_stage'
    if ($RecordedPath -ne '交接.md' -or [string]::IsNullOrWhiteSpace($RecordedStage)) {
        throw "Map $MapId has no valid handoff metadata"
    }
    Assert-HandoffFile $MapId $RecordedStage
    if ($Status -eq 'closed') {
        $ExistingTarget = Get-YamlValue $MapYaml 'handoff_target'
        if ($ExistingTarget -ne $HandoffTarget) {
            throw "Map $MapId is already closed with another handoff target"
        }
        [pscustomobject]@{ map_id = $MapId; status = 'closed'; handoff_target = $HandoffTarget; retry = $true } | ConvertTo-Json -Compress
        exit 0
    }
    if ($Status -ne 'ready_for_handoff') {
        throw "Map $MapId has invalid lifecycle status: $Status"
    }
    Assert-SnapshotUnchanged $Snapshot
    $Now = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [System.Globalization.CultureInfo]::InvariantCulture)
    $Updated = Set-YamlValue $MapContent 'status' 'closed'
    $Updated = Set-YamlValue $Updated 'handoff_target' $HandoffTarget
    $Updated = Set-YamlValue $Updated 'closed_at' $Now
    $Updated = Set-YamlValue $Updated 'updated_at' $Now
    Write-MapIfUnchanged $Updated $Snapshot[$MapFile.FullName]
    $VerifiedMap = Get-Frontmatter (Get-Content -LiteralPath $MapFile.FullName -Raw -Encoding UTF8)
    if ((Get-YamlValue $VerifiedMap 'status') -ne 'closed' -or (Get-YamlValue $VerifiedMap 'handoff_target') -ne $HandoffTarget) {
        throw 'Close terminal verification failed'
    }
    [pscustomobject]@{ map_id = $MapId; status = 'closed'; handoff_target = $HandoffTarget; retry = $false } | ConvertTo-Json -Compress
} finally {
    $Lock.Dispose()
}
