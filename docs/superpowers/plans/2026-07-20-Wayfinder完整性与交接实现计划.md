# Wayfinder 完整性与交接实现计划

## 目标

在现有本地 Markdown 协议内补齐 Frontier 完整性、map 生命周期交接和 Research 来源指针门禁。

## 任务

- [x] 在 `scripts/验证Wayfinder演化.ps1` 增加遗漏 Frontier、非 active map、交接前置条件和 Research 来源/指针失败样本，先验证旧实现失败。
- [x] 扩展 `解析Frontier指针.ps1`：解析 map frontmatter、校验生命周期、以 Ticket index 计算完整 eligible 集合。
- [x] 新增 `管理Wayfinder生命周期.ps1`，实现 PrepareHandoff 与 Close 原子状态转换。
- [x] 扩展 `发布Research资产.ps1`：必填 Sources、生成来源区、幂等写回 ticket Assets。
- [x] 更新 Wayfinder skill、地图模板、README 和试运行证据。
- [x] 提升插件 cachebuster，同步个人插件源并在实际缓存目录复测。
- [x] 完成规格符合性与代码质量复审。

本次不新增 tracker 适配、Research Git 分支或 setup 泛化配置；不提交、不推送。
