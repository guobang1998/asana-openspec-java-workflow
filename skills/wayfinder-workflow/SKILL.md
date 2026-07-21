---
name: wayfinder-workflow
description: Use when a goal spans more than one agent session, the route to a Java/Spring/MyBatis outcome is unclear, or several decisions and dependencies must be resolved before PRD, OpenSpec, or implementation can begin.
---

# Wayfinder Workflow

触发类型：user-invoked（用户显式建图或继续 map）/ model-invoked（`asana-openspec-delivery` 命中跨会话目标时）。Wayfinder 是前置找路层：找决策路径，不默认交付目标。

## 本地协议

没有 issue tracker 时，使用：

```text
.workflow-maps/<map-id>/
  地图.md
  tickets/
    <ticket-id>-<标题>.md
  research/
    <ticket-id>-研究.md
```

若目标是 Java 仓库，先加载 `docs/agents/代码规范地图.md`；缺失时，setup-workflow 的只读发现优先于 Wayfinder。只读发现属于前置条件，不计入“画 map / 解一票”的限制；代码规范地图仍待用户确认写入时，在 map Notes 标记“待确认”。

## 状态源

YAML frontmatter 是唯一状态源：ticket 的 `status`、`claim`、`claimed_at`、`closed_at`、`blocked_by`、`blocks`、`closure_kind`、`closure_source_ticket` 只能在 YAML 更新；正文 `## Claim` 和 `## Resolution` 只记录审计与结论，不得重复写状态、认领人或阻塞列表。map frontmatter 是地图生命周期状态源，只允许 `active | ready_for_handoff | closed`。地图 `## Frontier` 只保存可重建的有序 ticket 链接，不是第二个票据状态源。

<!-- frontier-pointers: links-only -->

## 画图

1. 先命名 `Destination`，明确这次找路最终要得到的决策、规格或变更边界。Destination 尚不能明确时，先按“决策对话协议”一次只问一个关键问题；用户显式确认后再把 Destination 写入地图。
2. 广度澄清：只找当前可明确的问题、首批可行动作和未知区域，不深挖某一票。
3. 基于 `assets/templates/wayfinding-map模板.md` 创建地图；基于 `frontier-ticket模板.md` 创建可精确表述、可在一个会话完成的票据。
4. 先建 ticket，再写 `Blocking`；在地图 `## Frontier` 按优先级写入候选 ticket 的名称链接。开放、未阻塞、未认领 ticket 才是 frontier，最终资格仍以 YAML 为准。
5. 一次会话只做一件事：画 map，或解决一个 ticket。唯一例外是画图结束后可按“Research 自动并行”启动、等待并串行收口当前可执行的 research 票；不得同时处理 prototype、grilling、task 或目标交付。

`tickets/` 的直接普通 Markdown 文件是票据全集；Ticket index 必须一一覆盖。Frontier 可以自定义优先级顺序，但遗漏任何 eligible 票、引用索引外票或重复票都会失败；已关闭、已认领、仍受阻的 stale 指针允许暂时保留并跳过。

<!-- frontier-integrity: directory-index-frontier -->

没有可明确的问题、且目标可在一个会话完成时，不建 map，转回 PRD/OpenSpec 或直接询问用户下一步。

## 票据类型

| 类型 | 交互 | 用途 |
|---|---|---|
| research | AFK | 阅读文档、代码或第三方资料，产出链接摘要。 |
| prototype | HITL | 提供粗糙产物供用户反馈。 |
| grilling | HITL | 一次一个问题澄清取舍；不得替用户回答。 |
| task | HITL 或 AFK | 完成解阻塞动作，不把目标交付伪装成 ticket。 |

## Research 自动并行

<!-- research-batch: parallel-background-then-serial-close -->

画图并完成双向 blocking 后，先运行 `scripts/解析Frontier指针.ps1 -MapPath <地图路径> -Mode ResearchBatch`。该只读模式按地图顺序返回全部 `open + unclaimed + unblocked + research/AFK`，不会返回 blocked、claimed、HITL 或其他类型。

没有后台子代理能力时，不调用认领脚本、不修改 ticket，保留 research 票在 Frontier 并停止。具备后台能力时：

