param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$Errors = [System.Collections.Generic.List[string]]::new()
$Selector = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/解析Frontier指针.ps1'
$Lifecycle = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/管理Wayfinder生命周期.ps1'
$Publisher = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/发布Research资产.ps1'
$ClaimManager = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/管理Research认领.ps1'

function Write-Utf8([string]$Path, [string]$Content) {
    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-MustReject([scriptblock]$Action, [string]$Message, [string]$ExpectedMessage) {
    $Rejected = $false
    try {
        $null = & $Action
    } catch {
        $Rejected = $true
        if (-not $_.Exception.Message.Contains($ExpectedMessage)) {
            $Errors.Add("$Message；实际异常不匹配：$($_.Exception.Message)")
        }
    }
    if (-not $Rejected) {
        $Errors.Add($Message)
    }
}

function New-TicketContent(
    [string]$Id,
    [string]$Title,
    [string]$Status = 'open',
    [string]$Claim = 'unclaimed',
    [string]$Type = 'research',
    [string]$Interaction = 'AFK',
    [string]$DecisionStatus = 'not_required',
    [string]$ClosureKind = 'pending'
) {
    return @"
---
id: $Id
status: $Status
type: $Type
interaction: $Interaction
decision_status: $DecisionStatus
confirmed_choice:
confirmed_by:
confirmed_at:
closure_kind: $ClosureKind
closure_source_ticket:
claim: $Claim
claimed_at:
blocked_by: []
blocks: []
created_at: 2026-07-20T16:00:00+08:00
closed_at:
---

# $Title

## Resolution

- 结论：
- 对地图的决策指针：

## Assets

-
"@
}

function New-MapContent(
    [string]$Status,
    [string]$Repository,
    [string]$Frontier,
    [string]$Index,
    [string]$Fog = '-'
) {
    return @"
---
id: audit-map
status: $Status
repository: $Repository
handoff_path:
handoff_stage:
handoff_target:
created_at: 2026-07-20T16:00:00+08:00
updated_at: 2026-07-20T16:00:00+08:00
ready_at:
closed_at:
---

# 完整性审查地图

## Destination

形成可交给 PRD 的已确认路线。

## Notes

- 本 map 只找路。

## Frontier

$Frontier

## Decisions so far

-

## Not yet specified

$Fog

## Out of scope

-

## Ticket index

| Ticket | 链接 |
|---|---|
$Index
"@
}

$FixtureRoots = [System.Collections.Generic.List[string]]::new()
try {
    $FrontierRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wayfinder-integrity-' + [Guid]::NewGuid().ToString('N'))
    $FixtureRoots.Add($FrontierRoot)
    $FrontierTickets = Join-Path $FrontierRoot 'tickets'
    New-Item -ItemType Directory -Path $FrontierTickets -Force | Out-Null
    Write-Utf8 (Join-Path $FrontierTickets 'a-票据.md') (New-TicketContent 'a' '优先级较低的调研')
    Write-Utf8 (Join-Path $FrontierTickets 'b-票据.md') (New-TicketContent 'b' '优先级较高的调研')
    $Index = "| 优先级较低的调研 | [优先级较低的调研](tickets/a-票据.md) |`n| 优先级较高的调研 | [优先级较高的调研](tickets/b-票据.md) |"
    $MissingMap = New-MapContent 'active' $FrontierRoot '1. [优先级较低的调研](tickets/a-票据.md)' $Index
    $FrontierMap = Join-Path $FrontierRoot '地图.md'
    Write-Utf8 $FrontierMap $MissingMap
    Invoke-MustReject { & $Selector -MapPath $FrontierMap } 'Frontier 遗漏可执行票时仍返回了下一票' 'Frontier is missing eligible tickets'
    Invoke-MustReject { & $Selector -MapPath $FrontierMap -Mode ResearchBatch } 'ResearchBatch 接受了不完整 Frontier' 'Frontier is missing eligible tickets'

    $OrderedMap = New-MapContent 'active' $FrontierRoot "1. [优先级较高的调研](tickets/b-票据.md)`n2. [优先级较低的调研](tickets/a-票据.md)" $Index
    Write-Utf8 $FrontierMap $OrderedMap
    try {
        $First = (& $Selector -MapPath $FrontierMap) | ConvertFrom-Json
        if ($First.id -ne 'b') {
            $Errors.Add('Frontier 完整性校验破坏了用户自定义顺序')
        }
    } catch {
        $Errors.Add("完整 Frontier 不可执行：$($_.Exception.Message)")
    }

    $ClosedA = New-TicketContent 'a' '优先级较低的调研' 'closed' 'codex:done' 'research' 'AFK' 'not_required' 'fact'
    $ClosedA = $ClosedA.Replace('- 结论：', '- 结论：已完成。').Replace('closed_at:', 'closed_at: 2026-07-20T16:05:00+08:00')
    Write-Utf8 (Join-Path $FrontierTickets 'a-票据.md') $ClosedA
    Write-Utf8 $FrontierMap (New-MapContent 'active' $FrontierRoot "1. [优先级较低的调研](tickets/a-票据.md)`n2. [优先级较高的调研](tickets/b-票据.md)" $Index)
    try {
        $AfterStale = (& $Selector -MapPath $FrontierMap) | ConvertFrom-Json
        if ($AfterStale.id -ne 'b') {
            $Errors.Add('stale Frontier 指针未被允许并跳过')
        }
    } catch {
        $Errors.Add("stale Frontier 指针被错误拒绝：$($_.Exception.Message)")
    }
    Write-Utf8 (Join-Path $FrontierTickets 'a-票据.md') (New-TicketContent 'a' '优先级较低的调研')

    $HiddenTicketPath = Join-Path $FrontierTickets 'hidden-票据.md'
    Write-Utf8 $HiddenTicketPath (New-TicketContent 'hidden' '隐藏但仍属于全集的调研')
    (Get-Item -LiteralPath $HiddenTicketPath).Attributes = (Get-Item -LiteralPath $HiddenTicketPath).Attributes -bor [System.IO.FileAttributes]::Hidden
    Invoke-MustReject { & $Selector -MapPath $FrontierMap } '隐藏 Markdown ticket 未进入目录全集审计' 'Ticket index is missing ticket'
    (Get-Item -LiteralPath $HiddenTicketPath -Force).Attributes = [System.IO.FileAttributes]::Normal
    Remove-Item -LiteralPath $HiddenTicketPath -Force

    Write-Utf8 $FrontierMap (New-MapContent 'closed' $FrontierRoot "1. [优先级较高的调研](tickets/b-票据.md)`n2. [优先级较低的调研](tickets/a-票据.md)" $Index)
    Invoke-MustReject { & $Selector -MapPath $FrontierMap } 'closed map 仍可选择 ticket' 'is closed and cannot select or claim tickets'
    Write-Utf8 $FrontierMap (New-MapContent 'ready_for_handoff' $FrontierRoot "1. [优先级较高的调研](tickets/b-票据.md)`n2. [优先级较低的调研](tickets/a-票据.md)" $Index)
    Invoke-MustReject { & $Selector -MapPath $FrontierMap } 'ready_for_handoff map 仍可选择 ticket' 'is ready_for_handoff and cannot select or claim tickets'
    Invoke-MustReject { & $ClaimManager -MapPath $FrontierMap -Operation ClaimBatch -Owner 'codex:late-claim' } 'ready_for_handoff map 仍可 claim ticket' 'is ready_for_handoff and cannot select or claim tickets'

    $LifecycleRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wayfinder-handoff-' + [Guid]::NewGuid().ToString('N'))
    $FixtureRoots.Add($LifecycleRoot)
    $LifecycleTickets = Join-Path $LifecycleRoot 'tickets'
    New-Item -ItemType Directory -Path $LifecycleTickets -Force | Out-Null
    $ClosedTicket = New-TicketContent 'done' '已完成的范围决定' 'closed' 'codex:done' 'research' 'AFK' 'not_required' 'fact'
    $ClosedTicket = $ClosedTicket.Replace('- 结论：', '- 结论：已确认范围。').Replace('closed_at:', 'closed_at: 2026-07-20T16:10:00+08:00')
    Write-Utf8 (Join-Path $LifecycleTickets 'done-票据.md') $ClosedTicket
    $LifecycleIndex = '| 已完成的范围决定 | [已完成的范围决定](tickets/done-票据.md) |'
    $LifecycleMap = Join-Path $LifecycleRoot '地图.md'
    Write-Utf8 $LifecycleMap (New-MapContent 'active' $LifecycleRoot '' $LifecycleIndex)

    if (-not (Test-Path -LiteralPath $Lifecycle)) {
        $Errors.Add('缺少 Wayfinder 生命周期管理脚本')
    } else {
        try {
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md' } 'active map 未准备交接便允许 Close' 'must prepare handoff before close'
            $InvalidReadyMap = (New-MapContent 'ready_for_handoff' $LifecycleRoot '' $LifecycleIndex).Replace('handoff_path:', 'handoff_path: 交接.md').Replace('handoff_stage:', 'handoff_stage: prd')
            Write-Utf8 $LifecycleMap $InvalidReadyMap
            Write-Utf8 (Join-Path $LifecycleRoot '交接.md') 'THIS IS NOT A VALID HANDOFF'
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md' } '首次 Close 接受了无效交接文件' 'incomplete YAML frontmatter'
            Write-Utf8 $LifecycleMap (New-MapContent 'active' $LifecycleRoot '' $LifecycleIndex)
            Write-Utf8 (Join-Path $LifecycleRoot '交接.md') @"
---
map_id: audit-map
status: ready_for_handoff
handoff_stage: prd
generated_at: 2026-07-20T16:11:00+08:00
---

# 中断残留交接
"@
            $Prepared = (& $Lifecycle -MapPath $LifecycleMap -Operation PrepareHandoff -HandoffStage prd) | ConvertFrom-Json
            if ($Prepared.status -ne 'ready_for_handoff' -or -not (Test-Path -LiteralPath $Prepared.handoff_path)) {
                $Errors.Add('PrepareHandoff 未生成交接或未进入 ready_for_handoff')
            }
            Remove-Item -LiteralPath $Prepared.handoff_path -Force
            $PreparedRetry = (& $Lifecycle -MapPath $LifecycleMap -Operation PrepareHandoff -HandoffStage prd) | ConvertFrom-Json
            if (-not $PreparedRetry.retry -or -not (Test-Path -LiteralPath $PreparedRetry.handoff_path)) {
                $Errors.Add('PrepareHandoff 同 stage 重试未修复丢失的交接文件')
            }
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation PrepareHandoff -HandoffStage openspec } 'PrepareHandoff 接受了不同 stage 重试' 'already targets handoff stage'
            $Closed = (& $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md') | ConvertFrom-Json
            if ($Closed.status -ne 'closed') {
                $Errors.Add('Close 未关闭 ready_for_handoff map')
            }
            $ValidHandoff = Get-Content -LiteralPath $PreparedRetry.handoff_path -Raw -Encoding UTF8
            Remove-Item -LiteralPath $PreparedRetry.handoff_path -Force
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md' } 'Close 重试接受了缺失的交接文件' 'has no valid handoff file'
            Write-Utf8 $PreparedRetry.handoff_path ($ValidHandoff.Replace('map_id: audit-map', 'map_id: another-map'))
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md' } 'Close 重试接受了不属于当前 map 的交接文件' 'has an invalid handoff file'
            Write-Utf8 $PreparedRetry.handoff_path $ValidHandoff
            $ClosedRetry = (& $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'docs/prd/目标PRD.md') | ConvertFrom-Json
            if (-not $ClosedRetry.retry) {
                $Errors.Add('Close 同 target 重试不是幂等成功')
            }
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation Close -HandoffTarget 'openspec/changes/other' } 'Close 接受了不同 target 重试' 'already closed with another handoff target'
        } catch {
            $Errors.Add("Wayfinder 生命周期流程失败：$($_.Exception.Message)")
        }

        Write-Utf8 $LifecycleMap (New-MapContent 'active' $LifecycleRoot '' $LifecycleIndex '- 尚未确认灰度窗口。')
        Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation PrepareHandoff -HandoffStage prd } '存在有效 fog 时允许 PrepareHandoff' 'is not ready for handoff'

        foreach ($LiveStatus in @('open', 'claimed')) {
            $LiveClaim = if ($LiveStatus -eq 'open') { 'unclaimed' } else { 'codex:working' }
            Write-Utf8 (Join-Path $LifecycleTickets 'live-票据.md') (New-TicketContent 'live' '仍在推进的票据' $LiveStatus $LiveClaim)
            $LiveIndex = "$LifecycleIndex`n| 仍在推进的票据 | [仍在推进的票据](tickets/live-票据.md) |"
            Write-Utf8 $LifecycleMap (New-MapContent 'active' $LifecycleRoot '1. [仍在推进的票据](tickets/live-票据.md)' $LiveIndex)
            Invoke-MustReject { & $Lifecycle -MapPath $LifecycleMap -Operation PrepareHandoff -HandoffStage prd } "$LiveStatus ticket 存在时允许 PrepareHandoff" 'is not ready for handoff'
            Remove-Item -LiteralPath (Join-Path $LifecycleTickets 'live-票据.md') -Force
        }

        $RaceScripts = Join-Path $LifecycleRoot 'race-scripts'
        New-Item -ItemType Directory -Path $RaceScripts -Force | Out-Null
        Copy-Item -LiteralPath $Lifecycle -Destination (Join-Path $RaceScripts '管理Wayfinder生命周期.ps1')
        $RaceMap = Join-Path $LifecycleRoot '并发地图.md'
        Write-Utf8 $RaceMap (New-MapContent 'active' $LifecycleRoot '' $LifecycleIndex)
        Write-Utf8 (Join-Path $RaceScripts '解析Frontier指针.ps1') @'
param([string]$MapPath, [string]$Mode)
$content = Get-Content -LiteralPath $MapPath -Raw -Encoding UTF8
$countPath = Join-Path (Split-Path -Parent $MapPath) 'audit-count.txt'
$count = if (Test-Path -LiteralPath $countPath) { [int](Get-Content -LiteralPath $countPath -Raw) + 1 } else { 1 }
[System.IO.File]::WriteAllText($countPath, [string]$count, [System.Text.Encoding]::ASCII)
if ($count -eq 2 -and $content -notmatch 'concurrent-external-edit') {
    [System.IO.File]::AppendAllText($MapPath, "`n<!-- concurrent-external-edit -->`n", [System.Text.UTF8Encoding]::new($false))
}
$ticket = (Get-ChildItem -LiteralPath (Join-Path (Split-Path -Parent $MapPath) 'tickets') -File -Filter 'done-*.md')[0].FullName
[pscustomobject]@{ map_id = 'audit-map'; status = 'active'; eligible = @(); missing = @(); stale = @(); tickets = @([pscustomobject]@{ id = 'done'; path = $ticket; status = 'closed' }); live_count = 0; has_fog = $false } | ConvertTo-Json -Depth 5 -Compress
'@
        Invoke-MustReject { & (Join-Path $RaceScripts '管理Wayfinder生命周期.ps1') -MapPath $RaceMap -Operation PrepareHandoff -HandoffStage prd } '生命周期脚本覆盖了 Audit 期间的并发 map 修改' 'changed during lifecycle transition'
    }

    $ResearchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wayfinder-sources-' + [Guid]::NewGuid().ToString('N'))
    $FixtureRoots.Add($ResearchRoot)
    $ResearchTickets = Join-Path $ResearchRoot 'tickets'
    New-Item -ItemType Directory -Path $ResearchTickets -Force | Out-Null
    Write-Utf8 (Join-Path $ResearchRoot 'docs/官方规格.md') '# 官方规格'
    Write-Utf8 (Join-Path $ResearchRoot 'docs/file..md') '# 不允许作为来源'
    $ResearchTicketPath = Join-Path $ResearchTickets 'research-api-票据.md'
    Write-Utf8 $ResearchTicketPath (New-TicketContent 'research-api' '调研支付 API' 'claimed' 'codex:owner-a')
    $ResearchIndex = '| 调研支付 API | [调研支付 API](tickets/research-api-票据.md) |'
    $ResearchMap = Join-Path $ResearchRoot '地图.md'
    Write-Utf8 $ResearchMap (New-MapContent 'active' $ResearchRoot '1. [调研支付 API](tickets/research-api-票据.md)' $ResearchIndex)

    $HiddenRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wayfinder-hidden-flow-' + [Guid]::NewGuid().ToString('N'))
    $FixtureRoots.Add($HiddenRoot)
    $HiddenTickets = Join-Path $HiddenRoot 'tickets'
    New-Item -ItemType Directory -Path $HiddenTickets -Force | Out-Null
    $HiddenFlowTicket = Join-Path $HiddenTickets 'hidden-flow-票据.md'
    Write-Utf8 $HiddenFlowTicket (New-TicketContent 'hidden-flow' '隐藏票据完整流程')
    (Get-Item -LiteralPath $HiddenFlowTicket).Attributes = (Get-Item -LiteralPath $HiddenFlowTicket).Attributes -bor [System.IO.FileAttributes]::Hidden
    $HiddenIndex = '| 隐藏票据完整流程 | [隐藏票据完整流程](tickets/hidden-flow-票据.md) |'
    $HiddenMap = Join-Path $HiddenRoot '地图.md'
    Write-Utf8 $HiddenMap (New-MapContent 'active' $HiddenRoot '1. [隐藏票据完整流程](tickets/hidden-flow-票据.md)' $HiddenIndex)
    try {
        $HiddenClaim = (& $ClaimManager -MapPath $HiddenMap -Operation ClaimBatch -Owner 'codex:hidden-owner') | ConvertFrom-Json
        if (@($HiddenClaim.claimed).Count -ne 1 -or @($HiddenClaim.failed).Count -ne 0) {
            $Errors.Add('合法 hidden ticket 无法完成 claim')
        }
        $HiddenAsset = (& $Publisher -MapPath $HiddenMap -TicketId 'hidden-flow' -Owner 'codex:hidden-owner' -Content '# 隐藏调研结论' -Sources @('https://example.com/hidden')) | ConvertFrom-Json
        if (-not (Test-Path -LiteralPath $HiddenAsset.path)) {
            $Errors.Add('合法 hidden ticket 无法发布 Research 资产')
        }
    } catch {
        $Errors.Add("合法 hidden ticket 完整流程失败：$($_.Exception.Message)")
    }

    Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 结论' -Sources @() } 'Research 缺少 Sources 仍可发布' 'requires at least one primary source'
    try {
        $Published = (& $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 结论`n`n第一版。' -Sources @('https://example.com/docs', 'repo:docs/官方规格.md', 'commit:abcdef1')) | ConvertFrom-Json
        $AssetContent = Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8
        $TicketContent = Get-Content -LiteralPath $ResearchTicketPath -Raw -Encoding UTF8
        if ($AssetContent -notmatch '(?m)^## Sources$' -or $AssetContent -notmatch 'repo:docs/官方规格.md') {
            $Errors.Add('Research 资产未生成来源区')
        }
        if ([regex]::Matches($TicketContent, [regex]::Escape('../research/research-api-研究.md')).Count -ne 1) {
            $Errors.Add('Research 发布未在 ticket Assets 写入唯一指针')
        }
        $null = & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 结论`n`n第二版。' -Sources @('https://example.com/docs')
        $TicketAfterRetry = Get-Content -LiteralPath $ResearchTicketPath -Raw -Encoding UTF8
        if ([regex]::Matches($TicketAfterRetry, [regex]::Escape('../research/research-api-研究.md')).Count -ne 1) {
            $Errors.Add('Research 同 owner 重试重复写入 Assets 指针')
        }

        $AssetBeforeRejectedPublish = Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8
        $DuplicatePointer = '- [Research：调研支付 API](../research/research-api-研究.md)'
        Write-Utf8 $ResearchTicketPath ($TicketAfterRetry.Replace($DuplicatePointer, "$DuplicatePointer`n$DuplicatePointer"))
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 不应落盘的新内容' -Sources @('https://example.com/rejected') } 'Research 指针校验失败后仍返回成功' 'duplicate Research asset pointers'
        if ((Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8) -ne $AssetBeforeRejectedPublish) {
            $Errors.Add('Research 发布拒绝后仍覆盖了已有资产')
        }
        Write-Utf8 $ResearchTicketPath $TicketAfterRetry

        $AssetBeforeDuplicateSources = Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content "# 不应落盘`n`n## Sources`n`n- 伪造来源" -Sources @('https://example.com/rejected') } 'Research 正文重复 Sources 后仍返回成功' 'exactly one Sources section'
        if ((Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8) -ne $AssetBeforeDuplicateSources) {
            $Errors.Add('Research 重复 Sources 被拒绝后仍覆盖了已有资产')
        }

        $AssetBeforeSidePointer = Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8
        $SidePointerTicket = $TicketAfterRetry.Replace('## Resolution', "## Notes`n`n旁路引用：../research/research-api-研究.md`n`n## Resolution")
        Write-Utf8 $ResearchTicketPath $SidePointerTicket
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 不应落盘的旁路指针版本' -Sources @('https://example.com/rejected') } 'Research 旁路重复指针后仍返回成功' 'exactly one global asset pointer'
        if ((Get-Content -LiteralPath $Published.path -Raw -Encoding UTF8) -ne $AssetBeforeSidePointer) {
            $Errors.Add('Research 旁路重复指针被拒绝后仍覆盖了已有资产')
        }
        Write-Utf8 $ResearchTicketPath $TicketAfterRetry

        Write-Utf8 $ResearchTicketPath ($TicketAfterRetry.Replace('claim: codex:owner-a', 'claim: codex:owner-b'))
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-b' -Content '# 新结论' -Sources @('https://example.com/new') } '新 owner 未显式接管便覆盖旧资产' 'belongs to another session'
        $TakenOver = (& $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-b' -TakeoverOwner 'codex:owner-a' -Content '# 新结论' -Sources @('https://example.com/new')) | ConvertFrom-Json
        if (-not $TakenOver.takeover -or (Get-Content -LiteralPath $TakenOver.path -Raw -Encoding UTF8) -notmatch 'previous_owner: codex:owner-a') {
            $Errors.Add('TakeoverOwner 未记录安全接管')
        }
        $null = & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-b' -Content '# 新结论重试' -Sources @('https://example.com/new')
        if ((Get-Content -LiteralPath $TakenOver.path -Raw -Encoding UTF8) -notmatch 'previous_owner: codex:owner-a') {
            $Errors.Add('接管后的同 owner 重试丢失 previous_owner')
        }

        $OwnerBTicket = Get-Content -LiteralPath $ResearchTicketPath -Raw -Encoding UTF8
        $OwnerCTicket = $OwnerBTicket.Replace('claim: codex:owner-b', 'claim: codex:owner-c')
        Write-Utf8 $ResearchTicketPath $OwnerCTicket
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-c' -TakeoverOwner 'codex:owner-a' -Content '# 错误接管' -Sources @('https://example.com/new') } 'TakeoverOwner 接受了不匹配的旧 owner' 'belongs to another session'

        $ResolvedTicket = $OwnerCTicket.Replace('- 结论：', '- 结论：已经完成。')
        Write-Utf8 $ResearchTicketPath $ResolvedTicket
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-c' -TakeoverOwner 'codex:owner-b' -Content '# 错误接管' -Sources @('https://example.com/new') } 'TakeoverOwner 接受了已有 Resolution 的 ticket' 'belongs to another session'

        Write-Utf8 $ResearchTicketPath $OwnerCTicket
        $ValidAsset = Get-Content -LiteralPath $TakenOver.path -Raw -Encoding UTF8
        Write-Utf8 $TakenOver.path ($ValidAsset.Replace('ticket_id: research-api', 'ticket_id: other-ticket'))
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-c' -TakeoverOwner 'codex:owner-b' -Content '# 错误接管' -Sources @('https://example.com/new') } 'TakeoverOwner 接受了 ticket_id 不匹配的资产' 'belongs to another ticket'
        Write-Utf8 $TakenOver.path $ValidAsset
        Write-Utf8 $ResearchTicketPath $OwnerBTicket
    } catch {
        $Errors.Add("Research 来源与资产指针流程失败：$($_.Exception.Message)")
    }

    $OutsideRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('wayfinder-source-outside-' + [Guid]::NewGuid().ToString('N'))
    $FixtureRoots.Add($OutsideRoot)
    New-Item -ItemType Directory -Path $OutsideRoot -Force | Out-Null
    Write-Utf8 (Join-Path $OutsideRoot 'secret.md') '# 仓库外来源'
    $JunctionPath = Join-Path $ResearchRoot 'linked-outside'
    try {
        New-Item -ItemType Junction -Path $JunctionPath -Target $OutsideRoot | Out-Null
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-b' -Content '# 结论' -Sources @('repo:linked-outside/secret.md') } 'Research repo 来源通过中间 junction 逃出仓库' 'cannot traverse a junction or symbolic link'
    } finally {
        if (Test-Path -LiteralPath $JunctionPath) {
            [System.IO.Directory]::Delete($JunctionPath)
        }
    }

    foreach ($BadSource in @('http://example.com', 'repo:../secret.txt', 'repo:docs/file..md', 'commit:abc', "https://example.com`nattack", '<官方来源>')) {
        $ExpectedSourceError = if ($BadSource.StartsWith('repo:')) { 'Invalid repository source' } elseif ($BadSource -match '[\r\n]' -or $BadSource.StartsWith('<')) { 'Invalid Research source' } else { 'Unsupported Research source' }
        Invoke-MustReject { & $Publisher -MapPath $ResearchMap -TicketId 'research-api' -Owner 'codex:owner-b' -Content '# 结论' -Sources @($BadSource) } "Research 接受了非法来源：$BadSource" $ExpectedSourceError
    }
} finally {
    foreach ($FixtureRoot in $FixtureRoots) {
        if (Test-Path -LiteralPath $FixtureRoot) {
            Remove-Item -LiteralPath $FixtureRoot -Recurse -Force
        }
    }
}

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Wayfinder integrity and handoff: PASS'
