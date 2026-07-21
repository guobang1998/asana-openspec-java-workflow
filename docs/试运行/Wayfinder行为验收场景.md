# Wayfinder 行为验收场景

> 每次修改 `wayfinder-workflow` 后，使用独立 agent 逐条试跑。记录实际输出，不用“已通过”代替证据。

## 场景 1：跨会话模糊目标只画图

<!-- scenario-id: cross-session-map -->

**输入：** “治理订单模块，先参考现有 workflow 规划。”

**期望：** 先做 setup 只读发现；随后只创建 map、Destination、Not yet specified、Out of scope、首批 frontier ticket 和 blocking。不得实现代码或解决第一张票。

**证据：** map 路径、ticket 链接、未产生业务代码改动。

## 场景 2：小 bugfix 不建 map

<!-- scenario-id: small-bugfix -->

**输入：** “修复订单详情空地址导致 NPE，并补回归测试。”

**期望：** 不创建 `.workflow-maps/`；按既有 bugfix、PRD/OpenSpec、测试流程推进。

**证据：** 路由结论、测试 seam、没有 map 文件。

## 场景 3：Mapper/SQL 查询优化

<!-- scenario-id: mapper-sql -->

**输入：** “订单列表按售后状态筛选很慢，先定位 Mapper/SQL 并给出索引、分页和 `EXPLAIN` 验证方案。”

**期望：** 不创建 `.workflow-maps/`；先进入 `sql-performance-review` 专项模式和 MySQL 安全边界。输出查询路径、索引假设、分页/排序约束及验证命令，不直接执行生产 SQL；确认要修改 Mapper 或索引后，才回到 PRD/OpenSpec。

**证据：** 路由结论、目标 Mapper/SQL 影响面、性能审查清单、没有 map 文件。

## 场景 4：中等复杂需求拆切片

<!-- scenario-id: medium-slicing -->

**输入：** “为商户订单列表补售后状态筛选、导出权限和审计记录；先拆出安全推进路径。”

**期望：** 先做 setup 前置（缺地图时），再只创建 map 和首批 frontier ticket；每张票含单值 `type`、`interaction`、Current slice、Out of scope、Inputs、Outputs、Acceptance、Rollback or abandon 与 blocking。当前会话不实现业务代码。

**证据：** map 的 `## Frontier` 为有序 ticket 链接；`解析Frontier指针.ps1` 返回第一个可认领 ticket；无业务代码改动。

## 执行证据要求

## 决策对话真实样本

以下样本使用固定格式供自动化检查；每个样本只包含一个待决问题。选项 ID 稳定，语义互斥由规格审查确认。

### Destination 澄清

<!-- dialogue-sample: destination -->
- 已知事实: 目标跨多个会话，但交付终点尚未冻结。
- Q1: 这张地图最终应冻结哪类结果？
- A: 冻结可进入 PRD 的业务边界。
- B: 冻结可进入 OpenSpec 的技术变更边界。
- C: 只形成调研结论，不进入交付。
- 推荐: A - 先稳定业务边界，能减少后续规格返工。
- 请确认: 回复 A、B、C，或给出一个明确的自定义 Destination。
<!-- dialogue-sample-end -->

### Grilling 取舍

<!-- dialogue-sample: grilling -->
- 已知事实: 当前接口可同步返回，也可转异步任务。
- Q1: 用户提交后采用哪种完成语义？
- A: 同步完成并直接返回结果。
- B: 异步受理并返回任务 ID。
- 推荐: B - 长耗时场景更稳定，但前端需要轮询或订阅状态。
- 请确认: 回复 A 或 B；未确认前保持 ticket claimed。
<!-- dialogue-sample-end -->

### Prototype 验收

<!-- dialogue-sample: prototype -->
- 已知事实: 原型已经覆盖主路径和空状态，尚未冻结列表密度。
- Q1: 列表默认采用哪种信息密度？
- A: 紧凑表格，优先扫描效率。
- B: 标准表格，平衡信息与留白。
- C: 宽松列表，优先单项可读性。
- 推荐: A - 这是高频运营界面，扫描和批量操作更重要。
- 请确认: 回复 A、B、C，或指出需要调整的具体密度规则。
<!-- dialogue-sample-end -->

### AFK 调研转 HITL

