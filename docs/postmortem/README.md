# 流程复盘记录目录

本目录存放用户问题处理后的复盘文件。

## 命名规则

```text
docs/postmortem/<问题ID>-<问题摘要>.md
```

示例：

```text
docs/postmortem/P1-20260529-支付成功订单未更新.md
```

## 使用方式

1. 当前问题先按既有 Asana / PRD / OpenSpec / CodeGraph / 实现 / 测试 / Review / PR Gate 流程处理。
2. 根因明确后，复制 `assets/templates/流程复盘记录模板.md` 生成本目录下的复盘文件。
3. 如果属于可预防问题，把改进项追加到 `docs/improvements/工作流改进追踪.md`。
4. 交给中央 workflow 维护者前，按模板中的脱敏检查清理敏感信息。
