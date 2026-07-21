param(
    [Parameter(Mandatory)]
    [string]$MapPath,

    [Parameter(Mandatory)]
    [ValidateSet('ClaimBatch', 'VerifyOwned', 'ReleaseOwned')]
    [string]$Operation,

    [Parameter(Mandatory)]
    [string]$Owner,

    [string[]]$TicketPaths = @(),

    [ValidateRange(100, 30000)]
    [int]$LockTimeoutMs = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Owner -notmatch '^[A-Za-z0-9][A-Za-z0-9:._-]*$' -or $Owner -eq 'unclaimed') {
    throw 'Owner must be a safe, non-empty session-scoped value'
}

$MapFile = Get-Item -LiteralPath $MapPath
$MapDirectory = $MapFile.Directory.FullName
$TicketsDirectory = [System.IO.Path]::GetFullPath((Join-Path $MapDirectory 'tickets'))
$TicketsDirectoryItem = Get-Item -LiteralPath $TicketsDirectory
if (($TicketsDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Tickets directory cannot be a junction or symbolic link: $TicketsDirectory"
}
$TicketsPrefix = $TicketsDirectory + [System.IO.Path]::DirectorySeparatorChar
$Selector = Join-Path $PSScriptRoot '解析Frontier指针.ps1'
$LockPath = Join-Path $MapDirectory '.wayfinder-state.lock'

function Enter-ResearchLock {
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
    throw "Timed out acquiring Research claim lock: $LockPath"
}

function Get-YamlValue([string]$Content, [string]$Name) {
    $Frontmatter = [regex]::Match($Content, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $Frontmatter.Success) {
        throw 'Ticket has incomplete YAML frontmatter'
    }
    $Matches = [regex]::Matches($Frontmatter.Groups['yaml'].Value, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one YAML key $Name"
    }
    return $Matches[0].Groups['value'].Value.Trim()
}

function Set-YamlValue([string]$Content, [string]$Name, [string]$Value) {
    $Frontmatter = [regex]::Match($Content, '(?s)\A(?<prefix>---\r?\n)(?<yaml>.*?)(?<suffix>\r?\n---(?:\r?\n|\z).*)\z')
    if (-not $Frontmatter.Success) {
        throw 'Ticket has incomplete YAML frontmatter'
    }
    $Yaml = $Frontmatter.Groups['yaml'].Value
    $Pattern = "(?m)^$([regex]::Escape($Name)):[^\r\n]*$"
    if ([regex]::Matches($Yaml, $Pattern).Count -ne 1) {
        throw "Expected exactly one YAML key $Name"
    }
    $UpdatedYaml = [regex]::Replace(
        $Yaml,
        $Pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{ param($Match) "$Name`: $Value" },
        1
    )
    return $Frontmatter.Groups['prefix'].Value + $UpdatedYaml + $Frontmatter.Groups['suffix'].Value
}

function Write-Atomic([string]$Path, [string]$Content) {
    $TemporaryPath = "$Path.tmp.$([Guid]::NewGuid().ToString('N'))"
    $BackupPath = "$Path.bak.$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($TemporaryPath, $Content, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Replace($TemporaryPath, $Path, $BackupPath, $true)
    } finally {
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
        if (Test-Path -LiteralPath $BackupPath) {
            Remove-Item -LiteralPath $BackupPath -Force
        }
    }
}

