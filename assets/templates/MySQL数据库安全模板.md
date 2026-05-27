# MySQL 数据库安全模板

用于 MySQL MCP / AI 数据库访问。原则：一个专门 AI 账号，权限够用，但危险操作必须被 MCP/流程拦住。

## AI 账号

账号建议：

```text
ai_agent
```

不要使用人工账号。不要把密码写入代码、PRD、OpenSpec、PR 描述或日志。

## 推荐授权

示例：

```sql
CREATE USER 'ai_agent'@'%' IDENTIFIED BY '<use-secret-manager>';

GRANT SELECT, SHOW VIEW, EXECUTE
ON your_db.* TO 'ai_agent'@'%';

GRANT INSERT, UPDATE, DELETE
ON your_db.* TO 'ai_agent'@'%';

GRANT CREATE, ALTER
ON your_db.* TO 'ai_agent'@'%';

FLUSH PRIVILEGES;
```

不要授予：

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

注意：`ALTER` 权限可以执行破坏性子操作。必须由 MCP/流程拦截 `ALTER TABLE ... DROP`、删除字段、删除索引、删除约束。

## 环境策略

| 环境 | 建议权限 |
|---|---|
| dev | 允许读写，DELETE 需确认 |
| test | 允许读写，DELETE 需确认 |
| uat | 允许读写，DELETE/DDL 强确认 |
| prod | 默认只读，不建议写入 |

## 执行规则

### 可直接执行

- `SHOW`
- `DESCRIBE`
- `SELECT`
- `EXPLAIN`

### 需要确认

- `INSERT`
- `UPDATE`

执行前必须展示：

- SQL 原文。
- 目标库表。
- 预估影响行数。
- 回滚方式。

### 必须强确认

- `DELETE`
- `CREATE`
- 非破坏性 `ALTER`

执行 `DELETE` 前必须先跑：

```sql
SELECT *
FROM target_table
WHERE <same condition>
LIMIT 50;
```

然后展示：

- 将删除的数据预览。
- 影响行数。
- 完整 `DELETE` SQL。
- 回滚方案。

用户明确说“确认执行 DELETE”后才允许执行。

执行 `CREATE` / 非破坏性 `ALTER` 前必须展示：

- 完整 DDL。
- 目标库表、字段、索引。
- 是否锁表、是否影响线上读写。
- 回滚 SQL 或回滚步骤。
- OpenSpec change-id。

用户明确说“确认执行 DDL”后才允许执行。

### 默认拒绝

- `DROP`
- `TRUNCATE`
- `ALTER TABLE ... DROP`
- `ALTER TABLE ... RENAME`
- 删除字段、删除索引、删除约束
- 无 `WHERE` 的 `UPDATE`
- 无 `WHERE` 的 `DELETE`
- `WHERE 1=1`
- 影响行数超过阈值的写操作

## OpenSpec 数据影响区模板

```md
## 数据库影响

- 数据库：
- 表：
- 字段：
- 索引：
- 读写 SQL：
- 是否迁移历史数据：
- 是否需要回滚：
- 验证 SQL：
- 风险：
```

## 审计建议

- 记录执行人：AI / 用户。
- 记录 Asana 任务。
- 记录 OpenSpec change-id。
- 记录 SQL、影响行数、执行时间。
- 记录确认文本。
