---
name: java-backend-review
description: Use when reviewing Java, Spring Boot, MyBatis, SQL, transaction logic, backend API changes, or PRs before merge. Focus on correctness, transaction semantics, null safety, concurrency, security, logging, and maintainable layered design.
---

# Java Backend Review

面向 Java/Spring/MyBatis 后端的专项评审。先看风险，再看风格。

评审前先应用 `coding-discipline`：确认改动是否小范围、是否有需求依据、是否存在无关重构或过度设计。写法问题优先参考 `java-coding-standard`，Spring 服务结构优先参考 `springboot-service-patterns`。

## 检查清单

### 正确性

- 每个改动是否能对应 PRD、OpenSpec 或 `tasks.md`。
- 是否存在未要求的功能、无关重构或过度抽象。
- 业务分支是否覆盖主流程、异常流程、边界条件。
- 状态流转是否可逆、可追踪、不会跳状态。
- 金额、时间、数量、分页、排序是否有边界处理。

### Spring 分层

- Controller 不写业务逻辑。
- Service 负责事务和业务编排。
- Mapper/Repository 只做数据访问。
- DTO/VO/PO 边界清楚。
- 统一异常处理，不把内部异常直接返回给用户。

### 事务

- `@Transactional` 是否在正确 service 层。
- 事务内是否调用外部接口、MQ、慢 IO。
- 异常是否会触发 rollback。
- 自调用是否导致事务失效。

### MyBatis/SQL

- 参数绑定是否安全，避免 `${}` 注入。
- 查询是否有必要索引。
- 分页是否稳定排序。
- update/delete 是否有明确 where 条件。
- N+1 查询是否可接受。

### Null Safety

- 外部输入、DB 字段、Map/List 取值是否判空。
- Optional 使用是否清晰，不滥用。
- 集合返回值优先空集合，不返回 null。

### 并发与幂等

- 重复请求是否安全。
- 定时任务/MQ 消费是否幂等。
- 乐观锁/唯一索引/分布式锁是否需要。
- 缓存更新是否有一致性风险。

### 安全

- 涉及接口、权限、输入、密钥、敏感数据时，必须跑 `springboot-security-review`。
- 权限校验是否在后端。
- 是否有越权访问、IDOR、SQL 注入、敏感信息泄露。
- 日志不打印 token、密码、完整身份证、银行卡。

### 日志与可观测性

- 关键失败有业务上下文。
- 日志包含 traceId/requestId 时保持原 key。
- 不用日志掩盖异常。
- 告警指标是否需要补充。

### 测试

- 先按 `java-test-strategy` 判断测试类型。
- 单测覆盖核心分支。
- 涉及 DB/事务时有集成测试或清晰手动验证。
- Bugfix 必须有回归测试或说明无法自动化原因。

## 输出格式

先列问题，按风险排序：

```text
P0 阻塞：必须修
P1 高风险：合并前修
P2 中风险：建议修
P3 低风险：可后续
```

每条问题包含：

- 文件/方法。
- 风险。
- 建议修复。
- 是否需要测试。
