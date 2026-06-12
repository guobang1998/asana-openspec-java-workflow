---
name: large-refactor-workflow
description: Use when a request is a large refactor, architecture change, module rewrite, cross-module migration, technical debt cleanup, framework upgrade, API compatibility migration, or any change too large for a single OpenSpec change. Forces Discovery, RFC, characterization tests, phased OpenSpec changes, small PRs, compatibility, rollback, and cleanup.
---

# Large Refactor Workflow

大重构工作流。目标：把“大而乱”的重构拆成可评审、可测试、可回滚的小阶段。

## 触发条件

满足任一条件即视为大重构：

- 跨 3 个以上模块。
- 影响 Controller / Service / Mapper 多层。
- 改核心领域模型、核心表、核心接口。
- 需要迁移大量调用方。
- 需要删除旧架构或替换框架。
- 预计超过 2 天。
- 无法一个 PR 安全合并。
- 需求描述是“重构、治理、解耦、升级、统一、抽象、替换”。

## 总原则

- 不用一个巨大 OpenSpec change 承载全部重构。
- 先 Discovery，再 RFC，再拆 phase。
- 命中大重构条件后，不直接默认启用多 agent；必须先询问用户是否启用。
- 用户确认启用多 agent 后，必须再确认 worker 数量、角色、并发数和 Claude 是否参与。
- 先补测试基线，再改结构。
- 每个 phase 开始前先写实现前边界声明。
- 命中 A 类高风险链路时，必须填写高风险链路映射。
- 高风险复查按风险触发，Claude 只是可选承载方式。
- 每个 phase 都能独立 Review、合并、回滚。
- 不做“顺手全仓库重写”。
- 多 worker 不共用同一个主工作区直接改代码；Implementation Worker 使用独立 `git worktree`，或只输出 patch / result。
- Codex App Leader 负责最终合并、验证和 PR。

## 阶段

```text
Asana Epic
-> Discovery
-> Refactor RFC
-> Characterization Tests
-> Phase Plan
-> 实现前边界声明和分段审核判断
-> 是否启用多 agent 协作：询问用户
-> Worker 数量和分工：询问用户
-> 多个 OpenSpec changes
-> 小 PR 串行合并
-> 灰度/兼容/回滚
-> 删除旧代码
-> 复盘/archive
```

## Discovery

必须先用 `codegraph-context-guard`：

- 入口。
- 调用链。
- callers/callees。
- 影响文件。
- 影响接口。
- 影响表。
- 事务边界。
- 权限和安全点。
- 测试缺口。

输出：

```text
当前结构：
核心入口：
调用链：
影响面：
风险路径：
测试缺口：
可拆阶段：
```

## 多 Agent 启用确认

命中大重构条件后，Leader 必须先做评估，不直接创建 worker。

第一次确认：是否启用多 agent

```text
这个需求看起来是大重构。建议先 RFC + phase/tasks，再决定执行方式。

要启用多 agent 协作吗？

A. 启用：Codex Leader 拆任务，多 worker 分工，Claude 可选审查，适合降低大范围改造风险，但成本更高。
B. 不启用：单 Codex agent 分阶段推进，流程轻一些，但并行审查和隔离更弱。
```

第二次确认：worker 数量和分工

```text
多 agent 分工方案如下，请确认是否按这个启动：

1. Leader Codex：主控、拆任务、合并、总验证
2. Discovery Worker：CodeGraph impact / 调用链 / 影响面
3. OpenSpec Worker：proposal / design / tasks / specs
4. Implementation Worker A：模块 A 实现
5. Implementation Worker B：模块 B 实现
6. Test Worker：单测 / 集成 / 回归验证
7. Claude Reviewer：最终代码审查 / adversarial review（可选）

预计成本：
- Codex worker：
- Claude review：
- Implementation 并发：
- 预计轮次：
- 主要风险：

是否确认启动这个分工？
```

