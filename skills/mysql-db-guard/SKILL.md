---
name: mysql-db-guard
description: Use when a task involves MySQL MCP access, AI database accounts, SQL execution, table/schema inspection, data writes, DELETE authorization, migration SQL, MyBatis SQL validation, EXPLAIN review, or database safety gates for Java/Spring/MyBatis work.
---

# MySQL DB Guard

MySQL MCP / AI 专用账号安全规则。目标：让 AI 能查库、验证 SQL、必要时写测试/UAT 数据和非破坏性 DDL，但不裸奔、不误删、不执行高危 DDL。

## 账号原则

- 使用一个专门 AI 账号，例如 `ai_agent`。
- 不使用任何人工账号。
- 密码只放环境变量或密钥管理系统，不写进 PRD、OpenSpec、代码、日志。
- 默认连接 dev/test/uat。生产环境默认只读；生产写入必须走人工变更流程。

## 推荐权限

允许：

```sql
SELECT
SHOW VIEW
EXECUTE
INSERT
UPDATE
DELETE
CREATE
ALTER
```

禁止：

```sql
DROP
TRUNCATE
GRANT OPTION
SUPER
FILE
PROCESS
SHUTDOWN
RELOAD
```

注意：MySQL 的 `ALTER` 权限无法细分到子操作。给了 `ALTER` 后，必须由 MCP/流程硬拦 `ALTER ... DROP`、删除索引、删除字段等破坏性操作。

## SQL 执行分级

### L0 直接允许

- `SHOW`
- `DESCRIBE`
- `SELECT`
- `EXPLAIN`

限制：

- 默认加结果行数上限。
- 不查询敏感字段明文，除非用户明确要求且环境允许。

### L1 需要确认

- `INSERT`
- `UPDATE`

执行前必须给出：

- SQL 原文。
- 目标库表。
- `WHERE` 条件或插入字段。
- 预估影响行数。
- 回滚方式。

### L2 强确认

- `DELETE`
- `CREATE TABLE`
- `CREATE INDEX`
- `ALTER TABLE ... ADD`
- `ALTER TABLE ... MODIFY`
- `ALTER TABLE ... ADD INDEX`

执行 `DELETE` 前必须：

- 先用 `SELECT` 预览将删除的数据。
- 给出影响行数。
- 给出完整 SQL。
- 给出回滚方案。
- 用户明确说“确认执行 DELETE”后才执行。

执行 `CREATE` / 非破坏性 `ALTER` 前必须：

- 给出完整 DDL。
- 说明目标库表、字段、索引。
- 说明是否锁表、是否影响线上读写。
- 给出回滚 SQL 或回滚步骤。
- 写入 OpenSpec 的数据库影响区。
- 用户明确说“确认执行 DDL”后才执行。

### L3 默认拒绝

- `DROP`
- `TRUNCATE`
- `ALTER TABLE ... DROP`
- `ALTER TABLE ... RENAME`
- 删除字段、删除索引、删除约束
- 无 `WHERE` 的 `UPDATE`
- 无 `WHERE` 的 `DELETE`
- `WHERE 1=1`
- 影响行数超过安全阈值的写操作

处理方式：拒绝执行，只输出风险说明和人工操作建议。

## 和 OpenSpec 的关系

涉及数据库变更时，必须写入 OpenSpec：

- 影响表。
- 影响字段。
- SQL 行为变化。
- 索引变化。
- 数据迁移方式。
- 回滚方案。
- 验证 SQL。

## 和 Java/MyBatis 的关系

评审 MyBatis SQL 时检查：

- `${}` 是否有注入风险。
- 参数绑定是否正确。
- update/delete 是否有明确 `WHERE`。
- 分页是否有稳定排序。
- 是否需要索引。
- `EXPLAIN` 是否有全表扫描风险。

## 输出格式

```text
结论：PASS / NEED_CONFIRM / BLOCKED
SQL 类型：
目标库表：
影响行数：
风险：
回滚：
下一步：
```

不要替用户绕过确认。尤其是 `DELETE`、`CREATE`、`ALTER`、生产写入。
