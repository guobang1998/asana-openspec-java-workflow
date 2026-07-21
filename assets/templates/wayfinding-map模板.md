---
id: <map-id>
status: active
# allowed status: active | ready_for_handoff | closed
repository: <仓库路径或名称>
handoff_path:
handoff_stage:
handoff_target:
created_at: <时间>
updated_at: <时间>
ready_at:
closed_at:
---

# <地图标题>

## Destination

-

## Notes

- 代码规范地图：`docs/agents/代码规范地图.md` / 不适用
- 本 map 默认只找路，不直接实现。

## Frontier

<!-- frontier-pointers: ordered-ticket-links -->
<!-- ticket-display: title-first -->

> 这里只保存按优先级排序的 ticket 链接。它是可重建的路由指针，不保存状态、claim 或 blocking；这些动态事实仍以 ticket YAML 为准。不得遗漏 Ticket index 中任何当前可执行票。

1. [<票据标题>](tickets/<ticket-id>-<标题>.md)

## Decisions so far

> 每条决定使用一个独立列表项，并且必须且只能引用一个来源 ticket。未确认决定、自由文本决定和重复章节都会被 frontier 解析器拒绝。

-

## Not yet specified

> 这里只记录尚不能精确建票的 fog，不放 ticket 链接。条目变清晰后，先建票，再删除这里的原条目。

-

## Out of scope

> 只记录已经关闭为 `out_of_scope` 的票；格式为名称链接加排除原因。

- [<票据标题>](tickets/<ticket-id>-<标题>.md) - <超出 Destination 的原因>

## Ticket index

> 此处必须覆盖 `tickets/` 下每个直接普通 Markdown 票据且恰好一次。状态、claim、blocking 以 ticket YAML 为准，不在 map 重复维护。

| Ticket | 链接 |
|---|---|
| | |
