---
name: java-test-strategy
description: Use when adding, changing, reviewing, or preparing PRs for Java/Spring/MyBatis code. Decides required unit tests, integration tests, regression tests, manual verification, test commands, and PR test evidence.
---

# Java Test Strategy

Java 测试策略。目标：PR 前测试能对应需求验收标准，不用一句“已测试”糊过去。

## 使用时机

测试策略分两次使用：

1. Plan Review 阶段：先确定要写哪些单测、集成测试、手动验证和回滚验证。
2. 实现后：检查这些测试是否真的完成，并记录未覆盖项。

## 基本规则

- 行为变更必须有测试，或说明不能自动化原因。
- Bugfix 必须有回归测试，先复现 bug 再修。
- 生产问题、revert、重大漏检修复必须先确认复现方式；无法自动化复现时，必须写清手动复现和验证证据。
- 新增业务规则必须覆盖正常流、边界、异常流。
- 测试独立、可重复，不依赖隐藏数据库状态。
- 不能为了过构建删除或跳过测试。

## 按变更类型选测试

### Service 业务逻辑

优先：

- JUnit 5
- Mockito
- AssertJ

覆盖：

- 正常流程。
- 参数为空/非法。
- 状态不允许。
- 权限或归属不满足。
- 外部依赖失败。

### Controller / API

优先：

- `@WebMvcTest`
- MockMvc

覆盖：

- HTTP status。
- 入参校验。
- JSON 字段。
- 鉴权失败。
- 业务异常映射。

### Mapper / SQL

优先：

- 集成测试。
- 测试库 / Testcontainers / 项目现有 DB 测试方案。

覆盖：

- SQL 条件。
- 分页排序。
- 空结果。
- 唯一约束。
- update/delete 影响行数。

### 事务 / 幂等 / 并发

优先集成测试或可重复脚本验证：

- 事务回滚。
- 重复请求。
- 唯一索引冲突。
- MQ/定时任务重复执行。

### 配置 / 日志 / 文案

可以只做构建和手动验证，但必须说明：

- 改了什么配置。
- 如何验证生效。
- 是否影响环境变量或部署。

### 生产问题 / 复盘改进

生产问题、重大漏检或回归测试遗漏修复时，测试说明必须补充：

- 原问题如何复现，或为什么无法复现。
- 哪个测试覆盖了本次根因。
- 哪些同类场景仍未覆盖。
- 是否需要把测试策略改进项写入 `docs/improvements/工作流改进追踪.md`。
- 如果只能手动验证，必须给日志、SQL、截图或接口响应等证据。

## 允许只做手动验证的情况

可以，但必须写明原因：

- 第三方系统不可控。
- 老项目缺少测试框架，补自动化成本过大。
- 需要真实 UAT 数据。
- 需要人工审批或外部回调。

手动验证必须给：

- 环境。
- 步骤。
- 输入。
- 预期结果。
- 实际结果。
- 截图/日志/SQL 证据，若有。

## PR 测试说明模板

```md
## 测试

- 编译：
- 单元测试：
- 集成测试：
- 手动验证：
- 未覆盖项：
- 原因：
- 生产问题复现：
- 回归覆盖：
- 复盘改进项：
```

## 输出格式

```text
测试结论：PASS / NEED_TEST / MANUAL_ONLY / BLOCKED
Plan Review 测试策略：
必须新增测试：
建议新增测试：
可手动验证：
回滚验证：
测试命令：
未覆盖风险：
复盘改进项：
```
