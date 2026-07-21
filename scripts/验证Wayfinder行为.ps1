param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$Errors = [System.Collections.Generic.List[string]]::new()

function Require-Text([System.IO.FileInfo]$File, [string]$ExpectedText) {
    if ($null -eq $File) {
        $Errors.Add("Missing file for contract: $ExpectedText")
        return
    }

    $Content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    if (-not $Content.Contains($ExpectedText)) {
        $Errors.Add("Missing contract: $($File.FullName) -> $ExpectedText")
    }
}

function Forbid-Text([System.IO.FileInfo]$File, [string]$UnexpectedText) {
    if ($null -eq $File) {
        return
    }

    $Content = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
    if ($Content.Contains($UnexpectedText)) {
        $Errors.Add("Conflicting contract: $($File.FullName) -> $UnexpectedText")
    }
}

function Find-RootMarkdownByText([string]$ExpectedText) {
    Get-ChildItem -LiteralPath $RepoRoot -File -Filter '*.md' | Where-Object {
        (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8).Contains($ExpectedText)
    } | Select-Object -First 1
}

$Delivery = Get-Item -LiteralPath (Join-Path $RepoRoot 'skills/asana-openspec-delivery/SKILL.md')
$PrdWriter = Get-Item -LiteralPath (Join-Path $RepoRoot 'skills/prd-writer/SKILL.md')
$Readme = Get-Item -LiteralPath (Join-Path $RepoRoot 'README.md')
$ProjectAgents = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'assets/templates') -File -Filter 'AGENTS*' | Select-Object -First 1
$UsageGuide = Find-RootMarkdownByText '## MySQL MCP'
$Flowchart = Find-RootMarkdownByText 'flowchart LR'
$TeamIntro = Find-RootMarkdownByText 'Codex + OpenSpec + MySQL MCP + ai_agent'
$InstallGuide = Find-RootMarkdownByText 'marketplace.json'
$MapTemplate = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'assets/templates') -File -Filter 'wayfinding-map*.md' | Select-Object -First 1
$TicketTemplate = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'assets/templates') -File -Filter 'frontier-ticket*.md' | Select-Object -First 1
$Wayfinder = Get-Item -LiteralPath (Join-Path $RepoRoot 'skills/wayfinder-workflow/SKILL.md')
$WayfinderScripts = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts'
$ReleaseVerifier = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scripts') -File | Where-Object {
    (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8).Contains('Plugin release state: PASS')
} | Select-Object -First 1
$BehaviorRecord = Get-Item -LiteralPath (Join-Path $RepoRoot 'docs/试运行/Wayfinder行为验收场景.md')

Require-Text $Delivery '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $Readme '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $PrdWriter '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $ProjectAgents '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $UsageGuide '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $Flowchart '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $TeamIntro '<!-- route-priority: setup > wayfinder > brainstorming -->'
Require-Text $InstallGuide 'setup-workflow'
Require-Text $InstallGuide 'wayfinder-workflow'
Require-Text $InstallGuide '<!-- install-release-verification: source-version-equals-plugin-list -->'
Forbid-Text $Delivery 'scope-unclear-must-brainstorming'
Forbid-Text $PrdWriter 'scope-unclear-must-brainstorming'

Require-Text $MapTemplate '## Frontier'
Require-Text $MapTemplate '<!-- frontier-pointers: ordered-ticket-links -->'
Require-Text $Wayfinder '<!-- frontier-selection: ordered-pointer-then-ticket-yaml -->'
Require-Text $Wayfinder '<!-- frontier-pointers: links-only -->'
Require-Text $Wayfinder '<!-- frontier-resource: bundled -->'
Require-Text $Wayfinder '<!-- frontier-read-scope: pointers-and-blockers -->'
Require-Text $Wayfinder '<!-- hitl-dialogue: one-question-options-recommendation-confirmation -->'
Require-Text $Wayfinder '<!-- hitl-close-gate: explicit-confirmation-required -->'
Require-Text $Wayfinder '<!-- afk-to-hitl-order: create-frontier-validate-close -->'
Require-Text $TicketTemplate '<!-- ticket-enum: choose-one -->'
Require-Text $TicketTemplate 'decision_status: <not_required | pending | confirmed>'
Require-Text $TicketTemplate 'confirmed_choice:'
Require-Text $TicketTemplate '## Confirmation'
Require-Text $Readme '<!-- route-branch: brainstorming-after-wayfinder -->'
Require-Text $Readme '<!-- wayfinder-user-experience: guided-confirmation -->'
if ($null -eq $ReleaseVerifier) {
    $Errors.Add('Missing plugin release verifier')
}

