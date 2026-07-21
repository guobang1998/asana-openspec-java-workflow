param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$Errors = [System.Collections.Generic.List[string]]::new()

function Require-File([string]$RelativePath) {
    if (-not (Test-Path (Join-Path $RepoRoot $RelativePath))) {
        $Errors.Add("缺少文件：$RelativePath")
    }
}

function Require-Text([string]$RelativePath, [string]$ExpectedText) {
    $Path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $Path)) {
        $Errors.Add("缺少文件：$RelativePath")
        return
    }

    $Content = Get-Content -Raw -Encoding UTF8 $Path
    if (-not $Content.Contains($ExpectedText)) {
        $Errors.Add("$RelativePath 缺少约定文本：$ExpectedText")
    }
}

function Forbid-Text([string]$RelativePath, [string]$UnexpectedText) {
    $Path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $Path)) {
        return
    }

    $Content = Get-Content -Raw -Encoding UTF8 $Path
    if ($Content.Contains($UnexpectedText)) {
        $Errors.Add("$RelativePath 不应包含文本：$UnexpectedText")
    }
}

Require-File 'skills/wayfinder-workflow/SKILL.md'
Require-File 'skills/wayfinder-workflow/scripts/解析Frontier指针.ps1'
Require-File 'skills/wayfinder-workflow/scripts/管理Research认领.ps1'
Require-File 'skills/wayfinder-workflow/scripts/发布Research资产.ps1'
Require-File 'skills/wayfinder-workflow/scripts/管理Wayfinder生命周期.ps1'
Require-File 'assets/templates/wayfinding-map模板.md'
Require-File 'assets/templates/frontier-ticket模板.md'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '.workflow-maps/<map-id>/'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '一次会话只做一件事'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'frontier'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'claim'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'HITL'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'YAML frontmatter 是唯一状态源'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'setup-workflow 的只读发现优先于 Wayfinder'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'model-invoked'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- frontier-resource: bundled -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- hitl-close-gate: explicit-confirmation-required -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- research-batch: parallel-background-then-serial-close -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- frontier-integrity: directory-index-frontier -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- research-provenance: sources-and-ticket-pointer -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' '<!-- map-lifecycle: active-ready-closed -->'
Require-Text 'skills/wayfinder-workflow/SKILL.md' 'fallback 必须扫描 `tickets/*.md` 全集'
Require-Text 'assets/templates/wayfinding-map模板.md' '## Destination'
Require-Text 'assets/templates/wayfinding-map模板.md' '## Not yet specified'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Question'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Claim'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Current slice'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Out of scope'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Inputs'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Outputs'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Acceptance'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Rollback or abandon'
Require-Text 'assets/templates/frontier-ticket模板.md' '# allowed status: open | claimed | closed'
Require-Text 'assets/templates/frontier-ticket模板.md' 'decision_status: <not_required | pending | confirmed>'
Require-Text 'assets/templates/frontier-ticket模板.md' '## Confirmation'
Forbid-Text 'assets/templates/frontier-ticket模板.md' '- 状态：open'
Require-Text 'skills/asana-openspec-delivery/SKILL.md' 'wayfinder-workflow'
Require-Text 'skills/asana-openspec-delivery/SKILL.md' 'setup-workflow 的只读发现优先于 Wayfinder'
Require-Text 'skills/large-refactor-workflow/SKILL.md' 'wayfinder-workflow'
Require-Text 'skills/large-refactor-workflow/SKILL.md' 'Destination、范围和首批决策尚不清晰时，不进入大重构流程'
Require-Text 'README.md' 'wayfinder-workflow'
Require-Text 'skills/java-backend-review/SKILL.md' '#### 正确性'
Require-Text 'skills/java-backend-review/SKILL.md' '#### 事务'
Require-Text 'skills/java-backend-review/SKILL.md' '#### 测试'
Require-Text 'docs/试运行/Wayfinder行为验收场景.md' '场景 4'
Require-Text '.codex-plugin/plugin.json' '"version": "1.8.0+codex.'

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Wayfinder 最小版：PASS'
