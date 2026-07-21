# Wayfinder 决策对话设计

## 目标

让用户只描述目标后，Wayfinder 能主动收敛关键取舍：每轮只问一个问题，提供 2 至 3 个互斥选项和明确推荐，并在用户显式确认前保持 HITL 票据未关闭。

## 范围

- 为 `wayfinder-workflow` 增加统一的 HITL 决策对话协议。
- 为 frontier ticket 增加可机读的决策状态和确认审计字段。
- 让 frontier 解析脚本拒绝“未确认却已关闭”的 HITL 票据。
- 增加真实验收样本和可执行行为验证。
- 更新 README 中的实际使用体验和调用示例。

## 非目标

- 不新增新的泛化工作流或独立 skill。
- 不改变 `setup-workflow > wayfinder-workflow > brainstorming` 的入口优先级。
- 不替代 PRD、OpenSpec、代码规范地图或四轴 Review。
- 不让模型替用户决定业务取舍。

## 交互协议

### Destination 未确认

如果目标尚不足以形成明确 Destination，Wayfinder 每轮只提出一个最关键问题，并按固定顺序给出：已知事实、待决问题、2 至 3 个互斥选项、推荐选项及理由、明确的确认请求。用户确认后才能把 Destination 视为稳定输入并继续建图。

### HITL frontier ticket

`prototype`、`grilling` 和 `task/HITL` 都使用同一协议：

1. 一轮只处理一个待决问题。
2. 展示 2 至 3 个互斥选项；确实只有两种时不凑第三项。
3. 给出推荐和理由，但不得替用户选定。
4. 用户回复必须能映射到某个选项，或给出自定义、可执行的明确决定。
5. 未收到显式确认时，票据保持 `claimed`，不得填写最终 Resolution、不得关闭、不得更新地图 Decisions。
6. 收到确认后，记录确认人、时间和原始决定，再关闭票据并重建 Frontier。

### AFK frontier ticket

`research` 和 `task/AFK` 可以独立完成事实调研。若调研结论只包含事实且不存在用户取舍，允许关闭；若仍存在方案选择，则关闭调研票并新建或解阻塞一张 HITL 决策票，不得把推荐伪装成已确认决定。

## 状态模型

ticket YAML 新增：

- `decision_status: not_required | pending | confirmed`
- `confirmed_choice:`：用户确认的选项 ID，或 `custom`。
- `confirmed_by:`
- `confirmed_at:`

约束：

- AFK 票据使用 `not_required`。
- HITL 票据创建和认领时使用 `pending`。
- HITL 票据只有在用户明确确认后才能改为 `confirmed`。
- `status: closed` 且 `interaction: HITL` 时，`decision_status` 必须为 `confirmed`，且 `confirmed_choice`、`confirmed_by`、合法的 `confirmed_at` 都不能为空，否则 frontier 解析失败并报告 ticket ID 和补录要求。
- 为兼容已有地图，缺少 `decision_status` 时按交互类型推断：AFK 为 `not_required`，HITL 为 `pending`；因此旧的已关闭 HITL 票会被识别为未确认并阻断继续推进。
- 不自动伪造旧票据的历史确认；旧地图应由用户补录真实确认，或重新打开票据获取确认。

## 票据正文

模板保留原有 `Question`、切片、输入输出、验收等区块，并新增决策包：

- 已知事实
- 选项
- 推荐
- 请确认
- Confirmation

YAML 是状态唯一来源；正文 Confirmation 保留用户原始决定和解释，不重复维护状态。推荐选项与 Confirmation 分区记录，不能把模型推荐当成用户确认。

## 地图决策门禁

地图只能包含一个 `## Decisions so far` 章节，其中每条决策必须且只能以一个 Markdown 链接引用来源 ticket。自由文本决定、重复章节、引用未关闭票据，或引用未确认的 HITL 票据时立即失败。这样“未确认不得更新地图”不只依赖文字约定。

## AFK 转 HITL 顺序

AFK 调研发现仍需用户取舍时，固定顺序为：先创建或解阻塞 HITL ticket，在 AFK `blocks` 与 HITL `blocked_by` 中写入互为镜像的关系并加入 Frontier，运行 frontier 校验成功，再关闭 AFK 调研票。不得先关闭 AFK；承担该交接的 AFK 票不能作为地图 Decisions 来源，最终决定必须引用已确认的 HITL 票。

## 验收

1. 静态合同验证能证明 skill、模板和 README 都声明了单问题、选项、推荐、确认门禁。
2. 可执行验证能证明关闭但未确认的 HITL blocker 会被拒绝，未确认 ticket 也不能出现在地图 Decisions。
3. 把同一票据改为 `decision_status: confirmed` 并补齐确认审计后，被阻塞票据才能成为 frontier。
4. 缺新字段的 open/closed、AFK/HITL 兼容样本具有明确、可重复的结果。
5. 四类真实样本使用可解析决策包，验证恰好一个问题、2 至 3 个带稳定 ID 的选项、引用一个选项的推荐和明确确认请求；选项语义是否互斥由规格审查负责。
6. AFK 转 HITL 样本证明 HITL 票先进入 Frontier，再关闭 AFK 票。
7. 现有 Wayfinder、第一阶段工作流和插件发布态验证继续通过。

## 风险与兼容

- 旧地图中缺少新字段不会立即解析失败，但旧的已关闭 HITL 票需要补一次确认审计。
- YAML 标量采用受限解析：拒绝重复键，识别引号空值和行尾注释；确认选项只允许 `A`、`B`、`C` 或 `custom`。
- 本地 Markdown 仍没有原子锁，claim 和确认前都必须重读票据。
- 推荐只代表当前证据下的系统建议，不等于用户授权。
