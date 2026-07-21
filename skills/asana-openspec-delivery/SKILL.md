---
name: asana-openspec-delivery
description: "Use when driving a Java/Spring/MyBatis requirement from intake through PRD, OpenSpec, CodeGraph impact, implementation, verification, review, PR, and archive. Intake can come from Asana, user conversation, meeting notes, incidents, technical debt, rough ideas, or cross-session goals with unclear routes."
---

# Asana OpenSpec Delivery

主交付流程。目标：让每条需求都有来源、PRD、OpenSpec 变更记录、实现计划、验证证据和 PR 交付记录。

## 入口路由

先判断需求来源和清晰度：

优先级：`setup-workflow > wayfinder-workflow > superpowers:brainstorming`。先补仓库事实，再为跨会话大目标找路；只有未命中前两项时，才按问题粒度进入 brainstorming。

<!-- route-priority: setup > wayfinder > brainstorming -->

| 输入 | 处理 |
|---|---|
| 新接入仓库，或缺少 `docs/agents/代码规范地图.md` | 先调用 `setup-workflow` 做只读发现；需要写入地图时等待用户确认 |
| 跨会话的大而模糊目标，或多个决策和依赖尚不清晰 | 已完成 setup 前置后调用 `wayfinder-workflow` 画 map；每张 ticket 再按需要澄清、写 PRD 或进入 OpenSpec |
| 明确 Asana 需求 | 读取 Asana，生成或完善 PRD |
| 用户对话中的明确需求 | 生成 PRD 草稿，标记 `需求来源：用户对话` |
| 单会话、小范围且目标基本可判断的模糊需求 | 进入轻量澄清或 `superpowers:brainstorming`，不写代码 |
| 会议纪要 | 生成 PRD 草稿，列待确认问题 |
| 技术债 / 重构想法 | Destination、范围或首批决策不清时先 Wayfinder；清楚后再 Discovery / RFC |
| 线上问题 | 先定位根因，等待用户确认处理模式 |

没有 Asana 不阻塞需求澄清；没有确认 PRD / OpenSpec 不进入实现。

轻量澄清是 delivery / prd-writer 内的最小澄清模式，只适用于小范围、低风险、目标基本可判断的模糊需求。

未命中 setup 或 Wayfinder 条件时，命中以下任一条件必须进入正式 `superpowers:brainstorming`：

- 新功能探索。
- 方案分歧较大。
- 范围不清。
- 涉及用户体验或业务口径。
- 可能演化成大重构。

## 阶段

```text
需求入口
-> 入口路由判断
-> 跨会话大目标：Wayfinder map -> 一次解决一个 ticket
-> 轻量澄清 / 按条件进入 Superpowers brainstorming
-> PRD Writer
-> PRD Review
-> 小需求 / 大重构分流
-> OpenSpec Planning
-> Plan Review
-> 分段审核基础判断
-> 可选 Superpowers writing-plans
-> 开发中
-> 测试迭代
-> Review Gates
-> 必要时高风险复查
-> 待 PR
-> 合并
-> OpenSpec archive
```

## 执行流程

1. 判断需求来源和清晰度，记录 `需求来源`、`是否已有 Asana`、`跟踪要求`：
   - 先检查 `docs/agents/代码规范地图.md`；存在时加载为仓库规范索引，不存在时调用 `setup-workflow` 做只读发现。
   - 同时命中“缺代码规范地图”和“跨会话大目标”时，setup-workflow 的只读发现优先于 Wayfinder；发现结束后可继续画 map，但 Notes 必须标记“代码规范地图待确认”。
   - setup 尚未得到写入确认时，不阻塞本次需求澄清，但必须标记“代码规范地图待确认”，且不得猜测构建、测试或 CI 命令。
   - 有 Asana：读取标题、背景、目标、验收人、优先级、影响面。
   - 无 Asana：读取用户对话、会议纪要、线上问题描述、技术债想法或 brainstorming 结果。
   - 需要团队协作、排期或跨团队跟踪时，标记待补 Asana。
