# Asana OpenSpec Java Workflow

面向 Java/Spring/MyBatis 后端团队的多入口需求 + OpenSpec + Codex 工作流工具包。它把来自 Asana、用户对话、会议纪要、线上问题或技术债的需求推进为 PRD、OpenSpec change、代码实现、测试、Review 和 PR，避免 AI 只靠聊天上下文直接乱改代码。

## 解决什么问题

- 需求来源很多，但没有统一入口路由。
- 新需求没有结构化 PRD。
- AI 写代码前没有变更设计。
- AI 容易乱定位代码、漏调用链。
- Java/Spring/MyBatis 代码规范不统一。
- MySQL 写入、DDL、DELETE 缺少安全确认。
- PR 前测试和 Review 记录不完整。
- 大重构容易变成一个巨大 PR，难 Review、难回滚。

## 核心流程

```text
需求入口（Asana / 用户对话 / 会议纪要 / 线上问题 / 技术债）
-> 入口路由判断
-> 明确需求：PRD md
-> 模糊需求：轻量澄清 / 按条件进入 superpowers:brainstorming
-> 新功能探索 / 方案分歧：superpowers:brainstorming
-> PRD 确认
-> OpenSpec 既有规格 / active changes 检查
-> OpenSpec change
-> CodeGraph 定位影响面
-> 分段审核基础判断（风险等级 / 是否建议高风险复查）
-> 可选 Superpowers writing-plans（仅复杂实现 / 多文件多步骤）
-> Codex 实现
-> 单测/集成/手动验证
-> 必要时高风险复查（只审范围、边界、风险和证据）
-> Java/Security/MySQL/Quality Gate
-> PR
-> OpenSpec archive
```

核心结论：

- Asana 是需求跟踪入口之一，不是唯一入口。
- 模糊需求必须先 brainstorming；轻量澄清或正式 `superpowers:brainstorming` 的输出只作为 PRD 输入。
- 没有 Asana 可以启动需求澄清和 PRD 草稿；没有确认 PRD / OpenSpec 不进入行为变更实现。

反馈闭环走补充流程，不替代主交付流程：

```text
用户问题
-> AI 初步定位并让用户确认根因和处理模式
-> 按既有流程修复 / 生成 PRD-OpenSpec / 只调查
-> 验证当前问题
-> 生成 docs/postmortem/<问题ID>-<问题摘要>.md
-> 追加 docs/improvements/工作流改进追踪.md
-> 判断是否升级中央 workflow
```

大重构走升级流程：

```text
重构入口（Asana Epic / 技术债 / 架构治理）
-> CodeGraph Discovery
-> 重构 RFC
-> 测试基线
-> phase 拆分 + 实现前边界声明
-> 分段审核基础判断
-> 询问是否启用多 agent
-> 确认 worker 数量和分工
-> 多个 OpenSpec changes
-> phase 出口分段审核
-> 必要时高风险复查
-> 可选 Claude review
-> 小 PR 串行合并
-> 清理旧代码
```

Superpowers 只作为辅助节点，不替代主交付流程：

```text
需求模糊 / 新功能探索
-> 必须先澄清目标、范围和方案
-> 小范围低风险可做轻量澄清；范围不清、方案分歧、新功能探索必须调用 superpowers:brainstorming
-> 输出作为 PRD 输入

PRD / OpenSpec 已确认，且实现复杂
-> 可调用 superpowers:writing-plans 拆文件、步骤、测试和提交节奏
-> 输出作为 OpenSpec tasks / 实现计划补充
```

完整图见：[流程图.md](./流程图.md)

## 安装给团队成员

Windows：

```powershell
git clone <repo-url> "$env:USERPROFILE\plugins\asana-openspec-java-workflow"
# 首次安装前先按 团队安装指南.md 创建 personal marketplace
codex plugin add asana-openspec-java-workflow@personal
```

macOS / Linux：

```bash
git clone <repo-url> ~/plugins/asana-openspec-java-workflow
# 首次安装前先按 团队安装指南.md 创建 personal marketplace
codex plugin add asana-openspec-java-workflow@personal
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
请按 asana-openspec-java-workflow 多入口需求路由处理这个需求。它可能来自 Asana、用户对话、会议纪要、线上问题或技术债想法；如果需求模糊，先澄清，不要写代码。
```

先生成 PRD：

```text
请使用 prd-writer，把这个需求整理成 PRD md。信息不够先列待确认问题，不要写代码。
```

没有 Asana 的会议/对话需求：

```text
这不是 Asana 任务，是会议里提到的想法。请先生成 PRD 草稿，记录需求来源和待确认问题，不要写代码。
```

PRD 确认后：

```text
PRD 已确认。请创建 OpenSpec change，并按 asana-openspec-java-workflow 推进 design/tasks/specs。
```

需求模糊或新功能探索时：

```text
这个需求还不清楚。请先用 superpowers:brainstorming 辅助澄清目标、范围和候选方案，产物只作为 PRD 输入，不直接进入实现。
```

实现复杂或多文件多步骤时：

```text
PRD 和 OpenSpec 已确认。这个实现较复杂，请用 superpowers:writing-plans 辅助拆执行计划，并保持计划服务于 OpenSpec tasks。
```

大重构：

```text
这是大重构。请使用 large-refactor-workflow，先做 Discovery、RFC、测试基线和 phase 拆分。
```

多 agent 大重构：

```text
这是大重构。请先评估是否启用多 agent 协作；如果建议启用，请给出 worker 数量、分工、并发数、Claude 是否参与和预计成本，等我确认后再启动。
```

