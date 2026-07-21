# 项目交付规则

默认中文回答。生成的描述、注释、模板内容使用中文；Java identifiers、annotations、SQL、config keys、API names、stack traces 保留原文。

## 需求入口规则

<!-- route-priority: setup > wayfinder > brainstorming -->

- 需求入口不限于 Asana，也可以来自用户对话、会议纪要、线上问题、技术债或新功能探索。
- Asana 是需求跟踪系统，不是唯一入口。
- 入口优先级：`setup-workflow > wayfinder-workflow > superpowers:brainstorming`。Java 仓库缺少 `docs/agents/代码规范地图.md` 时，先 `setup-workflow` 只读发现；跨会话、路径不清、存在多个决策或阻塞关系的大目标，先 `wayfinder-workflow` 只画 map。
- 未命中 setup 或 Wayfinder 时，模糊需求先澄清；范围不清、方案分歧较大、用户体验/业务口径不清或可能重构时，才使用 `superpowers:brainstorming`。
- 轻量澄清是 `prd-writer` / delivery 内的最小澄清模式，只适用于小范围、低风险、目标基本可判断的模糊需求。
- brainstorming 产物只作为 PRD 输入，不直接替代 PRD / OpenSpec。
- 没有 Asana 可以启动需求澄清；没有确认 PRD / OpenSpec 不允许进入行为变更实现。
- 需要团队协作、排期或跨团队跟踪时，应后补 Asana。
- 非 Asana 入口必须在 PRD 中记录需求来源、是否已有 Asana 和跟踪要求。

## 需求流程

- 每个需求总是先生成 PRD；信息不足时输出待确认问题，不写代码。
- PRD 未确认，不创建正式 OpenSpec change。
- 创建或更新 OpenSpec change 前，必须检查相关 `openspec/specs/*`、`openspec/changes/*` active changes、历史 PRD / Asana / 会议纪要 / 问题记录 / archived change。
- `design.md` 必须写明本次变更与既有规格/历史需求的关系：兼容、扩展、替换或冲突处理。
- 如果会破坏旧验收标准，必须写明迁移策略、回滚方案和验收人确认。
- 实现偏差时先更新 PRD/OpenSpec，再改代码。
- 每个需求必须记录 OpenSpec change-id。
- PR 前必须给出验证结果、风险、回滚方案。
- PR 前必须填写分段审核基础判断；B 类、A 类或大重构按条件补扩展字段。

## 分段审核与高风险复查规则

- 大需求和大重构先走 phase 分段审核，每个 phase 开工前写边界声明，phase 出口做基础判断。
- 高风险复查按风险触发，不按工具触发；Claude 只是可选 reviewer，不是强制依赖。
- C 类小改只填基础判断和未触发原因，不要求补齐大重构字段。
- B 类或大重构需要补充实现路径、关键设计选择、CodeGraph impact、高风险链路回看和继续推进依据。
- A 类高风险链路强建议高风险复查；如不触发，必须写负责人确认人、确认时间、确认依据、替代证据、剩余风险和不触发原因。
- 实现前复查看 phase 切分、边界声明、高风险链路、测试计划和回滚计划。
- 实现后复查看实际改动范围、核心实现路径、测试证据、回滚方案和高风险链路回看。
- 高风险复查只审范围、边界、风险和证据，不接手实现。
- 重复出现 2 次及以上的阻断项、建议项、输入材料不足或验证证据不足，应评估升级为 PR Gate、checklist、AGENTS、skill 或问题地图。

## 模块设计与接口权威边界

当需求涉及新模块、原型图转设计、核心表、DDL、DTO、前端接口文档、Apifox/OpenAPI、OpenSpec 或 PRD 字段口径时，先做模块设计与接口权威边界检查，不要直接从页面字段生成表，也不要把数据库字段原样搬进前端请求 DTO。

### 模块设计基础