2. 需求模糊、新功能探索或方案分歧较大时，先按优先级澄清，不写代码：
   - 目标跨多个会话、存在多项相互依赖决策、或无法描述从当前状态到 Destination 的路径时，先调用 `wayfinder-workflow`。本阶段只画 map；后续一次只解决一个 ticket。
    - Wayfinder ticket 需要用户澄清时，再按条件调用 `superpowers:brainstorming`；决策清晰后才进入 PRD/OpenSpec。
    - 未命中 Wayfinder 时，小范围、低风险、目标基本可判断可做轻量澄清，输出目标、范围、不做什么和待确认问题。
    - 未命中 Wayfinder 且新功能探索、方案分歧较大、用户体验/业务口径不清、范围不清或可能重构时，必须调用 `superpowers:brainstorming`。
   - brainstorming 输出只作为 PRD 输入，不替代 `prd-writer`。
   - 明确 bugfix、紧急止血、小范围配置或文档调整可跳过正式 brainstorming，但仍要进入 PRD / OpenSpec 门槛。
3. 总是先调用 `prd-writer`：
   - 信息足够：输出完整 PRD。
   - 信息不足：输出待确认问题列表，回到原始来源；有 Asana 时可回 Asana 评论，不写代码。
4. PRD 确认后，判断是小需求还是大重构。
5. 满足任一条件即视为大重构：
   - 跨 3 个以上模块。
   - 影响多层：Controller / Service / Mapper。
   - 改核心模型、核心表、核心接口。
   - 预计超过 2 天。
   - 需求关键词包含：重构、治理、解耦、升级、统一、替换。
6. 如果是大重构，调用 `large-refactor-workflow`，生成 RFC、测试基线和 phase 拆分。
7. 如果是小需求，PRD 确认后先做 OpenSpec 既有规格检查，再创建 OpenSpec change：
   - 查相关 `openspec/specs/*`，确认已归档需求形成的当前系统规格。
   - 查 `openspec/changes/*` active changes，确认是否有并行变更冲突。
   - 查相关历史 PRD、Asana 链接、会议纪要、问题记录或 archived change，确认旧验收标准是否会被破坏。
   - 在 `design.md` 写清“与既有规格/历史需求的关系”：兼容、扩展、替换或冲突处理。
8. 定位影响面：
   - 优先：`codegraph-context-guard`，查入口、调用链、callers/callees、impact。
   - 降级：`rg` / `find`(bash) 或 `Get-ChildItem`(PowerShell) / 文件读取，手动追踪调用链。
   - 最低：依赖人工 Code Review 明确影响面。
9. 检查 OpenSpec 文件：
   - `proposal.md`
   - `design.md`
   - `tasks.md`
   - `specs/`
10. 实现前做 Plan Review，确认：
   - 任务拆分。
   - 风险点。
   - 测试策略：单测 / 集成测试 / 手动验证。
   - SQL / 接口性能策略：列表、搜索、统计、导出、分页、排序、索引、`EXPLAIN` 证据。
   - 回滚方案：涉及 DB、核心逻辑、权限、状态流转时必须写清。
   - 分段审核基础判断：风险等级、命中条件、是否建议实现前复查。
   - 命中 A 类或明显 B 类风险时，先写实现前边界声明，再判断是否做实现前复查。
11. PRD / OpenSpec 已确认，且实现涉及多文件、多步骤、复杂测试或回滚策略时，可调用 `superpowers:writing-plans`：
   - 输出文件清单、步骤、测试命令和提交节奏。
   - 输出只作为 OpenSpec `tasks.md` 和实现计划补充。
   - 不替代已确认 PRD / OpenSpec；冲突时先更新主流程文档。
12. 实现前调用 `asana-openspec-java-workflow:coding-discipline`，确认假设、范围、不做内容、验证方式。
13. 实现时按 `java-coding-standard`、`springboot-service-patterns` 和 `sql-performance-review` 编码模式推进；涉及 Mapper/SQL、列表/搜索/统计/导出接口、分页排序、动态查询或索引时，先按 SQL 性能规则设计查询，再写代码。
14. 涉及接口、权限、输入、密钥、敏感数据时，调用 `springboot-security-review`。
15. 构建失败时调用 `java-build-fix`，只做最小修复。
16. 发现需求偏差时，先更新 PRD/OpenSpec，再改代码。
17. 实现后再次调用 `java-test-strategy`，按第 10 步测试策略确认单测、集成测试、手动验证是否完成。
18. 实现后调用 `codegraph-context-guard` 复查 impact，填写 `assets/templates/PR评审清单.md` 的分段审核基础判断；B 类、A 类或大重构按条件补扩展字段。
19. 实现后调用 `java-backend-review`，并按 `sql-performance-review` 审查模式检查 SQL/查询接口；再调用 `mysql-db-guard` 和 `pr-quality-gate`。不涉及 SQL/查询接口时，在 PR Gate 中写明不触发原因。
20. PR 描述必须包含需求来源、OpenSpec change-id、测试结果、风险说明、回滚方案；有 Asana 时必须包含 Asana 链接。
21. 合并后执行 OpenSpec verify/archive；有 Asana 时更新 Asana 状态。
22. 完成后记录流程改进数据；试运行阶段如触发高风险复查或字段过重，补充 `assets/templates/分段审核与高风险复查试运行记录.md`。