<!-- dialogue-sample: afk-handoff -->
- 已知事实: 调研已排除原地升级，但蓝绿和滚动迁移都可行；HITL 票已先写入 Frontier。
- Q1: 生产迁移采用哪种发布策略？
- A: 蓝绿迁移，资源成本更高但回退更直接。
- B: 滚动迁移，资源成本更低但兼容窗口更长。
- 推荐: A - 当前变更涉及合同切换，快速回退价值更高。
- 请确认: 回复 A 或 B；确认后才能关闭 HITL 并写入地图 Decisions。
<!-- dialogue-sample-end -->

<!-- evidence: trigger-accuracy -->
<!-- evidence: gate-preservation -->

每个场景必须记录：触发准确、是否减少重复确认、保留原有门禁、实际输入、实际路由结论、涉及文件和验证命令。未经独立 agent 或可执行脚本验证的结果标为“待验证”，不得写“通过”。

## 2026-07-10 试运行记录

- 历史场景 1、2 的路由记录仍可参考；旧场景 3、4 不再满足 AC-10 的样本类型，归档为历史证据。

## 2026-07-10 复跑记录

| 场景 | 触发准确 | 是否减少重复确认 | 原有门禁 | 结论与证据 |
|---|---|---|---|---|
| 1 跨会话模糊目标 | 是。先检查目标仓库代码规范地图，缺失时只读 setup，随后 Wayfinder。 | 是。未要求用户先选 PRD、RFC 或大重构 skill。 | 保留。未确认 PRD/OpenSpec 前不实现，画图后停止。 | 通过。独立 agent `019f4b62-ab20-7f30-97e7-d3028efda2f0` 只读仿真确认只创建 map/首批票据，不 claim 或解决票据。 |
| 2 小 bugfix | 是。不建 map。 | 是。直接进入既有 bugfix/TDD/OpenSpec 门槛。 | 保留。`coding-discipline`、测试策略、CodeGraph（按条件）、Review/PR Gate 仍生效。 | 通过。独立 agent `019f4b62-bf16-7350-8d65-fe94eb31d519` 确认不误触发 Wayfinder。 |
| 3 Mapper/SQL 查询优化 | 是。不建 map，进入 SQL 专项模式。 | 是。只收集 SQL、索引、分页和 `EXPLAIN` 证据，不扩成完整需求交付。 | 保留。`sql-performance-review` 必经；实际 `SHOW INDEX`/`EXPLAIN` 或 DDL 再按 MySQL 分级门禁。 | 通过。独立 agent `019f4b62-d7f2-7170-a169-4464bf6c7d42` 确认改 Mapper/索引后才回到 PRD/OpenSpec。 |
| 4 中等复杂需求拆切片 | 是。先确定目标仓库；缺规范地图则 setup，随后 Wayfinder 只画 map。 | 是。用户不必先决定如何拆 OpenSpec 或第一张票。 | 保留。本会话不实现；PRD/OpenSpec 在决策清楚后才进入。 | 通过。独立 agent `019f4b62-eca6-7d82-ba08-2569162d26e0` 确认第一张票按 `## Frontier` 指针和 YAML 资格选择；实际状态迁移由脚本验证。 |

### 自动化证据

- `scripts/验证Wayfinder行为.ps1`：通过。临时 map 中先选择 `ticket-a`；关闭 `ticket-a` 后，`ticket-b` 解阻塞并成为下一张 frontier。
- `scripts/验证Wayfinder最小版.ps1`：通过。
- `scripts/验证第一阶段工作流.ps1`：通过。

### 缺陷清单

- 本轮未发现新的阻断缺陷。
- 残余限制：本地 Markdown 没有原子锁；并发 claim 仍必须重读 YAML，并在冲突时人工合并，详见 `wayfinder-workflow` 的并发规则。

## 2026-07-20 决策对话升级记录

### 回放清单

| 检查项 | 结果 | 证据 |
|---|---|---|
| 每轮只问一个问题 | 通过 | 四个 `dialogue-sample` 均由脚本验证恰好一个 `Q1`。 |
| 2 至 3 个选项和推荐 | 通过 | 脚本验证选项数量、稳定 ID，以及推荐引用已有选项。 |
| 未确认不能关闭 HITL | 通过 | legacy closed HITL 和确认审计不完整样本均被 frontier 解析器拒绝。 |
| 未确认不能写地图 Decisions | 通过 | claimed/pending HITL 写入 Decisions 的样本被拒绝。 |
| AFK 调研转 HITL | 通过 | HITL 决策票先进入 Frontier，再允许关闭 AFK 调研票。 |
| 旧地图兼容 | 通过 | 缺新字段的 open/closed AFK 与 open/closed HITL 四种路径均有行为样本；旧 closed HITL 不伪造确认。 |