1. 生成本协调会话唯一 owner，例如 `codex:<session-id>`。
2. 调用 `scripts/管理Research认领.ps1 -Operation ClaimBatch`。只派发返回的 `claimed`，单票失败不影响其他票。
3. 每次派发前调用 `VerifyOwned`；owner 已变化时跳过该票。
4. 每个子代理只研究一票，只返回结论和一手来源，不编辑工作区。来源只接受官方文档、源代码、规格或一方 API。
5. 协调器串行调用 `scripts/发布Research资产.ps1 -MapPath <地图路径> -TicketId <ticket-id> -Owner <owner> -Content <研究正文> -Sources <来源数组>`。脚本与 claim 管理器共用 `.wayfinder-state.lock`，在同一临界区重新验证当前 claim，以 `ticket_id + owner` 发布固定资产，并把唯一相对链接写回 ticket `## Assets`。同 owner 重试幂等；旧 owner 中断后，新 owner 只有显式传入 `TakeoverOwner` 且 Resolution 为空时才能接管。
6. 子代理启动失败或中断时调用 `ReleaseOwned`；它只能释放仍属于本 owner、保持 claimed 且没有 Resolution 的票。
7. research 全部收口后立即停止，不顺带解决其他 frontier 票。

<!-- research-claim: atomic-owner-verify-release -->
<!-- research-provenance: sources-and-ticket-pointer -->

## 决策对话协议

<!-- hitl-dialogue: one-question-options-recommendation-confirmation -->

Destination 澄清以及所有 HITL ticket 都按以下顺序与用户交互：

1. `已知事实`：只列与当前取舍直接相关、已有证据支持的事实。
2. `待决问题`：一轮只问一个问题，不把多个取舍塞进同一轮。
3. `选项`：给出 2 至 3 个互斥选项，使用稳定 ID `A`、`B`、`C`；确实只有两种时不凑第三项。
4. `推荐`：明确引用一个选项并说明理由和主要代价。推荐是建议，不等于用户授权。
5. `请确认`：要求用户回复选项 ID，或给出自定义、可执行的明确决定。

用户回复无法映射到某个选项或明确决定时，只追问当前问题，不进入下一票。`prototype` 展示产物后同样只问一个聚焦的验收问题；不得用“看起来没问题”代替用户确认。

<!-- hitl-close-gate: explicit-confirmation-required -->

HITL ticket 创建和认领时使用 `decision_status: pending`。收到用户显式确认后，依次写入 `confirmed_choice`、`confirmed_by`、`confirmed_at`，将 `decision_status` 改为 `confirmed`，并在 `## Confirmation` 保留用户原始决定。未完成这些步骤时，票据保持 `claimed`：不得写最终 Resolution、不得关闭、不得更新地图 `## Decisions so far`。

AFK ticket 使用 `decision_status: not_required`。调研结束后若仍需用户取舍，不得把推荐当决定；必须先创建或解阻塞一张 HITL ticket，在 AFK `blocks` 与 HITL `blocked_by` 中写入互为镜像的阻塞关系并加入 Frontier，运行 frontier 解析确认链路合法，再关闭 AFK ticket。承担 HITL 交接的 AFK ticket 不能作为地图 Decisions 的来源，最终决定必须引用已确认的 HITL ticket。

<!-- afk-to-hitl-order: create-frontier-validate-close -->

## 地图演化

<!-- map-evolution: decision-fact-out-of-scope-superseded -->

`closure_kind` 只允许 `pending | decision | fact | out_of_scope | superseded`：open/claimed 使用 pending；已确认 HITL 正常关闭使用 decision；无需用户取舍的 AFK 事实使用 fact。

fog 变得可精确表述时，先创建 ticket 和 blocking，再从 `## Not yet specified` 删除对应条目；该区不得保存 ticket 链接。已有 ticket 被已确认范围决策排除时，先 claim，再以 `out_of_scope` 关闭并通过 `closure_source_ticket` 引用来源决定，只在地图 Out of scope 以“名称链接 + 原因”记录。已有 ticket 被已确认决定替代时，以 `superseded` 关闭并引用来源决定，不进入 Decisions 或 Out of scope。

失效 HITL 保持 `decision_status: pending` 和空确认字段；只有 `out_of_scope/superseded + 已确认来源决定 + 当前 owner` 才允许关闭。普通 closed/pending HITL 仍失败。其他会话已经 claim 的票不得直接失效，先暂停合并并发结论。

<!-- ticket-display: title-first -->

ticket 正文必须且只能有一个非空一级标题，它是用户可见名称。Frontier、Decisions、Out of scope、Ticket index 以及所有叙述都使用名称；ID 只用于 YAML、文件路径和机器字段。旧票也不得用裸 ID 或缺失标题继续推进。

## 继续推进

