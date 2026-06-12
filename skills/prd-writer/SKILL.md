---
name: prd-writer
description: Use when converting an Asana requirement, product request, support ticket, or rough business idea into a Chinese PRD for Java/Spring/MyBatis delivery. Trigger before OpenSpec planning when requirements are unclear, incomplete, or need acceptance criteria.
---

# PRD Writer

把 Asana 任务、用户对话、会议纪要、线上问题、技术债想法或 brainstorming 结果整理成可评审、可实现、可验收的 PRD。默认中文；保留 Java identifiers、API 名、SQL、配置 key 原文。

## 输入

PRD 输入可以来自：

- Asana 任务。
- 用户对话。
- 会议纪要。
- brainstorming 结果。
- 线上问题定位报告。
- 技术债 / 重构想法。

优先读取：

- Asana 任务标题、描述、评论、附件摘要。
- 用户或需求人给出的背景、截图、接口、日志、报错。
- 现有代码、接口文档、数据库字段。

如果输入不是 Asana，必须在 PRD 中记录 `需求来源`、`是否已有 Asana`、`跟踪要求` 和 `待补跟踪项`。

## 输出

生成 PRD 时使用这个结构：

```md
# PRD：<需求名称>

## 基本信息
## 背景
## 目标
## 不做什么
## 需求澄清记录
## 术语表
## 用户/系统交互
## 业务规则
## 接口/API 影响
## 数据/DB 影响
## 日志/监控
## 权限/安全
## 验收标准
## 风险与回滚
## 待确认问题
```

`## 基本信息` 至少包含：

```md
- 需求来源：Asana / 用户对话 / 会议纪要 / 线上问题 / 技术债 / 其他
- 关联 Asana：
- 是否已有 Asana：是 / 否 / 待补 / 不需要
- 跟踪要求：无需跟踪 / PR 前补 / 排期前补 / 跨团队前补
- brainstorming 记录：
- 待补跟踪项：
```

## 工作规则

1. 需求不清楚时先列 `待确认问题`，不要直接写实现方案。
2. 轻量澄清可以由 `prd-writer` 在 PRD 草稿前完成，但只适用于小范围、低风险、目标基本可判断的需求。
3. 需求涉及新功能探索、方案分歧、范围不清、用户体验/业务口径或可能重构时，必须先进入正式 `superpowers:brainstorming`。
4. 如果输入来自 brainstorming，PRD 必须吸收目标、背景、范围、不做什么、推荐方案和待确认问题；未确认问题不能写成已确认需求。
5. `superpowers:brainstorming` 的输出只作为 PRD 输入，不替代 PRD / OpenSpec，也不能直接进入实现。
6. 验收标准必须可测试，避免“体验更好”“性能优化”这类空话。
7. 明确 `不做什么`，防止实现范围膨胀。
8. 涉及 DB、权限、支付、金额、状态机时，必须单独列风险。
9. 发现 PRD 和代码事实冲突时，标出冲突并建议回到需求澄清。

## 完成标准

- PRD 能直接进入 OpenSpec change。
- 验收标准覆盖主流程、异常流程、边界条件。
- 所有待确认问题有 owner 或处理建议。
