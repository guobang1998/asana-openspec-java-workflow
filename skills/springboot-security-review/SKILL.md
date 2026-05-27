---
name: springboot-security-review
description: Use when adding or reviewing Spring Boot authentication, authorization, user input handling, API endpoints, file uploads, secrets, CORS/CSRF, rate limiting, sensitive data, SQL injection risk, or dependency security.
---

# Spring Boot Security Review

Spring Boot 安全评审。默认“后端强制校验，前端只做体验”。

## 触发场景

- 新增或修改接口。
- 登录、JWT、OAuth2、Session、SSO。
- 权限、角色、资源归属。
- 文件上传、导入导出。
- 支付、金额、订单、用户隐私。
- 新增配置、密钥、第三方接口。
- SQL、MyBatis、动态查询。

## 认证

- token 必须校验签名、过期时间、issuer/audience 等必要声明。
- Session cookie 使用 `HttpOnly`、`Secure`、合适的 `SameSite`。
- 登录失败、验证码、短信、重置密码要考虑频控。

## 授权

- 后端必须做权限校验。
- 敏感资源要校验 owner / tenant / merchant / org 归属。
- 默认拒绝，显式放行。
- 不信任前端传来的 role、userId、merchantId。

## 输入校验

- Controller DTO 使用 `@Valid`。
- 字符串长度、枚举值、金额范围、时间范围要限制。
- 文件上传校验大小、扩展名、MIME、存储路径。
- 不把用户输入拼进 SQL、路径、命令、模板。

## SQL 注入

- MyBatis 使用 `#{}` 参数绑定。
- `${}` 只允许白名单字段，例如排序字段，并且必须人工确认。
- 动态排序、动态表名、动态列名必须白名单。
- LIKE 查询要处理转义。

## CORS / CSRF

- 生产环境不使用 `*` 放开 CORS。
- Cookie/Session 型应用保留 CSRF 防护或说明原因。
- Bearer token API 可按项目策略关闭 CSRF，但要保持无状态认证。

## 密钥和配置

- 密码、token、API key 不进代码、不进日志、不进 PRD/OpenSpec。
- 配置用环境变量、密钥管理或部署平台注入。
- 示例配置只能放占位符。

## 敏感日志

- 不打印密码、token、银行卡、完整身份证、完整手机号。
- 错误响应不直接返回 `e.getMessage()` 给用户。
- 日志保留排障字段：traceId、业务 id、接口名、错误码。

## 依赖安全

- 新增依赖说明用途。
- 避免引入无人维护或高 CVE 风险依赖。
- 有安全扫描时，PR 前跑依赖检查。

## 输出格式

```text
结论：PASS / BLOCKED / NEED_FIX
认证：
授权：
输入校验：
SQL 注入：
敏感数据：
配置/密钥：
依赖：
必须修复：
```