Require-Text $BehaviorRecord '<!-- scenario-id: cross-session-map -->'
Require-Text $BehaviorRecord '<!-- scenario-id: small-bugfix -->'
Require-Text $BehaviorRecord '<!-- scenario-id: mapper-sql -->'
Require-Text $BehaviorRecord '<!-- scenario-id: medium-slicing -->'
Require-Text $BehaviorRecord '<!-- evidence: trigger-accuracy -->'
Require-Text $BehaviorRecord '<!-- evidence: gate-preservation -->'

$DialogueSampleIds = @('destination', 'grilling', 'prototype', 'afk-handoff')
if ($null -ne $BehaviorRecord) {
    $BehaviorContent = Get-Content -LiteralPath $BehaviorRecord.FullName -Raw -Encoding UTF8
    foreach ($SampleId in $DialogueSampleIds) {
        $Sample = [regex]::Match(
            $BehaviorContent,
            "(?ms)<!-- dialogue-sample: $([regex]::Escape($SampleId)) -->\s*(?<body>.*?)<!-- dialogue-sample-end -->"
        )
        if (-not $Sample.Success) {
            $Errors.Add("Missing dialogue sample: $SampleId")
            continue
        }
        $Body = $Sample.Groups['body'].Value
        $Questions = [regex]::Matches($Body, '(?m)^- Q(?<id>\d+): .+$')
        $Options = [regex]::Matches($Body, '(?m)^- (?<id>[A-C]): .+$')
        $Recommendation = [regex]::Match($Body, '(?m)^- 推荐: (?<id>[A-C]) - .+$')
        $Confirmation = [regex]::Match($Body, '(?m)^- 请确认: .*(回复|确认).+$')
        if ($Questions.Count -ne 1 -or $Questions[0].Groups['id'].Value -ne '1') {
            $Errors.Add("Dialogue sample must contain exactly one question: $SampleId")
        }
        if ($Options.Count -lt 2 -or $Options.Count -gt 3) {
            $Errors.Add("Dialogue sample must contain two or three options: $SampleId")
        }
        $OptionIds = @($Options | ForEach-Object { $_.Groups['id'].Value })
        $OptionIdList = [string]::Join(',', $OptionIds)
        if ($OptionIdList -ne 'A,B' -and $OptionIdList -ne 'A,B,C') {
            $Errors.Add("Dialogue sample option ids must be unique and continuous: $SampleId")
        }
        if (-not $Recommendation.Success -or $OptionIds -notcontains $Recommendation.Groups['id'].Value) {
            $Errors.Add("Dialogue sample recommendation must reference an option: $SampleId")
        }
        if (-not $Confirmation.Success) {
            $Errors.Add("Dialogue sample must request explicit confirmation: $SampleId")
        }
    }
}

$FrontierSelector = $null
if (Test-Path -LiteralPath $WayfinderScripts) {
    $FrontierSelector = Get-ChildItem -LiteralPath $WayfinderScripts -File -Filter '*Frontier*.ps1' | Select-Object -First 1
}

if ($null -eq $FrontierSelector) {
    $Errors.Add('Missing executable frontier selector')
} else {
    $FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wayfinder-contract-" + [Guid]::NewGuid().ToString('N'))
    try {
        $TicketsRoot = Join-Path $FixtureRoot 'tickets'
        New-Item -ItemType Directory -Path $TicketsRoot -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'map.md'), @"
# Map

## Frontier

1. [调研基础事实](tickets/a.md)
2. [执行后续任务](tickets/b.md)

## Decisions so far

-
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'a.md'), @"
---
id: ticket-a
status: open
type: research
interaction: AFK
claim: unclaimed
blocked_by: []
blocks: [ticket-b]
---

# 调研基础事实
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'b.md'), @"
---
id: ticket-b
status: open
type: task
interaction: AFK
claim: unclaimed
blocked_by: [ticket-a]
blocks: []
---

# 执行后续任务
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ignored.md'), 'not a ticket', [System.Text.UTF8Encoding]::new($false))

        $First = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'map.md')
        if ($LASTEXITCODE -ne 0 -or $First -notmatch 'ticket-a') {
            $Errors.Add('Frontier selector did not choose the first eligible ticket')
        }

        $Closed = (Get-Content -LiteralPath (Join-Path $TicketsRoot 'a.md') -Raw -Encoding UTF8).Replace('status: open', 'status: closed')
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'a.md'), $Closed, [System.Text.UTF8Encoding]::new($false))
        $Second = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'map.md')
        if ($LASTEXITCODE -ne 0 -or $Second -notmatch 'ticket-b') {
            $Errors.Add('Frontier selector did not promote an unblocked ticket')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'legacy-open-hitl-map.md'), @"
# Legacy open HITL map

## Frontier

1. [验收旧原型](tickets/g.md)

## Decisions so far

