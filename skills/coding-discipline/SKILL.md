---
name: coding-discipline
description: Use before writing, modifying, refactoring, or reviewing code in this Asana + OpenSpec + Java workflow. Applies Karpathy-style AI coding discipline: do not guess, keep changes surgical, avoid overengineering, tie every edit to PRD/OpenSpec/tasks, and define verification before claiming completion.
---

# Coding Discipline

AI 写代码纪律。它是上层行为规范，不替代 Java 编码规范。Java 具体风格仍按 repo 本地规则、Google Java Style、阿里 Java 开发手册和 `java-backend-review` 执行。

## 优先级

1. repo 本地规则：`AGENTS.md`、formatter、Checkstyle、Spotless、CI。
2. 需求合同：Asana、PRD、OpenSpec、`tasks.md`。
3. 本 skill：少猜、小改、简单、可验证。
4. Java 专项规范：`java-backend-review`。
5. PR 门禁：`pr-quality-gate`。

## 写代码前

必须先确认：

- 需求是否清楚。
- 改动是否能对应 PRD / OpenSpec / `tasks.md`。
- 是否存在多个解释。
- 是否需要 DB、权限、日志、配置、事务、测试变更。
- 验证方式是什么。

需求不清楚时：

- 不写代码。
- 先补 PRD 的 `待确认问题`。
- 或回 Asana 评论提问。

## 实现纪律

- 不做未要求的功能。
- 不做“未来可能有用”的抽象。
- 不重构无关文件。
- 不顺手改格式、注释、命名，除非和当前需求直接相关。
- 优先最小可行修改。
- 每个改动都能追溯到 PRD、OpenSpec 或 `tasks.md`。
- 发现旧代码问题但不影响当前需求时，只记录，不擅自修改。

## 复杂度控制

出现这些信号时要收敛：

- 一个简单需求写出很多新类。
- 单次改动跨太多模块。
- 为一个调用点抽象出框架。
- 加了配置项但没人需要配置。
- 为不可能出现的分支写大量防御代码。

处理方式：

- 回到 OpenSpec tasks。
- 拆小变更。
- 删除多余抽象。
- 保留必要测试。

## 验证纪律

完成前必须给证据：

- 编译结果。
- 单测/集成测试结果。
- 手动验证步骤。
- SQL/DDL 风险和回滚。
- 未验证项和原因。

不能只说“已完成”或“看起来没问题”。

## 输出格式

实现前：

```text
假设：
范围：
不做：
验证：
风险：
```

实现后：

```text
完成：
验证：
未验证：
风险：
下一步：
```
