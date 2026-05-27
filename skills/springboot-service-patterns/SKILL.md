---
name: springboot-service-patterns
description: Use when designing or implementing Spring Boot backend services, REST APIs, controller-service-mapper layering, validation, exception handling, transactions, pagination, caching, async jobs, external calls, and observability.
---

# Spring Boot Service Patterns

Spring Boot 服务设计模式。用于实现前的方案检查和实现中的结构约束。

## Controller

- 只做 HTTP 入参、`@Valid` 校验、鉴权入口、调用 Service、返回 VO。
- 不写业务规则、不直接调用 Mapper。
- REST 路径按资源设计，避免动词堆叠。
- 分页参数限制最大值，防止大分页。

## Service

- 承担业务编排和事务边界。
- 一个 public 方法对应一个清晰业务动作。
- 写操作考虑幂等、重复提交、状态校验。
- 外部接口、MQ、慢 IO 不要随意放进长事务。
- 查询方法可用 `@Transactional(readOnly = true)`，前提是项目惯例支持。

## Mapper / Repository

- 只做数据访问。
- 方法名表达查询条件和意图。
- MyBatis XML 保持 SQL 可读，复杂 SQL 要有索引和 explain 思路。

## DTO / VO / PO

- DTO 面向请求，不直接复用 PO。
- VO 面向响应，不泄露内部字段。
- PO/Entity 只表示数据库结构。
- 转换逻辑保持集中，避免 Controller 散落字段拼装。

## 校验和异常

- 入参用 Bean Validation：`@NotNull`、`@NotBlank`、`@Size` 等。
- 业务规则在 Service 校验。
- 统一异常处理，返回稳定错误码/错误结构。
- 不把原始异常信息直接返回给用户。

## 分页和排序

- 默认分页大小合理。
- 限制最大分页大小。
- 排序字段白名单。
- DB 分页必须稳定排序。

## 缓存

- 只有读多写少、收益明确时加缓存。
- 缓存 key 可读、稳定。
- 写操作要考虑失效策略。
- 不用缓存掩盖慢 SQL 根因。

## 异步和定时任务

- 定时任务和 MQ 消费必须幂等。
- 异步任务要有失败日志、重试或补偿方案。
- 线程池配置要有队列、拒绝策略、线程名前缀。

## 外部调用

- 设置超时。
- 明确重试条件，不盲目重试非幂等请求。
- 记录请求场景、业务 id、响应码、耗时。
- 失败要有降级、补偿或错误传播策略。

## 可观测性

- 关键链路有日志。
- 关键失败可定位用户、订单、任务、traceId。
- 需要时补指标：成功率、失败率、耗时、队列堆积。

## 完成标准

- 层次清晰。
- 事务边界明确。
- 异常、日志、分页、权限、幂等有处理。
- 能进入 `java-backend-review` 和 `pr-quality-gate`。