只有第二次也确认后，才创建 `.workflow-team/<change-id>/`、复制模板、创建 worktree 并分配 worker。

## Refactor RFC

RFC 必须包含：

- 背景和问题。
- 目标。
- 不做什么。
- 当前架构。
- 目标架构。
- 实现前边界声明。
- A 类高风险链路映射。
- 兼容策略。
- 数据迁移策略。
- 测试策略。
- 分阶段计划。
- 回滚方案。
- 风险和决策点。

模板见：

```text
assets/templates/重构RFC模板.md
```

## 测试基线

重构前必须先尽量补 characterization tests：

- 锁住旧行为。
- 覆盖核心路径。
- 覆盖高风险边界。
- 涉及 DB/事务时补集成测试或手动验证脚本。

没有测试基线时，不允许直接大改核心逻辑。

## Phase 拆分

推荐：

```text
phase-0-discovery
phase-1-add-new-abstraction-or-adapter
phase-2-migrate-callers
phase-3-switch-default
phase-4-remove-old-code
```

每个 phase 一个 OpenSpec change：

```text
openspec/changes/refactor-xxx-phase-1-add-adapter
openspec/changes/refactor-xxx-phase-2-migrate-callers
```

每个 phase 必须有：

- 独立目标。
- 明确不做什么。
- 实现前边界声明。
- 是否建议实现前复查。
- 影响面。
- 测试。
- 回滚。
- PR 范围。

## 分段审核与高风险复查

大重构默认执行分段审核基础判断，但不强制所有 phase 都高风险复查。

每个 phase 开始前：

- 写清只改哪些模块。
- 写清明确不改哪些模块。
- 写清复用哪些既有能力。
- 写清风险最高的 3 个点。
- 写清需要重点验证的测试类型。
- 判断风险等级：A 类 / B 类 / C 类。
- 命中 A 类时，填写高风险链路映射，并强建议实现前复查。
- 命中明显 B 类时，由负责人判断是否实现前复查。

每个 phase 结束后：

- 在 `PR评审清单.md` 填写分段审核基础判断。
- B 类、A 类或大重构补充实现路径、关键设计选择、CodeGraph impact、高风险链路回看和继续推进依据。
- 如果未触发高风险复查，写明原因、负责人和替代证据。
- 如果复查结论为阻断、输入材料不足、验证证据不足或范围漂移，不进入下一 phase。

## Phase 执行策略

- 开发可以并行，但必须明确依赖关系。
- 合并必须串行：phase-1 合并后才能合并 phase-2。
- 测试必须基于前一 phase 已合并后的最新基线。
- 不能用并行开发作为跳过 Review 或跳过测试的理由。
- 如果启用多 agent，任务依赖必须写入 `.workflow-team/<change-id>/dependencies.md`。
- Worker 状态必须写入 `.workflow-team/<change-id>/worker-status.md`。
- 每个 worker 任务目录必须包含 `task.md`、`task-metadata.yaml`、`task-log.jsonl`、`result.md`、`result-metadata.yaml`。
- `concurrency_group` 留空表示可并行；填写名称表示按 `workflow-config.yaml` 的 `max_parallel` 限流，`max_parallel: 1` 才是串行。
- `file_locks` 支持通配符；锁范围重叠时必须串行。当前是文件协议，不是自动锁服务；Leader 必须手动判断，或使用后续辅助脚本检测。

## 多 Agent 文件协议

启用多 agent 后，Leader 创建：

```text
.workflow-team/<change-id>/
  workflow-config.yaml
  manifest.md
  dependencies.md
  worker-status.md
  decisions.md
  merge-log.md
  冲突解决决策记录.md
  tasks/<task-id>/
    task.md
    task-metadata.yaml
    task-log.jsonl
    result.md
    result-metadata.yaml
```

模板来自：

