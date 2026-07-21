# Wayfinder 决策对话 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Wayfinder 增加“单问题、候选选项、系统推荐、用户显式确认”的 HITL 决策体验，并用脚本阻止未确认票据被关闭。

**Architecture:** 交互规则由 `SKILL.md` 定义，ticket YAML 保存机器状态，模板保存决策包和确认审计，`解析Frontier指针.ps1` 执行关闭门禁。现有行为验证脚本同时检查静态合同和真实状态迁移，不引入新的运行时依赖。

**Tech Stack:** Markdown、YAML frontmatter、PowerShell、Codex plugin manifest。

---

## Chunk 1: 交互合同与失败测试

### Task 1: 冻结行为合同

**Files:**
- Modify: `scripts/验证Wayfinder行为.ps1`
- Modify: `scripts/验证Wayfinder最小版.ps1`
- Modify: `docs/试运行/Wayfinder行为验收场景.md`

- [ ] **Step 1: 写入静态合同断言**

要求 skill 含单问题、2 至 3 个选项、推荐、显式确认和关闭门禁标记；要求模板含 `decision_status`、`confirmed_choice` 与 Confirmation。

- [ ] **Step 2: 写入状态迁移失败样本**

构造 `status: closed`、`interaction: HITL`、`decision_status: pending` 的 blocker，断言解析器拒绝继续选择 frontier；再把该票链接写入地图 Decisions，断言同样失败。

- [ ] **Step 3: 写入确认成功样本**

把 blocker 改为 `decision_status: confirmed` 并补齐 `confirmed_choice`、`confirmed_by`、`confirmed_at`，断言下游 ticket 成为 frontier。

- [ ] **Step 4: 写入兼容和 AFK 转交样本**

覆盖缺字段的 open/closed、AFK/HITL 四种旧票；覆盖“先创建 HITL 并进入 Frontier，再关闭 AFK”的顺序。

- [ ] **Step 5: 运行测试确认先失败**

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证Wayfinder行为.ps1`

Expected: FAIL，缺少交互合同或解析器没有拒绝未确认的 HITL 票。

## Chunk 2: 最小实现

### Task 2: 实现 HITL 决策协议

**Files:**
- Modify: `skills/wayfinder-workflow/SKILL.md`
- Modify: `assets/templates/frontier-ticket模板.md`
- Modify: `skills/wayfinder-workflow/scripts/解析Frontier指针.ps1`

- [ ] **Step 1: 在 skill 中定义统一对话顺序**

写明 Destination 和 HITL ticket 都是一轮一个问题、2 至 3 个互斥选项、推荐及理由、明确确认请求。

- [ ] **Step 2: 扩展 ticket 模板**

新增 `decision_status`、`confirmed_by`、`confirmed_at`，以及已知事实、选项、推荐、请确认和 Confirmation 区块。

- [ ] **Step 3: 加入解析门禁**

解析 `decision_status`；缺字段时按 interaction 兼容推断；拒绝关闭但未 confirmed 或确认审计不完整的 HITL ticket。校验地图 Decisions 引用的票据已关闭并满足同一确认门禁。

- [ ] **Step 4: 运行定向测试确认通过**

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证Wayfinder行为.ps1`

Expected: `Wayfinder behavior contract: PASS`

## Chunk 3: 用户体验与发布态

### Task 3: 补齐使用说明和验收样本

**Files:**
- Modify: `README.md`
- Modify: `docs/试运行/Wayfinder行为验收场景.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `scripts/验证Wayfinder最小版.ps1`

- [ ] **Step 1: 更新 README 调用体验**

说明用户可直接 `@wayfinder-workflow` 描述目标，系统会逐题给方案和推荐，确认后再关闭票据。

- [ ] **Step 2: 增加四类真实验收样本**

覆盖 Destination 澄清、grilling 取舍、prototype 验收、AFK 调研转 HITL。每个样本使用可解析格式，包含一个问题、2 至 3 个稳定选项 ID、推荐理由和确认请求。

- [ ] **Step 3: 更新插件 cachebuster 版本**

把版本提升到新的 `1.6.0+codex.<时间>`，并同步版本断言。

- [ ] **Step 4: 运行仓库验证**

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证Wayfinder最小版.ps1`

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证Wayfinder行为.ps1`

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证第一阶段工作流.ps1`

Expected: 全部 PASS。

- [ ] **Step 5: 同步个人插件源并重装缓存**

仅同步插件发布文件，排除 `.git`、`.agents`、`.claude`、`.idea`；执行 `codex plugin add asana-openspec-java-workflow@personal`。

- [ ] **Step 6: 验证发布态**

Run: `powershell -ExecutionPolicy Bypass -File scripts/验证插件发布态.ps1`

Expected: 源版本、插件列表版本和缓存版本一致。

提交不在本次授权范围内；保留工作区改动，等待用户明确要求后再提交。
