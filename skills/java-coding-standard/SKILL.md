---
name: java-coding-standard
description: Use when writing or reviewing Java/Spring/MyBatis code in this workflow. Covers naming, package structure, DTO/VO/PO boundaries, immutability, Optional, streams, exceptions, logging, configuration, tests, SQL performance coding rules, and local formatter precedence.
---

# Java Coding Standard

Java 编码规范。写代码时先用它，Review 时再用 `java-backend-review`。

## 优先级

1. repo 本地规则：formatter、Checkstyle、Spotless、PMD、Sonar、现有风格。
2. `AGENTS.md` 和 OpenSpec。
3. Google Java Style：格式、import、括号、命名。
4. 阿里 Java 开发手册：异常、日志、集合、并发、SQL、安全、测试。
5. 涉及 Mapper/SQL/查询接口时，先按 `sql-performance-review` 编码模式设计和实现 SQL。

## 命名

- 类名：`UpperCamelCase`。
- 方法、字段、局部变量：`lowerCamelCase`。
- 常量：`UPPER_SNAKE_CASE`，仅用于真正不可变的 `static final`。
- 包名全部小写。
- 避免拼音、中文标识、无意义缩写。
- 异常类以 `Exception` 结尾。
- POJO boolean 字段避免命名为 `isXxx`，防止框架映射歧义。

## 包结构

优先跟随项目现有结构。无既有规范时参考：

```text
config/
controller/
service/
mapper/
repository/
domain/
dto/
vo/
po/
enums/
exception/
util/
```

## 分层

- Controller：参数校验、鉴权入口、调用 Service，不写业务逻辑。
- Service：业务编排、事务边界、幂等、状态流转。
- Mapper/Repository：只做数据访问，不写业务决策。
- DTO：入参。
- VO：出参。
- PO/Entity：数据库映射。

## 注入和对象

- Spring 优先构造器注入，不用字段注入。
- 能不可变就不可变。
- 优先清晰代码，不为一个调用点抽象接口。
- 静态可变状态默认禁止。

## Null 和 Optional

- 外部输入、DB 查询、RPC 返回、Map/List 取值是 NPE 热点。
- 集合返回空集合，不返回 `null`。
- `Optional` 适合返回值，不适合作为字段或参数滥用。
- 自动拆箱前先确认非 null。

## 异常

- 不用异常做正常流程控制。
- 不吞异常。
- 捕获后必须处理、补上下文、转换或重新抛出。
- 生产代码不用 `printStackTrace()`。
- 优先业务异常和统一异常处理。

## 日志

- 使用 SLF4J，占位符日志：`log.info("xxx id={}", id)`。
- 不用 `System.out` / `System.err`。
- 失败日志要有场景、关键业务 id、异常栈。
- 不打印 token、密码、完整身份证、银行卡等敏感信息。
- 中文日志可以用，但保留 `traceId`、`client_id`、config key、字段名原文。

## 集合和 Stream

- 优先 `isEmpty()`。
- `Collectors.toMap` 必须考虑重复 key 和 null。
- 复杂嵌套 Stream 改普通循环。
- foreach 中不直接增删集合。
- 已知容量时初始化集合容量。

## SQL / MyBatis

- 设计、编写或修改 Mapper/SQL、列表、搜索、统计、导出、分页、排序时，必须先遵循 `sql-performance-review`，不是等到 Review 再补。
- 用户输入必须参数绑定。
- MyBatis 优先 `#{}`，禁止把用户输入拼到 `${}`。
- 查询明确列，避免 `select *`。
- update/delete 必须有明确 `WHERE`。
- 分页必须有稳定排序。
- 列表/搜索接口必须限制最大 pageSize，排序字段必须白名单。
- Service 不在循环里按行查库造成 N+1；先考虑批量查询和 Map 回填。
- 关键 SQL 准备 `EXPLAIN` 或目标数据库支持的等价执行计划证据。
- 金额使用 `BigDecimal` / MySQL `decimal`。

## 测试

- 行为变更必须有测试，或说明不能自动化的原因。
- 测正常流、边界、异常流。
- 测试独立、可重复，不依赖隐藏数据库状态。
- 测试命名表达业务行为。

## 完成标准

- 代码符合本地格式和项目风格。
- 改动范围小，每行改动能追溯到需求。
- 没有明显 NPE、事务、SQL、安全、日志风险。