## Skills

下表是本插件随包提供的 skills。团队成员需要把插件 clone 到本地插件源码目录，创建 personal marketplace，并执行 `codex plugin add asana-openspec-java-workflow@personal` 后，skill 名称才会在新会话中暴露。

插件 skills 在 Codex 可用清单里通常带插件前缀，例如 `asana-openspec-java-workflow:coding-discipline`。表中为文档简称；实际提示词优先使用带前缀名称。

如果当前会话提示“没有名为 xxx 的 skill”，先检查插件安装位置；仍不可用时，按项目 `AGENTS.md` 中对应规则执行，不要跳过 PRD / OpenSpec / CodeGraph / 测试 / PR Gate。

| Skill | 用途 |
|---|---|
| `prd-writer` | 多入口需求转 PRD |
| `asana-openspec-java-workflow:asana-openspec-delivery` | 主交付流程 |
| `large-refactor-workflow` | 大重构升级流程 |
| `codegraph-context-guard` | 代码图谱定位和影响面复查 |
| `asana-openspec-java-workflow:coding-discipline` | AI 写代码纪律 |
| `java-coding-standard` | Java 编码规范 |
| `springboot-service-patterns` | Spring Boot 服务设计 |
| `springboot-security-review` | Spring Boot 安全评审 |
| `mysql-db-guard` | MySQL MCP / AI 账号安全规则 |
| `java-test-strategy` | 单测、集成、手动验证策略 |
| `java-build-fix` | Maven/Gradle 构建失败修复 |
| `java-backend-review` | Java 后端专项 Review |
| `pr-quality-gate` | PR 前质量门禁 |

## Superpowers 使用规则

Superpowers 是辅助技能，不是本 workflow 的主流程。

- 模糊需求、新功能探索、方案分歧较大时，brainstorming 是一等入口；输出只作为 PRD 输入。
- 轻量澄清适用于小范围、低风险、目标基本可判断的模糊需求，只输出目标、范围、不做什么、待确认问题，并进入 PRD 草稿。
- 正式 `superpowers:brainstorming` 适用于新功能探索、方案分歧较大、用户体验/业务口径不清、范围不清、可能演化成重构的需求。
- 轻量澄清和正式 `superpowers:brainstorming` 都不能直接进入实现。
- PRD / OpenSpec 已确认，且实现涉及多文件、多步骤、复杂测试或回滚策略时，可使用 `superpowers:writing-plans`；输出只作为 OpenSpec `tasks.md` 和实现计划补充。
- 紧急止血、明确 bugfix、小范围配置或文档调整，不强制使用 `superpowers:brainstorming`。
- Superpowers 产物和已确认 PRD / OpenSpec 冲突时，以 PRD / OpenSpec 为准；必要时先更新主流程文档，再改代码。

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
  Claude代码审查任务单.md
  OpenSpec检查清单.md
  PR评审清单.md
  分段审核与高风险复查试运行记录.md
  MySQL数据库安全模板.md
  重构RFC模板.md
  重构检查清单.md
  多Agent重构任务单.md
  workflow-config.yaml
  manifest.md
  task-metadata.yaml
  task-log.jsonl
  result-metadata.yaml
  dependencies.md
  worker-status.md
  decisions.md
  merge-log.md
  冲突解决决策记录.md
  流程复盘记录模板.md

docs/
  workflow/
    大需求分段审核与高风险复查协议.md
  postmortem/
    README.md
  improvements/
    工作流改进追踪.md
  多Agent重构协作方案.md

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
- 需求入口不限于 Asana，也可以来自用户对话、会议纪要、线上问题、技术债或新功能探索。
- 没有 Asana 可以启动需求澄清；需要团队协作、排期或跨团队跟踪时，应后补 Asana。
- PRD 未确认，不进入实现。
- 创建或更新 OpenSpec change 前，先查既有 specs、active changes、历史 PRD/Asana/会议纪要/问题记录，确认不破坏旧验收标准。
- `design.md` 必须写明本次变更与既有规格/历史需求的关系。
- PR 前必须填写分段审核基础判断；B 类、A 类或大重构按条件补扩展字段。
- 高风险复查按风险触发，不按工具触发；Claude 只是可选承载方式。
- 实现偏差时，先改 PRD/OpenSpec，再改代码。
- 每个代码改动必须对应 PRD、OpenSpec 或 `tasks.md`。
- 行为变更必须有测试，或说明不能自动化原因。
- 生产问题、重大漏检、回归测试遗漏或 PR 被 revert 时，先解决当前问题，再生成复盘记录和改进追踪。
- 涉及 DB 必须写影响面、SQL、回滚方案。
- `DELETE`、`CREATE`、`ALTER` 必须确认。
- 大重构必须先写 RFC，并拆 phase / tasks。
- 大重构必须评估是否启用多 agent 协作，并询问用户确认。
- 启用多 agent 后，必须再确认 worker 数量、角色、并发数和 Claude 是否参与。
- Superpowers 只按条件触发，不能跳过 PRD / OpenSpec / CodeGraph / 测试 / PR Gate。
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
- Asana Connector：可选；用于需求跟踪、负责人、优先级、排期和状态流转。
- GitHub Connector
- MySQL MCP
- Superpowers skills：可选。只用于需求澄清和复杂实现拆计划，不替代本 workflow。
- JDK / Maven / Gradle
- `cc-plugin-codex`：可选。团队成员需要在 Codex App 中使用 Claude Code 审查时单独安装；本 workflow 不打包该插件。

安装细节见：[安装配置指南.md](./安装配置指南.md)
