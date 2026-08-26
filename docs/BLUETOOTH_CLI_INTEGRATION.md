# 蓝牙 CLI 能力集成文档

## 概述

Appless Phone 的蓝牙控制能力（打开 / 关闭 / 查询状态）不是直接调用 `@ohos.bluetooth` NAPI 模块，而是通过 **CLI Skill System** 接入系统底层命令行工具 `/system/bin/cli_tool/executable/ohos-bluetoothTool` 实现的。

整个能力链路采用 **声明式 + Hybrid 架构**：

- **声明式**：蓝牙命令通过一份 `SKILL.md` 描述（命令、触发词、权限、风险等级），新增 / 修改命令**不需要改任何 ArkTS 代码**。
- **Hybrid 路径**：高频明确的命令（如「打开蓝牙」）走代码 Pre-match 快速路径，<1 秒返回；模糊表达走 LLM 兜底路径。

底层能力接入流程见 `docs/UNDERLYING_CAPABILITY_INTEGRATION.md`，CLI Skill 系统架构见 `docs/CLI_SKILL_SYSTEM.md`，新增 Skill 接入步骤见 `docs/CLI_SKILL_INTEGRATION_GUIDE.md`。本文档聚焦蓝牙能力的端到端实现。

---

## 一、端到端调用链路

用户在 A2uiHome 输入「打开蓝牙」到蓝牙适配器被打开，完整路径如下：

```
用户输入 "打开蓝牙"
   │
   ▼
entry/.../A2uiHome/Index.ets: submitPrompt()
   ├─ 关键词检测（"蓝牙" | "bluetooth"）
   │    └─ requestPermissionsFromUser([ACCESS_BLUETOOTH])   ← UI 线程运行时弹窗
   └─ callLocalModel() → ReActAgentRunner.run()
        │
        ▼
   ┌──────────────────────────────────────────────────────────┐
   │ Pre-match 路径（代码预匹配，命中即跳过 LLM）             │
   │ SkillMatcher.match("打开蓝牙")                           │
   │   → SkillIndex 关键词搜索                                │
   │   → 命中 bluetooth/enable，score=0.95，无歧义           │
   │                                                          │
   │ LLM 兜底路径（未命中 / 得分低 / 有歧义时）               │
   │ LLM 读取 SKILL.md → 分析意图 → 调用 cli_exec 工具        │
   └──────────────────────────────────────────────────────────┘
        │
        ▼
   CliExecTool.run('{"skill":"bluetooth","command":"enable","params":{}}')
        │
        ▼
   CliRuntime.execute('bluetooth', 'enable', Map)
        ├─ dedupKey = "bluetooth:enable" 防并发重复执行
        ├─ PermissionChecker.checkAll()        ← 运行时权限二次校验
        │    └─ atManager.checkAccessToken(tokenId, ACCESS_BLUETOOTH)
        │       未授权 → requestPermissionsFromUser 兜底
        ├─ CommandBuilder.build()             ← 拼接 + 校验参数 + 反注入
        │    → finalCommand = "/system/bin/cli_tool/executable/ohos-bluetoothTool enable-bt"
        └─ CliExecutor.exec(finalCommand, 10000)
             │
             ▼
        libcli_bridge.so::execute(cmd)        ← NAPI 同步调用
             │
             ▼
        cli_bridge.cpp::ExecuteSync
             └─ popen("/system/bin/sh -c '<cmd> 2>&1'", "r")
                  ├─ fgets 读全部 stdout（含被 2>&1 重定向的 stderr）
                  ├─ pclose() → WIFEXITED/WEXITSTATUS 解码真实退出码
                  └─ 返回 {stdout, exitCode, error}
                        │
                        ▼
                  系统蓝牙服务（SA / IPC）→ 物理蓝牙适配器
                        │
                        ▼
                  CliExecTool.run 拦截 stdout 错误码翻译：
                  · ERR_BT_ENABLE_FAILED  → "蓝牙已经是开启状态，不能重复打开。"
                  · ERR_BT_DISABLE_FAILED → "蓝牙已经是关闭状态，不能重复关闭。"
                        │
                        ▼
                  CliResult.toObservation()
                  · ok（exit 0）→ "操作已完成"
                  · 失败         → "操作失败（exit N）：..."
```

---

## 二、Skill 定义层（声明式）

### 2.1 文件位置

`entry/src/main/resources/rawfile/skills/bluetooth/SKILL.md`

蓝牙能力只通过一份 Markdown + YAML frontmatter 描述，没有任何 ArkTS 业务代码。

### 2.2 完整 Skill 定义

