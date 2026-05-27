---
name: asana-openspec-delivery
description: Use when driving a requirement through the team's Asana + OpenSpec + Codex workflow: Asana intake, PRD, OpenSpec change, plan review, Java implementation, verification, human review, PR, and OpenSpec archive.
---

# Asana OpenSpec Delivery

主交付流程。目标：让每条需求都有来源、PRD、OpenSpec 变更记录、实现计划、验证证据和 PR 交付记录。

## 阶段

```text
Asana 新需求
-> 需求澄清
-> PRD Review
-> OpenSpec Planning
-> 开发中
-> 测试迭代
-> 人工 Review
-> 待 PR
-> 合并
-> OpenSpec archive
```

## 执行流程

1. 读取 Asana 需求，确认标题、背景、目标、验收人、优先级、影响面。
2. 需求不完整时，调用 `prd-writer` 先补 PRD。
3. 需求确认后，创建或要求创建 OpenSpec change。
4. 如果项目存在 `.codegraph/`，调用 `codegraph-context-guard` 定位入口、调用链和影响面。
5. 检查 OpenSpec 文件：
   - `proposal.md`
   - `design.md`
   - `tasks.md`
   - `specs/`
6. 实现前调用 `coding-discipline`，确认假设、范围、不做内容、验证方式。
7. 实现前做 Plan Review，确认任务拆分、风险、测试路径。
8. 实现时按 `java-coding-standard` 和 `springboot-service-patterns` 推进。
9. 涉及接口、权限、输入、密钥、敏感数据时，调用 `springboot-security-review`。
10. 构建失败时调用 `java-build-fix`，只做最小修复。
11. 发现需求偏差时，先更新 PRD/OpenSpec，再改代码。
12. 实现后调用 `java-test-strategy`，确认单测、集成测试、手动验证要求。
13. 实现后调用 `codegraph-context-guard` 复查 impact，再调用 `java-backend-review`、`mysql-db-guard` 和 `pr-quality-gate`。
14. PR 描述必须包含 Asana 链接、OpenSpec change-id、测试结果、风险说明。
15. 合并后执行 OpenSpec verify/archive，并更新 Asana 状态。

## 决策规则

- Asana 是需求入口，不承载完整实现细节。
- PRD 是业务合同，OpenSpec 是变更账本。
- OpenSpec 不清楚时，不进入实现。
- Review 不满意时，按问题类型回退：
  - 业务理解错：回 PRD。
  - 方案设计错：回 OpenSpec design。
  - 实现 bug：回开发中。
  - 测试不足：回 PR quality gate。

## 推荐 OpenSpec 命令

```text
/opsx:new <change-id>
/opsx:continue
/opsx:ff
/opsx:apply
/opsx:verify
/opsx:archive
```

## 完成标准

- Asana 状态已更新。
- PRD 已确认。
- OpenSpec change 已 verify/archive。
- PR 已合并或给出阻塞原因。
- 测试、Review、风险记录完整。
- 涉及 MySQL 时，已记录 SQL、影响行数、确认结果和回滚方案。
- 每个代码改动都能对应 PRD、OpenSpec 或 `tasks.md`。
- 涉及安全敏感点时，已完成 Spring Boot Security Review。
- 项目有 `.codegraph/` 时，已给出入口、调用链、影响面和 impact 复查结果。
- 行为变更已有单测/集成测试，或明确说明只能手动验证的原因和证据。
