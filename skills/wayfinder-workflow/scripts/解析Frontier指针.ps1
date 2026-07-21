param(
    [Parameter(Mandatory)]
    [string]$MapPath,

    [ValidateSet('FirstFrontier', 'ResearchBatch', 'Audit')]
    [string]$Mode = 'FirstFrontier'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$AllowedStatuses = @('open', 'claimed', 'closed')
$AllowedDecisionStatuses = @('not_required', 'pending', 'confirmed')
$AllowedClosureKinds = @('pending', 'decision', 'fact', 'out_of_scope', 'superseded')
$AllowedMapStatuses = @('active', 'ready_for_handoff', 'closed')
$AllowedInteractions = @{
    research = @('AFK')
    prototype = @('HITL')
    grilling = @('HITL')
    task = @('AFK', 'HITL')
}

function Get-Frontmatter([System.IO.FileInfo]$File) {
    $Lines = [System.Collections.Generic.List[string]]::new()
    $Started = $false
    $Closed = $false
    foreach ($Line in Get-Content -LiteralPath $File.FullName -Encoding UTF8) {
        if (-not $Started) {
            if ($Line -ne '---') {
                throw "Ticket has no YAML frontmatter: $($File.FullName)"
            }
            $Started = $true
            continue
        }
        if ($Line -eq '---') {
            $Closed = $true
            break
        }
        $Lines.Add($Line)
    }
    if (-not $Closed) {
        throw "Ticket has incomplete YAML frontmatter: $($File.FullName)"
    }
    $SeenKeys = @{}
    foreach ($Line in $Lines) {
        $KeyMatch = [regex]::Match($Line, '^(?<key>[A-Za-z_][A-Za-z0-9_-]*):')
        if (-not $KeyMatch.Success) {
            continue
        }
        $Key = $KeyMatch.Groups['key'].Value
        if ($SeenKeys.ContainsKey($Key)) {
            throw "Ticket has duplicate YAML key $Key`: $($File.FullName)"
        }
        $SeenKeys[$Key] = $true
    }
    return [string]::Join("`n", $Lines)
}

function ConvertFrom-QuotedScalar([string]$Value) {
    $Normalized = $Value.Trim()
    if ($Normalized -in @('~', 'null', 'Null', 'NULL', '""', "''")) {
        return ''
    }
    if ($Normalized.Length -ge 2) {
        $StartsWithDoubleQuote = $Normalized.StartsWith('"') -and $Normalized.EndsWith('"')
        $StartsWithSingleQuote = $Normalized.StartsWith("'") -and $Normalized.EndsWith("'")
        if ($StartsWithDoubleQuote -or $StartsWithSingleQuote) {
            return $Normalized.Substring(1, $Normalized.Length - 2).Trim()
        }
    }
    return $Normalized
}

function Remove-YamlInlineComment([string]$Value) {
    $InSingleQuote = $false
    $InDoubleQuote = $false
    for ($Index = 0; $Index -lt $Value.Length; $Index++) {
        $Character = $Value[$Index]
        if ($Character -eq "'" -and -not $InDoubleQuote) {
            $InSingleQuote = -not $InSingleQuote
            continue
        }
        if ($Character -eq '"' -and -not $InSingleQuote) {
            $InDoubleQuote = -not $InDoubleQuote
            continue
        }
        if ($Character -eq '#' -and -not $InSingleQuote -and -not $InDoubleQuote) {
            if ($Index -eq 0 -or [char]::IsWhiteSpace($Value[$Index - 1])) {
                return $Value.Substring(0, $Index)
            }
        }
    }
    return $Value
}

function ConvertFrom-YamlScalar([string]$Value) {
    return ConvertFrom-QuotedScalar (Remove-YamlInlineComment $Value)
}

function Get-Value([string]$Yaml, [string]$Name) {
    $Match = [regex]::Match($Yaml, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if (-not $Match.Success) {
        throw "Missing YAML value: $Name"
    }
    return ConvertFrom-YamlScalar $Match.Groups['value'].Value
}

function Get-OptionalValue([string]$Yaml, [string]$Name, [string]$DefaultValue = '') {
    $Match = [regex]::Match($Yaml, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>.*)$")
    if (-not $Match.Success) {
        return $DefaultValue
    }
    return ConvertFrom-YamlScalar $Match.Groups['value'].Value
}

function Get-TicketBody([System.IO.FileInfo]$File) {
    $Content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    $Frontmatter = [regex]::Match($Content, '(?s)\A---\r?\n.*?\r?\n---(?:\r?\n|\z)(?<body>.*)\z')
    if (-not $Frontmatter.Success) {
        throw "Ticket has incomplete YAML frontmatter: $($File.FullName)"
    }
    return $Frontmatter.Groups['body'].Value
}

function Get-ConfirmationText([System.IO.FileInfo]$File) {
    $Content = Get-TicketBody $File
    $Headings = [regex]::Matches($Content, '(?m)^## Confirmation[ \t]*$')
    if ($Headings.Count -gt 1) {
        throw "Ticket $($File.FullName) has duplicate Confirmation sections"
    }
    if ($Headings.Count -eq 0) {
        return ''
    }
    $Section = [regex]::Match($Content, '(?ms)^## Confirmation[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)')
    $Decisions = [regex]::Matches($Section.Groups['body'].Value, '(?m)^- 用户原始决定[：:][ \t]*(?<value>.*)$')
    if ($Decisions.Count -ne 1) {
        throw "Ticket $($File.FullName) must contain exactly one user decision in Confirmation"
    }
    return ConvertFrom-QuotedScalar $Decisions[0].Groups['value'].Value
}

function Get-TicketTitle([System.IO.FileInfo]$File, [string]$Id) {
    $Content = Get-TicketBody $File
    $Titles = [regex]::Matches($Content, '(?m)^#[ \t]+(?!#)(?<title>.*?)[ \t]*$')
    if ($Titles.Count -ne 1) {
        throw "Ticket $Id must contain exactly one non-empty level-one title"
    }
    $Title = $Titles[0].Groups['title'].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($Title) -or $Title.Equals($Id, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Ticket $Id must use a human-readable title instead of a bare id"
    }
    return $Title
}

function Get-InlineList([string]$Yaml, [string]$Name, [bool]$Required) {
    $Value = if ($Required) { Get-Value $Yaml $Name } else { Get-OptionalValue $Yaml $Name '[]' }
    if ($Value -eq '[]') {
        return @()
    }
    if (-not ($Value.StartsWith('[') -and $Value.EndsWith(']'))) {
        throw "$Name must use an inline YAML list: $Value"
    }
    return @($Value.Trim('[', ']').Split(',') | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ })
}

function Get-BlockedBy([string]$Yaml) {
    return Get-InlineList $Yaml 'blocked_by' $true
}

function Get-Blocks([string]$Yaml) {
    return Get-InlineList $Yaml 'blocks' $false
}

function Assert-TicketSchema($Ticket) {
    if ($AllowedStatuses -notcontains $Ticket.status) {
        throw "Ticket $($Ticket.id) has invalid status: $($Ticket.status)"
    }
    if (-not $AllowedInteractions.ContainsKey($Ticket.type)) {
        throw "Ticket $($Ticket.id) has invalid type: $($Ticket.type)"
    }
    if ($AllowedInteractions[$Ticket.type] -notcontains $Ticket.interaction) {
        throw "Ticket $($Ticket.id) has invalid interaction for $($Ticket.type): $($Ticket.interaction)"
    }
    if ($AllowedDecisionStatuses -notcontains $Ticket.decision_status) {
        throw "Ticket $($Ticket.id) has invalid decision_status: $($Ticket.decision_status)"
    }
    if ($AllowedClosureKinds -notcontains $Ticket.closure_kind) {
        throw "Ticket $($Ticket.id) has invalid closure_kind: $($Ticket.closure_kind)"
    }
    if ($Ticket.status -eq 'closed' -and $Ticket.closure_kind -eq 'pending') {
        throw "Ticket $($Ticket.id) is closed but closure_kind is pending"
    }
    if ($Ticket.status -ne 'closed' -and $Ticket.closure_kind -ne 'pending') {
        throw "Ticket $($Ticket.id) is not closed and must use closure_kind: pending"
    }
    if ($Ticket.interaction -eq 'AFK' -and $Ticket.decision_status -ne 'not_required') {
        throw "Ticket $($Ticket.id) is AFK and must use decision_status: not_required"
    }
    if ($Ticket.interaction -eq 'HITL' -and $Ticket.decision_status -eq 'not_required') {
        throw "Ticket $($Ticket.id) is HITL and cannot use decision_status: not_required"
    }
    $IsInvalidated = $Ticket.closure_kind -in @('out_of_scope', 'superseded')
    if ($Ticket.interaction -eq 'HITL' -and $Ticket.status -eq 'closed' -and -not $IsInvalidated -and $Ticket.decision_status -ne 'confirmed') {
        throw "Ticket $($Ticket.id) is a closed HITL ticket without explicit confirmation; add real confirmed_choice, confirmed_by and confirmed_at values or reopen it"
    }
    if ($Ticket.interaction -eq 'HITL' -and $Ticket.decision_status -eq 'confirmed') {
        if ([string]::IsNullOrWhiteSpace($Ticket.confirmed_choice) -or
            [string]::IsNullOrWhiteSpace($Ticket.confirmed_by) -or
            [string]::IsNullOrWhiteSpace($Ticket.confirmed_at)) {
            throw "Ticket $($Ticket.id) has incomplete explicit confirmation; confirmed_choice, confirmed_by and confirmed_at are required"
        }
        if ($Ticket.confirmed_choice -notin @('A', 'B', 'C', 'custom')) {
            throw "Ticket $($Ticket.id) has invalid confirmed_choice: $($Ticket.confirmed_choice)"
        }
        try {
            $null = [DateTimeOffset]::ParseExact(
                $Ticket.confirmed_at,
                [string[]]@("yyyy-MM-dd'T'HH:mm:ssK", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK"),
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None
            )
        } catch {
            throw "Ticket $($Ticket.id) has invalid confirmed_at: $($Ticket.confirmed_at)"
        }
        if ([string]::IsNullOrWhiteSpace($Ticket.confirmation_text) -or $Ticket.confirmation_text -match '^<.*>$') {
            throw "Ticket $($Ticket.id) has no user original decision in Confirmation"
        }
    }
    if ($Ticket.closure_kind -eq 'decision' -and ($Ticket.status -ne 'closed' -or $Ticket.interaction -ne 'HITL' -or $Ticket.decision_status -ne 'confirmed')) {
        throw "Ticket $($Ticket.id) can use closure_kind decision only after confirmed HITL closure"
    }
    if ($Ticket.closure_kind -eq 'fact' -and ($Ticket.status -ne 'closed' -or $Ticket.interaction -ne 'AFK')) {
        throw "Ticket $($Ticket.id) can use closure_kind fact only after AFK closure"
    }
    if ($IsInvalidated) {
        if ([string]::IsNullOrWhiteSpace($Ticket.closure_source_ticket)) {
            throw "Ticket $($Ticket.id) with closure_kind $($Ticket.closure_kind) requires closure_source_ticket"
        }
        if ($Ticket.claim -eq 'unclaimed' -or [string]::IsNullOrWhiteSpace($Ticket.claim)) {
            throw "Ticket $($Ticket.id) must be owned before $($Ticket.closure_kind) closure"
        }
        if ($Ticket.interaction -eq 'HITL') {
            if ($Ticket.decision_status -ne 'pending' -or
                -not [string]::IsNullOrWhiteSpace($Ticket.confirmed_choice) -or
                -not [string]::IsNullOrWhiteSpace($Ticket.confirmed_by) -or
                -not [string]::IsNullOrWhiteSpace($Ticket.confirmed_at) -or
                -not [string]::IsNullOrWhiteSpace($Ticket.confirmation_text)) {
                throw "Invalidated HITL ticket $($Ticket.id) must stay pending with empty confirmation fields"
            }
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($Ticket.closure_source_ticket)) {
        throw "Ticket $($Ticket.id) cannot set closure_source_ticket for closure_kind $($Ticket.closure_kind)"
    }
}

$MapFile = Get-Item -LiteralPath $MapPath
$MapStartsWithFrontmatter = (Get-Content -LiteralPath $MapFile.FullName -Encoding UTF8 -TotalCount 1) -eq '---'
$MapYaml = if ($MapStartsWithFrontmatter) { Get-Frontmatter $MapFile } else { '' }
$MapStatus = if ($MapStartsWithFrontmatter) { Get-Value $MapYaml 'status' } else { 'active' }
$MapId = if ($MapStartsWithFrontmatter) { Get-Value $MapYaml 'id' } else { [System.IO.Path]::GetFileNameWithoutExtension($MapFile.Name) }
if ($AllowedMapStatuses -notcontains $MapStatus) {
    throw "Map has invalid status: $MapStatus"
}
if ($Mode -ne 'Audit' -and $MapStatus -ne 'active') {
    throw "Map $MapId is $MapStatus and cannot select or claim tickets"
}
$MapDirectory = $MapFile.Directory.FullName
$TicketsDirectory = Join-Path $MapDirectory 'tickets'
if (-not (Test-Path -LiteralPath $TicketsDirectory)) {
    throw "Map has no tickets directory: $TicketsDirectory"
}
$TicketsDirectory = [System.IO.Path]::GetFullPath($TicketsDirectory)
$TicketsDirectoryItem = Get-Item -LiteralPath $TicketsDirectory
if (($TicketsDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Tickets directory cannot be a junction or symbolic link: $TicketsDirectory"
}
$TicketsPrefix = $TicketsDirectory + [System.IO.Path]::DirectorySeparatorChar
$TicketsById = @{}
$TicketsByPath = @{}

function Read-TicketFile([string]$Path) {
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not ($FullPath.StartsWith($TicketsPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Ticket path escapes tickets directory: $FullPath"
    }
    if (-not [string]::Equals([System.IO.Path]::GetDirectoryName($FullPath), $TicketsDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Ticket must be a direct child of tickets directory: $FullPath"
    }
    if ($TicketsByPath.ContainsKey($FullPath)) {
        return $TicketsByPath[$FullPath]
    }

    $File = Get-Item -LiteralPath $FullPath -Force
    if ($File.PSIsContainer) {
        throw "Ticket path is not a file: $FullPath"
    }
    if (($File.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Ticket path cannot be a junction or symbolic link: $FullPath"
    }
    $Yaml = Get-Frontmatter $File
    $Interaction = Get-Value $Yaml 'interaction'
    $Status = Get-Value $Yaml 'status'
    $DefaultDecisionStatus = if ($Interaction -eq 'AFK') { 'not_required' } else { 'pending' }
    $DefaultClosureKind = if ($Status -ne 'closed') { 'pending' } elseif ($Interaction -eq 'AFK') { 'fact' } else { 'decision' }
    $Id = Get-Value $Yaml 'id'
    $Ticket = [pscustomobject]@{
        id = $Id
        title = Get-TicketTitle $File $Id
        path = $File.FullName
        status = $Status
        type = Get-Value $Yaml 'type'
        interaction = $Interaction
        decision_status = Get-OptionalValue $Yaml 'decision_status' $DefaultDecisionStatus
        confirmed_choice = Get-OptionalValue $Yaml 'confirmed_choice'
        confirmed_by = Get-OptionalValue $Yaml 'confirmed_by'
        confirmed_at = Get-OptionalValue $Yaml 'confirmed_at'
        confirmation_text = Get-ConfirmationText $File
        claim = Get-Value $Yaml 'claim'
        blocked_by = Get-BlockedBy $Yaml
        blocks = Get-Blocks $Yaml
        closure_kind = Get-OptionalValue $Yaml 'closure_kind' $DefaultClosureKind
        closure_source_ticket = Get-OptionalValue $Yaml 'closure_source_ticket'
    }
    Assert-TicketSchema $Ticket
    if ($TicketsById.ContainsKey($Ticket.id) -and $TicketsById[$Ticket.id].path -ne $Ticket.path) {
        throw "Duplicate ticket id: $($Ticket.id)"
    }
    $TicketsById[$Ticket.id] = $Ticket
    $TicketsByPath[$FullPath] = $Ticket
    return $Ticket
}

function Read-TicketById([string]$Id) {
    if ($TicketsById.ContainsKey($Id)) {
        return $TicketsById[$Id]
    }
    if ($Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Ticket id is not safe for local lookup: $Id"
    }
    $Matches = @(Get-ChildItem -LiteralPath $TicketsDirectory -File -Filter "$([System.Management.Automation.WildcardPattern]::Escape($Id))-*.md")
    if ($Matches.Count -ne 1) {
        throw "Expected exactly one ticket file for blocker: $Id"
    }
    return Read-TicketFile $Matches[0].FullName
}

$ValidatedRelationships = @{}

function Assert-TicketRelationships($Ticket) {
    if ($ValidatedRelationships.ContainsKey($Ticket.id)) {
        return
    }
    if ($Ticket.closure_kind -in @('out_of_scope', 'superseded')) {
        if ($Ticket.closure_source_ticket -eq $Ticket.id) {
            throw "Ticket $($Ticket.id) cannot invalidate itself"
        }
        $Source = Read-TicketById $Ticket.closure_source_ticket
        if ($Source.status -ne 'closed' -or $Source.closure_kind -ne 'decision' -or
            $Source.interaction -ne 'HITL' -or $Source.decision_status -ne 'confirmed') {
            throw "Ticket $($Ticket.id) has invalid closure source decision: $($Ticket.closure_source_ticket)"
        }
    }
    $ValidatedRelationships[$Ticket.id] = $true
}

function Get-MapSection([string]$Name, [bool]$Required) {
    $Escaped = [regex]::Escape($Name)
    $Headings = [regex]::Matches($MapContent, "(?m)^## $Escaped[ \t]*$")
    if ($Headings.Count -gt 1) {
        throw "Map contains duplicate $Name sections"
    }
    if ($Headings.Count -eq 0) {
        if ($Required) {
            throw "Map has no $Name section"
        }
        return $null
    }
    return [regex]::Match($MapContent, "(?ms)^## $Escaped[ \t]*$\r?\n(?<body>.*?)(?=^## |\z)").Groups['body'].Value
}

function Get-MarkdownLinks([string]$Content) {
    return @([regex]::Matches($Content, '\[(?<label>[^\]]+)\]\((?<path>[^)]+)\)'))
}

function Read-LinkedTicket($Link) {
    $RelativePath = $Link.Groups['path'].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $Ticket = Read-TicketFile (Join-Path $MapDirectory $RelativePath)
    $Label = $Link.Groups['label'].Value.Trim()
    if ($Label -ne $Ticket.title) {
        throw "Ticket link must use title '$($Ticket.title)' instead of '$Label'"
    }
    Assert-TicketRelationships $Ticket
    return $Ticket
}

function Test-TicketUnblocked($Ticket) {
    foreach ($BlockingId in $Ticket.blocked_by) {
        $BlockingTicket = Read-TicketById $BlockingId
        Assert-TicketRelationships $BlockingTicket
        if ($BlockingTicket.blocks -notcontains $Ticket.id) {
            throw "Ticket $($Ticket.id) blocked_by $BlockingId is missing reciprocal blocks relationship"
        }
        if ($BlockingTicket.status -ne 'closed') {
            return $false
        }
    }
    return $true
}

function Test-MeaningfulFog([string]$Content) {
    if ($null -eq $Content) {
        return $false
    }
    $WithoutComments = [regex]::Replace($Content, '(?s)<!--.*?-->', '')
    foreach ($Line in @($WithoutComments -split '\r?\n')) {
        $Trimmed = $Line.Trim()
        if ([string]::IsNullOrWhiteSpace($Trimmed) -or $Trimmed -eq '-' -or $Trimmed.StartsWith('>')) {
            continue
        }
        return $true
    }
    return $false
}

$MapContent = Get-Content -LiteralPath $MapFile.FullName -Raw -Encoding UTF8
$null = Get-MapSection 'Destination' $false
$DecisionsBody = Get-MapSection 'Decisions so far' $true
$NotYetBody = Get-MapSection 'Not yet specified' $false
$OutOfScopeBody = Get-MapSection 'Out of scope' $false
$TicketIndexBody = Get-MapSection 'Ticket index' $MapStartsWithFrontmatter
$FrontierBody = Get-MapSection 'Frontier' $true

foreach ($DecisionLine in @($DecisionsBody -split '\r?\n')) {
    $TrimmedLine = $DecisionLine.Trim()
    if ([string]::IsNullOrWhiteSpace($TrimmedLine) -or $TrimmedLine -eq '-' -or
        $TrimmedLine.StartsWith('<!--') -or $TrimmedLine.StartsWith('>')) {
        continue
    }
    if (-not $TrimmedLine.StartsWith('- ')) {
        throw "Map Decisions contains an invalid entry without a ticket source link: $TrimmedLine"
    }
    $DecisionLinks = @(Get-MarkdownLinks $TrimmedLine)
    if ($DecisionLinks.Count -ne 1) {
        throw "Each map Decision must reference exactly one source ticket: $TrimmedLine"
    }
    $DecisionTicket = Read-LinkedTicket $DecisionLinks[0]
    if ($DecisionTicket.status -ne 'closed' -or $DecisionTicket.closure_kind -notin @('decision', 'fact')) {
        throw "Map Decisions references ticket $($DecisionTicket.id) with invalid closure_kind: $($DecisionTicket.closure_kind)"
    }
    if ($DecisionTicket.interaction -eq 'AFK') {
        foreach ($BlockedId in $DecisionTicket.blocks) {
            $BlockedTicket = Read-TicketById $BlockedId
            if ($BlockedTicket.interaction -eq 'HITL') {
                throw "Map Decisions cannot use AFK handoff ticket $($DecisionTicket.id) as the source for HITL decision $($BlockedTicket.id)"
            }
        }
    }
}

if ($null -ne $NotYetBody -and @(Get-MarkdownLinks $NotYetBody).Count -gt 0) {
    throw 'Map Not yet specified cannot contain ticket links; create the ticket and remove the fog entry'
}

if ($null -ne $OutOfScopeBody) {
    foreach ($OutLine in @($OutOfScopeBody -split '\r?\n')) {
        $TrimmedLine = $OutLine.Trim()
        if ([string]::IsNullOrWhiteSpace($TrimmedLine) -or $TrimmedLine -eq '-' -or
            $TrimmedLine.StartsWith('<!--') -or $TrimmedLine.StartsWith('>')) {
            continue
        }
        $OutLinks = @(Get-MarkdownLinks $TrimmedLine)
        if (-not $TrimmedLine.StartsWith('- ') -or $OutLinks.Count -ne 1 -or $TrimmedLine -notmatch '\)\s*[-—:：]\s*\S+') {
            throw "Each Out of scope entry must contain one ticket title link and a reason: $TrimmedLine"
        }
        $OutTicket = Read-LinkedTicket $OutLinks[0]
        if ($OutTicket.status -ne 'closed' -or $OutTicket.closure_kind -ne 'out_of_scope') {
            throw "Map Out of scope references ticket $($OutTicket.id) with invalid closure_kind: $($OutTicket.closure_kind)"
        }
    }
}

$IndexTickets = [System.Collections.Generic.List[object]]::new()
$IndexIds = @{}
if ($null -ne $TicketIndexBody) {
    foreach ($IndexLink in @(Get-MarkdownLinks $TicketIndexBody)) {
        $IndexTicket = Read-LinkedTicket $IndexLink
        if ($IndexIds.ContainsKey($IndexTicket.id)) {
            throw "Ticket index contains duplicate ticket: $($IndexTicket.id)"
        }
        $IndexIds[$IndexTicket.id] = $true
        $IndexTickets.Add($IndexTicket)
    }
}

$AllTickets = [System.Collections.Generic.List[object]]::new()
if ($MapStartsWithFrontmatter) {
    foreach ($TicketFile in @(Get-ChildItem -LiteralPath $TicketsDirectory -File -Filter '*.md' -Force | Sort-Object Name)) {
        if (($TicketFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Ticket path cannot be a junction or symbolic link: $($TicketFile.FullName)"
        }
        $Ticket = Read-TicketFile $TicketFile.FullName
        Assert-TicketRelationships $Ticket
        $AllTickets.Add($Ticket)
        if (-not $IndexIds.ContainsKey($Ticket.id)) {
            throw "Ticket index is missing ticket: $($Ticket.id)"
        }
    }
    if ($IndexTickets.Count -ne $AllTickets.Count) {
        throw 'Ticket index does not match tickets directory'
    }
} else {
    foreach ($IndexTicket in $IndexTickets) {
        $AllTickets.Add($IndexTicket)
    }
}

$EligibleById = @{}
foreach ($Ticket in $AllTickets) {
    if ($Ticket.status -eq 'open' -and $Ticket.claim -eq 'unclaimed' -and (Test-TicketUnblocked $Ticket)) {
        $EligibleById[$Ticket.id] = $Ticket
    }
}

$ResearchTickets = [System.Collections.Generic.List[object]]::new()
$EligibleTickets = [System.Collections.Generic.List[object]]::new()
$StaleTickets = [System.Collections.Generic.List[object]]::new()
$FrontierIds = @{}
$FrontierLinks = @(Get-MarkdownLinks $FrontierBody)
foreach ($Link in $FrontierLinks) {
    $Ticket = Read-LinkedTicket $Link
    if ($FrontierIds.ContainsKey($Ticket.id)) {
        throw "Frontier contains duplicate ticket: $($Ticket.id)"
    }
    $FrontierIds[$Ticket.id] = $true
    if ($MapStartsWithFrontmatter -and -not $IndexIds.ContainsKey($Ticket.id)) {
        throw "Frontier ticket is missing from Ticket index: $($Ticket.id)"
    }
    if (-not $MapStartsWithFrontmatter -and $Ticket.status -eq 'open' -and $Ticket.claim -eq 'unclaimed' -and (Test-TicketUnblocked $Ticket)) {
        $EligibleById[$Ticket.id] = $Ticket
    }
    if (-not $EligibleById.ContainsKey($Ticket.id)) {
        $StaleTickets.Add([pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Ticket.path })
        continue
    }
    $EligibleTicket = [pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Ticket.path; type = $Ticket.type; interaction = $Ticket.interaction }
    $EligibleTickets.Add($EligibleTicket)
    if ($Ticket.type -eq 'research' -and $Ticket.interaction -eq 'AFK') {
        $ResearchTickets.Add([pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Ticket.path })
    }
}

$MissingTickets = [System.Collections.Generic.List[object]]::new()
if ($MapStartsWithFrontmatter) {
    foreach ($Ticket in $AllTickets) {
        if ($EligibleById.ContainsKey($Ticket.id) -and -not $FrontierIds.ContainsKey($Ticket.id)) {
            $MissingTickets.Add([pscustomobject]@{ id = $Ticket.id; title = $Ticket.title; path = $Ticket.path })
        }
    }
}

$HasFog = Test-MeaningfulFog $NotYetBody
$LiveTickets = @($AllTickets | Where-Object { $_.status -ne 'closed' })

if ($Mode -eq 'Audit') {
    [pscustomobject]@{
        map_id = $MapId
        status = $MapStatus
        eligible = @($EligibleTickets)
        missing = @($MissingTickets)
        stale = @($StaleTickets)
        tickets = @($AllTickets | ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.title; path = $_.path; status = $_.status; claim = $_.claim; type = $_.type } })
        live_count = $LiveTickets.Count
        has_fog = $HasFog
    } | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

if ($MissingTickets.Count -gt 0) {
    throw "Frontier is missing eligible tickets: $([string]::Join(', ', @($MissingTickets | ForEach-Object { $_.title })))"
}

if ($MapStartsWithFrontmatter -and $LiveTickets.Count -eq 0 -and -not $HasFog) {
    throw "Map $MapId has no live tickets or fog; prepare its handoff"
}

if ($Mode -eq 'FirstFrontier' -and $EligibleTickets.Count -gt 0) {
    $EligibleTickets[0] | Select-Object id, title, path | ConvertTo-Json -Compress
    exit 0
}

if ($Mode -eq 'ResearchBatch') {
    [pscustomobject]@{ tickets = $ResearchTickets.ToArray() } | ConvertTo-Json -Depth 4 -Compress
    exit 0
}

[pscustomobject]@{ id = $null; title = $null; path = $null } | ConvertTo-Json -Compress