```yaml
---
name: bluetooth
description: 蓝牙适配器管理（打开/关闭）
type: cli_group
version: 1.0.0
schema_version: 1
commands:

  - name: get-state
    description: 查询蓝牙当前状态
    command: /system/bin/cli_tool/executable/ohos-bluetoothTool get-state
    triggers:
      - 蓝牙状态
      - 查看蓝牙
    parameters: []
    required_permissions:
      - ohos.permission.ACCESS_BLUETOOTH
    executor: shell
    risk_level: low
    timeout_ms: 5000

  - name: enable
    description: 打开蓝牙适配器（蓝牙已开启时不要重复执行，会报错）
    command: /system/bin/cli_tool/executable/ohos-bluetoothTool enable-bt
    triggers:
      - 打开蓝牙
      - 开启蓝牙
      - 开蓝牙
      - turn on bluetooth
    parameters: []
    required_permissions:
      - ohos.permission.ACCESS_BLUETOOTH
    executor: shell
    risk_level: low
    timeout_ms: 10000

  - name: disable
    description: 关闭蓝牙适配器（蓝牙已关闭时不要重复执行，会报错）
    command: /system/bin/cli_tool/executable/ohos-bluetoothTool disable-bt
    triggers:
      - 关闭蓝牙
      - 关掉蓝牙
      - 关蓝牙
      - turn off bluetooth
    parameters: []
    required_permissions:
      - ohos.permission.ACCESS_BLUETOOTH
    executor: shell
    risk_level: low
    timeout_ms: 10000
---
```

### 2.3 命令清单

| Skill 命令 | 功能 | 实际执行命令 | 默认超时 |
|---|---|---|---|
| `get-state` | 查询蓝牙状态 | `ohos-bluetoothTool get-state` | 5s |
| `enable` | 打开蓝牙 | `ohos-bluetoothTool enable-bt` | 10s |
| `disable` | 关闭蓝牙 | `ohos-bluetoothTool disable-bt` | 10s |

### 2.4 关键字段说明

| 字段 | 含义 |
|---|---|
| `name` | Skill 唯一标识（`bluetooth`） |
| `type` | `cli_group` 表示一组 shell 命令集合 |
| `commands[].command` | 实际执行的完整 shell 命令（绝对路径） |
| `commands[].triggers` | 触发关键词数组。**填了非空数组才会走 Pre-match 快速路径**；不填或空则只走 LLM 兜底 |
| `commands[].required_permissions` | 该命令执行前需要校验的权限列表 |
| `commands[].executor` | 执行器类型，蓝牙固定为 `shell` |
| `commands[].risk_level` | 风险等级（low/medium/high），影响 LLM 决策。蓝牙为 `low` |
| `commands[].timeout_ms` | 超时时间，CliExecutor 接收但目前未强制 kill |

### 2.5 重复操作报错约定

`ohos-bluetoothTool` 在状态已达标时会返回非零退出码和特定错误标识，文档明确约定：

- **`enable`**：蓝牙已开启（`STATE_TURN_ON`）时再执行会返回 `ERR_BT_ENABLE_FAILED`
- **`disable`**：蓝牙已关闭（`STATE_TURN_OFF`）时再执行会返回 `ERR_BT_DISABLE_FAILED`

最佳实践：当用户请求的操作与当前蓝牙状态一致时，应**直接告知用户**"蓝牙已经是开启/关闭状态"，**不执行命令**。

---

## 三、运行时层（`cli_runtime` 模块）

ohpm 包 `@loop/cli-runtime`，目录 `cli_runtime/src/main/ets/`。负责把 SKILL.md 转成可执行的命令流。

### 3.1 模块结构

| 文件 | 职责 |
|---|---|
| `SkillIndex.ets` | 加载所有 SKILL.md，建立 trigger 关键词索引；提供 `match()` 关键词搜索 |
| `CliRuntime.ets` | 运行时入口：编排 match → PermissionChecker → CommandBuilder → CliExecutor → AuditLog |
| `PermissionChecker.ets` | 运行时权限校验（基于 `abilityAccessCtrl.AtManager`） |
| `CommandBuilder.ets` | 命令构建：解析 `{{param}}` 占位符 → 类型 / 范围 / 枚举 / 正则校验 → 反注入 → shell 转义 |
| `CliExecutor.ets` | 命令执行器，代理到 native `libcli_bridge.so` |
| `AuditLog.ets` | 审计日志（按命令打开时记录） |
| `types/CliSkill.ets` | `CliSkill` / `CliCommand` 类型定义 |
| `types/SkillMatch.ets` | `SkillMatch` 类（保存 skill, command, score, matched triggers） |
| `types/CliResult.ets` | `CliResult` + `toObservation()` 中文友好输出 |
| `types/ParamSpec.ets` | 参数规格定义 |
| `types/Enums.ets` | 枚举（`CliExecutorKind`、`RiskLevel`、`ParamType` 等） |
| `types/ValidationResult.ets` | 命令构建校验结果 |

