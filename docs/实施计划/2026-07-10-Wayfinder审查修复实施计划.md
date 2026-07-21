# Wayfinder 审查修复实施计划

> **供执行 agent 使用：** 先运行两份验收脚本确认失败，再一次只修复一个审查根因并回归验证。

**目标：** 消除 Wayfinder 状态歧义、票据合同缺口、路由冲突、四轴 Review 层级断裂和行为验收缺口。

**架构：** ticket YAML frontmatter 是唯一机器状态源；正文只记录问题、执行边界、结论和审计信息。主流程固定 `setup 只读发现 -> Wayfinder`，行为场景用真实 prompt 验证，不以关键字检查替代。

**技术栈：** Markdown skill、PowerShell 静态验收、Codex 子 agent 行为试运行。

---

- [x] 扩展静态验收并确认旧实现失败。
- [x] 收敛 ticket 状态源和 AC-9 可执行字段。
- [x] 重排 Java Review 四轴检查清单，并收口 PR Gate 字段权威引用。
- [x] 固定 setup/Wayfinder 优先级和 model-invoked 语义。
- [x] 增加行为验收场景，运行静态和 agent 试运行。
- [x] 升级插件版本并完成结构、格式校验。
