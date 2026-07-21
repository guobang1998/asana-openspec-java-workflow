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

Require-File 'skills/setup-workflow/SKILL.md'
Require-File 'assets/templates/代码规范地图模板.md'
Require-Text 'skills/java-backend-review/SKILL.md' '## Standards'
Require-Text 'skills/java-backend-review/SKILL.md' '## Spec'
Require-Text 'skills/java-backend-review/SKILL.md' '## Tests'
Require-Text 'skills/java-backend-review/SKILL.md' '## Risk Gates'
Require-Text 'skills/pr-quality-gate/SKILL.md' '## 四轴汇总'
Require-Text 'skills/asana-openspec-delivery/SKILL.md' 'setup-workflow'
Require-Text 'README.md' '代码规范地图'
Require-Text '.codex-plugin/plugin.json' '"version": "1.8.0+codex.'

if ($Errors.Count -gt 0) {
    $Errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output '第一阶段规范入口与四轴审查：PASS'
