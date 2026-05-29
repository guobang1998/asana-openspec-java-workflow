# worker-status.md

## 使用说明

本文件记录多 Agent 重构执行进度。Leader 负责维护状态，worker 完成任务后可以建议状态变化，但不能自行把任务标为 `accepted`。

状态只允许使用：

```text
pending / ready / running / blocked / failed / retrying / done / accepted / abandoned
```

## Worker 状态表（核心信息）

| task-id | worker | role | status | progress | worktree | updated_at | current_blocker |
|---|---|---|---|---:|---|---|---|
| 001 |  | Discovery | pending | 0 |  |  |  |
| 002 |  | OpenSpec | pending | 0 |  |  |  |
| 003 |  | Implementation | pending | 0 |  |  |  |
| 004 |  | Implementation | pending | 0 |  |  |  |
| 005 |  | Test | pending | 0 |  |  |  |
| 006 | Claude | Review | pending | 0 |  |  |  |

## Worker 时间和资源

| task-id | started_at | timeout_at | branch | last_verification | next_action |
|---|---|---|---|---|---|
| 001 |  |  |  |  |  |
| 002 |  |  |  |  |  |
| 003 |  |  |  |  |  |
| 004 |  |  |  |  |  |
| 005 |  |  |  |  |  |
| 006 |  |  |  |  |  |

## 进度更新

更细的进度写入各任务目录下的 `task-log.jsonl`。这里仅保留汇总。

| 时间 | task-id | progress | message |
|---|---|---:|---|
|  |  |  |  |

## 失败和重试记录

| 时间 | task-id | 失败类型 | 失败原因 | 已重试次数 | Leader 决策 | 下一步 |
|---|---|---|---|---:|---|---|
|  |  | 工具失败 / 实现失败 / 方案失败 |  | 0 |  |  |

## 文件锁和并发组

`concurrency_group` 留空或 `null` 表示不受并发组限制，可以并行；填写名称表示与同组任务按 `workflow-config.yaml` 的 `max_parallel` 限流，`max_parallel: 1` 才是串行。

`file_locks` 支持通配符，但当前文件协议不会自动检测通配符重叠。Leader 必须手动判断，或使用后续辅助脚本检测。锁范围重叠时必须串行。

| task-id | concurrency_group | file_locks | 是否可并发 | 判断依据 |
|---|---|---|---|---|
|  |  |  | yes / no |  |

## 预算记录

| 项 | 预算 | 当前使用 | 是否超出 | 说明 |
|---|---:|---:|---|---|
| worker 数量 | 5 |  | no |  |
| Implementation Worker 并发数 | 2 |  | no |  |
| Claude 审查次数 | 1 |  | no |  |
| 失败重试轮次 | 2 |  | no |  |