- 设计顺序：边界与非目标 -> 核心实体/生命周期/角色/跨域边界 -> 未来变异点矩阵 -> 核心事实源/可信 ID -> 薄核心表 -> 扩展缝 -> DDL/技术设计/前端接口/PRD/OpenSpec -> 旧口径残留扫描。
- 核心表只放长期稳定字段；高变化内容优先放 extension/detail/child/workflow/event/snapshot/association 表。
- 普通字段不带表名前缀，例如 `title`、`status`、`price`；外键/跨域引用使用 `product_id`、`bundle_id`、`shop_id` 这类实体语义；同表多个同类角色时才用 `creator_user_id`、`operator_user_id`。
- 历史事实用 snapshot/event/ledger 保存，不能依赖当前主表反推。
- 如果一张表出现大量 subtype nullable 字段、不同生命周期字段、未来每个功能都要加 5~10 个字段，先停下来复盘，不要继续堆字段。

### 接口权威边界

核心原则：**前端负责表达用户意图，后端负责确认业务事实。**

请求字段只允许包含：
- 用户真实输入 / 选择 / 上传 / 排序的值。
- 后端无法从登录态、租户/店铺上下文、path/header、数据库关系、业务规则中可靠推导的值。

请求体默认禁止包含：
- 当前用户、创建人、更新人、审核人。
- 可由 auth/path/header/上下文推导的 `userId`、`shopId`、`tenantId`、`targetUserId`、`targetShopId`。
- 审核状态、发布状态、派生状态、权限判断结果。
- `canEdit`、`canDelete`、`canPublish` 等只读权限字段。
- 计算金额、库存状态、低库存状态、可售状态等后端判断结果。
- `deleted`、内部版本、signature/cache/snapshot、软删除唯一性辅助字段。

接口文档必须包含字段来源表：字段、位置、前端是否传、来源/责任方、生命周期、说明。
字段生命周期至少区分：`active`、`readonly`、`derived`、`forbidden`、`deprecated`、`internal`、`defensive-only`。

实现或审查前必须做跨层字段对齐：DDL / Model / Request DTO / Response VO / Apifox 或 OpenAPI / Mapper SQL / Service 校验 / Tests / PRD / OpenSpec / 前端文档。

## Superpowers 辅助规则

- Superpowers 是辅助技能，不替代需求入口记录 / PRD / OpenSpec / CodeGraph / 测试 / PR Gate 主流程。
- 小范围、低风险、目标基本可判断的模糊需求，可以先做轻量澄清。
- 已完成 setup 且未命中 Wayfinder 时，新功能探索、方案分歧较大、用户体验/业务口径不清、范围不清或可能重构时，必须调用 `superpowers:brainstorming` 澄清目标、范围、候选方案和待确认问题。
- `superpowers:brainstorming` 的输出只作为 PRD 输入；不能绕过 `prd-writer`，也不能直接进入实现。
- PRD / OpenSpec 已确认，且实现涉及多文件、多步骤、复杂测试或回滚策略时，可调用 `superpowers:writing-plans` 拆执行计划。
- `superpowers:writing-plans` 的输出只作为 OpenSpec `tasks.md` 和实现计划补充；不能替代已确认 PRD / OpenSpec。
- 紧急止血、明确 bugfix、小范围配置或文档调整，不强制使用 `superpowers:brainstorming`。
- Superpowers 产物和已确认 PRD / OpenSpec 冲突时，以 PRD / OpenSpec 为准；必要时先更新主流程文档，再改代码。

## 小需求 / 大重构分流

满足任一条件即视为大重构候选，先切换到 `large-refactor-workflow` 做评估，不直接默认启用多 agent：

- 跨 3 个以上模块。
- 影响多层：Controller / Service / Mapper。
- 改核心模型、核心表、核心接口。
- 预计超过 2 天。
- 关键词包含：重构、治理、解耦、升级、统一、替换。

## 大重构流程

