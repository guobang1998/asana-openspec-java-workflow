# Asana OpenSpec Java Workflow

面向 Java/Spring/MyBatis 后端团队的 Codex 工作流工具包。它把 Asana 需求推进为 PRD、OpenSpec change、代码实现、测试、Review 和 PR，避免 AI 只靠聊天上下文直接乱改代码。

## 解决什么问题

- 新需求没有结构化 PRD。
- AI 写代码前没有变更设计。
- AI 容易乱定位代码、漏调用链。
- Java/Spring/MyBatis 代码规范不统一。
- MySQL 写入、DDL、DELETE 缺少安全确认。
- PR 前测试和 Review 记录不完整。
- 大重构容易变成一个巨大 PR，难 Review、难回滚。

## 核心流程

```text
Asana 新需求
-> PRD md
-> OpenSpec change
-> CodeGraph 定位影响面
-> Codex 实现
-> 单测/集成/手动验证
-> Java/Security/MySQL/Quality Gate
-> PR
-> OpenSpec archive
-> Asana 完成
```

大重构走升级流程：

```text
Asana Epic
-> CodeGraph Discovery
-> 重构 RFC
-> 测试基线
-> 多个 OpenSpec changes
-> 小 PR 串行合并
-> 清理旧代码
```

完整图见：[流程图.md](./流程图.md)

## 安装给团队成员

Windows：

```powershell
git clone <repo-url> "$env:USERPROFILE\.codex\plugins\asana-openspec-java-workflow"
```

macOS / Linux：

```bash
git clone <repo-url> ~/.codex/plugins/asana-openspec-java-workflow
```

更多说明见：[团队安装指南.md](./团队安装指南.md)

## 项目接入

每个 Java 项目需要：

1. 把 [AGENTS模板.md](assets/templates/AGENTS模板.md) 合并到项目根目录 `AGENTS.md`
2. 安装并初始化 OpenSpec
3. 可选初始化 CodeGraph
4. 可选配置 Asana / GitHub Connector
5. 可选配置 MySQL MCP 和 `ai_agent`

OpenSpec：

```powershell
npm install -g @fission-ai/openspec@latest
cd <your-java-project>
openspec init
openspec config profile
openspec update
```

安装细节见：[安装配置指南.md](./安装配置指南.md)

## 最低版本

| 工具 | 最低要求 |
|---|---|
| Node.js | 20.19.0+，用于 OpenSpec |
| OpenSpec | 使用 `@fission-ai/openspec@latest` |
| CodeGraph | 使用 `@colbymchenry/codegraph` 当前版本 |
| MySQL MCP | 使用选定 server 当前稳定版本 |
| JDK / Maven / Gradle | 跟随项目仓库要求 |

没有明确语义化最低版本的工具，按“团队验证版本”锁定；升级后先用 `试运行指南.md` 跑一条小需求。

## 工具失败怎么办

不要绕过流程。OpenSpec、CodeGraph、MySQL MCP、构建/测试失败时按 [工具失败处理.md](./工具失败处理.md) 降级或暂停。

## 怎么使用

在 Codex 里说：

```text
请按 asana-openspec-java-workflow 流程处理这个 Asana 需求。
```

先生成 PRD：

```text
请使用 prd-writer，把这个需求整理成 PRD md。信息不够先列待确认问题，不要写代码。
```

PRD 确认后：

```text
PRD 已确认。请创建 OpenSpec change，并按 asana-openspec-java-workflow 推进 design/tasks/specs。
```

大重构：

```text
这是大重构。请使用 large-refactor-workflow，先做 Discovery、RFC、测试基线和 phase 拆分。
```

## Skills

| Skill | 用途 |
|---|---|
| `prd-writer` | Asana 需求转 PRD |
| `asana-openspec-delivery` | 主交付流程 |
| `large-refactor-workflow` | 大重构升级流程 |
| `codegraph-context-guard` | 代码图谱定位和影响面复查 |
| `coding-discipline` | AI 写代码纪律 |
| `java-coding-standard` | Java 编码规范 |
| `springboot-service-patterns` | Spring Boot 服务设计 |
| `springboot-security-review` | Spring Boot 安全评审 |
| `mysql-db-guard` | MySQL MCP / AI 账号安全规则 |
| `java-test-strategy` | 单测、集成、手动验证策略 |
| `java-build-fix` | Maven/Gradle 构建失败修复 |
| `java-backend-review` | Java 后端专项 Review |
| `pr-quality-gate` | PR 前质量门禁 |

## 目录结构

```text
.codex-plugin/
  plugin.json

skills/
  ...

assets/templates/
  AGENTS模板.md
  PRD模板.md
  Asana字段模板.md
  OpenSpec检查清单.md
  PR评审清单.md
  MySQL数据库安全模板.md
  重构RFC模板.md
  重构检查清单.md
  流程复盘记录模板.md

团队安装指南.md
安装配置指南.md
工具失败处理.md
团队介绍.md
试运行指南.md
流程图.md
使用说明.md
```

## 团队规则

- 需求不清楚，不写代码。
- PRD 未确认，不进入实现。
- 实现偏差时，先改 PRD/OpenSpec，再改代码。
- 每个代码改动必须对应 PRD、OpenSpec 或 `tasks.md`。
- 行为变更必须有测试，或说明不能自动化原因。
- 涉及 DB 必须写影响面、SQL、回滚方案。
- `DELETE`、`CREATE`、`ALTER` 必须确认。
- 大重构必须先写 RFC，并拆多个 OpenSpec changes。
- PR 前必须列出验证结果和未覆盖项。

## 推荐试点

第一次不要选大重构。建议选：

- 小 Bugfix
- 小接口新增
- 小字段新增
- 小查询条件优化
- 小配置/日志改动

试跑步骤见：[试运行指南.md](./试运行指南.md)

## 外部工具

本仓库不内置外部工具，需要按需安装：

- OpenSpec
- CodeGraph
- Asana Connector
- GitHub Connector
- MySQL MCP
- JDK / Maven / Gradle

安装细节见：[安装配置指南.md](./安装配置指南.md)
