# Wayfinder 自动研究与地图演化设计

## 目标

补齐与 Matt Wayfinder 当前体验最相关的三项能力：画图后自动并行消化可执行的 research 票、让地图对 fog/失效票/超范围票的演化可验证、让所有用户可见票据引用名称优先。

## 非目标

- 不新增 GitHub、GitLab、Asana tracker 适配。
- 不新增通用 research、prototype、grilling 或 domain-modeling skill。
- 不改变 `setup-workflow > wayfinder-workflow > brainstorming` 的入口优先级。
- 不放宽现有 HITL 显式确认门禁。

## Research 自动并行

画图完成并写好双向 blocking 后，协调器运行 frontier 解析器的只读 `ResearchBatch` 模式，按地图顺序返回全部 `open + unclaimed + unblocked + research/AFK` 票据；blocked、claimed、HITL 和其他类型不得返回。运行环境不支持后台子代理时，不执行 claim、不修改 ticket，保留在 Frontier 并停止。

运行环境支持时，必须调用同 skill 内的 `管理Research认领.ps1`。脚本用 map 级 `FileMode.CreateNew + FileOptions.DeleteOnClose` 锁串行化 ResearchBatch 选择和 YAML 写入；进程退出时锁由操作系统释放，不留下永久锁文件。它提供 `ClaimBatch`、`VerifyOwned`、`ReleaseOwned` 三种模式：

- `ClaimBatch` 在锁内重新选择并逐票写入包含协调会话标识的 owner；单票写入失败时记录失败并继续，返回实际成功列表。
- 派发每个子代理前必须调用 `VerifyOwned` 做最后 owner 校验；owner 已变化时不得派发。
- 子代理启动失败或中断时调用 `ReleaseOwned`；只有 claim 仍完全等于本协调器 owner、状态仍为 claimed 且没有 Resolution 时才释放，owner 已变化时拒绝释放。
- 两个协调器竞争时，后取得锁者重新选择，只能认领前一个协调器尚未认领的票。

每个研究子代理只负责一票，只返回研究结果和来源，不直接写工作区。协调器收到结果后串行写入独立资产：

```text
.workflow-maps/<map-id>/research/<ticket-id>-研究.md
```

协调器使用固定最终路径，但先写入带会话标识的临时资产；确认目标路径不存在或属于同一次重试后再发布。随后串行执行：校验证据、写 ticket Resolution、更新 `closure_kind`、关闭 ticket、更新 Decisions 和重建 Frontier。研究子代理不得直接编辑地图、ticket YAML 或其他研究资产，避免多个子代理同时写共享 Markdown。

这是“一次一票”的唯一例外：一次画图会话可以启动、等待并串行收口多张 research 票，但不能同时解决 prototype、grilling、task 或目标交付。research 收口完成后立即停止。研究产生用户取舍时，沿用现有 AFK 转 HITL 顺序，最终决定不能引用 research 票。

## 地图生命周期

ticket YAML 新增：

```yaml
closure_kind: pending
# pending | decision | fact | out_of_scope | superseded
closure_source_ticket:
```

规则：

- `open`、`claimed` 必须为 `pending`。
- 已确认 HITL 正常关闭为 `decision`。
- 不再需要用户取舍的 AFK 事实关闭为 `fact`。
- 已存在 ticket 被已确认的范围决策判定超出 Destination 时，先 claim，再关闭为 `out_of_scope`；`closure_source_ticket` 必须引用一张 closed/decision 且完成确认审计的 HITL 来源票。目标 HITL 保持 `decision_status: pending`，确认字段必须为空；这表示它没有被用户逐票确认，只是被另一张已确认范围决策关闭。目标票从 Frontier 移除，只能以“名称链接 + 原因”进入 `## Out of scope`，不能进入 Decisions。
- 已确认决策使尚未执行的 ticket 失效时，先 claim，再关闭为 `superseded`；`closure_source_ticket` 必须引用一张 closed/decision 且完成确认审计的 HITL 来源票。目标 HITL 同样保持 `decision_status: pending` 且确认字段为空。目标票从 Frontier 移除，不进入 Decisions 或 Out of scope；在 Resolution 记录替代来源。
- 票据已被其他会话 claim 时，不得直接判定 superseded 或 out_of_scope，必须暂停并合并并发结论。
- `## Decisions so far` 只允许引用 `decision` 或 `fact`。AFK `fact` 若阻塞任何 HITL，仍不能成为决定来源。
- 普通 `closed + HITL + pending` 继续拒绝；只有 `out_of_scope/superseded + 合法 closure_source_ticket + 当前非空 owner + 空确认字段` 这一组合允许关闭。
- `## Not yet specified` 不允许放 ticket 链接。fog 变得可精确表述时，先创建 ticket 和 blocking，再删除对应 fog 条目；信息只保留一份。
- 地图只能有一个 Destination、Decisions、Not yet specified 和 Out of scope 章节。

兼容旧地图：缺少 `closure_kind` 时，open/claimed 推断为 `pending`；closed HITL 只有在原有 `decision_status: confirmed`、确认字段和用户原始决定完整时才推断为 `decision`，否则继续报错；closed AFK 推断为 `fact`，但若它阻塞任何 HITL，仍不得写入 Decisions。`out_of_scope` 和 `superseded` 不做推断，必须显式记录且提供来源决定。

## 名称优先

ticket 的一级标题是用户可见规范名称。地图 Frontier、Decisions、Out of scope 和 Ticket index 的链接文本必须与一级标题完全一致；ticket ID 只保留在 YAML、文件名和机器输出字段中。frontier 解析器返回 `title`，模型叙述和确认时引用标题，不用裸 ID。

## 验收

1. skill 明确研究并行派发、原子 owner claim、失败释放、协调器串行落盘和无子代理降级规则。
2. frontier 解析器提供只读 `ResearchBatch` 模式；行为验证覆盖多张 research 稳定返回，blocked/claimed/HITL/task 不返回，且选择过程零状态修改。
3. Decisions、Out of scope、Not yet specified 的章节唯一性和允许内容由解析器校验。
4. `closure_kind` 与 status/interaction 不合法组合被拒绝；普通 closed/pending HITL 失败，只有确认字段为空且引用合法来源决定的 out-of-scope/superseded HITL 可关闭。
5. 双协调器竞争只产生一个 owner；部分 claim 失败只返回成功票；启动失败只释放自己的 claim，owner 变化时拒绝释放。
6. out-of-scope 与 superseded 票不能进入 Decisions；out-of-scope 条目必须包含原因。
7. Frontier、Decisions、Out of scope、Ticket index 分别覆盖名称链接成功和失败样本；空标题、重复一级标题、裸 ID 标签和标题不一致都被拒绝。selector 输出包含 `title`，模型叙述使用标题。
8. 现有 HITL 确认、AFK 转 HITL、第一阶段和插件发布态验证继续通过。

## 风险

- skill 只能指示运行环境派发子代理；`ResearchBatch` 只负责可执行选择，不伪装成已经派发。没有后台代理能力时必须诚实降级，不能声称自动研究已完成。
- Research 批量 claim 使用专用原子锁；普通 ticket 和地图正文写入仍无通用原子锁，因此子代理不写共享地图，协调器负责串行收口。
- `closure_kind` 是本地 Markdown 协议字段，不等同于未来 tracker 的标签设计。