- 大重构不允许用一个巨大 OpenSpec change 承载全部变更。
- 命中跨模块、核心模型、核心表、核心接口、预计超过 2 天时，先走 `large-refactor-workflow`。
- 需要团队排期或跨团队跟踪时，先建或关联 Asana Epic；没有 Asana 时先记录需求来源并写 RFC 草稿。
- 先用 CodeGraph 做 Discovery。
- 先写 `docs/refactor/<重构名>/重构RFC.md`。
- 先补测试基线，再改结构。
- 按 phase 拆多个 OpenSpec changes。
- 必须询问用户是否启用多 agent 协作。
- 用户确认启用后，必须再确认 worker 数量、角色、并发数和 Claude 是否参与。
- 只有用户确认分工后，才创建 `.workflow-team/<change-id>/` 状态目录、worktree 和 worker 任务。
- 每个 phase 必须可独立 Review、合并、回滚。
- 开发可并行，合并必须串行。
- phase-n 必须在 phase-(n-1) 合并后的基线上测试。
- 回滚方案必须在测试环境验证，或说明无法验证原因。
- PR 必须小范围串行推进。

## 多 Agent 协作规则

启用多 agent 后：

- Codex App Leader 主控，负责拆任务、依赖、合并、总验证和 PR。
- Codex worker 分工执行 Discovery / OpenSpec / Implementation / Test / Documentation。
- Claude 只能在用户确认后作为 reviewer / critic / rescue 参与，默认只读审查。
- `cc-plugin-codex` 是可选外部依赖，不随本 workflow 打包；未安装时 Claude review 标记为未启用或手动审查。
- 多 worker 不共用同一个主工作区直接改代码。
- Implementation Worker 使用独立 `git worktree`，或只输出 patch / result。
- Leader 创建 `.workflow-team/<change-id>/`，并维护 `workflow-config.yaml`、`manifest.md`、`dependencies.md`、`worker-status.md`、`decisions.md`、`merge-log.md`。
- 每个 worker 任务目录必须包含 `task.md`、`task-metadata.yaml`、`task-log.jsonl`、`result.md`、`result-metadata.yaml`。
- `concurrency_group` 留空表示可并行；填写名称表示按 `workflow-config.yaml` 的 `max_parallel` 限流，`max_parallel: 1` 才是串行。
- `file_locks` 支持通配符；锁范围重叠时必须串行。当前是文件协议，不是自动锁服务；Leader 需要手动判断，或使用后续辅助脚本检测。
- 冲突必须写入 `冲突解决决策记录.md`。
- Claude 审查必须使用 `Claude代码审查任务单.md` 提供 PRD、OpenSpec、diff/base、重点接口和风险边界。
- 核心状态源是 `.workflow-team/<change-id>/` 文件协议，不依赖 Claude Code Task 工具作为唯一状态源。

## CodeGraph 代码图谱规则

- 陌生代码、跨模块需求、接口/Service/Mapper 改动前先定位影响面。
- 优先使用 CodeGraph。
- 优先查 `codegraph_context`、`codegraph_trace`、`codegraph_impact`。
- 修改前查入口、调用链、影响面。
- 修改后 PR 前复查 impact。
- CodeGraph 找不到、过期或信息不足时，再用 `rg` / `find`(bash) 或 `Get-ChildItem`(PowerShell) / 文件读取手动追踪函数名、类名、接口路径、SQL id。
- 手动追踪必须记录“未用 CodeGraph，可能遗漏”的风险。
- 仍不确定时，PR 标记 `[NEEDS-MANUAL-REVIEW]`，要求资深开发者复查影响面。
- 小改动且文件明确时可以少查，但最终说明必须能解释影响面。

## AI 写代码纪律

- 不猜需求；不清楚先写 PRD 的待确认问题，有 Asana 时可回 Asana 评论。
- 不做未要求的功能。
- 不做无关重构。
- 不做“未来可能有用”的抽象。
- 每个代码改动必须能对应 PRD、OpenSpec 或 `tasks.md`。
- 优先小范围、可验证的修改。
- 完成前必须给验证证据，不能只说“已完成”。

## Java 编码规范

