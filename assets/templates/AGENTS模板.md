# 项目交付规则

默认中文回答。生成的描述、注释、模板内容使用中文；Java identifiers、annotations、SQL、config keys、API names、stack traces 保留原文。

## 需求流程

- 需求入口是 Asana。
- 开发前必须有 PRD 或 OpenSpec proposal。
- 需求不清楚时先澄清，不写代码。
- 实现偏差时先更新 PRD/OpenSpec，再改代码。
- 每个需求必须记录 OpenSpec change-id。
- PR 前必须给出验证结果、风险、回滚方案。

## CodeGraph 代码图谱规则

- 如果项目存在 `.codegraph/`，陌生代码、跨模块需求、接口/Service/Mapper 改动前先查 CodeGraph。
- 优先查 `context`、`search`、`callers`、`callees`、`impact`。
- 修改前查入口、调用链、影响面。
- 修改后 PR 前复查 impact。
- CodeGraph 找不到、过期或信息不足时，再用 `rg` / 文件读取兜底。
- 小改动且文件明确时可以少查，但最终说明必须能解释影响面。

## AI 写代码纪律

- 不猜需求；不清楚先写 PRD 的待确认问题，或回 Asana 评论。
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

## 测试规则

- 行为变更必须有测试，或说明不能自动化原因。
- Bugfix 必须有回归测试，先复现 bug 再修。
- Service 逻辑优先 JUnit 5 + Mockito。
- Controller/API 优先 MockMvc / WebMvcTest。
- Mapper/SQL/事务优先集成测试。
- 只能手动验证时，必须写环境、步骤、输入、预期、实际、证据。
- PR 描述必须列出编译、单测、集成测试、手动验证和未覆盖项。

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

## Review 规则

- 先看正确性，再看风格。
- P0/P1 问题必须合并前修复。
- 测试无法自动化时，必须说明原因和手动验证步骤。
