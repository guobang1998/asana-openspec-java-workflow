---
name: sql-performance-review
description: Use whenever designing, writing, modifying, or reviewing Java/Spring/MyBatis SQL, Mapper methods, list/search/statistics/export APIs, pagination, sorting, dynamic query conditions, indexes, or data-access loops. In implementation mode, follow it as coding rules before writing SQL; in review mode, use it to review code; when the user explicitly invokes this skill/prompt, do a SQL-only review and do not expand into full PRD/OpenSpec/Java review or PR Gate unless asked.
---

# SQL Performance Review

面向 Java/Spring/MyBatis 的接口性能与 SQL 质量规则。目标：写代码时先避免慢 SQL，审查时拦住“功能能跑，但接口慢、SQL 难维护、上线后变慢查询”的实现。

本 skill 有三种模式：

- 编码模式：设计或编写 Mapper/SQL/查询接口时，先按本规则设计查询形状、分页排序、索引和证据，不等到 Review 才补救。
- 审查模式：审查已有代码或 PR 时，按本规则检查 SQL 质量和接口性能风险。
- 专项模式：用户直接点名 `sql-performance-review` 或给出 SQL 性能审查提示词时，只做 SQL/Mapper/查询接口专项审查；不要自动扩展到 PRD、OpenSpec、完整 Java Review 或 PR Gate，除非用户明确要求。

涉及真实数据库执行、DDL、数据写入、权限和回滚时，仍按 `mysql-db-guard` 执行。

## 使用时机

命中任一条件必须使用：

- 设计、编写、修改或审查 SQL / Mapper / 查询接口。
- 新增或修改 MyBatis XML / 注解 SQL / Mapper 方法。
- 新增或修改列表、搜索、筛选、统计、导出接口。
- 修改分页、排序、动态查询条件、表连接、聚合、`COUNT`。
- Service 中新增循环查库、批量查库、按行补数据逻辑。
- 新增或修改索引、字段、表结构，且查询依赖这些结构。
- PR 前发现“性能风险”“SQL 验证方式”“数据库确认”需要填写。

纯配置、纯文案、纯 DTO 字段重命名且不改变查询行为时，可以说明“不涉及 SQL 性能规则”。

## 编码模式

写代码时先遵循这些规则：

- 先确定接口类型：列表、搜索、统计、导出、详情、写操作，不同类型不要共用一坨 SQL。
- 先定分页上限、稳定排序、排序白名单，再写 SQL。
- 先看查询条件和目标数据量，再决定是否需要联合索引或 read model。
- Service 不要先写循环查库；先考虑批量查询和 Map 回填。
- 列表页只查展示字段；正文、JSON、大 text/blob 放详情接口。
- 复杂动态查询先写清条件组合和索引匹配，再落 MyBatis XML。
- 关键 SQL 写完后准备 `EXPLAIN` 或等价执行计划证据。

编码模式输出可简化为：

```text
SQL 编码规则结论：PASS / NEED_FIX / NEED_EXPLAIN
本次查询类型：
必须遵循的分页/排序：
必须避免的慢查询点：
建议 SQL / Mapper 形状：
索引和 EXPLAIN 计划：
```

## 审查模式

审查代码或 PR 时，按下面静态 SQL 规范、查询性能规则、索引匹配规则和 `EXPLAIN` 判定输出完整结论。

## 输入材料

评审前尽量收集：

- 接口：Controller 路径、Service 方法、Mapper 方法。
- SQL：最终 SQL 或 MyBatis XML 片段，动态条件说明。
- 数据：目标表、主要过滤字段、预计数据量、是否大表。
- 分页：默认 pageSize、最大 pageSize、排序字段和稳定排序规则。
- 索引：相关 DDL、已有索引、候选联合索引。
- 证据：`EXPLAIN`，或目标数据库支持的等价执行计划命令；无法连接数据库时说明原因。
- 目标：PRD/OpenSpec 是否定义响应时间、导出上限、数据范围。

缺少材料时不要假装通过；缺执行计划证据标记 `NEED_EXPLAIN`，需要改 SQL 或补索引标记 `NEED_FIX`。

## 静态 SQL 规范

发现以下问题直接列为阻断或高风险：

- 用户输入拼进 `${}`、`ORDER BY ${}`、`LIKE '%${keyword}%'` 等注入风险：P0 / BLOCKED。
- `select *` 出现在业务 SQL 中，且不是临时排障查询：P2；大表或响应接口中为 P1。
- 分页查询没有稳定排序：P1。
- 列表/搜索接口没有默认分页和最大 pageSize：P1。
- 导出接口没有数量上限、异步任务或后台文件方案：P1。
- `update/delete` 无明确 `WHERE`：P0 / BLOCKED，并交给 `mysql-db-guard`。
- 动态排序字段没有白名单：P1；若可被用户输入控制则 P0。
- Mapper XML 巨大嵌套、条件重复、字段散落难维护：P2，要求拆清查询意图或复用片段。