- 优先遵守 repo 本地 formatter、Checkstyle、Spotless、PMD、Sonar、CI。
- 类名 `UpperCamelCase`，方法/字段/变量 `lowerCamelCase`，常量 `UPPER_SNAKE_CASE`。
- 避免拼音、中文标识、无意义缩写。
- Spring 优先构造器注入，不用字段注入。
- 生产代码不用 `System.out`、`System.err`、`printStackTrace()`。
- 异常不能静默吞掉，必须处理、补上下文、转换或重新抛出。
- 日志使用 SLF4J 占位符，不拼接字符串打印异常。
- MyBatis 优先 `#{}`，禁止把用户输入拼到 `${}`。
- update/delete 必须有明确 `WHERE`。
- 金额使用 `BigDecimal` / MySQL `decimal`。

## Spring Boot 服务规则

- Controller 不写业务逻辑，只做 HTTP 层职责。
- Service 负责业务编排、事务、幂等、状态流转。
- Mapper/Repository 只做数据访问。
- DTO 用于入参，VO 用于出参，PO/Entity 用于数据库映射。
- 入参用 Bean Validation，业务规则在 Service 校验。
- 统一异常处理，错误响应不泄露内部异常。
- 分页必须限制最大页大小，排序字段必须白名单。
- 外部调用必须有超时、失败日志、重试/补偿策略。

## SQL 性能与查询质量规则

- 涉及 Mapper/SQL、列表、搜索、统计、导出、分页或排序时，写代码必须先遵循 SQL 性能规则；审查代码或 PR 时必须按 `sql-performance-review` 审查模式给出结论。
- 列表/搜索接口必须有默认分页、最大 pageSize、稳定排序和排序字段白名单。
- Service 不能在循环中按行调用 Mapper / Repository 造成 N+1；优先批量查询或 read model。
- 列表页只查必要列，避免返回正文、JSON、图片、大 text/blob。
- 关键 SQL 必须提供 `EXPLAIN` 或等价执行计划证据；高风险 SQL 缺少证据不能 PASS。
- 大表查询必须说明索引匹配，不能只说“已有索引”。
- 缓存不能替代慢 SQL 根因修复；先检查查询条件、索引、分页和返回字段。

## 测试规则

- Plan Review 阶段先确认测试策略和回滚方案。
- 行为变更必须有测试，或说明不能自动化原因。
- Bugfix 必须有回归测试，先复现 bug 再修。
- 生产问题、revert、重大漏检修复必须先确认复现方式；无法自动化复现时，必须写清手动复现和验证证据。
- Service 逻辑优先 JUnit 5 + Mockito。
- Controller/API 优先 MockMvc / WebMvcTest。
- Mapper/SQL/事务优先集成测试；关键查询补 `EXPLAIN` 或等价执行计划证据。
- 只能手动验证时，必须写环境、步骤、输入、预期、实际、证据。
- PR 描述必须列出编译、单测、集成测试、手动验证和未覆盖项。

## 反馈闭环与复盘

- 用户提交问题后，先按既有需求来源 / PRD / OpenSpec / CodeGraph / 实现 / 测试 / Review / PR Gate 流程处理当前问题。
- AI 初步定位后，必须输出疑似根因、证据、影响面、修复方案和风险，让用户确认根因与处理模式。
- 根因未确认前，不生成最终复盘结论，不更新中央 workflow，不把疑似问题沉淀为通用规则。
- P0/P1 紧急问题优先止血，可先修复和验证，再补 PRD / OpenSpec / 复盘记录。
- 普通 bugfix 在用户确认根因后，走轻量 PRD / OpenSpec，再修复。
- 需求不清或会改变行为时，必须先 PRD，再 OpenSpec，再实现。
- 生产问题、重大漏检、回归测试遗漏、revert 或 PR Gate 未拦住的风险，必须使用 `assets/templates/流程复盘记录模板.md` 生成 `docs/postmortem/<问题ID>-<问题摘要>.md`。
- 可预防问题必须追加到 `docs/improvements/工作流改进追踪.md`，并标记是否建议升级中央 workflow。
- 反馈包交给中央 workflow 维护者前必须脱敏。

## Codex 交接与知识沉淀规则

