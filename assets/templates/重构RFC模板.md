# 重构 RFC：<重构名称>

## 背景

为什么要重构。当前痛点是什么。

## 目标

- 目标 1：
- 目标 2：

## 不做什么

- 本次不做：

## 当前架构

### 核心入口

- 

### 调用链

```text
入口 -> Service -> Mapper -> DB
```

### 主要问题

- 

## 目标架构

### 新结构

- 

### 分层边界

- Controller：
- Service：
- Mapper/Repository：
- DTO/VO/PO：

## 影响面

| 类型 | 内容 |
|---|---|
| 接口 |  |
| Service |  |
| Mapper/SQL |  |
| DB |  |
| 权限 |  |
| 日志/监控 |  |
| 外部系统 |  |

## 兼容策略

- 是否保留旧接口：
- 是否需要 adapter/facade：
- 是否需要 feature flag：
- 是否需要双读/双写：

## 数据迁移策略

- 是否需要迁移历史数据：
- 迁移 SQL：
- 校验 SQL：
- 回滚 SQL：

## 测试基线

- Characterization tests：
- 单元测试：
- 集成测试：
- 手动验证：
- 未覆盖项：

## 分阶段计划

### Phase 0：Discovery

- 目标：
- OpenSpec change-id：
- 验证：

### Phase 1：新增兼容层/新结构

- 目标：
- OpenSpec change-id：
- 验证：

### Phase 2：迁移调用方

- 目标：
- OpenSpec change-id：
- 验证：

### Phase 3：切换默认路径

- 目标：
- OpenSpec change-id：
- 验证：

### Phase 4：删除旧代码

- 目标：
- OpenSpec change-id：
- 验证：

## 回滚方案

- 代码回滚：
- 配置回滚：
- 数据回滚：
- 灰度回滚：

## 风险

- 

## 待确认问题

- [ ] 
