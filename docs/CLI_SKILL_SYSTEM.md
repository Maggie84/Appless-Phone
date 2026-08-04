# CLI Skill System - 架构说明

## 概述

CLI Skill System 允许语音助手通过预定义的 CLI 命令执行手机操作（如打开蓝牙、开关WiFi等），采用 **hybrid 架构**：高频技能走代码 pre-match 快速路径，低频技能走 LLM 推理路径。

## 核心架构

```
用户输入 "打开蓝牙"
        │
        ▼
┌─────────────────────────────────┐
│  SkillMatcher.match("打开蓝牙")  │  ← 关键词匹配（代码预匹配）
│  → 命中 bluetooth/enable        │
│     score=0.95                  │
└──────────┬──────────────────────┘
           │ 命中且无歧义
           ▼
┌─────────────────────────────────┐
│  cli_exec(bluetooth/enable)     │  ← 跳过 LLM，直接执行
│  → PermissionChecker.checkAll()  │
│  → 执行 /system/bin/.../ohos-    │
│    bluetoothTool enable-bt       │
│  → 返回 "操作已完成"             │
└──────────┬──────────────────────┘
           │
           ▼    (如果未命中 pre-match)
          LLM  ← LLM 读取 SKILL.md → cli_exec
```

## Hybrid 路径说明

### 1. Pre-match 快速路径（代码优先）

- **触发条件**：命令的 SKILL.md 中声明了 `triggers` 关键词，且 `SkillMatcher` 匹配得分高且无歧义
- **流程**：`ReActAgentRunner.run()` → `SkillMatcher.match()` → `cli_exec` → OBSERVATION + FINAL → 返回
- **优点**：不经过 LLM 推理，<1秒返回结果

### 2. LLM 路径（兜底）

- **触发条件**：`SkillMatcher` 未命中 / 得分低 / 有歧义
- **流程**：LLM 读取 SKILL.md → 分析用户意图 → 调用 `cli_exec` → 执行命令
- **优点**：灵活，可以处理各种自然语言表达

## 文件结构

### 新模块：cli_runtime（ohpm 包 `@loop/cli-runtime`）

| 文件 | 作用 |
|------|------|
| `cli_runtime/src/main/ets/SkillIndex.ets` | 技能索引，加载所有 SKILL.md 并建立 trigger 关键词搜索树 |
| `cli_runtime/src/main/ets/CliRuntime.ets` | 运行时入口：match → PermissionChecker → CommandBuilder → CliExecutor |
| `cli_runtime/src/main/ets/PermissionChecker.ets` | 权限校验，通过 `abilityAccessCtrl.AtManager.checkAccessToken()` 做运行时检查 |
| `cli_runtime/src/main/ets/CliExecutor.ets` | 命令执行器，代理到 native `libcli_bridge.so` |
| `cli_runtime/src/main/ets/CommandBuilder.ets` | 命令构建，将 skill/command/params 拼接为完整 shell 命令 |
| `cli_runtime/src/main/ets/AuditLog.ets` | 审计日志（执行记录） |
| `cli_runtime/src/main/ets/types/CliSkill.ets` | `CliSkill` / `CliCommand` 类型定义 |
| `cli_runtime/src/main/ets/types/SkillMatch.ets` | `SkillMatch` 类，保存匹配结果（skill, command, score, triggers） |
| `cli_runtime/src/main/ets/types/CliResult.ets` | `CliResult` + `toObservation()` 输出中文友好结果 |
| `cli_runtime/src/main/ets/types/ParamSpec.ets` | 参数定义 |
| `cli_runtime/src/main/ets/types/Enums.ets` | 枚举（executor 类型、风险级别） |
| `cli_runtime/src/main/ets/types/ValidationResult.ets` | 校验结果 |

### 修改：agent_core（`@loop/agent-core`）

| 文件 | 修改内容 |
|------|----------|
| `agent_core/src/main/ets/agent/ReActAgentRunner.ets` | 新增 `SkillMatcher` 字段 + `setSkillMatcher()` + pre-match 分支（匹配成功则直接 cli_exec + FINAL）+ `buildCliExecInput()` + `safeRunTool()` |
| `agent_core/src/main/ets/agent/CliExecTool.ets` | **新文件**。AgentTool 实现，解析 JSON 输入 `{"skill":"...","command":"...","params":{}}` 并调用 `CliRuntime.execute()` |
| `agent_core/src/main/ets/agent/SkillMatcher.ets` | **新文件**。封装 `CliRuntime.match()`，提供 `loadFromSnapshot()` 批量加载技能 |
| `agent_core/src/main/ets/agent/ToolRegistry.ets` | `createConfiguredLoopToolRegistry()` 新增 `cliRuntime` 参数，注册 `CliExecTool` |
| `agent_core/src/main/ets/aiphone/LoopBackend.ets` | 注册 `CliExecTool`、`SkillReadTool`；构造 `ReActAgentRunner` 时传入 `skillSnapshot` + `setSkillMatcher()` |
| `agent_core/src/main/ets/aiphone/LoopBackendTypes.ets` | `LoopBackendRequest` 新增 `cliRuntime`/`skillSnapshot`/`skillMatcher` 字段 |
| `agent_core/src/main/ets/skill/AgentSkill.ets` | 新增 `rawFrontmatter` 字段，保存原始 frontmatter（YAML 头） |
| `agent_core/src/main/ets/skill/SkillMarkdownParser.ets` | 解析 frontmatter 并传给 AgentSkill |
| `agent_core/src/main/ets/cli/SkillAdapter.ets` | **新文件**。`adaptSkillToCli()` 将 LLM 用的 `AgentSkill` 转换为 CLI 用的 `CliSkill`（含 trigger、permissions 等元数据解析） |
| `agent_core/Index.ets` | 导出 `CliExecTool` / `SkillMatcher` / `adaptSkillToCli` |
| `agent_core/oh-package.json5` | 添加依赖 `@loop/cli-runtime: "file:../cli_runtime"` |