1. 用户未指定 map 且存在多个 active map 时，先列出地图名称和 Destination，请用户选择；不得猜测或 claim。确定 map 后，只加载 `地图.md` 的低分辨率索引，并读取 `## Frontier` 中按顺序列出的 ticket 名称链接。
2. 用户未指定票时，优先运行本 skill 同级 `scripts/解析Frontier指针.ps1 -MapPath <地图路径>`；从已加载的 skill 目录解析脚本，绝不假定目标仓库存在 `scripts/`。它扫描 `tickets/*.md` 的 YAML frontmatter 以核对全集，只读取 Frontier、blocking、Decisions、Out of scope 所需正文，不加载无关票据的研究正文；先校验地图决策来源和 Frontier 完整性，再输出第一个可认领 ticket。脚本不可用时，fallback 必须扫描 `tickets/*.md` 全集并与 Ticket index、Frontier 对齐；仅当不存在 missing/unknown，且候选票 `status: open`、`claim: unclaimed`、所有 `blocked_by` ticket 已关闭时，才能 claim。

<!-- frontier-resource: bundled -->
<!-- frontier-read-scope: pointers-and-blockers -->

<!-- frontier-selection: ordered-pointer-then-ticket-yaml -->
3. 用票据名称向用户说明当前选择；ID 只保留在机器上下文。将 YAML 更新为 `status: claimed`、`claim: <执行者>`、`claimed_at: <时间>`，再在 `## Claim` 追加审计记录。并发会话发现已被认领时换下一张票。
4. 只解决这一张票。HITL 票按决策对话协议等待用户显式确认；AFK 票可自行调研或完成解阻塞动作。
5. HITL 票先完成确认字段和 `## Confirmation`，再将结论写到 `## Resolution`，以 `closure_kind: decision` 关闭；AFK 票直接写事实结论，以 `closure_kind: fact` 关闭。随后更新 `closed_at`，在地图 `## Decisions so far` 以名称链接追加一句指针；每项必须且只能包含一个来源 ticket 链接，不允许自由文本决定或重复 Decisions 章节。再只读取 Ticket index 的 YAML 重建 `## Frontier` 名称链接顺序：移除已关闭或已认领票，加入新近解阻塞的 open/unclaimed 票。运行 frontier 解析器校验 Decisions 来源和新 Frontier；失败时不得继续推进。
6. 新发现的问题：能精确表述则新建 ticket；尚不能精确表述则放入 `## Not yet specified`；超出 Destination 则写入 `## Out of scope`。

## 完成与交接

<!-- map-lifecycle: active-ready-closed -->

当 Ticket index 中所有票都已关闭，且 `## Not yet specified` 只剩空行、`-`、模板引用说明或 HTML 注释时，运行 `scripts/管理Wayfinder生命周期.ps1 -Operation PrepareHandoff -HandoffStage <prd|openspec|rfc|done>`。Destination 无法唯一决定下一阶段时，按决策对话协议只问一次，不猜测。

脚本生成只含 Destination、Decision pointers 和 Research assets 的 `交接.md`，并把 map 改为 `ready_for_handoff`；此后不得继续选票。下游 PRD/OpenSpec/RFC 或最终决定实际接收后，运行 `-Operation Close -HandoffTarget <真实目标>` 关闭 map。同 stage/target 重试幂等，不同值失败。

Research claim、资产发布和地图生命周期脚本共用 map 级 `.wayfinder-state.lock`。生命周期更新先准备临时文件，再做最终哈希校验并原子替换；共享锁可保证合作脚本串行，但无法对不遵守锁的编辑器提供文件系统级 CAS。普通 ticket 与地图正文的人工写入仍没有多文件事务；人工编辑前后应暂停自动生命周期操作，发现冲突时人工合并，不得假定成功。

## 边界

- Map 是索引，细节只写在 ticket 或关联资产中。
- Frontier ticket 服务 OpenSpec `tasks.md`，不替代它；业务合同仍是 PRD，行为变更仍是 OpenSpec。
- ticket 默认只产出决策。用户明确允许执行时，Notes 必须写明执行边界，并继续经过 `coding-discipline`、Java/SQL/DB/安全和 PR Gate。
- 不把未明确的 fog 预切成伪精确 ticket；不把 out of scope 当作未明确事项。
- 旧地图缺少 `decision_status` 时，AFK 按 `not_required`、HITL 按 `pending` 读取。旧的 closed HITL 必须补录真实确认字段，或重新打开向用户确认；系统不得伪造历史确认。
- 旧地图缺少 `closure_kind` 时：open/claimed 推断 pending；通过原确认门禁的 closed HITL 推断 decision；closed AFK 推断 fact，但承担 HITL 交接的 AFK 仍不能进入 Decisions。
