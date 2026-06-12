---
name: pr-quality-gate
description: Use before opening or merging a PR for a Java/Spring/MyBatis requirement delivered through Asana and OpenSpec. Checks build, tests, OpenSpec tasks, PR description, review readiness, risk, rollback, and documentation sync.
---

# PR Quality Gate

PR 前门禁。目标：合并前把“能不能交付”说清楚。

## 必查项

### 需求链路

- Asana 任务存在且状态正确。
- PRD 已确认。
- OpenSpec change-id 已记录。
- 已检查相关既有 specs、active changes、历史 PRD/Asana，且 `design.md` 写明关系。
- 没有未说明的旧验收标准破坏；如有破坏，已记录迁移、回滚和确认。
- `tasks.md` 已完成或明确剩余项。
- 偏差已回写 PRD/OpenSpec。
- 每个代码改动都能对应 PRD、OpenSpec 或 `tasks.md`。
- 没有未要求的功能、无关重构或过度抽象。
- 项目有 `.codegraph/` 时，已完成 CodeGraph impact 复查。
- 涉及 Java/Spring/MyBatis 行为变更时，AI 必须主动检查 CodeGraph 索引状态；缺少 CodeGraph impact 证据时不能给 PASS。

### 验证

- 编译通过。
- 单测通过。
- 关键集成测试通过，或写明无法自动化原因。
- 验收标准逐条对应验证结果。
- 新增/修改 SQL 有验证方式。

### Review

- 已跑 Java 后端评审。
- 审查后如果用户说“下一步 / 开始 PR / 生成 PR 描述 / 没问题了”，自动进入本 PR Quality Gate，不要求用户记住提示词。
- 已按 `asana-openspec-java-workflow:coding-discipline` 检查修改范围和验证证据。
- 已按 `java-coding-standard` 检查编码规范。
- 已按 `springboot-service-patterns` 检查服务结构。
- 涉及安全敏感点时，已跑 `springboot-security-review`。
- 已按 `java-test-strategy` 检查测试覆盖和 PR 测试说明。
- 涉及 MySQL 时，已跑 `mysql-db-guard`。
- 已检查权限、安全、日志、事务、幂等。
- 涉及写 SQL 时，已记录影响行数、确认记录和回滚方案。
- P0/P1 问题已修复。
- P2 问题有处理决定。
- 如本 PR 来自生产问题、重大漏检、回归测试遗漏或 revert，已生成或计划生成流程复盘记录。
- 如本 PR 暴露可预防问题，已在 `docs/improvements/工作流改进追踪.md` 记录 IMP 改进项，或说明不记录原因。

### PR 描述

PR 描述必须包含：

```md
## 需求来源
Asana:
OpenSpec change-id:

## 变更内容

## 验证结果

构建:
单测:
集成测试:
手动验证:
未覆盖项:
安全检查:
CodeGraph impact:

## 预期风险

并发风险:
事务一致性风险:
数据兼容风险:
配置差异风险:
第三方依赖风险:
性能风险:
未覆盖风险:

## 上线观察

需要观察的接口:
需要观察的日志:
需要观察的错误码:
需要观察的数据一致性点:
建议观察时长:

## 回滚方案

## 数据库确认
是否涉及 MySQL:
SQL 类型:
影响行数:
是否已确认:

## 反馈闭环
是否触发复盘:
复盘文件:
改进追踪 IMP:
是否建议升级中央 workflow:

## Review 关注点
```

## 输出

给出结论：

```text
PASS：可以开 PR/合并
BLOCKED：必须修复后再 PR
CONDITIONAL：可 PR，但需在描述里标明风险
```

判定规则：

- 有 Java/Spring/MyBatis 行为变更，且项目有 `.codegraph/`，但未完成 CodeGraph impact：`BLOCKED`。
- CodeGraph 暂不可用但已手动追踪影响面、风险可控：最多 `CONDITIONAL`，PR 描述必须写明降级原因和未确认风险。
- 有行为变更但未列出预期风险、未覆盖风险和上线观察：最多 `CONDITIONAL`，重大风险缺失时 `BLOCKED`。
- P0/P1 生产问题、revert、重大漏检或回归测试遗漏未生成复盘计划：最多 `CONDITIONAL`；如果缺少根因和修复验证，`BLOCKED`。
- 已确认可预防问题但没有记录 IMP 改进项，也未说明不记录原因：最多 `CONDITIONAL`。
- 只有纯文档、注释、格式化、非代码资源改动时，可以不要求 CodeGraph impact，但要说明原因。

不要只说“看起来可以”。必须列出验证证据或缺口。
