---
name: codegraph-context-guard
description: Use when a repository has CodeGraph initialized or the task needs accurate codebase navigation, impact analysis, call-chain tracing, symbol lookup, architecture exploration, or prevention of AI mis-locating Java/Spring/MyBatis code. Prefer CodeGraph context before grep/read loops when .codegraph exists.
---

# CodeGraph Context Guard

CodeGraph 使用规则。目标：让 AI 先看知识图谱，再动代码，减少乱定位、漏调用链、误判影响面。

## 定位

CodeGraph 是外部 MCP/CLI，不属于本插件本体。本 skill 只定义使用纪律。

## 什么时候必须用

项目存在 `.codegraph/`，且任务满足任一条件：

- 陌生模块。
- 跨 Controller / Service / Mapper。
- 涉及接口入口、权限、事务、SQL、状态流转。
- 要找“谁调用了这个方法”。
- 要判断“改这个会影响哪里”。
- 要写 OpenSpec design/tasks。
- PR 前要复查影响面。

## 什么时候可以不用

- 用户明确给出文件和方法。
- 单文件小改动。
- 注释、文案、格式等无行为变化。

即使不用，也要在最终说明中讲清楚为什么影响面明确。

## 查询顺序

优先：

```text
context   -> 了解任务相关区域
search    -> 找 symbol / class / method
callers   -> 查谁调用它
callees   -> 查它调用谁
impact    -> 改动前后影响面
node      -> 看单个 symbol 详情
files     -> 看目录/文件结构
```

避免上来全仓库 `grep + read`。

## CodeGraph 降级策略

当没有 `.codegraph/`、索引过期、工具不可用或结果明显不足时，按顺序降级：

1. CodeGraph：`.codegraph/` 存在且索引健康。
   - `codegraph_context`：确认入口、关键类、影响面。
   - `codegraph_trace`：确认调用链。
   - `codegraph_impact`：确认改动影响。
2. 手动追踪：CodeGraph 不可用时。
   - 用 `rg` / `find`(bash) 或 `Get-ChildItem`(PowerShell) 搜索函数名、类名、接口路径、SQL id。
   - 逐文件读取入口、调用方、被调用方。
   - 记录“未用 CodeGraph，可能遗漏”的风险。
3. 人工 Review：代码量大或影响面仍不确定时。
   - PR 标记 `[NEEDS-MANUAL-REVIEW]`。
   - 要求资深开发者复查影响面。

降级时必须说明：

- 为什么降级。
- 用了什么替代方式。
- 仍然不确定的影响面。

## OpenSpec 前

写 `design.md` / `tasks.md` 前必须确认：

- 入口类/方法。
- 主要调用链。
- 受影响 Service/Mapper/配置。
- 是否涉及 DB、权限、日志、外部接口。
- 需要测试的影响面。

## 实现前

输出简短定位摘要：

```text
入口：
调用链：
影响文件：
风险点：
需要验证：
```

## 实现后

PR 前复查：

- 本次改动影响了哪些 callers/callees。
- 是否有遗漏调用路径。
- 是否需要补测试。
- 是否需要更新 OpenSpec 或 PR 描述。

## Stale Index

如果 CodeGraph 结果明显过期：

- 先提示需要更新索引。
- 不用过期结果做最终依据。
- 可以用文件读取临时兜底，但要说明已兜底。

## 输出要求

不要说“我看过代码图谱”这种空话。必须给出：

- 查到的入口。
- 关键调用链。
- 影响面。
- 使用的定位方式：CodeGraph / 手动追踪 / 人工 Review。
- 仍需人工确认的点。