## 分段审核与高风险复查软接入

分段审核与高风险复查按 `docs/workflow/大需求分段审核与高风险复查协议.md` 执行，当前是软接入，不替代 PRD、OpenSpec、CodeGraph、测试和 PR Gate。主流程先做 phase / PR 基础判断，命中风险再触发复查。

执行入口：

- PRD / 需求澄清：判断是否可能命中 A 类或 B 类。
- OpenSpec / RFC：记录 phase 切分、实现前边界声明和 A 类高风险链路映射。
- 实现前：A 类或明显 B 类风险先做实现前复查判断。
- 实现后 / PR 前：在 `PR评审清单.md` 填写基础判断，按风险等级补扩展字段。
- PR Gate：检查是否填写基础判断、跳过高风险复查原因和替代证据。
- 复盘 / 规则回流：重复问题或 A 类严重遗漏升级为 checklist、AGENTS、skill 或问题地图。

字段分层：

- C 类小改：只填基础判断和未触发原因。
- B 类 / 大重构：补实现路径、关键设计选择、CodeGraph impact、风险回看和继续推进依据。
- A 类：强制补高风险链路映射、当前控制方式、剩余风险和实现前后高风险复查记录。

试运行规则：

- 先拿 1 个 C 类小改和 1 个复杂迁移 slice 试填。
- 再在 3 到 5 个真实大需求中观察字段成本和风险命中率。
- 字段大量空置时，先删减或改成条件字段，不升级硬门禁。
- 字段稳定有效后，才考虑将 PR Gate 软检查升级为硬阻断或自动化审计。

## 决策规则

- Asana 是需求跟踪入口之一，不承载完整实现细节，也不是唯一入口。
- 代码规范地图是仓库事实的轻量索引；`AGENTS.md`、CI、PRD 和 OpenSpec 仍有更高权威。
- Wayfinder 是跨会话目标的找路层；map 不替代 PRD，frontier ticket 不替代 OpenSpec `tasks.md`，并且默认不直接实现目标。
- PRD 是业务合同，OpenSpec 是变更账本。
- Superpowers 是辅助技能，只按条件触发，不接管主流程。
- `superpowers:brainstorming` 只用于需求澄清，输出进入 PRD。
- `superpowers:writing-plans` 只用于复杂实现拆计划，输出服务 OpenSpec `tasks.md`。
- PRD 未确认，不创建正式 OpenSpec change。
- OpenSpec 不清楚时，不进入实现。
- 大重构不用单个 OpenSpec change 承载全部变更。
- Review 不满意时，按问题类型回退：
  - 业务理解错：回 PRD。
  - 方案设计错：回 OpenSpec design。
  - 实现 bug：回开发中。
  - 测试不足：回 `java-test-strategy` 补测试。

## OpenSpec 既有规格检查

每次创建或更新 change 前，都要把新需求放回现有规格里看，而不是孤立看当前入口描述。

必须确认：

- 相关 `openspec/specs/*` 中是否已有行为、接口、字段、权限、状态流转或错误码约束。
- `openspec/changes/*` 中是否有 active change 修改同一 capability、接口、表、Service 或 Mapper。
- 历史 PRD、Asana、会议纪要、问题记录、archived change 是否包含仍有效的验收标准。
- 本次 change 是兼容扩展、行为替换、旧能力下线，还是修正历史规格错误。
- 如需破坏旧行为，必须在 `design.md` 写明原因、迁移策略、回滚方案和验收人确认。

