---
name: setup-workflow
description: Use when a Java/Spring/MyBatis repository first adopts this workflow, lacks docs/agents/代码规范地图.md, or a user asks to work, review, or open a PR according to the repository's code standards.
---

# Setup Workflow

先发现仓库事实，再让后续需求走到正确规范。默认只读；不得默认改目标仓库、外部任务系统或 CI。

## 发现

按以下优先级读取并记录，不猜测：

1. `AGENTS.md`、`CONTRIBUTING.md`、`README.md` 和已有架构/接口文档。
2. `pom.xml`、`build.gradle*`、CI、Formatter、Checkstyle、Spotless、PMD、Sonar。
3. OpenSpec、`.codegraph/`、测试目录和可验证的构建/测试命令。
4. Controller/Service/Mapper 包结构、DTO/VO/PO、异常和日志约定。
5. 数据库、SQL、权限和接口字段权威边界；不得输出账号、密钥或生产地址真实值。

不确定的命令标记为“候选，未验证”，不能伪装成可运行命令。

## 输出

先给出：仓库画像、规则优先级、构建/测试候选、现有门禁、缺口和建议写入清单。

若 `docs/agents/代码规范地图.md` 不存在或过期，给出以下写入计划，等待用户确认：

```text
目标文件：docs/agents/代码规范地图.md
来源：<已读取的规则和工具>
变更：新增 / 更新
不会覆盖：用户自定义段落和未确认事实
```

用户确认后，基于 `assets/templates/代码规范地图模板.md` 创建或更新地图。重复运行时只更新已验证事实，不重复追加段落。

## 路由

- 用户说“按规范改”“帮我 Review”“准备 PR”，先加载代码规范地图；缺失时先执行本 skill 的只读发现。
- 地图只提供项目上下文，不替代 `AGENTS.md`、PRD、OpenSpec、CI 或现有专项 skill。
- Java 实现继续使用 `java-coding-standard`、`springboot-service-patterns`；SQL/DB/安全继续由原有专项 gate 控制。
- 需求模糊仍走澄清/PRD；setup 不替代 `prd-writer` 或 OpenSpec。

## 常见错误

- 不要把数据库字段原样放进请求 DTO；请求只表达用户意图，身份、店铺、状态、权限和派生值由后端确认。
- 不要把代码规范地图当作唯一权威；仓库规则变更后，以最新 `AGENTS.md`、CI 和已确认合同为准，并更新地图。
- 不要因缺地图跳过 Review 或 PR Gate；先记录缺口，再按现有流程继续。