- 每次完成明确 coding session、修复任务、功能开发、排查任务，结束前应生成一份结构化交接。
- 交接至少包含：今日任务、今日完成、关键改动、改动文件、遇到的问题、未解决事项、风险/待确认、明日建议。
- 对每个问题，补充：问题类型、是否建议进入问题地图、建议归类到哪个索引。
- 问题类型优先使用：工具链 / 需求规格 / 高风险工程 / 代码理解 / 测试验证 / 交付治理。
- 每次交接都补 `下次可直接复用的东西`，明确哪些判断、步骤、模板、检查单可以直接复用。
- 如果某类问题高概率重复出现，应建议沉淀到问题索引页，而不只停留在当次交接。
- 若团队使用 Obsidian，可将问题索引汇总到 `AI Coding 常见问题地图` 一类页面。

## 安全规则

- 后端必须做权限校验，不能信任前端传来的 role、userId、merchantId。
- 敏感资源必须校验 owner / tenant / merchant / org 归属。
- token、密码、API key 不进代码、不进日志、不进 PRD/OpenSpec。
- 生产 CORS 不使用 `*`。
- 文件上传必须校验大小、类型、扩展名、存储路径。
- 错误响应不能直接返回原始 `e.getMessage()`。

## MySQL MCP / AI 账号规则

- 只使用专门 AI 账号，不使用人工账号。
- AI 账号密码只能放环境变量或密钥管理系统。
- 允许 `SELECT`、`SHOW`、`DESCRIBE`、`EXPLAIN` 直接查询。
- `INSERT`、`UPDATE` 执行前必须展示 SQL、影响范围和回滚方式。
- `DELETE` 必须先用同条件 `SELECT` 预览影响数据，并得到用户明确授权。
- `CREATE`、非破坏性 `ALTER` 必须展示完整 DDL、影响范围、锁表风险、回滚方案，并得到用户明确授权。
- 禁止执行 `DROP`、`TRUNCATE`、`ALTER TABLE ... DROP`。
- 禁止执行删除字段、删除索引、删除约束等破坏性 `ALTER`。
- 禁止执行无 `WHERE` 的 `UPDATE` / `DELETE`。
- 生产 DDL 默认只生成迁移 SQL 和回滚 SQL，不直接执行。
- 生产环境默认只读；生产写入必须走人工变更流程。

## 构建失败修复

- 先收集完整错误，再按根因分组。
- 一次只修一个根因。
- 只做最小改动，不做架构重写。
- 修完必须重新运行同一构建命令验证。
- 不通过跳过测试、删除测试、压制 warning 来伪造成功。

## 工具失败处理

- OpenSpec 命令失败：停止实现，记录命令、错误、当前 change-id，先修 OpenSpec 状态。
- CodeGraph 不可用：降级到 `rg` / `find`(bash) 或 `Get-ChildItem`(PowerShell) / 文件读取手动追踪，并在 PR 中说明。
- MySQL MCP 失败：不绕过安全规则；改为生成 SQL 和人工执行步骤。
- SQL 性能证据缺失：先做静态 SQL 性能评审；高风险 SQL 缺少 `EXPLAIN` 时不得给 PASS。
- 测试命令失败：优先修测试或代码；不能用跳过测试替代。

## 风险升级

发现以下情况立即暂停并升级：

- 影响面超出预期，例如 CodeGraph callers > 10。
- 发现核心事务边界变更。
- 需要数据迁移，例如影响行数 > 1000。
- 需要停机窗口。
- 发现安全漏洞或权限绕过。

升级动作：更新 OpenSpec `design.md` 风险部分，有 Asana 时评论 @验收人，评估是否切换到大重构流程，并暂停实现等待确认。

## Review 规则

- 先看正确性，再看风格。
- P0/P1 问题必须合并前修复。
- 涉及 SQL/查询接口时，PR 前必须有 SQL 性能结论、分页/排序说明和 `EXPLAIN` 或低风险理由。
- 测试无法自动化时，必须说明原因和手动验证步骤。
