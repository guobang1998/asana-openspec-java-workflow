# manifest.md

## 基本信息

| 字段 | 值 |
|---|---|
| change_id |  |
| repo_name |  |
| created_at |  |
| leader | Codex App |
| mode | single-agent / multi-agent |
| user_confirmed_multi_agent | yes / no |
| user_confirmed_worker_plan | yes / no |

## 目标

- 

## 不做什么

- 

## 输入上下文

| 类型 | 路径或链接 | 说明 |
|---|---|---|
| PRD |  |  |
| RFC |  |  |
| OpenSpec |  |  |
| Asana |  |  |
| 其他 |  |  |

## Worker 分工

| task-id | role | worker | 目标 | 是否启用 |
|---|---|---|---|---|
| 001 | Discovery | Codex | 影响面和调用链分析 | yes |
| 002 | OpenSpec | Codex | 规格和任务拆分 | yes |
| 003 | Implementation | Codex | 模块 A 实现 | yes |
| 004 | Implementation | Codex | 模块 B 实现 | yes |
| 005 | Test | Codex | 测试补齐和回归 | yes |
| 006 | Review | Claude | 代码审查和风险挑战 | optional |

## 预算和限制

| 项 | 值 | 说明 |
|---|---:|---|
| max_workers | 5 | Codex worker 上限，不含可选 Claude Review |
| max_implementation_concurrency | 2 | Implementation worker 并发上限 |
| max_claude_reviews | 1 | 默认最终审查一次 |
| estimated_tokens | 50000 | 粗略预算 |
| max_rounds_per_worker | 2 | 超过后 Leader 重新拆任务 |

## 验证命令

| 类型 | 命令 | 是否必需 |
|---|---|---|
| build | mvn clean compile | yes |
| unit_test | mvn test | yes |
| integration_test |  | no |
| coverage |  | no |
| manual |  | no |

## 状态文件

| 文件 | 用途 |
|---|---|
| workflow-config.yaml | 全局配置、预算、状态枚举、worktree 命名规则 |
| dependencies.md | 任务依赖、数据流、文件锁 |
| worker-status.md | Worker 状态、进度、失败、预算 |
| decisions.md | Leader 决策记录 |
| merge-log.md | 合并顺序、冲突、验证结果 |
| 冲突解决决策记录.md | 冲突处理细节 |

## 风险

| 风险 | 等级 | 处理方式 |
|---|---|---|
|  | high / normal / low |  |

## 完成条件

- 所有必须任务状态为 `accepted`。
- `result-metadata.yaml` 的最终状态为 `accepted`；如果是 `failed` 或 `abandoned`，失败或放弃原因已记录。
- 构建和测试按本文件要求完成。
- Claude review 已归档，或明确记录未启用原因。
- 合并冲突和 Leader 决策已记录。