### 缺陷清单

- 已修复：YAML 空字段后的 `\s*` 会跨行读取下一字段，可能把空 `confirmed_by` 误判为有值；现已限定为横向空白。
- 已修复：带 YAML 行尾注释的空引号、重复 YAML 键、缺少用户原始决定都可绕过确认审计；现已规范化标量并逐项拒绝。
- 已修复：自由文本 Decisions、重复 Decisions 章节和无来源票据决定可绕过地图门禁；现已要求每项恰好引用一张来源票。
- 已修复：AFK 转 HITL 只写单向 `blocked_by` 也能推进；现已要求 `blocked_by` 与 `blocks` 互为镜像，并禁止 AFK 交接票成为 Decisions 来源。
- 未解决：本地 Markdown 仍没有原子锁；确认前和 claim 前必须重读 YAML。

### 自动化证据

- RED：新增合同后，旧实现缺少 13 项对话、模板、样本和状态门禁，验证按预期失败。
- GREEN：`scripts/验证Wayfinder行为.ps1`、`scripts/验证Wayfinder最小版.ps1`、`scripts/验证第一阶段工作流.ps1` 全部通过。
- 独立审查：首轮发现 Decisions 与确认审计绕过，二轮发现行尾注释和 AFK 双向阻塞缺口；修复后最终窄范围复审为 `Approved`。
- 上一阶段发布态：cachebuster 版本为 `1.6.0+codex.202607201428`；当前版本见文末自动研究与地图演化升级记录。

## 2026-07-20 自动研究与地图演化升级

### 场景 5：画图后并行消化 Research

<!-- scenario-id: parallel-research -->

**输入：** map 首批 Frontier 同时包含两张 unblocked research、一张 blocked research、一张已认领 research、一张 task 和一张 HITL。

**期望：** `ResearchBatch` 只按地图顺序返回两张可执行 research，且选择过程不修改任何文件。支持后台子代理时由原子认领管理器产生唯一 owner，并行研究后由协调器串行收口；不支持时零 claim、零状态修改。

**证据：** `scripts/验证Wayfinder演化.ps1` 校验批量选择、文件哈希、双协调器竞争、部分认领失败、派发前 owner 校验、仅释放自身 claim，以及 Research 资产首次发布、同 owner 重试和跨 owner 拒绝覆盖。

### 场景 6：地图演化与名称优先

<!-- scenario-id: map-evolution -->

**输入：** 已确认范围决定排除一张 HITL 票，并使另一张原型票失效；fog 中另有一项变得可精确建票。

**期望：** 排除票以 `out_of_scope` 关闭并引用来源决定，只进入 Out of scope；失效票以 `superseded` 关闭，不进入 Decisions；fog 先建票再删除原条目。Frontier、Decisions、Out of scope 和 Ticket index 都显示 ticket 一级标题，不显示裸 ID。

**证据：** `scripts/验证Wayfinder演化.ps1` 校验关闭组合、来源决定、章节唯一性、fog 禁止链接以及四个区域的标题一致性。

### 自动化证据

<!-- evidence: research-parallelism -->
<!-- evidence: map-lifecycle -->
<!-- evidence: title-first -->

- `scripts/验证Wayfinder演化.ps1`：通过。覆盖 ResearchBatch、原子 claim、Research 资产 owner/retry 发布门禁、竞争与部分失败、closure_kind、来源决定、四区标题和 fog 规则。
- 现有 `scripts/验证Wayfinder行为.ps1`：通过。HITL 确认与 AFK 转 HITL 门禁未回归。
- 发布版本：`1.7.0+codex.202607201613`。

### 缺陷清单

- 未解决：普通 ticket 和地图正文仍没有通用原子锁；Research 批量 claim 与独立资产发布已分别使用专用 map 级锁。
- 降级规则：当前运行环境没有后台子代理能力时，ResearchBatch 仅报告候选，不执行认领或伪造研究结果。

## 2026-07-20 Frontier 完整性与交接升级

### 场景 7：Frontier 遗漏票据

<!-- scenario-id: frontier-completeness -->

**输入：** `tickets/` 和 Ticket index 中存在两张 eligible 票，但 Frontier 只列出其中一张。

