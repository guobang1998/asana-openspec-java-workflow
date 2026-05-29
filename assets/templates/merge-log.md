# merge-log.md

## 使用说明

本文件记录多 Agent worktree / patch 的合并顺序、冲突、验证和回滚信息。Leader 合并前后都要更新。

## 合并总表

| order | timestamp | task-id | source | method | status | conflicts | verification | rollback |
|---:|---|---|---|---|---|---|---|---|
| 1 |  |  | branch / worktree / patch | merge / rebase / cherry-pick / apply-patch | pending / merged / failed / reverted | yes / no | pending / passed / failed |  |

## 合并详情模板

### Merge 001 - task-id

基本信息：

| 字段 | 值 |
|---|---|
| task-id |  |
| source_branch |  |
| source_worktree |  |
| patch_path |  |
| method | merge / rebase / cherry-pick / apply-patch |
| started_at |  |
| finished_at |  |
| status | pending / merged / failed / reverted |

合并前检查：

- `dependencies.md` 中上游任务已 `accepted`：
- `worker-status.md` 无阻塞：
- `result-metadata.yaml` 状态可接受：
- `file_locks` 无未解决重叠：
- PR 范围无无关变更：

冲突记录：

| 文件 | 冲突来源 | 解决方式 | 决策记录 |
|---|---|---|---|
|  |  |  | decisions.md#D001 |

验证记录：

| 命令 | 结果 | 说明 |
|---|---|---|
| mvn clean compile | pending / passed / failed |  |
| mvn test | pending / passed / failed |  |

回滚方案：

- 

Leader 结论：

- 
