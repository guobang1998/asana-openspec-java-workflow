param(
    [Parameter(Mandatory)]
    [string]$MapPath,

    [Parameter(Mandatory)]
    [string]$TicketId,

    [Parameter(Mandatory)]
    [string]$Owner,

    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]]$Sources,

    [string]$TakeoverOwner,

    [ValidateRange(100, 30000)]
    [int]$LockTimeoutMs = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($TicketId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw 'TicketId contains unsafe characters'
}
if ($Owner -notmatch '^[A-Za-z0-9][A-Za-z0-9:._-]*$' -or $Owner -eq 'unclaimed') {
    throw 'Owner must be a safe, non-empty session-scoped value'
}
if ([string]::IsNullOrWhiteSpace($Content)) {
    throw 'Research content must not be empty'
}
if ($Sources.Count -eq 0) {
    throw 'Research requires at least one primary source'
}
if (-not [string]::IsNullOrWhiteSpace($TakeoverOwner) -and
    ($TakeoverOwner -notmatch '^[A-Za-z0-9][A-Za-z0-9:._-]*$' -or $TakeoverOwner -eq 'unclaimed')) {
    throw 'TakeoverOwner must be a safe previous owner value'
}

$MapFile = Get-Item -LiteralPath $MapPath
$MapDirectory = $MapFile.Directory.FullName
$TicketsDirectory = Join-Path $MapDirectory 'tickets'
$TicketsDirectoryItem = Get-Item -LiteralPath $TicketsDirectory
if (($TicketsDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Tickets directory cannot be a junction or symbolic link: $TicketsDirectory"
}
$ResearchDirectory = Join-Path $MapDirectory 'research'
$LockPath = Join-Path $MapDirectory '.wayfinder-state.lock'

function Enter-ResearchAssetLock {
    $Deadline = [DateTime]::UtcNow.AddMilliseconds($LockTimeoutMs)
    while ([DateTime]::UtcNow -lt $Deadline) {
        try {
            $Stream = [System.IO.FileStream]::new(
                $LockPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None,
                1,
                [System.IO.FileOptions]::DeleteOnClose
            )
            $Bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Owner)
            $Stream.Write($Bytes, 0, $Bytes.Length)
            $Stream.Flush($true)
            return $Stream
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 50
        }
    }
    throw "Timed out acquiring Research asset lock: $LockPath"
}

function Get-Frontmatter([string]$Path) {
    $Raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $Match = [regex]::Match($Raw, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $Match.Success) {
        throw "File has incomplete YAML frontmatter: $Path"
    }
    return $Match.Groups['yaml'].Value
}