```text
assets/templates/workflow-config.yaml
assets/templates/manifest.md
assets/templates/多Agent重构任务单.md
assets/templates/task-metadata.yaml
assets/templates/task-log.jsonl
assets/templates/result-metadata.yaml
assets/templates/dependencies.md
assets/templates/worker-status.md
assets/templates/decisions.md
assets/templates/merge-log.md
assets/templates/冲突解决决策记录.md
assets/templates/Claude代码审查任务单.md
```

Leader 必须维护：

- dependencies：任务依赖、数据流、契约、file locks。
- worker-status：状态、进度、失败、重试、预算。
- task-log：created / progress / state_change / escalation / verification 等事件。
- result-metadata：files_changed、lines_added、build_success、test_success、test_coverage、duration_seconds、token_usage、retry_count、escalated。

## Claude 审查

Claude 是可选 reviewer / critic / rescue，不是默认实现者。

- 团队成员需要额外安装 `cc-plugin-codex`，本 workflow 不打包该插件。
- 在 Codex 中可使用 `$cc:review`、`$cc:adversarial-review`、`$cc:status`、`$cc:result`。
- Leader 必须给 Claude 提供 `Claude代码审查任务单.md`，避免只做通用风格审查。
- 如果用户未确认 Claude 参与，Claude review 不作为必过门禁。
- Claude review 结果只作为审查输入，最终修改和合并仍由 Leader 决定。

## 失败、冲突和清理

- 工具失败可重试 1 次；仍失败则写入 `worker-status.md` 和 `task-log.jsonl`，由 Leader 决定降级或暂停。
- 编译、测试、方案失败不自动反复重试，必须由 Leader 决策。
- 任务超时后进入 `blocked` 或 `failed`，由 Leader 判断是否继续。
- 合并前检查 `file_locks`，确认没有两个未验收任务修改同一关键文件。
- 冲突必须记录到 `冲突解决决策记录.md`，包括冲突文件、冲突来源、决策依据、处理方式和补充测试。
- 失败 worktree 按 `workflow-config.yaml` 的 `rollback_strategy` 和 `worktree_retention` 处理。

## Phase 完成标准

每个 phase 完成前必须满足：

- OpenSpec change 已完成并通过 Review。
- 已填写分段审核基础判断。
- 命中 B 类、A 类或大重构时，已补充扩展字段或写明不触发原因。
- 命中 A 类高风险链路时，已填写高风险链路映射、当前控制方式和剩余风险。
- 回滚方案已文档化。
- 回滚方案已在测试环境验证，或写明无法验证原因。
- Feature flag 可快速切换，若适用。
- 数据迁移有反向 SQL，若适用。
- 测试策略已执行：单测 / 集成测试 / 手动验证。
- CodeGraph impact 已复查，或说明降级追踪方式。
- PR 只覆盖当前 phase 或 phase 内一个子任务。

## 兼容和回滚

优先考虑：

- adapter。
- facade。
- feature flag。
- 双读/双写，按需。
- 老接口保留一段时间。
- 新旧逻辑并行校验，按需。

禁止：

- 一次删除旧实现。
- 一次迁移全部调用方。
- 无回滚路径切换核心逻辑。

## PR 策略

- 小 PR。
- 每个 PR 只做一个 phase 或 phase 内一个子任务。
- 开发可并行，合并必须串行。
- 如果启用多 agent，所有必须任务必须为 `accepted`，无未处理 `blocked` / `failed`。
- 如果用户确认 Claude 参与，Claude review 阻塞项必须处理或记录拒绝理由。
- PR 描述必须链接 Asana Epic、RFC、OpenSpec change-id。
- PR 描述必须包含分段审核基础判断；B 类、A 类或大重构补充扩展字段。
- PR 前跑 CodeGraph impact、Java Review、测试策略、Quality Gate。

## 输出格式

```text
结论：SMALL_CHANGE / LARGE_REFACTOR
原因：
Discovery 结果：
RFC 路径：
Phase 拆分：
是否建议启用多 agent：
用户确认结果：
worker 分工方案：
第一阶段 OpenSpec change：
测试基线：
风险：
下一步：
```