"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'g.md'), @"
---
id: ticket-g
status: open
type: prototype
interaction: HITL
claim: unclaimed
blocked_by: []
blocks: []
---

# 验收旧原型
"@, [System.Text.UTF8Encoding]::new($false))
        $LegacyOpenHitl = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'legacy-open-hitl-map.md')
        if ($LASTEXITCODE -ne 0 -or $LegacyOpenHitl -notmatch 'ticket-g') {
            $Errors.Add('Frontier selector did not infer pending for a legacy open HITL ticket')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'hitl-map.md'), @"
# HITL map

## Frontier

1. [执行确认后任务](tickets/d.md)

## Decisions so far

"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: closed
type: grilling
interaction: HITL
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'd.md'), @"
---
id: ticket-d
status: open
type: task
interaction: AFK
claim: unclaimed
blocked_by: [ticket-c]
blocks: []
---

# 执行确认后任务
"@, [System.Text.UTF8Encoding]::new($false))

        $RejectedLegacyClosedHitl = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedLegacyClosedHitl = $true
            if ($_.Exception.Message -notmatch 'ticket-c') {
                $Errors.Add('Legacy closed HITL error did not identify the ticket')
            }
        }
        if (-not $RejectedLegacyClosedHitl) {
            $Errors.Add('Frontier selector accepted a legacy closed HITL ticket without confirmation')
        }

        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: closed
type: grilling
interaction: HITL
decision_status: confirmed
confirmed_choice: A
confirmed_by: "" # YAML 语义仍为空
confirmed_at: 2026-07-20T14:00:00+08:00
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略

## Confirmation

- 用户原始决定：""
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedIncompleteConfirmation = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedIncompleteConfirmation = $true
        }
        if (-not $RejectedIncompleteConfirmation) {
            $Errors.Add('Frontier selector accepted incomplete HITL confirmation audit fields')
        }

        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: closed
type: grilling
interaction: HITL
decision_status: confirmed
decision_status: pending
confirmed_choice: A
confirmed_by: user
confirmed_at: 2026-07-20T14:00:00+08:00
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略

## Confirmation

- 用户原始决定：选择 A。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedDuplicateYamlKey = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedDuplicateYamlKey = $true
        }
        if (-not $RejectedDuplicateYamlKey) {
            $Errors.Add('Frontier selector accepted duplicate YAML decision_status keys')
        }

        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: closed
type: grilling
interaction: HITL
decision_status: confirmed
confirmed_choice: A
confirmed_by: user
confirmed_at: 2026-07-20T14:00:00+08:00
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedMissingConfirmationBody = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedMissingConfirmationBody = $true
        }
        if (-not $RejectedMissingConfirmationBody) {
            $Errors.Add('Frontier selector accepted confirmed HITL without a Confirmation body')
        }

        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: closed
type: grilling
interaction: HITL
decision_status: confirmed
confirmed_choice: A
confirmed_by: user
confirmed_at: 2026-07-20T14:00:00+08:00
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略

## Confirmation

- 用户原始决定：选择 A。
"@, [System.Text.UTF8Encoding]::new($false))
        $Confirmed = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        if ($LASTEXITCODE -ne 0 -or $Confirmed -notmatch 'ticket-d') {
            $Errors.Add('Frontier selector did not accept a fully confirmed HITL blocker')
        }

        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-c-decision.md'), @"
---
id: ticket-c
status: claimed
type: grilling
interaction: HITL
decision_status: pending
confirmed_choice:
confirmed_by:
confirmed_at:
claim: codex
blocked_by: []
blocks: [ticket-d]
---

# 确认迁移策略
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'hitl-map.md'), @"
# HITL map

## Frontier

1. [执行确认后任务](tickets/d.md)

## Decisions so far

- [确认迁移策略](tickets/ticket-c-decision.md)：尚未确认的决定。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedPendingDecision = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedPendingDecision = $true
        }
        if (-not $RejectedPendingDecision) {
            $Errors.Add('Frontier selector accepted an unconfirmed HITL ticket in map Decisions')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'hitl-map.md'), @"
# HITL map

## Frontier

1. [执行确认后任务](tickets/d.md)

## Decisions so far

- 尚未确认的自由文本决定。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedUnlinkedDecision = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedUnlinkedDecision = $true
        }
        if (-not $RejectedUnlinkedDecision) {
            $Errors.Add('Frontier selector accepted a map Decision without a source ticket link')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'hitl-map.md'), @"
# HITL map

## Frontier

1. [执行确认后任务](tickets/d.md)

## Decisions so far

-

## Decisions so far