function Get-YamlValue([string]$Yaml, [string]$Name) {
    $Matches = [regex]::Matches($Yaml, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one YAML key $Name"
    }
    return $Matches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Get-OptionalYamlValue([string]$Yaml, [string]$Name) {
    $Matches = [regex]::Matches($Yaml, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if ($Matches.Count -gt 1) {
        throw "Expected at most one YAML key $Name"
    }
    if ($Matches.Count -eq 0) {
        return ''
    }
    return $Matches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
}

function Get-TicketTitle([string]$TicketContent, [string]$TicketId) {
    $Body = [regex]::Match($TicketContent, '(?s)\A---\r?\n.*?\r?\n---(?:\r?\n|\z)(?<body>.*)\z')
    if (-not $Body.Success) {
        throw "Ticket $TicketId has incomplete YAML frontmatter"
    }
    $Titles = [regex]::Matches($Body.Groups['body'].Value, '(?m)^#[ \t]+(?!#)(?<title>.+?)[ \t]*$')
    if ($Titles.Count -ne 1) {
        throw "Ticket $TicketId must contain exactly one level-one title"
    }
    return $Titles[0].Groups['title'].Value.Trim()
}

function Test-ResolutionEmpty([string]$TicketContent) {
    $Section = [regex]::Match($TicketContent, '(?ms)^## Resolution[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)')
    if (-not $Section.Success) {
        return $true
    }
    $Meaningful = @($Section.Groups['body'].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -and $_ -ne '-' -and $_ -notmatch '^-[ \t]*(结论|对地图的决策指针)[：:][ \t]*$'
    })
    return $Meaningful.Count -eq 0
}

function Add-AssetPointer([string]$TicketContent, [string]$TicketId, [string]$TicketTitle) {
    $Headings = [regex]::Matches($TicketContent, '(?m)^## Assets[ \t]*$')
    if ($Headings.Count -ne 1) {
        throw "Ticket $TicketId must contain exactly one Assets section"
    }
    $Section = [regex]::Match($TicketContent, '(?ms)^## Assets[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)')
    $RelativePath = "../research/$TicketId-研究.md"
    $Pointer = "- [Research：$TicketTitle]($RelativePath)"
    $PointerCount = [regex]::Matches($Section.Groups['body'].Value, [regex]::Escape($Pointer)).Count
    if ($PointerCount -gt 1) {
        throw "Ticket $TicketId contains duplicate Research asset pointers"
    }
    if ($PointerCount -eq 1) {
        return $TicketContent
    }
    if ($Section.Groups['body'].Value.Contains($RelativePath)) {
        throw "Ticket $TicketId contains a conflicting Research asset pointer"
    }
    $ExistingBody = $Section.Groups['body'].Value.Trim()
    $NewBody = if ([string]::IsNullOrWhiteSpace($ExistingBody) -or $ExistingBody -eq '-') {
        "$Pointer`n`n"
    } else {
        "$($ExistingBody.TrimEnd())`n$Pointer`n`n"
    }
    return $TicketContent.Substring(0, $Section.Groups['body'].Index) + $NewBody + $TicketContent.Substring($Section.Groups['body'].Index + $Section.Groups['body'].Length)
}

function Get-NormalizedSources([string[]]$Values, [string]$Repository) {
    $Normalized = [System.Collections.Generic.List[string]]::new()
    foreach ($Source in $Values) {
        $Value = if ($null -eq $Source) { '' } else { $Source.Trim() }
        if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\r\n`]' -or $Value -match '^<.*>$') {
            throw "Invalid Research source: $Source"
        }
        $Uri = $null
        if ([Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$Uri) -and $Uri.Scheme -eq 'https' -and -not [string]::IsNullOrWhiteSpace($Uri.Host)) {
            $Normalized.Add($Uri.AbsoluteUri)
            continue
        }
        if ($Value.StartsWith('repo:')) {
            $RelativePath = $Value.Substring(5)
            $Segments = @($RelativePath -split '/')
            if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath.Contains('..') -or [System.IO.Path]::IsPathRooted($RelativePath) -or
                $RelativePath.Contains('\') -or $RelativePath.IndexOfAny([char[]]':*?"<>|') -ge 0 -or
                $Segments -contains '..' -or $Segments -contains '') {
                throw "Invalid repository source: $Value"
            }
            if (-not [string]::IsNullOrWhiteSpace($Repository) -and (Test-Path -LiteralPath $Repository -PathType Container)) {
                $RepositoryRoot = [System.IO.Path]::GetFullPath($Repository)
                $Candidate = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
                $RepositoryPrefix = $RepositoryRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
                if (-not $Candidate.StartsWith($RepositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
                    throw "Repository source does not resolve to a regular file: $Value"
                }
                $CurrentPath = $RepositoryRoot
                foreach ($Segment in $Segments) {
                    $CurrentPath = Join-Path $CurrentPath $Segment
                    $CurrentItem = Get-Item -LiteralPath $CurrentPath
                    if (($CurrentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                        throw "Repository source cannot traverse a junction or symbolic link: $Value"
                    }
                }
            }
            $Normalized.Add($Value)
            continue
        }
        if ($Value -match '^commit:[0-9a-fA-F]{7,40}$') {
            $Normalized.Add($Value.ToLowerInvariant())
            continue
        }
        throw "Unsupported Research source: $Value"
    }
    return $Normalized.ToArray()
}

function Write-PublishedAsset([string]$Path, [string]$Value, [bool]$ReplaceExisting) {
    $TemporaryPath = "$Path.tmp.$([Guid]::NewGuid().ToString('N'))"
    $BackupPath = "$Path.bak.$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($TemporaryPath, $Value, [System.Text.UTF8Encoding]::new($false))
        if ($ReplaceExisting) {
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

$Lock = Enter-ResearchAssetLock
try {
    $TicketMatches = @(Get-ChildItem -LiteralPath $TicketsDirectory -File -Filter "$([System.Management.Automation.WildcardPattern]::Escape($TicketId))-*.md" -Force)
    if ($TicketMatches.Count -ne 1) {
        throw "Expected exactly one ticket file for $TicketId"
    }
    if (($TicketMatches[0].Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Ticket path must be a regular file: $($TicketMatches[0].FullName)"
    }

    $TicketContent = Get-Content -LiteralPath $TicketMatches[0].FullName -Raw -Encoding UTF8
    $TicketHash = (Get-FileHash -LiteralPath $TicketMatches[0].FullName -Algorithm SHA256).Hash
    $TicketYaml = Get-Frontmatter $TicketMatches[0].FullName
    if ((Get-YamlValue $TicketYaml 'id') -ne $TicketId -or
        (Get-YamlValue $TicketYaml 'type') -ne 'research' -or
        (Get-YamlValue $TicketYaml 'interaction') -ne 'AFK' -or
        (Get-YamlValue $TicketYaml 'status') -ne 'claimed' -or
        (Get-YamlValue $TicketYaml 'claim') -ne $Owner) {
        throw "Research ticket $TicketId is not currently owned by $Owner"
    }
    $TicketTitle = Get-TicketTitle $TicketContent $TicketId
    $Repository = ''
    if ((Get-Content -LiteralPath $MapFile.FullName -Encoding UTF8 -TotalCount 1) -eq '---') {
        $MapYaml = Get-Frontmatter $MapFile.FullName
        $RepositoryMatches = [regex]::Matches($MapYaml, '(?m)^repository:[ \t]*(?<value>.*)$')
        if ($RepositoryMatches.Count -gt 1) {
            throw 'Map has duplicate repository keys'
        }
        if ($RepositoryMatches.Count -eq 1) {
            $Repository = $RepositoryMatches[0].Groups['value'].Value.Trim().Trim('"').Trim("'")
        }
    }
    $NormalizedSources = Get-NormalizedSources $Sources $Repository

    New-Item -ItemType Directory -Path $ResearchDirectory -Force | Out-Null
    $ResearchDirectoryItem = Get-Item -LiteralPath $ResearchDirectory
    if (($ResearchDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Research directory cannot be a junction or symbolic link: $ResearchDirectory"
    }
    $FinalPath = Join-Path $ResearchDirectory "$TicketId-研究.md"
    $ReplaceExisting = Test-Path -LiteralPath $FinalPath
    $Takeover = $false
    $PreviousOwner = ''
    if ($ReplaceExisting) {
        $ExistingItem = Get-Item -LiteralPath $FinalPath
        if ($ExistingItem.PSIsContainer -or ($ExistingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Research asset path must be a regular file: $FinalPath"
        }
        $ExistingYaml = Get-Frontmatter $FinalPath
        if ((Get-YamlValue $ExistingYaml 'ticket_id') -ne $TicketId) {
            throw "Research asset belongs to another ticket: $FinalPath"
        }
        $ExistingOwner = Get-YamlValue $ExistingYaml 'owner'
        $ExistingPreviousOwner = Get-OptionalYamlValue $ExistingYaml 'previous_owner'
        if ($ExistingOwner -ne $Owner) {
            if ([string]::IsNullOrWhiteSpace($TakeoverOwner) -or $TakeoverOwner -ne $ExistingOwner -or -not (Test-ResolutionEmpty $TicketContent)) {
                throw "Research asset already belongs to another session: $FinalPath"
            }
            $Takeover = $true
            $PreviousOwner = $ExistingOwner
        } else {
            $PreviousOwner = $ExistingPreviousOwner
        }
    }

    $NormalizedContent = $Content.Trim()
    $PublishedAt = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [System.Globalization.CultureInfo]::InvariantCulture)
    $SourceLines = @($NormalizedSources | ForEach-Object { "- ``$_``" })
    $Asset = "---`nticket_id: $TicketId`nowner: $Owner`nprevious_owner: $PreviousOwner`npublished_at: $PublishedAt`n---`n`n$NormalizedContent`n`n## Sources`n`n$([string]::Join("`n", $SourceLines))`n"
    if ([regex]::Matches($Asset, '(?m)^## Sources[ \t]*$').Count -ne 1) {
        throw 'Research asset must contain exactly one Sources section'
    }
    $UpdatedTicket = Add-AssetPointer $TicketContent $TicketId $TicketTitle
    $PointerPath = "../research/$TicketId-研究.md"
    if ([regex]::Matches($UpdatedTicket, [regex]::Escape($PointerPath)).Count -ne 1) {
        throw 'Research ticket must contain exactly one global asset pointer'
    }
    Write-PublishedAsset $FinalPath $Asset $ReplaceExisting

    if ((Get-FileHash -LiteralPath $TicketMatches[0].FullName -Algorithm SHA256).Hash -ne $TicketHash) {
        throw "Research ticket changed during asset publication: $($TicketMatches[0].FullName)"
    }
    if ($UpdatedTicket -ne $TicketContent) {
        Write-PublishedAsset $TicketMatches[0].FullName $UpdatedTicket $true
    }

    $VerifiedAssetYaml = Get-Frontmatter $FinalPath
    $VerifiedTicket = Get-Content -LiteralPath $TicketMatches[0].FullName -Raw -Encoding UTF8
    if ((Get-YamlValue $VerifiedAssetYaml 'ticket_id') -ne $TicketId -or
        (Get-YamlValue $VerifiedAssetYaml 'owner') -ne $Owner -or
        [regex]::Matches($VerifiedTicket, [regex]::Escape($PointerPath)).Count -ne 1 -or
        [regex]::Matches((Get-Content -LiteralPath $FinalPath -Raw -Encoding UTF8), '(?m)^## Sources[ \t]*$').Count -ne 1) {
        throw 'Research asset terminal verification failed'
    }

    [pscustomobject]@{
        ticket_id = $TicketId
        owner = $Owner
        path = $FinalPath
        retry = $ReplaceExisting
        takeover = $Takeover
    } | ConvertTo-Json -Compress
} finally {
    $Lock.Dispose()
}