输出到 `design.md`：

```md
## 与既有规格/历史需求的关系

- 相关现有 specs：
- 相关 active changes：
- 相关历史 PRD / Asana / 会议纪要 / 问题记录 / archived change：
- 本次变更关系：兼容 / 扩展 / 替换 / 冲突修正
- 可能破坏的旧验收标准：
- 处理方式：
```

## OpenSpec 命令使用时机

| 阶段 | 命令 | 说明 |
|---|---|---|
| PRD 确认后 | `/opsx:new <change-id>` | 创建新 change |
| 编辑 OpenSpec | `/opsx:continue` | 继续编辑当前 change |
| 快速填充 | `/opsx:ff` | AI 生成 proposal/design/tasks |
| 开始实现 | `/opsx:apply` | 应用 change 到代码 |
| PR 合并后 | `/opsx:verify` | 验证实现完整性 |
| 验证通过 | `/opsx:archive` | 归档并关闭 change |

## 工具失败处理

工具失败时不要绕过流程。按仓库根目录 `工具失败处理.md` 执行：

- OpenSpec 失败：停止实现，记录命令、错误和 change-id，修复后重跑。
- CodeGraph 失败：降级到 `rg` / `find`(bash) 或 `Get-ChildItem`(PowerShell) / 文件读取，并在 PR 里说明定位方式。
- MySQL MCP 失败：不绕过 `mysql-db-guard`，输出 SQL、影响面和回滚方案，改人工执行。
- SQL 性能证据缺失：不绕过 `sql-performance-review`，先做静态评审；高风险 SQL 缺少 `EXPLAIN` 时不得给 PASS。
- 构建/测试失败：调用 `java-build-fix`，不能跳过测试伪造通过。
- Asana / GitHub Connector 失败：手动补齐链接和上下文；连接恢复后，有 Asana 时补回状态。

## 风险升级规则

发现以下情况立即暂停并升级：

- 影响面超出预期，例如 CodeGraph callers > 10。
- 发现核心事务边界变更。
- 需要数据迁移，例如影响行数 > 1000。
- 需要停机窗口。
- 发现安全漏洞或权限绕过。
- 命中 A 类高风险链路，但缺少实现前边界声明、负责人确认人、确认时间、确认依据、CodeGraph impact、关键测试证据或回滚方案。

升级动作：

1. 更新 OpenSpec `design.md` 风险部分。
2. 有 Asana 时评论 @验收人；没有 Asana 时在 PRD/OpenSpec 风险区记录待确认人。
3. 评估是否需要切换到 `large-refactor-workflow`。
4. 评估是否需要触发实现前复查或实现后复查。
5. 暂停实现，等待确认；确认后再继续原流程、补充设计后继续，或切换大重构流程。

## 完成后记录

用于流程改进，不做个人 KPI。

- 实际耗时 vs 预估。
- Review 轮次和主要问题。
- 测试发现的 bug 数。
- 是否发生回退，原因是什么。
- CodeGraph 是否准确定位影响面。

## 完成标准

- Asana 状态已更新，或已明确本需求没有 Asana / 暂不需要 Asana。
- PRD 已确认。
- 已检查相关既有 specs、active changes 和历史 PRD/Asana/会议纪要/问题记录，并在 `design.md` 记录关系。
- OpenSpec change 已 verify/archive。
- PR 已合并或给出阻塞原因。
- 测试、Review、风险记录完整。
- 涉及 MySQL 时，已记录 SQL、影响行数、确认结果和回滚方案。
- 涉及 SQL/查询接口时，已完成 `sql-performance-review`，并记录分页、排序、索引、`EXPLAIN` 或低风险理由。
- 每个代码改动都能对应 PRD、OpenSpec 或 `tasks.md`。
- 已填写分段审核基础判断；B 类、A 类或大重构已按条件补充扩展字段或写明不触发原因。
- 涉及安全敏感点时，已完成 Spring Boot Security Review。
- 已给出入口、调用链、影响面；没有 CodeGraph 时，说明降级追踪方式。
- 行为变更已有单测/集成测试，或明确说明只能手动验证的原因和证据。
- 大重构已拆为 RFC + 多个 OpenSpec changes + 小 PR，不用单个 change 吃全部。
- 已记录完成后改进数据。
