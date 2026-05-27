---
name: java-build-fix
description: Use when Java, Maven, Gradle, Spring Boot build, compilation, dependency, annotation processor, Checkstyle, SpotBugs, PMD, or test compilation fails. Fix build errors with minimal surgical changes and rerun verification after each fix.
---

# Java Build Fix

Java 构建失败修复流程。目标：最小改动让构建恢复，不做顺手重构。

## 先判断构建工具

优先使用项目 wrapper：

```text
mvnw / mvnw.cmd
gradlew / gradlew.bat
```

再看：

```text
pom.xml
build.gradle
build.gradle.kts
settings.gradle
```

## 标准流程

1. 运行编译或用户指定命令。
2. 收集完整错误，不只看最后一行。
3. 按文件和根因分组。
4. 一次只修一个根因。
5. 用最小改动修复。
6. 重新运行同一命令验证。
7. 不引入新错误。

## 常见 Maven 命令

```powershell
.\mvnw.cmd compile
.\mvnw.cmd test
.\mvnw.cmd -DskipTests package
.\mvnw.cmd dependency:tree
```

没有 wrapper 时：

```powershell
mvn compile
mvn test
mvn dependency:tree
```

## 常见 Gradle 命令

```powershell
.\gradlew.bat compileJava
.\gradlew.bat test
.\gradlew.bat build
.\gradlew.bat dependencies
```

## 常见错误处理

| 错误 | 常见原因 | 处理 |
|---|---|---|
| `cannot find symbol` | import 缺失、类名错、依赖缺失 | 读上下文，补 import 或依赖 |
| `incompatible types` | 类型不匹配 | 修窄类型，不大改逻辑 |
| `method ... cannot be applied` | 参数数量/类型不对 | 对齐调用和方法签名 |
| `No qualifying bean` | Bean 未注册、profile 不对 | 检查注解、扫描路径、配置 |
| `BeanCreationException` | 配置缺失、依赖错误 | 看 root cause |
| Lombok/MapStruct 失败 | annotation processor 配置问题 | 检查 processor 配置 |
| dependency resolve 失败 | 仓库/版本/私服凭证 | 不猜版本，报告依赖决策 |
| Checkstyle/SpotBugs | 格式或风险规则 | 按项目规则最小修复 |

## 禁止事项

- 不为修构建做架构重写。
- 不改无关文件。
- 不隐藏错误。
- 不随便加 `@SuppressWarnings`。
- 不跳过测试来伪造成功。
- 不删除测试来让构建过。

## 停止条件

遇到这些情况要停下报告：

- 同一错误修 3 次仍失败。
- 修复导致更多错误。
- 需要新增外部依赖且版本不确定。
- 需要私服凭证或网络权限。
- 需要架构决策。

## 输出格式

```text
构建工具：
失败命令：
根因：
已修复：
剩余错误：
验证命令：
结果：
```
