---
id: <ticket-id>
status: open
# allowed status: open | claimed | closed
# 创建 ticket 时必须从允许值中选择一个单值，不能保留本模板的占位写法。
type: <research | prototype | grilling | task>
interaction: <AFK | HITL>
decision_status: <not_required | pending | confirmed>
# AFK 使用 not_required；HITL 创建时使用 pending，用户显式确认后才能使用 confirmed。
confirmed_choice:
confirmed_by:
confirmed_at:
closure_kind: pending
# allowed closure_kind: pending | decision | fact | out_of_scope | superseded
closure_source_ticket:
claim: unclaimed
claimed_at:
blocked_by: []
blocks: []
created_at: <时间>
closed_at:
---

# <票据标题>

<!-- ticket-enum: choose-one -->

## Question

- 当前需要回答或解阻塞的一个问题：

## Decision packet

### 已知事实

-

### 选项

- A:
- B:

### 推荐

- 推荐选项：
- 理由与主要代价：

### 请确认

- 请回复选项 ID，或给出自定义、可执行的明确决定。

## Current slice

- 本会话完成到什么程度：

## Out of scope

- 本票明确不做什么：

## Inputs

- 依赖的前置决策、资料、权限或 ticket：

## Outputs

- 产出文件、链接、接口结论或决策：

## Acceptance

- 如何证明本票已完成：

## Notes

- 本票允许执行的边界：仅调研 / 仅原型 / 仅解阻塞 / 用户明确授权的执行范围。
- 与 PRD / OpenSpec 的关系：

## Claim

- 审计记录：

## Blocking

- 以 YAML 的 `blocked_by` 和 `blocks` 为唯一准则。

## Resolution

- 结论：
- 对地图的决策指针：

## Confirmation

- 用户原始决定：
- 补充说明：推荐与用户确认必须分开记录；本区不重复维护 YAML 状态。

## Rollback or abandon

- 放弃或回退条件：

## Assets

-
