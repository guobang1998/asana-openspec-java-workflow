# Claude 代码审查任务单

## 使用场景

本任务单用于让 Claude Code 在 Codex App 工作流中做代码审查、adversarial review、测试缺口检查和风险挑战。Leader Codex 负责填写业务上下文、审查范围和重点风险，再通过 `cc-plugin-codex` 在 Codex 中发起 Claude 审查。

## 推荐命令

常规审查：

```text
$cc:review
```

风险挑战式审查：

```text
$cc:adversarial-review
```

后台任务状态和结果：

```text
$cc:status
$cc:result <job-id>
```

## 审查任务

请审查本次变更，并只输出可执行、可验证的问题。不要因为个人风格偏好提出非阻塞建议。

## 业务背景

- Asana：
- PRD：
- OpenSpec change：
- 需求目标：
- 不做什么：
- 验收标准：

## 审查范围

- 对比基线：
- 重点文件：
- 重点接口：
- 重点 Controller：
- 重点 Service：
- 重点 Mapper / SQL：
- DB / 事务 / 权限边界：

## 请重点检查

1. 是否偏离 PRD / OpenSpec。
2. 是否破坏旧验收标准或历史兼容行为。
3. 是否存在权限绕过、鉴权遗漏、敏感信息泄露。
4. 是否存在事务边界、并发、幂等、空值处理风险。
5. SQL 条件、分页、排序、更新影响行数是否正确。
6. 异常处理和错误响应是否符合项目风格。
7. 测试是否覆盖主流程、异常流、边界条件和回归路径。
8. 是否有无关重构、范围膨胀或未要求功能。
9. PR 是否可以合并，阻塞项有哪些。

## 输出格式

```md
# Claude 审查结果

## 结论

PASS / BLOCKED / CONDITIONAL

## 阻塞问题

- [P0/P1] 文件/方法：
  - 问题：
  - 风险：
  - 建议修复：

## 非阻塞建议

- [P2/P3] 文件/方法：
  - 建议：

## 测试缺口

- 缺口：
- 建议补充：

## 需要 Leader 决策

- 决策点：
- 可选方案：
```

## 边界

- Claude 默认只读审查，不直接修改主工作区。
- Claude 结论是审查输入，不替代 Leader Codex 的最终合并判断。
- 涉及 DB、权限、安全、核心事务边界的问题，必须由 Leader Codex 收口确认。
- 如果审查范围或业务上下文不足，先要求补充 PRD、OpenSpec、diff/base 或重点文件，不要猜测业务意图。