**期望：** `FirstFrontier` 与 `ResearchBatch` 都拒绝推进，并明确报告遗漏票；自定义 Frontier 顺序完整时保持原顺序。已关闭、已认领或仍受阻票的 stale 指针允许保留并跳过。

**证据：** `scripts/验证Wayfinder完整性与交接.ps1` 覆盖遗漏、重复、索引不完整、自定义顺序和 stale 指针。

### 场景 8：地图收敛与交接

<!-- scenario-id: lifecycle-handoff -->

**输入：** 所有票已关闭，fog 为空，准备进入 PRD；随后由真实 PRD 接收。

**期望：** `PrepareHandoff` 生成 `交接.md` 并把地图置为 `ready_for_handoff`；同阶段重试可修复缺失交接文件，不同阶段失败。只有记录真实下游目标后，`Close` 才把地图置为 `closed`；closed map 不再选票。

**证据：** 自动化覆盖 active 直接关闭失败、fog 阻断、半成功恢复、同值幂等、不同值拒绝和 closed map 拒绝。

### 场景 9：Research 来源与接管

<!-- scenario-id: research-provenance -->

**输入：** 已认领 Research 票分别使用 HTTPS、仓库相对路径和 commit 来源发布；旧 owner 中断后由新 owner 尝试接管。

**期望：** 无来源或非法来源拒绝；资产只生成一个 `## Sources`，ticket `## Assets` 只写一个相对链接。同 owner 重试不重复；新 owner 只有显式指定旧 owner、仍持有当前 claim、Resolution 为空且资产 ticket_id 一致时才能接管，并记录 `previous_owner`。

**证据：** 自动化覆盖三类合法来源、非法来源、幂等、错误旧 owner、已有 Resolution 和资产 ticket_id 冲突。

### 自动化证据

<!-- evidence: frontier-completeness -->
<!-- evidence: lifecycle-handoff -->
<!-- evidence: research-provenance -->

- `scripts/验证Wayfinder完整性与交接.ps1`：通过。覆盖 Frontier 全集（含隐藏 Markdown）、stale 指针、ready 禁选/禁 claim、open/claimed/fog 阻断、并发改图拒绝、交接恢复与损坏拒绝、Research 来源和票据回链。
- `scripts/验证Wayfinder演化.ps1`：通过。既有并行 Research、地图演化和名称优先合同未回归。
- `scripts/验证Wayfinder行为.ps1`：通过。HITL 显式确认和 AFK 转 HITL 门禁未回归。
- 发布版本：`1.8.0+codex.202607201647`。

### 缺陷清单

- 已修复：Frontier 只校验已列链接，遗漏 eligible 票时仍可继续。
- 已修复：map `status` 未参与选择，已关闭地图仍可返回票据。
- 已修复：Research 资产没有强制来源合同，也没有回写所属 ticket 的稳定入口。
- 已修复：地图全部收敛后缺少显式 `ready_for_handoff -> closed` 交接状态。
- 已修复：生命周期初读内容与后续快照不绑定，Audit 期间的外部改图可能被旧内容覆盖；现以初读哈希、二次 Audit、临时文件先准备和替换前最终哈希复核拒绝已发生的变化。
- 已修复：`Close` 首次及幂等重试只检查交接路径存在；现校验普通文件、`map_id`、`status` 和 `handoff_stage`。
- 已修复：Research 先覆盖资产再检查 ticket 指针，拒绝路径可能留下新资产；现把全部指针校验前移到首次写入前。
- 已修复：Research 正文重复 `## Sources`，或同一资产路径出现在 `Assets` 外，仍可能写后才拒绝；现对候选资产和更新后 ticket 做完整写前校验。
- 已修复：`repo:` 来源可通过中间 junction 逃出仓库；现逐级拒绝重解析路径，并拒绝任意内嵌 `..`。
- 已修复：隐藏 Markdown ticket 未进入目录全集，接管后的同 owner 重试会抹掉 `previous_owner`；两者均补回归样本。
- 已修复：负向样本捕获任意异常即算成功；现同时校验稳定错误片段，防止无关解析错误误绿。
- 残余限制：不接入外部 issue tracker，不创建 Research Git 分支；共享锁只约束合作脚本，普通文件 API 不能对锁外人工编辑提供哈希比较替换 CAS，人工编辑前后需暂停生命周期操作并在冲突时合并。
