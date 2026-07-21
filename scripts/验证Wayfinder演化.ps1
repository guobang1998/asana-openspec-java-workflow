param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$Errors = [System.Collections.Generic.List[string]]::new()
$Wayfinder = Join-Path $RepoRoot 'skills/wayfinder-workflow/SKILL.md'
$Selector = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/解析Frontier指针.ps1'
$ClaimManager = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/管理Research认领.ps1'
$AssetPublisher = Join-Path $RepoRoot 'skills/wayfinder-workflow/scripts/发布Research资产.ps1'
$TicketTemplate = Join-Path $RepoRoot 'assets/templates/frontier-ticket模板.md'
$MapTemplate = Join-Path $RepoRoot 'assets/templates/wayfinding-map模板.md'
$BehaviorRecord = Join-Path $RepoRoot 'docs/试运行/Wayfinder行为验收场景.md'

function Require-Text([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path)) {
        $Errors.Add("缺少文件：$Path")
        return
    }
    if (-not (Get-Content -LiteralPath $Path -Raw -Encoding UTF8).Contains($Expected)) {
        $Errors.Add("缺少合同：$Path -> $Expected")
    }
}

Require-Text $Wayfinder '<!-- research-batch: parallel-background-then-serial-close -->'
Require-Text $Wayfinder '<!-- research-claim: atomic-owner-verify-release -->'
Require-Text $Wayfinder '<!-- frontier-integrity: directory-index-frontier -->'
Require-Text $Wayfinder '<!-- research-provenance: sources-and-ticket-pointer -->'
Require-Text $Wayfinder '<!-- map-lifecycle: active-ready-closed -->'
Require-Text $Wayfinder '<!-- map-evolution: decision-fact-out-of-scope-superseded -->'
Require-Text $Wayfinder '<!-- ticket-display: title-first -->'
Require-Text $Wayfinder 'scripts/发布Research资产.ps1'
Require-Text $ClaimManager ".wayfinder-state.lock"
Require-Text $AssetPublisher ".wayfinder-state.lock"
Require-Text $TicketTemplate 'closure_kind: pending'
Require-Text $TicketTemplate 'closure_source_ticket:'
Require-Text $MapTemplate '<!-- ticket-display: title-first -->'
Require-Text $BehaviorRecord '<!-- scenario-id: parallel-research -->'
Require-Text $BehaviorRecord '<!-- scenario-id: map-evolution -->'
Require-Text $BehaviorRecord '<!-- evidence: research-parallelism -->'
Require-Text $BehaviorRecord '<!-- evidence: map-lifecycle -->'
Require-Text $BehaviorRecord '<!-- evidence: title-first -->'
if (-not (Test-Path -LiteralPath $ClaimManager)) {
    $Errors.Add('缺少 Research 原子认领管理器')
}
if (-not (Test-Path -LiteralPath $AssetPublisher)) {
    $Errors.Add('缺少 Research 资产发布门禁')
}

function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-Rejects([string]$MapPath, [string]$MapContent, [string]$Message) {
    Write-Utf8 $MapPath $MapContent
    $Rejected = $false
    try {
        $null = & $Selector -MapPath $MapPath
    } catch {
        $Rejected = $true
    }
    if (-not $Rejected) {
        $Errors.Add($Message)
    }
}

function Replace-Once([string]$Content, [string]$OldValue, [string]$NewValue) {
    $Pattern = [regex]::Escape($OldValue)
    if ([regex]::Matches($Content, $Pattern).Count -ne 1) {
        throw "验收样本无法唯一定位待替换文本：$OldValue"
    }
    return [regex]::Replace($Content, $Pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($Match) $NewValue }, 1)
}

$FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wayfinder-evolution-" + [Guid]::NewGuid().ToString('N'))
$ClaimFixtures = [System.Collections.Generic.List[string]]::new()
try {
    $TicketsRoot = Join-Path $FixtureRoot 'tickets'
    New-Item -ItemType Directory -Path $TicketsRoot -Force | Out-Null
    $MapPath = Join-Path $FixtureRoot '地图.md'

    $TicketContents = @{
        'scope-decision' = @"
---
id: scope-decision
status: closed
type: grilling
interaction: HITL
decision_status: confirmed
confirmed_choice: A
confirmed_by: user
confirmed_at: 2026-07-20T15:00:00+08:00
closure_kind: decision
closure_source_ticket:
claim: codex:scope
claimed_at: 2026-07-20T14:59:00+08:00
blocked_by: []
blocks: [legacy-report, old-prototype]
closed_at: 2026-07-20T15:00:00+08:00
---

# 确认交付边界

## Confirmation

- 用户原始决定：选择 A，只交付新流程。
"@
        'legacy-report' = @"
---
id: legacy-report
status: closed
type: task
interaction: HITL
decision_status: pending
confirmed_choice:
confirmed_by:
confirmed_at:
closure_kind: out_of_scope
closure_source_ticket: scope-decision
claim: codex:scope
claimed_at: 2026-07-20T15:01:00+08:00
blocked_by: [scope-decision]
blocks: []
closed_at: 2026-07-20T15:02:00+08:00
---

# 废弃旧报表
"@
        'old-prototype' = @"
---
id: old-prototype
status: closed
type: prototype
interaction: HITL
decision_status: pending
confirmed_choice:
confirmed_by:
confirmed_at:
closure_kind: superseded
closure_source_ticket: scope-decision
claim: codex:scope
claimed_at: 2026-07-20T15:01:00+08:00
blocked_by: [scope-decision]
blocks: []
closed_at: 2026-07-20T15:02:00+08:00
---

# 旧版交互原型
"@
        'research-api' = @"
---
id: research-api
# allowed status: open | claimed | closed
status: open
type: research
interaction: AFK
decision_status: not_required
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: []
closed_at:
---

# 调研支付 API

status: closed
claim: attacker

## Resolution

- 结论：
- 对地图的决策指针：

## Assets

-
"@
        'research-cost' = @"
---
id: research-cost
status: open
type: research
interaction: AFK
decision_status: not_required
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: []
closed_at:
---

# 调研迁移成本
"@
        'prepare-data' = @"
---
id: prepare-data
status: open
type: task
interaction: AFK
decision_status: not_required
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: [research-blocked]
closed_at:
---

# 准备测试数据
"@
        'research-blocked' = @"
---
id: research-blocked
status: open
type: research
interaction: AFK
decision_status: not_required
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: [prepare-data]
blocks: []
closed_at:
---

# 调研受阻事实
"@
        'research-claimed' = @"
---
id: research-claimed
status: claimed
type: research
interaction: AFK
decision_status: not_required
closure_kind: pending
closure_source_ticket:
claim: codex:other
claimed_at: 2026-07-20T15:00:00+08:00
blocked_by: []
blocks: []
closed_at:
---

# 已认领调研
"@
        'grilling-ui' = @"
---
id: grilling-ui
status: open
type: grilling
interaction: HITL
decision_status: pending
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: []
closed_at:
---

# 确认界面策略
"@
    }

    foreach ($Entry in $TicketContents.GetEnumerator()) {
        Write-Utf8 (Join-Path $TicketsRoot ("$($Entry.Key)-票据.md")) $Entry.Value
    }

    $BaseMap = @"
# 发布治理地图

## Destination

冻结新流程交付边界。

## Frontier

1. [调研支付 API](tickets/research-api-票据.md)
2. [调研迁移成本](tickets/research-cost-票据.md)
3. [准备测试数据](tickets/prepare-data-票据.md)
4. [调研受阻事实](tickets/research-blocked-票据.md)
5. [已认领调研](tickets/research-claimed-票据.md)
6. [确认界面策略](tickets/grilling-ui-票据.md)

## Decisions so far

- [确认交付边界](tickets/scope-decision-票据.md)：只交付新流程。

## Not yet specified

- 回滚窗口的精确时长。

## Out of scope

- [废弃旧报表](tickets/legacy-report-票据.md) - 已确认不在本次交付边界。

## Ticket index

| Ticket | 链接 |
|---|---|
| 调研支付 API | [调研支付 API](tickets/research-api-票据.md) |
| 调研迁移成本 | [调研迁移成本](tickets/research-cost-票据.md) |
| 准备测试数据 | [准备测试数据](tickets/prepare-data-票据.md) |
| 调研受阻事实 | [调研受阻事实](tickets/research-blocked-票据.md) |
| 已认领调研 | [已认领调研](tickets/research-claimed-票据.md) |
| 确认界面策略 | [确认界面策略](tickets/grilling-ui-票据.md) |
| 确认交付边界 | [确认交付边界](tickets/scope-decision-票据.md) |
| 废弃旧报表 | [废弃旧报表](tickets/legacy-report-票据.md) |
| 旧版交互原型 | [旧版交互原型](tickets/old-prototype-票据.md) |
"@
    Write-Utf8 $MapPath $BaseMap

    try {
        $BeforeHashes = @(Get-ChildItem -LiteralPath $FixtureRoot -Recurse -File | Sort-Object FullName | ForEach-Object { "$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
        $BatchRaw = & $Selector -MapPath $MapPath -Mode ResearchBatch
        $Batch = @(($BatchRaw | ConvertFrom-Json).tickets)
        $AfterHashes = @(Get-ChildItem -LiteralPath $FixtureRoot -Recurse -File | Sort-Object FullName | ForEach-Object { "$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
        $BatchIds = @($Batch | ForEach-Object { $_.id })
        if ([string]::Join(',', $BatchIds) -ne 'research-api,research-cost') {
            $Errors.Add("ResearchBatch 选择错误：$([string]::Join(',', $BatchIds))")
        }
        if (@(Compare-Object $BeforeHashes $AfterHashes).Count -ne 0) {
            $Errors.Add('ResearchBatch 不是只读操作')
        }
        if (@($Batch | Where-Object { [string]::IsNullOrWhiteSpace($_.title) }).Count -gt 0) {
            $Errors.Add('ResearchBatch 未返回用户可见标题')
        }
    } catch {
        $Errors.Add("ResearchBatch 不可执行：$($_.Exception.Message)")
    }

    Invoke-Rejects $MapPath (Replace-Once $BaseMap '1. [调研支付 API](tickets/research-api-票据.md)' '1. [错误标题](tickets/research-api-票据.md)') 'Frontier 接受了错误名称标签'
    Invoke-Rejects $MapPath (Replace-Once $BaseMap '- [确认交付边界](tickets/scope-decision-票据.md)：只交付新流程。' '- [错误标题](tickets/scope-decision-票据.md)：只交付新流程。') 'Decisions 接受了错误名称标签'
    Invoke-Rejects $MapPath (Replace-Once $BaseMap '- [废弃旧报表](tickets/legacy-report-票据.md) - 已确认不在本次交付边界。' '- [错误标题](tickets/legacy-report-票据.md) - 已确认不在本次交付边界。') 'Out of scope 接受了错误名称标签'
    Invoke-Rejects $MapPath (Replace-Once $BaseMap '| 旧版交互原型 | [旧版交互原型](tickets/old-prototype-票据.md) |' '| 旧版交互原型 | [错误标题](tickets/old-prototype-票据.md) |') 'Ticket index 接受了错误名称标签'
    $NestedTickets = Join-Path $TicketsRoot '嵌套目录'
    New-Item -ItemType Directory -Path $NestedTickets -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $TicketsRoot 'research-api-票据.md') -Destination (Join-Path $NestedTickets 'research-api-票据.md')
    Invoke-Rejects $MapPath (Replace-Once $BaseMap '1. [调研支付 API](tickets/research-api-票据.md)' '1. [调研支付 API](tickets/嵌套目录/research-api-票据.md)') '地图接受了 tickets 子目录票据路径'
    Invoke-Rejects $MapPath ($BaseMap.Replace('- 回滚窗口的精确时长。', '- [调研支付 API](tickets/research-api-票据.md)')) 'Not yet specified 接受了 ticket 链接'
    Invoke-Rejects $MapPath ($BaseMap.Replace(' - 已确认不在本次交付边界。', '')) 'Out of scope 接受了没有原因的条目'
    Invoke-Rejects $MapPath ($BaseMap.Replace('- [确认交付边界](tickets/scope-decision-票据.md)：只交付新流程。', '- [废弃旧报表](tickets/legacy-report-票据.md)：错误写入决定。')) 'Decisions 接受了 out_of_scope 票据'
    Invoke-Rejects $MapPath ($BaseMap.Replace('- [确认交付边界](tickets/scope-decision-票据.md)：只交付新流程。', '- [旧版交互原型](tickets/old-prototype-票据.md)：错误写入决定。')) 'Decisions 接受了 superseded 票据'
    Invoke-Rejects $MapPath ($BaseMap + "`n## Out of scope`n`n- 重复章节") '地图接受了重复 Out of scope 章节'
    Invoke-Rejects $MapPath ($BaseMap + "`n## Not yet specified`n`n- 重复章节") '地图接受了重复 Not yet specified 章节'

    $ResearchApiPath = Join-Path $TicketsRoot 'research-api-票据.md'
    Write-Utf8 $ResearchApiPath ($TicketContents['research-api'].Replace('# 调研支付 API', '# '))
    Invoke-Rejects $MapPath $BaseMap '票据接受了空一级标题'
    Write-Utf8 $ResearchApiPath ($TicketContents['research-api'] + "`n# 第二个一级标题`n")
    Invoke-Rejects $MapPath $BaseMap '票据接受了重复一级标题'
    Write-Utf8 $ResearchApiPath ($TicketContents['research-api'].Replace('# 调研支付 API', '# research-api'))
    Invoke-Rejects $MapPath $BaseMap '票据接受了裸 ID 一级标题'
    Write-Utf8 $ResearchApiPath $TicketContents['research-api']

    $FogTicket = @"
---
id: rollback-window
status: open
type: grilling
interaction: HITL
decision_status: pending
closure_kind: pending
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: []
closed_at:
---

# 确认回滚窗口
"@
    Write-Utf8 (Join-Path $TicketsRoot 'rollback-window-票据.md') $FogTicket
    $FogTransferred = Replace-Once $BaseMap '- 回滚窗口的精确时长。' ''
    $FogTransferred = Replace-Once $FogTransferred '6. [确认界面策略](tickets/grilling-ui-票据.md)' "6. [确认界面策略](tickets/grilling-ui-票据.md)`n7. [确认回滚窗口](tickets/rollback-window-票据.md)"
    $FogTransferred = Replace-Once $FogTransferred '| 旧版交互原型 | [旧版交互原型](tickets/old-prototype-票据.md) |' "| 旧版交互原型 | [旧版交互原型](tickets/old-prototype-票据.md) |`n| 确认回滚窗口 | [确认回滚窗口](tickets/rollback-window-票据.md) |"
    Write-Utf8 $MapPath $FogTransferred
    try {
        $null = & $Selector -MapPath $MapPath
    } catch {
        $Errors.Add("fog 创建票据并移除原条目后仍不可执行：$($_.Exception.Message)")
    }

    Write-Utf8 $MapPath $BaseMap
    $InvalidSource = $TicketContents['legacy-report'].Replace('closure_source_ticket: scope-decision', 'closure_source_ticket: missing-decision')
    Write-Utf8 (Join-Path $TicketsRoot 'legacy-report-票据.md') $InvalidSource
    try {
        $null = & $Selector -MapPath $MapPath
        $Errors.Add('out_of_scope HITL 接受了无效来源决定')
    } catch {}
    Write-Utf8 (Join-Path $TicketsRoot 'legacy-report-票据.md') $TicketContents['legacy-report']

    $OrdinaryClosedPending = $TicketContents['legacy-report'].Replace('closure_kind: out_of_scope', 'closure_kind: decision').Replace('closure_source_ticket: scope-decision', 'closure_source_ticket:')
    Write-Utf8 (Join-Path $TicketsRoot 'legacy-report-票据.md') $OrdinaryClosedPending
    try {
        $null = & $Selector -MapPath $MapPath
        $Errors.Add('普通 closed/pending HITL 绕过了确认门禁')
    } catch {}
    Write-Utf8 (Join-Path $TicketsRoot 'legacy-report-票据.md') $TicketContents['legacy-report']

    function New-ClaimFixture {
        $ClaimFixture = Join-Path ([System.IO.Path]::GetTempPath()) ("wayfinder-claim-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $ClaimFixture -Force | Out-Null
        Copy-Item -LiteralPath $MapPath -Destination (Join-Path $ClaimFixture '地图.md')
        Copy-Item -LiteralPath $TicketsRoot -Destination (Join-Path $ClaimFixture 'tickets') -Recurse
        $ClaimFixtures.Add($ClaimFixture)
        return $ClaimFixture
    }

    if (Test-Path -LiteralPath $ClaimManager) {
        $ClaimFixture = New-ClaimFixture
        $ClaimMap = Join-Path $ClaimFixture '地图.md'
        try {
            $RejectedUnsafeOwner = $false
            try {
                $null = & $ClaimManager -MapPath $ClaimMap -Operation ClaimBatch -Owner "codex:bad`nstatus:closed"
            } catch {
                $RejectedUnsafeOwner = $true
            }
            if (-not $RejectedUnsafeOwner) {
                $Errors.Add('Research claim 接受了可注入 YAML 的 owner')
            }
            $ClaimRaw = & $ClaimManager -MapPath $ClaimMap -Operation ClaimBatch -Owner 'codex:owner-a'
            $ClaimResult = $ClaimRaw | ConvertFrom-Json
            if (@($ClaimResult.claimed).Count -ne 2) {
                $Errors.Add("ClaimBatch 未认领全部可执行 research：$ClaimRaw")
            }
            $SecondRaw = & $ClaimManager -MapPath $ClaimMap -Operation ClaimBatch -Owner 'codex:owner-b'
            $SecondResult = $SecondRaw | ConvertFrom-Json
            if (@($SecondResult.claimed).Count -ne 0) {
                $Errors.Add('第二协调器重复认领了 research')
            }
            $ClaimedPaths = @($ClaimResult.claimed | ForEach-Object { $_.path })
            $null = & $ClaimManager -MapPath $ClaimMap -Operation VerifyOwned -Owner 'codex:owner-a' -TicketPaths $ClaimedPaths
            if (Test-Path -LiteralPath $AssetPublisher) {
                $FirstAsset = (& $AssetPublisher -MapPath $ClaimMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 研究结论`n`n第一版。' -Sources @('https://example.com/research')) | ConvertFrom-Json
                $RetryAsset = (& $AssetPublisher -MapPath $ClaimMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 研究结论`n`n第二版。' -Sources @('https://example.com/research')) | ConvertFrom-Json
                if ($FirstAsset.retry -or -not $RetryAsset.retry) {
                    $Errors.Add('Research 资产没有区分首次发布与同 owner 重试')
                }
                $AssetBeforeConflict = Get-Content -LiteralPath $RetryAsset.path -Raw -Encoding UTF8
                if ($AssetBeforeConflict -notmatch '第二版') {
                    $Errors.Add('Research 资产同 owner 重试没有更新内容')
                }
                $ApiTicketPath = @($ClaimedPaths | Where-Object { (Split-Path -Leaf $_) -like 'research-api-*' })[0]
                $OwnedByOther = (Get-Content -LiteralPath $ApiTicketPath -Raw -Encoding UTF8).Replace('claim: codex:owner-a', 'claim: codex:owner-b')
                Write-Utf8 $ApiTicketPath $OwnedByOther
                $RejectedOtherOwner = $false
                try {
                    $null = & $AssetPublisher -MapPath $ClaimMap -TicketId 'research-api' -Owner 'codex:owner-b' -Content '# 研究结论`n`n其他会话。' -Sources @('https://example.com/research')
                } catch {
                    $RejectedOtherOwner = $true
                }
                if (-not $RejectedOtherOwner -or (Get-Content -LiteralPath $RetryAsset.path -Raw -Encoding UTF8) -ne $AssetBeforeConflict) {
                    $Errors.Add('Research 资产允许其他 owner 覆盖或冲突后内容发生变化')
                }
                $RejectedStaleOwner = $false
                try {
                    $null = & $AssetPublisher -MapPath $ClaimMap -TicketId 'research-api' -Owner 'codex:owner-a' -Content '# 研究结论`n`n过期 owner。' -Sources @('https://example.com/research')
                } catch {
                    $RejectedStaleOwner = $true
                }
                if (-not $RejectedStaleOwner) {
                    $Errors.Add('Research 资产允许已失去 claim 的 owner 发布')
                }
                Write-Utf8 $ApiTicketPath ($OwnedByOther.Replace('claim: codex:owner-b', 'claim: codex:owner-a'))
            }
            $ChangedPath = $ClaimedPaths[0]
            $Changed = (Get-Content -LiteralPath $ChangedPath -Raw -Encoding UTF8).Replace('claim: codex:owner-a', 'claim: codex:owner-b')
            Write-Utf8 $ChangedPath $Changed
            $ReleaseRaw = & $ClaimManager -MapPath $ClaimMap -Operation ReleaseOwned -Owner 'codex:owner-a' -TicketPaths $ClaimedPaths
            $ReleaseResult = $ReleaseRaw | ConvertFrom-Json
            if (@($ReleaseResult.released).Count -ne 1 -or @($ReleaseResult.rejected).Count -ne 1) {
                $Errors.Add('ReleaseOwned 没有做到只释放自己的 claim')
            }
        } catch {
            $Errors.Add("Research claim 管理器执行失败：$($_.Exception.Message)")
        }

        $ConcurrentFixture = New-ClaimFixture
        $ConcurrentMap = Join-Path $ConcurrentFixture '地图.md'
        $Jobs = @(
            Start-Job -ScriptBlock {
                param($ScriptPath, $TargetMap)
                & $ScriptPath -MapPath $TargetMap -Operation ClaimBatch -Owner 'codex:race-a'
            } -ArgumentList $ClaimManager, $ConcurrentMap
            Start-Job -ScriptBlock {
                param($ScriptPath, $TargetMap)
                & $ScriptPath -MapPath $TargetMap -Operation ClaimBatch -Owner 'codex:race-b'
            } -ArgumentList $ClaimManager, $ConcurrentMap
        )
        try {
            $null = $Jobs | Wait-Job -Timeout 20
            $RaceResults = @($Jobs | ForEach-Object { (Receive-Job -Job $_ -ErrorAction Stop) | ConvertFrom-Json })
            $RaceClaimed = @($RaceResults | ForEach-Object { @($_.claimed) })
            $RaceOwners = @($RaceResults | Where-Object { @($_.claimed).Count -gt 0 } | ForEach-Object { $_.owner })
            if ($RaceClaimed.Count -ne 2 -or $RaceOwners.Count -ne 1) {
                $Errors.Add('双协调器竞争没有收敛到唯一 owner')
            }
        } catch {
            $Errors.Add("双协调器竞争测试失败：$($_.Exception.Message)")
        } finally {
            $Jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        $PartialFixture = New-ClaimFixture
        $PartialMap = Join-Path $PartialFixture '地图.md'
        $LockedTicket = Join-Path $PartialFixture 'tickets/research-cost-票据.md'
        $HeldFile = [System.IO.File]::Open(
            $LockedTicket,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::Read
        )
        try {
            $PartialRaw = & $ClaimManager -MapPath $PartialMap -Operation ClaimBatch -Owner 'codex:partial'
            $PartialResult = $PartialRaw | ConvertFrom-Json
            if (@($PartialResult.claimed).Count -ne 1 -or @($PartialResult.failed).Count -ne 1) {
                $Errors.Add("部分认领失败没有保留成功结果：$PartialRaw")
            }
        } catch {
            $Errors.Add("部分认领失败测试异常：$($_.Exception.Message)")
        } finally {
            $HeldFile.Dispose()
        }
    }
} finally {
    if (Test-Path -LiteralPath $FixtureRoot) {
        Remove-Item -LiteralPath $FixtureRoot -Recurse -Force
    }
    foreach ($ClaimFixture in $ClaimFixtures) {
        if (Test-Path -LiteralPath $ClaimFixture) {
            Remove-Item -LiteralPath $ClaimFixture -Recurse -Force
        }
    }
}

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Wayfinder research and evolution: PASS'