### 3.2 `CliRuntime.execute()` 流程

入口 `cli_runtime/src/main/ets/CliRuntime.ets:49`：

```
execute(skillName, commandName, params)
  │
  ├─ 1. findCommand(skillName, commandName)
  │     未找到 → 返回 CliResult.failure("unknown skill/command")
  │
  ├─ 2. dedupKey = "${skillName}:${commandName}"
  │     已在 executing Set 中 → 返回 failure("command already in progress")
  │     否则加入 Set（防并发重复执行相同命令）
  │
  ├─ 3. PermissionChecker.checkAll(command)
  │     有 missing 权限 → 返回 failure("permission denied: ...")
  │
  ├─ 4. CommandBuilder.build(command, params)
  │     校验失败 → 返回 failure("validation failed: ...")
  │     成功 → 得到 finalCommand（已转义 / 已替换占位符）
  │
  ├─ 5. CliExecutor.exec(finalCommand, command.timeoutMs)
  │     调 native CliExecFn，返回 {stdout, stderr, exitCode, durationMs}
  │
  ├─ 6. CliResult.fromExecution(stdout, stderr, exitCode, durationMs)
  │     exitCode === 0 → ok=true
  │
  ├─ 7. 若 command.audit === true → AuditLog.logResult(...)
  │
  └─ 8. finally: executing.delete(dedupKey)
```

### 3.3 `SkillIndex.match()` 关键词匹配算法

入口 `cli_runtime/src/main/ets/SkillIndex.ets:36`：

- **构建期**：`load()` 遍历所有 skill 的所有 command，建立 `commandIndex`（`skill/command` → CliCommand）和 `triggerIndex`（trigger → SkillMatch 列表）
- **匹配期**：`match(userInput)` 对每个 command 的每个 trigger 做 `input.toLowerCase().indexOf(trigger.toLowerCase()) >= 0` 子串匹配
- **打分**：`score = trigger.length / max(relevantLen, 1)`，即触发词占输入长度的比例（输入越短越像精确命令，分越高）
- **过滤**：`score >= MIN_SCORE (0.1)` 才进入候选
- **排序**：按 score 降序
- **歧义判定**：`needsTieBreak()` 检查前两名 score 差值是否 `< TIE_BREAK_DELTA (0.1)`

阈值常量：

| 常量 | 值 | 含义 |
|---|---|---|
| `MIN_SCORE` | 0.1 | 最低得分阈值，低于此分不进候选 |
| `STRONG_SCORE` | 0.5 | 强匹配阈值，≥ 此值且无歧义走 Pre-match |
| `TIE_BREAK_DELTA` | 0.1 | 前两名差值小于此值视为有歧义 |

蓝牙「打开蓝牙」这种短输入通常 score ≥ 0.95，远超 `STRONG_SCORE`，会走 Pre-match 路径。

### 3.4 `PermissionChecker` 权限校验

入口 `cli_runtime/src/main/ets/PermissionChecker.ets:24`：

由于 ArkTS 的 `Permissions` 是 **string literal union**，无法直接传动态 string，因此采用**白名单映射**：

| 声明权限 | 处理 |
|---|---|
| `ohos.permission.ACCESS_BLUETOOTH` | `checkAccessToken` + 未授权时 `requestPermissionsFromUser` 兜底 + 二次 `checkAccessToken` |
| `ohos.permission.MICROPHONE` | `checkAccessToken` |
| `ohos.permission.LOCATION` / `APPROXIMATELY_LOCATION` | `checkAccessToken` |
| `ohos.permission.READ_CALENDAR` / `WRITE_CALENDAR` | `checkAccessToken` |
| `ohos.permission.INTERNET` / `GET_NETWORK_INFO` / `GET_BUNDLE_INFO` | `checkAccessToken`（多为 system_grant） |

蓝牙权限的特殊处理：第一次 `checkAccessToken` 失败时，会主动 `requestPermissionsFromUser` 并重新检查——这是为了应对 Pre-match 路径绕过了 `Index.ets:submitPrompt` 关键词预请求的场景。

### 3.5 `CommandBuilder` 命令构建

入口 `cli_runtime/src/main/ets/CommandBuilder.ets:23`：

虽然蓝牙命令没有参数（`parameters: []`），但 CommandBuilder 支持通用流程：

