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
- 先补测试基线，再改结构。
- 每个 phase 都能独立 Review、合并、回滚。
- 不做“顺手全仓库重写”。

## 阶段

```text
Asana Epic
-> Discovery
-> Refactor RFC
-> Characterization Tests
-> Phase Plan
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

## Refactor RFC

RFC 必须包含：

- 背景和问题。
- 目标。
- 不做什么。
- 当前架构。
- 目标架构。
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
- 影响面。
- 测试。
- 回滚。
- PR 范围。

## Phase 执行策略

- 开发可以并行，但必须明确依赖关系。
- 合并必须串行：phase-1 合并后才能合并 phase-2。
- 测试必须基于前一 phase 已合并后的最新基线。
- 不能用并行开发作为跳过 Review 或跳过测试的理由。

## Phase 完成标准

每个 phase 完成前必须满足：

- OpenSpec change 已完成并通过 Review。
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
- PR 描述必须链接 Asana Epic、RFC、OpenSpec change-id。
- PR 前跑 CodeGraph impact、Java Review、测试策略、Quality Gate。

## 输出格式

```text
结论：SMALL_CHANGE / LARGE_REFACTOR
原因：
Discovery 结果：
RFC 路径：
Phase 拆分：
第一阶段 OpenSpec change：
测试基线：
风险：
下一步：
```