## 查询性能规则

重点检查：

- N+1：循环里调用 Mapper / Repository / RPC 查详情。优先批量查询、`IN` 查询、join 或 read model。
- 大字段：列表接口避免查正文、JSON、图片、附件、大 text/blob；详情接口再查。
- in-memory 分页/排序/过滤：大结果集先全查再处理为 P1。
- 深分页：`LIMIT offset,size` 面向大表和深页时要说明可接受范围；必要时改 keyset pagination。
- `COUNT(*)`：复杂 join / 大表 / 多条件统计要评估成本，可拆 count、缓存统计或异步汇总，但不能用缓存掩盖慢 SQL 根因。
- `LIKE '%keyword%'`：普通 BTree 索引不可用，需说明数据量和替代方案。
- 函数包列：`DATE(column)`、`LOWER(column)`、`CAST(column)` 等会破坏索引命中，优先改范围条件或存规范化字段。
- `OR` 条件：跨多个低选择性字段时易失索引，必要时拆 `UNION ALL` 或调整索引。
- join：确认 join 字段有索引，确认一对多不会放大行数，列表页避免无边界 join。
- group/order：`GROUP BY`、`ORDER BY` 可能触发 `Using temporary` / `Using filesort`，必须结合数据量解释。

## 索引匹配规则

检查索引时按查询形状判断，不只看“有索引”：

- 联合索引遵守最左前缀，等值条件优先，范围条件后面的列通常难继续利用。
- 常见列表查询至少覆盖：租户/店铺/归属上下文、软删除、状态、时间或排序键。
- 排序字段应尽量进入联合索引，避免大表 filesort。
- 唯一性和幂等依赖唯一索引，不只靠 Service 判断。
- 新增索引要评估写入成本、锁表风险和回滚；执行细节交给 `mysql-db-guard`。

## EXPLAIN 判定

关键 SQL 必须有执行计划证据，特别是列表、搜索、统计、导出、大表 join、复杂动态条件。

`EXPLAIN` 重点看：

- `type`：优先 `const` / `eq_ref` / `ref` / `range`；大表上 `ALL` 或 `index` 默认高风险。
- `key`：是否命中预期索引；`NULL` 要解释原因。
- `rows` / `filtered`：扫描行数是否明显大于返回规模。
- `Extra`：`Using temporary`、`Using filesort`、`Using join buffer`、`Dependent subquery` 要解释或修。

允许例外：

- 小表、字典表、枚举表，全表扫描可接受，但必须写明数据规模和增长预期。
- 管理端低频接口可以接受较慢查询，但必须有数量上限、观察点和后续优化条件。
- 无法连接数据库时，先做静态评审；高风险 SQL 没有 `EXPLAIN` 不能 PASS。

## 严重级别

```text
P0 阻塞：SQL 注入、无 WHERE 写操作、用户可控动态 SQL、可能误改/误删数据。
P1 高风险：用户可见接口可能慢、N+1、大表全扫、无分页上限、无稳定排序、关键 SQL 无 EXPLAIN。
P2 中风险：SQL 可维护性差、字段过宽、索引匹配未说明、性能证据不足但风险可控。
P3 低风险：命名、注释、局部可读性、后续可优化项。
```

## 输出格式

```text
结论：PASS / NEED_EXPLAIN / NEED_FIX / BLOCKED
接口：
SQL / Mapper：
数据量假设：
分页和排序：
索引匹配：
EXPLAIN 证据：
问题清单：
修复建议：
需要补充的测试或验证：
PR 风险说明：
```

## PR Gate 口径

- 触发本 skill 但未执行：PR Gate 必须 `BLOCKED`。
- 有 P0/P1 未修复：PR Gate 必须 `BLOCKED`。
- 高风险 SQL 缺少 `EXPLAIN`：PR Gate 必须 `BLOCKED`。
- 数据库不可访问，但静态评审已完成且只剩低风险证据缺口：PR Gate 最多 `CONDITIONAL`。
- `PASS` 需要同时满足：SQL 写法合规、分页/排序可控、索引匹配有说明、关键 SQL 有执行计划或明确低风险理由。

## 常见修复方向

- 循环查库改批量查询，并在 Service 层按 id map 回填。
- 列表 SQL 改明确列，只返回列表页需要字段。
- 大表列表补联合索引，例如归属上下文 + 软删除 + 状态 + 排序键。
- 深分页改基于游标或上一页最后一条排序键。
- 动态排序改白名单映射，不接收裸字段名。
- 复杂统计拆 read model、汇总表或异步任务；先说明一致性和刷新时机。
- `LIKE '%keyword%'` 改全文索引、搜索服务、前缀匹配或限制数据范围。