1. **占位符提取**：用 `/\{\{(\w+)\}\}/g` 从 command 模板里提取参数名
2. **参数查找**：在 `command.parameters` 里找对应 `ParamSpec`
3. **值解析**：未传值时按 `required` / `defaultValue` 决定报错或使用默认值
4. **多重校验**：
   - `checkType`：NUMBER 必须 `Number.isFinite`；BOOLEAN 必须是 `true/false/1/0/yes/no`
   - `checkRange`：`spec.range` 格式 `"min-max"`，NUMBER 比值，STRING 比长度
   - `checkPattern`：正则匹配
   - `checkEnum`：枚举值校验
   - `checkInjection`：**禁止** `[;&|`$()<>]` 等 shell 元字符（防注入）
5. **Shell 转义**：NUMBER 直接转字符串；BOOLEAN 取小写；STRING 用双引号包裹并转义内部双引号 → `"value\"with\"quotes"`
6. **占位符替换**：`{{name}}` → 转义后的值

蓝牙命令无占位符，会直接返回 `ValidationResult.valid(command.command)`，finalCommand 即 SKILL.md 中声明的原命令。

### 3.6 `CliExecutor` 执行器

入口 `cli_runtime/src/main/ets/CliExecutor.ets:28`：

```typescript
async exec(command: string, _timeoutMs: number = 30000): Promise<ExecutedCommand> {
  const start = Date.now();
  try {
    const result = this.execFn(command);   // 调用注入的 native exec 函数
    return { stdout, stderr, exitCode, durationMs: Date.now() - start };
  } catch (error) {
    return { stdout: '', stderr: msg, exitCode: -1, durationMs: ... };
  }
}
```

- `CliExecFn` 类型：`(command: string) => CliOut`，是同步函数（native 内部 `popen` 同步执行）
- `_timeoutMs` 参数目前未实现强制 kill（参数名加 `_` 前缀表示未使用），依赖 native `popen` 自然结束
- 蓝牙命令超时声明 5s/10s 仅作为参考阈值

### 3.7 `CliResult.toObservation()` 友好输出

入口 `cli_runtime/src/main/ets/types/CliResult.ets:38`：

| 场景 | 输出 |
|---|---|
| `ok === true` | `"操作已完成"` |
| `ok === false && error !== null` | `"操作失败（${error}）"` + 如有 stderr 追加 `：${stderr}` |

返回给 LLM 作为 OBSERVATION，让模型自然语言转述给用户。

---

## 四、Agent 集成层（`agent_core` 模块）

ohpm 包 `@loop/agent-core`，目录 `agent_core/src/main/ets/`。负责把 CLI 能力暴露给 LLM Agent。

### 4.1 文件清单

| 文件 | 职责 |
|---|---|
| `agent/CliExecTool.ets` | **AgentTool 实现**，工具名 `cli_exec`，是 LLM / Pre-match 调用 CLI 的统一入口 |
| `agent/SkillMatcher.ets` | 封装 `CliRuntime.match()`，提供 `loadFromSnapshot()` 批量加载技能 |
| `agent/ReActAgentRunner.ets` | ReAct 循环 + Pre-match 分支（命中且无歧义 → 直接 `cli_exec` + FINAL，跳过 LLM 推理） |
| `agent/ToolRegistry.ets` | `createConfiguredLoopToolRegistry()` 新增 `cliRuntime` 参数，注册 `CliExecTool` |
| `aiphone/LoopBackend.ets` | 注册 `CliExecTool` + `SkillReadTool`；构造 `ReActAgentRunner` 时传入 `skillSnapshot` + `setSkillMatcher()` |
| `aiphone/LoopBackendTypes.ets` | `LoopBackendRequest` 新增 `cliRuntime` / `skillSnapshot` / `skillMatcher` 字段 |
| `skill/AgentSkill.ets` | 新增 `rawFrontmatter` 字段，保存原始 frontmatter（YAML 头） |
| `skill/SkillMarkdownParser.ets` | 解析 frontmatter 并传给 AgentSkill |
| `cli/SkillAdapter.ets` | `adaptSkillToCli()` 把 LLM 用的 `AgentSkill` 转成 CLI 用的 `CliSkill`（含 trigger / permissions 等元数据解析） |
| `Index.ets` | 导出 `CliExecTool` / `SkillMatcher` / `adaptSkillToCli` |

### 4.2 `CliExecTool` 工具

入口 `agent_core/src/main/ets/agent/CliExecTool.ets`：

- **工具名**：`cli_exec`
- **描述**（暴露给 LLM）：
  > Execute a CLI skill registered in cli_runtime. Input JSON: `{"skill":"<skill_name>","command":"<command_name>","params":{<param_name>:<param_value>}}`. Only skill/command pairs returned by the previous SkillMatcher suggestion are allowed.
- **输入**：JSON 字符串
- **输出**：`CliResult.toObservation()` 的字符串

**特殊处理（蓝牙专用）**：

```typescript
if (result.stdout.indexOf('ERR_BT_ENABLE_FAILED') >= 0) {
  return '蓝牙已经是开启状态，不能重复打开。';
}
if (result.stdout.indexOf('ERR_BT_DISABLE_FAILED') >= 0) {
  return '蓝牙已经是关闭状态，不能重复关闭。';
}
return obs;
```

蓝牙的"重复操作"错误通过 stdout 的错误码字符串识别，直接翻译成中文友好提示，避免把底层 `ERR_BT_*` 错误码暴露给用户。

### 4.3 Hybrid 路径决策（`ReActAgentRunner`）

| 路径 | 触发条件 | 流程 | 优点 |
|---|---|---|---|
| **Pre-match 快速路径** | `SkillMatcher.match()` 命中 + `score ≥ STRONG_SCORE (0.5)` + 无歧义（前两名差值 ≥ `TIE_BREAK_DELTA (0.1)`） | `safeRunTool('cli_exec')` → OBSERVATION + FINAL | 不经过 LLM 推理，<1s 返回 |
| **LLM 兜底路径** | 未命中 / 得分低 / 有歧义 | LLM 读 `SKILL.md`（通过 `SkillReadTool`） → 分析意图 → 调用 `cli_exec` → OBSERVATION → 继续 ReAct 循环 | 灵活，处理各种自然语言表达 |

蓝牙的 3 个命令都声明了 triggers，常见输入（"打开蓝牙"、"关闭蓝牙"、"查看蓝牙状态"）几乎都走 Pre-match 路径。

---

## 五、Native 桥接层

### 5.1 NAPI 插件

文件：`entry/src/main/cpp/cli_bridge.cpp`

`libcli_bridge.so` 是一个 NAPI 插件，导出 4 个函数：

| 函数 | 用途 |
|---|---|
| `ping()` | 健康检查，返回 `"pong"` |
| `execute(cmd)` | **CLI 命令执行**，返回 `{stdout, exitCode, error?}` |
| `dbExec(dbPath, sql)` | SQLite 执行（无返回值） |
| `dbQuery(dbPath, sql)` | SQLite 查询（返回 rows） |

蓝牙命令调用的是 `execute`。

### 5.2 `ExecuteSync` 实现细节

入口 `entry/src/main/cpp/cli_bridge.cpp:120`：

```cpp
static napi_value ExecuteSync(napi_env env, napi_callback_info info) {
  // 1. 取 JS 传入的 cmd 字符串（最大 4096 字节）
  char cmdStr[4096] = {0};
  napi_get_value_string_utf8(env, argv[0], cmdStr, sizeof(cmdStr), &len);

  // 2. 用 /system/bin/sh -c 包裹，并把 stderr 重定向到 stdout
  std::string wrappedCmd = "/system/bin/sh -c '";
  wrappedCmd += cmdStr;
  wrappedCmd += " 2>&1'";

  // 3. popen 同步执行
  FILE* fp = popen(wrappedCmd.c_str(), "r");
  std::string output;
  int exitCode = -1;
  if (fp) {
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
      output += buf;
    }
    // 4. pclose 返回 waitpid 状态字，需要解码
    exitCode = pclose(fp);
    if (WIFEXITED(exitCode)) {
      exitCode = WEXITSTATUS(exitCode);   // 正常退出 → 真实 exit code
    } else if (WIFSIGNALED(exitCode)) {
      exitCode = -WTERMSIG(exitCode);     // 被信号杀死 → 负信号号
    }
  } else {
    // popen 失败 → 返回 errno 信息
  }

  // 5. 构造 {stdout, exitCode, error?} 返回给 JS
}
```

### 5.3 关键注意点

| 点 | 说明 |
|---|---|
| **stderr 合并** | 通过 `2>&1` 把 stderr 重定向到 stdout，所以 JS 侧拿到的 `stdout` 包含错误信息（如 `ERR_BT_*` 错误码就在这里） |
| **退出码解码** | `pclose()` 返回的是原始 waitpid 状态字，必须用 `WIFEXITED` + `WEXITSTATUS` 解码才能拿到真实的 0/1 退出码。这是常见踩坑点 |
| **命令长度上限** | `cmdStr[4096]`，超过 4096 字节的命令会被截断 |
| **同步阻塞** | `popen` 同步执行，会阻塞 NAPI 线程。蓝牙 enable-bt 默认 10s 超时，期间调用方会等待 |
| **shell 注入** | ExecuteSync 本身不防注入，安全依赖 `CommandBuilder.checkInjection` 在 ArkTS 侧拦截危险字符 |

### 5.4 ArkTS 加载层

文件：`entry/src/main/ets/native/NativeCli.ets`

通过动态 import 加载 `libcli_bridge.so`，导出：

| 函数 | 用途 |
|---|---|
| `ensureInit()` | 懒加载 .so，初始化 native 引用 |
| `getExecFn()` | 返回注入到 `CliRuntime` 的 `CliExecFn`（包装 native `execute`） |
| `getError()` | 获取最近一次错误（加载失败时） |

`CliExecutor` 接收的 `CliExecFn` 即由此提供。

---

## 六、应用入口集成

### 6.1 `A2uiHome/Index.ets`

| 行 | 作用 |
|---|---|
| `:168` | 声明常量 `BLUETOOTH_PERMISSION = 'ohos.permission.ACCESS_BLUETOOTH'` |
| `:1813` | `submitPrompt` 中检测输入含「蓝牙」或「bluetooth」关键词 |
| `:1816` | 调用 `requestPermissionsFromUser(context, [BLUETOOTH_PERMISSION])` 在 UI 线程请求权限 |
| `aboutToAppear()` | 调用 `initCliRuntime()`：`ensureInit()` → `getExecFn()` → `new CliRuntime(ctx, execFn)` → `setCliRuntime()` → `initSkillSystem()` |

### 6.2 `LocalModelClient.ets`

新增模块级变量 `_cliRuntime` / `_skillSnapshot` / `_skillMatcher`，导出 `setCliRuntime()` / `initSkillSystem()`，在 `callLocalModel()` 的 `LoopBackendRequest` 中传入这三个字段，让 `ReActAgentRunner` 能拿到 CLI 能力。

### 6.3 `module.json5` 权限声明

`entry/src/main/module.json5:75`：

```json5
{
  "name": "ohos.permission.ACCESS_BLUETOOTH",
  "reason": "$string:reason_bluetooth",
  "usedScene": { ... }
}
```

蓝牙权限是 **`user_grant`**，需要在 module.json5 声明 + 运行时弹窗请求。

### 6.4 CMake 编译

`entry/src/main/cpp/CMakeLists.txt` 添加 `cli_bridge` native library 编译目标。

### 6.5 依赖声明

| 文件 | 改动 |
|---|---|
| `agent_core/oh-package.json5` | 添加依赖 `@loop/cli-runtime: "file:../cli_runtime"` |
| `entry/oh-package.json5` | 添加依赖 `@loop/cli-runtime: "file:../cli_runtime"` |

---

## 七、权限模型

### 7.1 蓝牙权限特性

| 维度 | 值 |
|---|---|
| 权限名 | `ohos.permission.ACCESS_BLUETOOTH` |
| Grant mode | `user_grant`（需运行时弹窗） |
| 申请方式 | `atManager.requestPermissionsFromUser(context, [...])` |
| 调用约束 | **必须在 UI 线程调用**，否则静默失败 |
| 校验方式 | `atManager.checkAccessToken(tokenId, perm)` 返回 `GrantStatus` |

### 7.2 三层权限保障

蓝牙权限有 3 道防线，确保任何路径调用都安全：

```
┌────────────────────────────────────────────────────────────────┐
│ 防线 1：submitPrompt 关键词预请求                              │
│ entry/.../Index.ets:1813 检测「蓝牙/bluetooth」关键词         │
│ → requestPermissionsFromUser(ACCESS_BLUETOOTH)                │
│ 适用场景：用户在 A2uiHome 直接输入"打开蓝牙"                  │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│ 防线 2：PermissionChecker.checkAll() 执行前二次校验            │
│ cli_runtime/.../PermissionChecker.ets:42                       │
│ → checkAccessToken(tokenId, ACCESS_BLUETOOTH)                  │
│ → 未授权时再 requestPermissionsFromUser 兜底                  │
│ 适用场景：Pre-match 路径绕过 submitPrompt、LLM 直接调工具     │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│ 防线 3：底层 ohos-bluetoothTool 自身权限校验                  │
│ 系统二进制会校验调用方进程的 ACCESS_BLUETOOTH                  │
│ → 未授权返回非零 exitCode + suggestion: check permission      │
│ 适用场景：兜底，万一前面两道都失效                            │
└────────────────────────────────────────────────────────────────┘
```

### 7.3 授权状态查询

```bash
# 查 app 权限授权状态
hdc shell "bm dump -n com.example.loop" | grep -A5 "reqPermissionStates"
# 0 = PERMISSION_GRANTED, -1 = 未授权
```

---

## 八、设备与签名要求

### 8.1 设备要求

通过 `childProcessManager.startNativeChildProcess("libcli_bridge.so:Main")` 执行 NAPI 插件，**需要系统签名或开发者设备权限**（见 `SKILL.md:69-70`）。

### 8.2 系统二进制可用性确认

`ohos-bluetoothTool` 是 OpenHarmony 系统镜像里的 CLI 工具，位于 `/system/bin/cli_tool/executable/`。手动测试可用性：

```bash
# 用 root shell 直接执行
hdc shell "/system/bin/cli_tool/executable/ohos-bluetoothTool get-state 2>&1; echo exit=$?"
hdc shell "/system/bin/cli_tool/executable/ohos-bluetoothTool enable-bt 2>&1; echo exit=$?"
hdc shell "/system/bin/cli_tool/executable/ohos-bluetoothTool disable-bt 2>&1; echo exit=$?"
```

确认返回 `exit=0` 即工具本身可用。如果 binary 不存在，需要检查系统镜像是否编译了对应工具。

---

## 九、排查指南

底层调用失败时按以下层次排查（完整版见 `docs/UNDERLYING_CAPABILITY_INTEGRATION.md`）：

### 9.1 排查层次

| 层次 | 现象 | 排查命令 | 根因 |
|---|---|---|---|
| 1. NAPI 模块加载 | `Cannot read property XXX of undefined` | `hdc shell "ls /system/lib64/module/ \| grep cli_bridge"` | `.so` 没打包进 HAP 或路径错误 |
| 2. 系统服务 SA | NAPI 调用成功但返回非零错误码（如 `ret=60882950`） | `hdc shell "hidumper -ls" \| grep bluetooth` | 蓝牙 SA 没注册到 samgr |
| 3. 权限授权 | `exit 1` + `ERR_*_FAILED` + `suggestion: check permission` | `hdc shell "bm dump -n com.example.loop" \| grep -A5 reqPermissionStates` | `user_grant` 权限没运行时请求 |
| 4. CLI 工具本身 | `exit 1` + 工具返回 JSON 错误 | `hdc shell "/system/bin/cli_tool/executable/ohos-bluetoothTool <cmd> 2>&1; echo exit=$?"` | binary 不存在 / 内部调系统服务失败 / 重复操作 |

### 9.2 蓝牙专项排查清单

如果用户报"打开蓝牙没反应"，按顺序：

1. **查应用日志**（DevEco Studio Logcat 过滤标签 `CliRuntime` / `CliExecutor` / `PermissionChecker` / `SkillMatcher` / `ReActAgentRunner`）
2. **查 SkillMatcher 是否命中**：日志应有 `CliRuntime: exec bluetooth/enable exit=0 duration=...`
   - 没有这条 → Pre-match 未命中，检查 LLM 是否调用了 `cli_exec`（看 ReActAgent 日志）
3. **查权限是否已授权**：`hdc shell "bm dump -n com.example.loop" | grep BLUETOOTH`
4. **手动执行命令**：`hdc shell "/system/bin/cli_tool/executable/ohos-bluetoothTool enable-bt 2>&1; echo exit=$?"`
   - `exit=0` → 工具正常，问题在 app 调用链
   - `exit=1` + `ERR_BT_ENABLE_FAILED` → 蓝牙已开启，应直接告知用户而非执行命令
   - `exit=1` + `suggestion: check permission` → 权限未授权
   - binary 不存在 → 系统镜像未编译此工具

### 9.3 常见错误码

| stdout 错误码 | 含义 | CliExecTool 翻译 |
|---|---|---|
| `ERR_BT_ENABLE_FAILED` | 蓝牙已开启，enable 重复执行 | "蓝牙已经是开启状态，不能重复打开。" |
| `ERR_BT_DISABLE_FAILED` | 蓝牙已关闭，disable 重复执行 | "蓝牙已经是关闭状态，不能重复关闭。" |
| `suggestion: check permission` | 权限未授权 | CliResult.toObservation → "操作失败（exit 1）：..." |

---

## 十、扩展：新增类似 CLI 能力的步骤

蓝牙能力的实现模式可以复用。新增一个类似能力（如 WiFi、手电筒、屏幕亮度）只需 3 步（详见 `docs/CLI_SKILL_INTEGRATION_GUIDE.md`）：

1. **编写 SKILL.md**：在 `entry/src/main/resources/rawfile/skills/<skill-name>/SKILL.md` 创建文件，声明 `commands` + `triggers` + `required_permissions`
2. **声明权限**：在 `entry/src/main/module.json5` 的 `requestPermissions` 添加新权限
3. **确认 native binary**：用 `hdc shell ls -la /system/bin/cli_tool/executable/ohos-xxxTool` 确认系统二进制存在

如果权限是 `user_grant`，额外需要在 `entry/src/main/ets/pages/A2uiHome/Index.ets:submitPrompt` 加关键词拦截 + `requestPermissionsFromUser`，并在 `cli_runtime/src/main/ets/PermissionChecker.ets` 的白名单映射里加新权限分支。

**无需修改任何 ArkTS 业务代码**——`SkillIndex` 会自动索引新 Skill，`CliRuntime` 自动执行新命令。

---

## 十一、关键文件索引

按调用顺序排列的完整文件清单：

| 层 | 文件 | 行 | 作用 |
|---|---|---|---|
| Skill 定义 | `entry/src/main/resources/rawfile/skills/bluetooth/SKILL.md` | - | 蓝牙 skill 声明 |
| 应用入口 | `entry/src/main/ets/pages/A2uiHome/Index.ets` | `:168` | BLUETOOTH_PERMISSION 常量 |
| 应用入口 | `entry/src/main/ets/pages/A2uiHome/Index.ets` | `:1813` | submitPrompt 关键词检测 |
| 应用入口 | `entry/src/main/ets/pages/A2uiHome/Index.ets` | `:1816` | requestPermissionsFromUser |
| 应用入口 | `entry/src/main/ets/pages/A2uiHome/Index.ets` | `aboutToAppear` | initCliRuntime() |
| 应用入口 | `entry/src/main/ets/model/LocalModelClient.ets` | - | setCliRuntime / initSkillSystem |
| Native 加载 | `entry/src/main/ets/native/NativeCli.ets` | - | 动态加载 libcli_bridge.so |
| Native 桥接 | `entry/src/main/cpp/cli_bridge.cpp` | `:120` | ExecuteSync（popen 执行） |
| Native 编译 | `entry/src/main/cpp/CMakeLists.txt` | - | cli_bridge 编译目标 |
| 权限声明 | `entry/src/main/module.json5` | `:75` | ACCESS_BLUETOOTH 声明 |
| Agent 工具 | `agent_core/src/main/ets/agent/CliExecTool.ets` | `:21` | cli_exec 工具 run() |
| Agent 工具 | `agent_core/src/main/ets/agent/CliExecTool.ets` | `:56-61` | 蓝牙错误码翻译 |
| Agent 工具 | `agent_core/src/main/ets/agent/SkillMatcher.ets` | - | match 封装 |
| Agent Runner | `agent_core/src/main/ets/agent/ReActAgentRunner.ets` | - | Pre-match 分支 |
| Agent Backend | `agent_core/src/main/ets/aiphone/LoopBackend.ets` | - | 注册工具 + 注入 matcher |
| Skill Adapter | `agent_core/src/main/ets/cli/SkillAdapter.ets` | - | AgentSkill → CliSkill |
| CLI 运行时 | `cli_runtime/src/main/ets/CliRuntime.ets` | `:49` | execute() 入口 |
| CLI 运行时 | `cli_runtime/src/main/ets/SkillIndex.ets` | `:36` | match() 关键词搜索 |
| CLI 运行时 | `cli_runtime/src/main/ets/PermissionChecker.ets` | `:24` | checkAll() 权限校验 |
| CLI 运行时 | `cli_runtime/src/main/ets/CommandBuilder.ets` | `:23` | build() 命令构建 |
| CLI 运行时 | `cli_runtime/src/main/ets/CliExecutor.ets` | `:28` | exec() 执行代理 |
| CLI 运行时 | `cli_runtime/src/main/ets/types/CliResult.ets` | `:38` | toObservation() |
| CLI 运行时 | `cli_runtime/src/main/ets/AuditLog.ets` | - | 审计日志 |
| 模块导出 | `agent_core/Index.ets` | - | 导出 CliExecTool 等 |
| 模块导出 | `cli_runtime/Index.ets` | - | 导出 CliRuntime 等 |
| 依赖声明 | `agent_core/oh-package.json5` | - | 依赖 @loop/cli-runtime |
| 依赖声明 | `entry/oh-package.json5` | - | 依赖 @loop/cli-runtime |

---

## 十二、相关文档

| 文档 | 内容 |
|---|---|
| `docs/CLI_SKILL_SYSTEM.md` | CLI Skill System 整体架构、Hybrid 路径、文件结构、Skill 定义规范 |
| `docs/CLI_SKILL_INTEGRATION_GUIDE.md` | 新增 CLI Skill 的接入指南（3 步流程 + 示例） |
| `docs/UNDERLYING_CAPABILITY_INTEGRATION.md` | 底层系统能力（地理围栏、蓝牙等）接入设计、排查方法论、新能力接入流程 |
| `docs/SYSTEM_SETTING_INTEGRATION.md` | 系统设置类能力集成（参考实现） |
| `docs/DO_NOT_DISTURB_INTEGRATION.md` | 勿扰模式集成（参考实现） |
