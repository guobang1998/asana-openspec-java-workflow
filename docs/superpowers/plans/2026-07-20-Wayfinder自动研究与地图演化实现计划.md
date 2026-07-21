# Wayfinder 自动研究与地图演化 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不增加 tracker 适配和通用 skill 的前提下，为 Wayfinder 增加 research 并行编排、地图生命周期门禁和名称优先展示。

**Architecture:** `SKILL.md` 定义编排行为，ticket YAML 的 `closure_kind` 保存关闭语义，现有 frontier 解析器校验地图章节与票据关系。研究子代理只产出独立 Markdown 资产，协调器串行修改共享状态。

**Tech Stack:** Markdown、YAML frontmatter、PowerShell、Codex plugin manifest。

---

## Chunk 1: 失败合同

### Task 1: 增加行为测试

**Files:**
- Modify: `scripts/验证Wayfinder行为.ps1`
- Modify: `scripts/验证Wayfinder最小版.ps1`
- Modify: `docs/试运行/Wayfinder行为验收场景.md`
- Create: `skills/wayfinder-workflow/scripts/管理Research认领.ps1`
- Create: `skills/wayfinder-workflow/scripts/发布Research资产.ps1`

- [x] 增加 research 并行、owner claim、失败释放、协调器串行落盘和无后台代理降级的静态合同。
- [x] 为 frontier 解析器增加 `ResearchBatch` 失败测试：多张 research 稳定返回，blocked/claimed/HITL/task 不返回，执行前后文件哈希不变。
- [x] 增加 Research claim 管理器竞争测试、部分写入失败测试、派发前 owner 校验和仅释放自身 owner 测试。
- [x] 增加 `closure_kind` 合法组合、地图章节唯一性和 fog 禁止 ticket 链接的失败样本。
- [x] 增加 out-of-scope/superseded 必须引用已确认来源决定、且不得进入 Decisions 的失败样本。
- [x] 增加普通 closed/pending HITL 失败，以及带合法来源、空确认字段的失效 HITL 成功样本。
- [x] 为 Frontier、Decisions、Out of scope、Ticket index 分别增加名称成功/失败样本，并覆盖空标题、重复 H1、裸 ID。
- [x] 运行 `powershell -ExecutionPolicy Bypass -File scripts/验证Wayfinder行为.ps1`，确认旧实现失败。

## Chunk 2: 最小实现

### Task 2: 扩展协议、模板和解析器

**Files:**
- Modify: `skills/wayfinder-workflow/SKILL.md`
- Modify: `assets/templates/frontier-ticket模板.md`
- Modify: `assets/templates/wayfinding-map模板.md`
- Modify: `skills/wayfinder-workflow/scripts/解析Frontier指针.ps1`
- Create: `skills/wayfinder-workflow/scripts/管理Research认领.ps1`
- Create: `skills/wayfinder-workflow/scripts/发布Research资产.ps1`

- [x] 在 skill 中改写“画图后停止”：只允许启动、等待和串行收口 research，禁止顺带处理其他票。
- [x] 在模板中增加 `closure_kind: pending`、`closure_source_ticket`，并把地图链接示例改为名称优先。
- [x] 为解析器增加只读 `ResearchBatch` 模式。
- [x] 实现 map 级 DeleteOnClose 原子锁，以及 `ClaimBatch/VerifyOwned/ReleaseOwned`。
- [x] 实现绑定 `ticket_id + owner` 的 Research 资产原子发布与同 owner 重试。
- [x] 解析 ticket 一级标题并返回 `title`。
- [x] 校验 `closure_kind`、来源决定、Decisions、Out of scope、Not yet specified 和名称链接；保留旧 closed HITL/AFK 安全兼容矩阵。
- [x] 重跑 Wayfinder 行为与最小版测试，确认通过。

## Chunk 3: 真实样本与发布态

### Task 3: 验收、版本和缓存

**Files:**
- Modify: `README.md`
- Modify: `docs/试运行/Wayfinder行为验收场景.md`
- Modify: `.codex-plugin/plugin.json`
- Modify: `scripts/验证第一阶段工作流.ps1`

- [x] 增加真实 research 并行和地图演化样本。
- [x] README 说明 research 自动处理、名称优先和无子代理降级体验。
- [x] 提升 cachebuster 版本并同步版本断言。
- [x] 运行 Wayfinder、第一阶段、发布态和 `git diff --check`。
- [x] 同步个人插件源、重装缓存，并在缓存目录重跑行为验证。

本次不提交、不推送；保留工作区既有改动。
