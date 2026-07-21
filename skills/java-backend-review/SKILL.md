---
name: java-backend-review
description: Use when reviewing Java, Spring Boot, MyBatis, SQL, transaction logic, backend API changes, or PRs before merge. Focus on correctness, transaction semantics, null safety, concurrency, security, logging, API performance, SQL quality, and maintainable layered design.
---

# Java Backend Review

面向 Java/Spring/MyBatis 后端的专项评审。结论固定按 Standards、Spec、Tests、Risk Gates 四轴输出；四轴不互相抵消。

评审前先应用 `asana-openspec-java-workflow:coding-discipline`：确认改动是否小范围、是否有需求依据、是否存在无关重构或过度设计。写法问题优先参考 `java-coding-standard`，Spring 服务结构优先参考 `springboot-service-patterns`。

如果改动涉及 Mapper/SQL、列表/搜索/统计/导出接口、分页排序、动态查询条件、索引、或 Service 循环查库，必须按 `sql-performance-review` 审查模式检查 SQL。Java Review 不能用“功能可用”替代 SQL 性能结论。

## 检查清单

### Standards

- 先读取 `docs/agents/代码规范地图.md`；不存在时说明缺口，并回退到 `AGENTS.md`、CI 和仓库现有约定。
- 检查命名、分层、DTO/VO/PO、异常、日志、空安全和可维护性。
- 请求 DTO 只能表达用户输入；`userId`、`shopId`、`tenantId`、状态、权限、派生金额/库存和内部字段不得作为正向请求合同。
- 接口/DTO 变更应提供字段来源表，标明 active、readonly、derived、forbidden、internal 或 defensive-only。

#### Spring 分层

- Controller 不写业务逻辑。
- Service 负责事务和业务编排。
- Mapper/Repository 只做数据访问。
- DTO/VO/PO 边界清楚。
- 统一异常处理，不把内部异常直接返回给用户。

### Spec

#### 正确性

- 每个改动是否能对应 PRD、OpenSpec 或 `tasks.md`。
- 是否存在未要求的功能、无关重构或过度抽象。
- 业务分支是否覆盖主流程、异常流程、边界条件。
- 状态流转是否可逆、可追踪、不会跳状态。
- 金额、时间、数量、分页、排序是否有边界处理。

### Risk Gates

#### 事务

- `@Transactional` 是否在正确 service 层。
- 事务内是否调用外部接口、MQ、慢 IO。
- 异常是否会触发 rollback。
- 自调用是否导致事务失效。

#### MyBatis/SQL

- 参数绑定是否安全，避免 `${}` 注入。
- 查询是否有必要索引。
- 分页是否稳定排序。
- update/delete 是否有明确 where 条件。
- N+1 查询是否可接受。

#### 接口性能与 SQL 质量

- 列表、搜索、统计、导出接口是否有默认分页和最大 pageSize。
- 分页是否有稳定排序，排序字段是否白名单控制。
- Service 是否在循环中调用 Mapper / Repository 造成 N+1。
- 列表接口是否只查必要列，避免正文、JSON、图片、大 text/blob。
- 关键 SQL 是否有 `EXPLAIN` 证据，或明确低风险理由。
- 大表查询是否命中预期索引，联合索引顺序是否匹配过滤和排序。
- `COUNT(*)`、`GROUP BY`、`ORDER BY`、多表 join 是否存在慢查询风险。
- 是否用缓存掩盖慢 SQL 根因；缓存只能作为收益明确的补充方案。

#### Null Safety

- 外部输入、DB 字段、Map/List 取值是否判空。
- Optional 使用是否清晰，不滥用。
- 集合返回值优先空集合，不返回 null。

#### 并发与幂等

- 重复请求是否安全。
- 定时任务/MQ 消费是否幂等。
- 乐观锁/唯一索引/分布式锁是否需要。
- 缓存更新是否有一致性风险。

#### 安全

- 涉及接口、权限、输入、密钥、敏感数据时，必须跑 `springboot-security-review`。
- 权限校验是否在后端。
- 是否有越权访问、IDOR、SQL 注入、敏感信息泄露。
- 日志不打印 token、密码、完整身份证、银行卡。

#### 日志与可观测性

- 关键失败有业务上下文。
- 日志包含 traceId/requestId 时保持原 key。
- 不用日志掩盖异常。
- 告警指标是否需要补充。

### Tests

#### 测试

- 先按 `java-test-strategy` 判断测试类型。
- 单测覆盖核心分支。
- 涉及 DB/事务时有集成测试或清晰手动验证。
- Bugfix 必须有回归测试或说明无法自动化原因。

## 输出格式

报告必须保留以下四个标题。每个标题内按 P0-P3 标记风险；不要把不同轴的问题合并重排。

```text
## Standards
仓库规则、分层、接口字段权威、可维护性问题。

## Spec
PRD / OpenSpec / tasks.md 的遗漏、偏差和范围漂移。

## Tests
已验证项、未验证项、回归和手动验证证据。

## Risk Gates
事务、并发、SQL/DB、安全、性能、回滚和上线观察。
```

每条问题包含：

- 文件/方法。
- 风险。
- 建议修复。
- 是否需要测试。

## 审查后的下一步引导

如果未发现 P0/P1 阻塞问题，且用户说“下一步 / 开始 PR / 生成 PR 描述 / 没问题了”，AI 必须主动提示并进入 `pr-quality-gate`。不要让用户从空白开始填 PR。

进入 PR 前必须补齐：

- CodeGraph 索引状态确认。
- CodeGraph impact 影响面证据，或明确降级原因。
- `sql-performance-review` 结论；不涉及 SQL/查询接口时说明原因。
- 测试命令和结果。
- 未覆盖风险。
- 回滚方案。

如果用户纠正问题分类，例如“这不是硬编码错误”，先接受并修正分类，再继续 PR 门禁；不要把已纠正的分类写进 PR 风险结论。
