# Wayfinder 最小版实施计划

> **供执行 agent 使用：** 按本计划执行时，先运行 `scripts/验证Wayfinder最小版.ps1`，确认缺口存在；每完成一项后重跑校验。

**目标：** 让跨会话、路径不清的大目标先生成本地 Markdown 地图和 frontier ticket，而不是直接进入实现。

**架构：** map 存在 `.workflow-maps/<map-id>/地图.md`，只保存低分辨率索引；每个 ticket 是独立 Markdown 文件。Wayfinder 每次只画图或解决一个已认领票据，并在进入 Java 交付前加载既有代码规范地图。

**技术栈：** Codex plugin、Markdown skill、PowerShell 静态验收。

---

## 文件职责

| 路径 | 职责 |
|---|---|
| `skills/wayfinder-workflow/SKILL.md` | 找路、建图、领票、解一票的行为约束。 |
| `assets/templates/wayfinding-map模板.md` | 本地 map 的低分辨率索引结构。 |
| `assets/templates/frontier-ticket模板.md` | 票据问题、类型、认领、阻塞和结论结构。 |
| `skills/asana-openspec-delivery/SKILL.md` | 大且模糊目标优先路由至 Wayfinder。 |
| `README.md` | 团队成员的显式调用示例。 |
| `scripts/验证Wayfinder最小版.ps1` | 静态验收地图、票据和路由合同。 |

## 执行步骤

- [x] 创建静态验收脚本并运行，确认旧状态缺少 Wayfinder 合同而失败。
- [x] 新增 map 与 ticket 模板。
- [x] 新增 `wayfinder-workflow`，明确本地路径、fog、frontier、claim、blocking、HITL/AFK 和单票约束。
- [x] 接入主交付流程与 README；保持 setup、PRD、OpenSpec、Java/SQL/DB 门禁权威。
- [x] 升级插件版本，运行静态验收、skill/plugin 结构校验和空白检查。