### 修改：entry（主应用）

| 文件 | 修改内容 |
|------|----------|
| `entry/src/main/ets/pages/A2uiHome/Index.ets` | `aboutToAppear()` 调用 `initCliRuntime()`；通过 `ensureInit()` → `getExecFn()` 获取 native exec 函数 → `new CliRuntime(ctx, execFn)` → `setCliRuntime()` → `initSkillSystem()` |
| `entry/src/main/ets/model/LocalModelClient.ets` | 新增 `_cliRuntime` / `_skillSnapshot` / `_skillMatcher` 模块级变量；导出 `setCliRuntime()` / `initSkillSystem()`；`callLocalModel()` 的 `LoopBackendRequest` 中传入三字段 |
| `entry/src/main/ets/native/NativeCli.ets` | **新文件**。动态加载 `libcli_bridge.so`，导出 `ensureInit()` / `getExecFn()` / `getError()` |
| `entry/src/main/cpp/cli_bridge.cpp` | **新文件**。NAPI 插件，`execute(string) → {stdout, stderr, exitCode}`，调用 `system()` 或 `popen()` 执行 shell 命令 |
| `entry/src/main/module.json5` | 添加 `ohos.permission.ACCESS_BLUETOOTH` 声明 |
| `entry/src/main/cpp/CMakeLists.txt` | 添加 `cli_bridge` native library 编译 |
| `entry/oh-package.json5` | 添加依赖 `@loop/cli-runtime: "file:../cli_runtime"` |

### UX 改进

| 文件 | 修改内容 |
|------|----------|
| `cli_runtime/src/main/ets/types/CliResult.ets` | `toObservation()` 输出中文友好结果：成功 → "操作已完成"，失败 → "操作失败（原因）" |
| `entry/src/main/ets/pages/A2uiHome/state/A2uiHomeState.ets` | `inputTextAfterPromptSubmit()` 返回空字符串，发送后清除输入框文字 |

## Skill 定义规范

所有技能定义在 `entry/src/main/resources/rawfile/skills/<skill-name>/SKILL.md`。

### 示例：bluetooth/SKILL.md

```yaml
---
name: bluetooth
description: 蓝牙适配器管理（打开/关闭）
type: cli_group
version: 1.0.0
commands:
  - name: enable
    description: 打开蓝牙适配器
    command: /system/bin/cli_tool/executable/ohos-bluetoothTool enable-bt
    triggers:
      - 打开蓝牙
      - 开启蓝牙
      - 开蓝牙
      - turn on bluetooth
    required_permissions:
      - ohos.permission.ACCESS_BLUETOOTH
    executor: shell
    risk_level: low
    timeout_ms: 10000
  - name: disable
    description: 关闭蓝牙适配器
    command: /system/bin/cli_tool/executable/ohos-bluetoothTool disable-bt
    triggers:
      - 关闭蓝牙
      - 关掉蓝牙
      - 关蓝牙
      - turn off bluetooth
    required_permissions:
      - ohos.permission.ACCESS_BLUETOOTH
    executor: shell
    risk_level: low
    timeout_ms: 10000
---
```

### 关键字段说明

| 字段 | 说明 |
|------|------|
| `triggers` | 触发关键词数组。填写后走 pre-match 快速路径；不填或为空数组则只走 LLM 路径 |
| `command` | 实际执行的 shell 命令 |
| `required_permissions` | 需要的权限列表，`PermissionChecker` 会在执行前做运行时检查 |
| `executor` | 执行器类型（shell / native） |
| `risk_level` | 风险等级（low / medium / high），影响 LLM 决策 |

## 添加新 Skill 的步骤

1. 创建目录 `entry/src/main/resources/rawfile/skills/<skill-name>/`
2. 编写 `SKILL.md`，包含 `commands` 定义和 `triggers`
3. 在 `module.json5` 中声明所需的 `requestPermissions`
4. 确保 native binary 路径正确（`/system/bin/cli_tool/executable/...`）
5. （如果是 `user_grant` 权限）在 `EntryAbility.requestUserGrantPermissions()` 中添加权限请求
6. 编译安装：`hvigorw assembleHap` + `hdc install`

## 权限模型

| 权限类型 | 说明 | 处理方式 |
|----------|------|----------|
| `system_grant` | 安装时自动授予 | 只需在 `module.json5` 声明 |
| `user_grant` | 需要用户弹窗授权 | `module.json5` 声明 + `EntryAbility` 运行时 `requestPermissionsFromUser()` + `PermissionChecker` 执行前校验 |

`PermissionChecker.checkAll()` 目前通过白名单映射（因 ArkTS `Permissions` 是 string literal union，无法直接传动态 string）对已知权限做运行时检查。
