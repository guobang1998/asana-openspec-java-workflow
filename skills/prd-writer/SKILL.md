---
name: prd-writer
description: Use when converting an Asana requirement, product request, support ticket, or rough business idea into a Chinese PRD for Java/Spring/MyBatis delivery. Trigger before OpenSpec planning when requirements are unclear, incomplete, or need acceptance criteria.
---

# PRD Writer

把 Asana 需求整理成可评审、可实现、可验收的 PRD。默认中文；保留 Java identifiers、API 名、SQL、配置 key 原文。

## 输入

优先读取：

- Asana 任务标题、描述、评论、附件摘要。
- 需求人给出的背景、截图、接口、日志、报错。
- 现有代码、接口文档、数据库字段。

## 输出

生成 PRD 时使用这个结构：

```md
# PRD：<需求名称>

## 背景
## 目标
## 不做什么
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

## 工作规则

1. 需求不清楚时先列 `待确认问题`，不要直接写实现方案。
2. 需求非常模糊、新功能探索或方案分歧较大时，可先用 `superpowers:brainstorming` 澄清目标、范围、候选方案和待确认问题；其输出只作为 PRD 输入，不替代 PRD。
3. 验收标准必须可测试，避免“体验更好”“性能优化”这类空话。
4. 明确 `不做什么`，防止实现范围膨胀。
5. 涉及 DB、权限、支付、金额、状态机时，必须单独列风险。
6. 发现 PRD 和代码事实冲突时，标出冲突并建议回到需求澄清。

## 完成标准

- PRD 能直接进入 OpenSpec change。
- 验收标准覆盖主流程、异常流程、边界条件。
- 所有待确认问题有 owner 或处理建议。
