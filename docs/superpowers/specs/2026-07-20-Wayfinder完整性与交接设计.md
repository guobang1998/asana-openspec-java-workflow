# Wayfinder 完整性与交接设计

## 目标

修复本地 Markdown Wayfinder 的三个剩余行为缺口：Frontier 可遗漏可执行票、非 active 地图仍可选票、Research 资产缺少来源与 ticket 上下文指针。

## 非目标

- 不新增 GitHub、GitLab、Asana 或其他 tracker 适配。
- 不引入 Research 临时 Git 分支。
- 不扩展 setup-workflow 的领域模型、ADR 或 triage 配置。
- 不改变 `setup-workflow > wayfinder-workflow > brainstorming` 的入口顺序。

## Frontier 完整性

`tickets/` 目录中的直接普通 Markdown 文件是票据全集；`Ticket index` 是 map 中对该全集的完整名称索引，`Frontier` 是当前可执行票据的有序指针。解析器扫描 `tickets/*.md`，要求每个合法 ticket 恰好在 Ticket index 出现一次，索引也不得引用目录外、子目录或不存在的文件。随后从全集计算 `open + unclaimed + unblocked` 集合；Frontier 可以自定义顺序。

Frontier 审计分类固定为：

- `missing`：属于 eligible，但未出现在 Frontier；失败。
- `unknown`：Frontier 链接未进入 Ticket index，或索引/Frontier 重复引用同一票；失败。
- `stale`：已进入 Ticket index 和 Frontier，但当前已关闭、已认领或受阻；允许并跳过，保留 claim 后串行重建兼容性。
- `eligible`：按 Frontier 现有顺序返回的当前可执行票。

普通选票和 ResearchBatch 在 missing/unknown 非空时失败，避免错误返回“没有下一票”。

## Map 生命周期与交接

map frontmatter 的 `status` 只允许：

- `active`：允许 FirstFrontier、ResearchBatch 和 claim。
- `ready_for_handoff`：全部 ticket 已关闭且 Not yet specified 没有有效 fog；禁止继续选票。
- `closed`：交接已被下游 PRD、OpenSpec、RFC 或最终决定消费；禁止继续选票。

有效 fog 的定义：忽略空行、单独的 `-`、以 `>` 开头的模板说明和完整 HTML 注释；其他非空内容均视为仍未澄清的 fog。

所有自动状态脚本统一使用 map 级 `.wayfinder-state.lock`：Research claim、资产发布和生命周期转换互斥。新增 `管理Wayfinder生命周期.ps1`：

- `PrepareHandoff`：锁内重新读取 map、tickets 和文件哈希，要求 active map、Ticket index 完整、全部票据 closed、fog 为空。先以临时文件发布带 `map_id` 的确定性 `交接.md`，再原子替换 map 为 `ready_for_handoff`，记录 `handoff_path`、`handoff_stage`、`ready_at`、`updated_at`，最后重读两文件验证终态。
- `Close`：要求 ready_for_handoff、交接文件存在、`HandoffTarget` 非空；把 map 更新为 closed，记录 `handoff_target`、`closed_at`、`updated_at`。

跨文件操作不宣称事务原子性，采用可恢复顺序：若进程在交接文件发布后、map 更新前中断，map 仍为 active；同参数重试可识别相同 `map_id` 的交接文件并覆盖修复。若 map 已为 ready_for_handoff 但交接文件丢失，普通解析失败，`PrepareHandoff` 允许按 map 记录的 stage 修复交接文件。生命周期脚本先准备临时文件，再做最终哈希校验并原子替换 map；共享锁保证合作脚本串行。普通文件 API 无法把哈希比较与替换合成 CAS，不遵守共享锁的人工编辑仍存在极窄的 hash-to-replace 竞争窗，因此人工编辑前后必须暂停生命周期操作并在冲突时合并。

生命周期重试矩阵：

- ready_for_handoff + 相同 HandoffStage：`PrepareHandoff` 校验或修复交接文件后幂等成功，返回 `retry: true`；不同 stage 失败。
- closed：`PrepareHandoff` 一律失败。
- closed + 相同 HandoffTarget：`Close` 终态复核后幂等成功，返回 `retry: true`；不同 target 失败。
- active：`Close` 失败；ready_for_handoff：首次 Close 成功并终态复核。

`HandoffStage` 只允许 `prd | openspec | rfc | done`。Destination 无法唯一判断下一阶段时，按现有决策对话协议询问用户一次，不猜测。

交接文件只复制 Destination 和 Decisions 的上下文指针，并列出 Research 资产链接；不复制 ticket 内的完整结论。

## Research 来源与资产指针

`发布Research资产.ps1` 新增必填 `Sources`，至少一条有效来源。精确语法为：绝对 `https://<host>/<path>` URL；`repo:<无前导斜杠且不含 .. 的仓库相对路径>`；`commit:<7 至 40 位十六进制提交号>`。拒绝空值、占位符、换行及其他 scheme；`repo:` 在 map repository 可解析为本地目录时还必须指向现存普通文件。skill 要求来源为官方文档、源代码、规格或一方 API。

资产正文由脚本生成唯一 `## Sources` 区域。资产发布后，脚本在同一 map 级锁内把相对链接写入对应 ticket 的唯一 `## Assets`：

```markdown
- [Research：<ticket title>](../research/<ticket-id>-研究.md)
```

同 owner 重试必须幂等：允许更新资产内容，但 ticket 指针只能存在一次。发布顺序固定为：锁内验证 owner 和 ticket 快照，发布/更新资产，原子更新 ticket Assets，最后重读资产与 ticket 验证终态。若只完成资产发布便中断，同 owner 重试识别资产 owner 并补写指针；若指针已存在但资产丢失，重试先恢复资产再确认原指针。脚本成功前不得关闭 research ticket。

当前 claim owner 是唯一写权限。已有资产属于旧 owner 时默认失败；新 owner 只有显式传入 `TakeoverOwner=<旧 owner>`，且 ticket 仍为 claimed、Resolution 为空、旧资产的 ticket_id 匹配时，才允许安全接管并覆盖。新资产记录 `previous_owner`，ticket 的同一路径指针保持不变。这样保留默认防覆盖，同时避免旧 owner 中断后形成永久孤儿资产。失去 claim、缺少 Sources、重复 Assets 章节或冲突链接全部失败。

## 验收

1. Ticket index 存在可执行票但 Frontier 遗漏时，FirstFrontier 和 ResearchBatch 均失败。
2. Frontier 自定义顺序仍保留；stale 指针不阻塞选择。
3. map status 为 ready_for_handoff 或 closed 时不能选票或 claim。
4. 存在 open/claimed ticket 或有效 fog 时不能 PrepareHandoff。
5. 全票关闭且 fog 为空时生成交接并进入 ready_for_handoff；Close 必须记录下游目标。
6. Research 缺来源不能发布；发布后资产包含 Sources，ticket Assets 恰好一个相对指针。
7. 同 owner 重试不重复指针，其他 owner 不能覆盖。
8. PrepareHandoff 和 Close 覆盖同参数幂等成功、不同参数失败，以及“交接文件已发布但 map 未更新”的恢复样本。
9. TakeoverOwner 覆盖当前 claim + 空 Resolution + 匹配旧 owner 的成功样本，以及 owner 不匹配、已有 Resolution、ticket_id 不匹配的拒绝样本。
10. Sources 覆盖 HTTPS、repo 相对路径、commit SHA 正例，以及 HTTP、路径穿越、短 SHA、换行和占位符反例。
11. 现有 HITL、地图演化、第一阶段和插件发布态验证不回归。