- [确认迁移策略](tickets/ticket-c-decision.md)：重复章节中的决定。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedDuplicateDecisions = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'hitl-map.md')
        } catch {
            $RejectedDuplicateDecisions = $true
        }
        if (-not $RejectedDuplicateDecisions) {
            $Errors.Add('Frontier selector accepted duplicate map Decisions sections')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'afk-handoff-map.md'), @"
# AFK handoff map

## Frontier

1. [确认发布策略](tickets/ticket-f-decision.md)

## Decisions so far

"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-e-research.md'), @"
---
id: ticket-e
status: claimed
type: research
interaction: AFK
decision_status: not_required
claim: codex
blocked_by: []
blocks: [ticket-f]
---

# 调研发布策略
"@, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-f-decision.md'), @"
---
id: ticket-f
status: open
type: grilling
interaction: HITL
decision_status: pending
confirmed_choice:
confirmed_by:
confirmed_at:
claim: unclaimed
blocked_by: [ticket-e]
blocks: []
---

# 确认发布策略
"@, [System.Text.UTF8Encoding]::new($false))
        $AsymmetricResearch = (Get-Content -LiteralPath (Join-Path $TicketsRoot 'ticket-e-research.md') -Raw -Encoding UTF8).Replace('blocks: [ticket-f]', 'blocks: []')
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-e-research.md'), $AsymmetricResearch, [System.Text.UTF8Encoding]::new($false))
        $RejectedAsymmetricBlocking = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'afk-handoff-map.md')
        } catch {
            $RejectedAsymmetricBlocking = $true
        }
        if (-not $RejectedAsymmetricBlocking) {
            $Errors.Add('AFK handoff accepted blocked_by without the reciprocal blocks relationship')
        }
        $SymmetricResearch = $AsymmetricResearch.Replace('blocks: []', 'blocks: [ticket-f]')
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-e-research.md'), $SymmetricResearch, [System.Text.UTF8Encoding]::new($false))

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'afk-handoff-map.md'), @"
# AFK handoff map

## Frontier

1. [确认发布策略](tickets/ticket-f-decision.md)

## Decisions so far

- [调研发布策略](tickets/ticket-e-research.md)：尚未完成人工取舍的 AFK 推荐。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedAfkRecommendation = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'afk-handoff-map.md')
        } catch {
            $RejectedAfkRecommendation = $true
        }
        if (-not $RejectedAfkRecommendation) {
            $Errors.Add('AFK handoff accepted a research recommendation in map Decisions before HITL confirmation')
        }

        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'afk-handoff-map.md'), @"
# AFK handoff map

## Frontier

1. [确认发布策略](tickets/ticket-f-decision.md)

## Decisions so far

-
"@, [System.Text.UTF8Encoding]::new($false))
        $BeforeAfkClosure = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'afk-handoff-map.md')
        if ($LASTEXITCODE -ne 0 -or $BeforeAfkClosure -notmatch '"id":null') {
            $Errors.Add('AFK handoff did not validate the blocked HITL ticket before research closure')
        }

        $ClosedResearch = (Get-Content -LiteralPath (Join-Path $TicketsRoot 'ticket-e-research.md') -Raw -Encoding UTF8).Replace('status: claimed', 'status: closed')
        [System.IO.File]::WriteAllText((Join-Path $TicketsRoot 'ticket-e-research.md'), $ClosedResearch, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'afk-handoff-map.md'), @"
# AFK handoff map

## Frontier

1. [确认发布策略](tickets/ticket-f-decision.md)

## Decisions so far

- [调研发布策略](tickets/ticket-e-research.md)：AFK 推荐不能替代 HITL 确认。
"@, [System.Text.UTF8Encoding]::new($false))
        $RejectedClosedAfkRecommendation = $false
        try {
            $null = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'afk-handoff-map.md')
        } catch {
            $RejectedClosedAfkRecommendation = $true
        }
        if (-not $RejectedClosedAfkRecommendation) {
            $Errors.Add('AFK handoff accepted a closed research recommendation as a map Decision')
        }
        [System.IO.File]::WriteAllText((Join-Path $FixtureRoot 'afk-handoff-map.md'), @"
# AFK handoff map

## Frontier

1. [确认发布策略](tickets/ticket-f-decision.md)

## Decisions so far

-
"@, [System.Text.UTF8Encoding]::new($false))
        $AfterAfkClosure = & $FrontierSelector.FullName -MapPath (Join-Path $FixtureRoot 'afk-handoff-map.md')
        if ($LASTEXITCODE -ne 0 -or $AfterAfkClosure -notmatch 'ticket-f') {
            $Errors.Add('AFK handoff did not expose the HITL ticket after research closure')
        }

    } finally {
        if (Test-Path -LiteralPath $FixtureRoot) {
            Remove-Item -LiteralPath $FixtureRoot -Recurse -Force
        }
    }
}

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Wayfinder behavior contract: PASS'