function Resolve-TicketPath([string]$Path) {
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $FullPath.StartsWith($TicketsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Ticket path escapes tickets directory: $FullPath"
    }
    if (-not [string]::Equals([System.IO.Path]::GetDirectoryName($FullPath), $TicketsDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Ticket must be a direct child of tickets directory: $FullPath"
    }
    $TicketItem = Get-Item -LiteralPath $FullPath -Force
    if ($TicketItem.PSIsContainer -or ($TicketItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Ticket path must be a regular file: $FullPath"
    }
    return $TicketItem.FullName
}

function Test-ResolutionEmpty([string]$Content) {
    $Section = [regex]::Match($Content, '(?ms)^## Resolution[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)')
    if (-not $Section.Success) {
        return $true
    }
    $Meaningful = @($Section.Groups['body'].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -and $_ -ne '-' -and $_ -notmatch '^-[ \t]*(结论|对地图的决策指针)[：:][ \t]*$'
    })
    return $Meaningful.Count -eq 0
}

$Lock = Enter-ResearchLock
try {
    if ($Operation -eq 'ClaimBatch') {
        $Claimed = [System.Collections.Generic.List[object]]::new()
        $Failed = [System.Collections.Generic.List[object]]::new()
        $BatchRaw = & $Selector -MapPath $MapFile.FullName -Mode ResearchBatch
        $Batch = @(($BatchRaw | ConvertFrom-Json).tickets)
        $ClaimedAt = [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz', [System.Globalization.CultureInfo]::InvariantCulture)
        foreach ($Ticket in $Batch) {
            try {
                $Path = Resolve-TicketPath $Ticket.path
                $Content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
                if ((Get-YamlValue $Content 'status') -ne 'open' -or (Get-YamlValue $Content 'claim') -ne 'unclaimed') {
                    throw 'Ticket is no longer open and unclaimed'
                }
                $Updated = Set-YamlValue $Content 'status' 'claimed'
                $Updated = Set-YamlValue $Updated 'claim' $Owner
                $Updated = Set-YamlValue $Updated 'claimed_at' $ClaimedAt
                Write-Atomic $Path $Updated
                $Verified = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
                if ((Get-YamlValue $Verified 'status') -ne 'claimed' -or (Get-YamlValue $Verified 'claim') -ne $Owner) {
                    throw 'Claim verification failed after write'
                }
                $Claimed.Add([pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Path })
            } catch {
                $Failed.Add([pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Ticket.path; error = $_.Exception.Message })
            }
        }
        [pscustomobject]@{ owner = $Owner; claimed = @($Claimed); failed = @($Failed) } | ConvertTo-Json -Depth 5 -Compress
        exit 0
    }

    if ($TicketPaths.Count -eq 0) {
        throw "$Operation requires TicketPaths"
    }

    if ($Operation -eq 'VerifyOwned') {
        $VerifiedTickets = [System.Collections.Generic.List[object]]::new()
        foreach ($TicketPath in $TicketPaths) {
            $Path = Resolve-TicketPath $TicketPath
            $Content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
            if ((Get-YamlValue $Content 'status') -ne 'claimed' -or (Get-YamlValue $Content 'claim') -ne $Owner) {
                throw "Research ticket is no longer owned by $Owner`: $Path"
            }
            $VerifiedTickets.Add([pscustomobject]@{ path = $Path })
        }
        [pscustomobject]@{ owner = $Owner; verified = @($VerifiedTickets) } | ConvertTo-Json -Depth 4 -Compress
        exit 0
    }

    $Released = [System.Collections.Generic.List[object]]::new()
    $Rejected = [System.Collections.Generic.List[object]]::new()
    foreach ($TicketPath in $TicketPaths) {
        $Path = Resolve-TicketPath $TicketPath
        $Content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ((Get-YamlValue $Content 'status') -ne 'claimed' -or
            (Get-YamlValue $Content 'claim') -ne $Owner -or
            -not (Test-ResolutionEmpty $Content)) {
            $Rejected.Add([pscustomobject]@{ path = $Path })
            continue
        }
        $Updated = Set-YamlValue $Content 'status' 'open'
        $Updated = Set-YamlValue $Updated 'claim' 'unclaimed'
        $Updated = Set-YamlValue $Updated 'claimed_at' ''
        Write-Atomic $Path $Updated
        $Released.Add([pscustomobject]@{ path = $Path })
    }
    [pscustomobject]@{ owner = $Owner; released = @($Released); rejected = @($Rejected) } | ConvertTo-Json -Depth 4 -Compress
} finally {
    $Lock.Dispose()
}
