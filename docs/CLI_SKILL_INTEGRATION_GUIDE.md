# 新增 CLI Skill 接入指南

本文档说明如何在 Appless-Phone 项目中接入新的 CLI 技能。整个流程不需要修改任何 ArkTS 代码，只需 3 步：编写 SKILL.md → 声明权限 → 确认 native binary。

---

## 前置条件

- 设备上已存在要调用的 native binary（如 `/system/bin/cli_tool/executable/ohos-xxxTool`）
- CLI skill 系统已部署（`cli_runtime` 模块 + `agent_core` 集成 + native bridge）

---

## 第 1 步：创建 SKILL.md

在 `entry/src/main/resources/rawfile/skills/<skill-name>/SKILL.md` 创建技能定义文件。

### 模板

```yaml
---
name: <skill-name>              # 必填，小写字母+数字+连字符，与目录名一致
description: <技能描述>          # 必填，1-1024 字符，说明技能用途
type: cli_group                  # 固定值
version: 1.0.0
schema_version: 1
commands:
  - name: <command-name>         # 命令名，如 enable / disable / status
    description: <命令描述>
    command: <完整 shell 命令>    # 如 /system/bin/cli_tool/executable/ohos-xxxTool action
    triggers:                     # 触发关键词，填了走 pre-match 快速路径；不填或空数组走 LLM 路径
      - 触发词1
      - 触发词2
    parameters: []               # 参数定义，目前一般为空
    required_permissions:         # 需要的权限列表
      - ohos.permission.XXX
    executor: shell
    risk_level: low               # low / medium / high
    timeout_ms: 10000
---

# <Skill Name> Skill

简要说明。

## 命令清单

| 命令 | 功能 | 执行命令 |
|------|------|----------|
| <command> | <描述> | <shell 命令> |

## 权限

- `ohos.permission.XXX`

## 注意

通过 `libcli_bridge.so` 执行。需要系统签名或开发者设备权限。
```

### 现有示例：bluetooth

参考 `entry/src/main/resources/rawfile/skills/bluetooth/SKILL.md`：

```yaml
---
name: bluetooth
description: 蓝牙适配器管理（打开/关闭）
type: cli_group
version: 1.0.0
schema_version: 1
commands:
  - name: enable
    description: 打开蓝牙适配器
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
    description: 关闭蓝牙适配器
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

---

## 第 2 步：声明权限

在 `entry/src/main/module.json5` 的 `requestPermissions` 数组中添加所需权限。

### system_grant 权限（安装时自动授予）

```json5
{
  "name": "ohos.permission.INTERNET"
}
```

### user_grant 权限（需要用户弹窗授权）

```json5
{
  "name": "ohos.permission.MICROPHONE",
  "reason": "$string:microphone_permission_reason",  // 必须提供 reason
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "inuse"
  }
}
```

> **注意**：`reason` 字段对应 `entry/src/main/resources/base/element/string.json` 中的字符串资源。如果没有合适的，需要新增。

### 权限类型查询

- `system_grant`：安装时自动授予，如 `INTERNET`、`GET_NETWORK_INFO`、`ACCESS_BLUETOOTH`、`GET_BUNDLE_INFO`
- `user_grant`：需要运行时弹窗，如 `MICROPHONE`、`LOCATION`、`READ_CALENDAR`、`WRITE_CALENDAR`

> 如果是 `user_grant` 权限，还需要在 `EntryAbility.onWindowStageCreate()` 中添加 `requestPermissionsFromUser()` 调用（参考 `PermissionChecker` 中的白名单也需要同步更新）。

---

## 第 3 步：确认 native binary

确保设备上存在 SKILL.md 中 `command` 字段指定的可执行文件路径。

可以通过 `hdc shell` 验证：

```bash
hdc shell ls -la /system/bin/cli_tool/executable/ohos-xxxTool
```

如果 binary 不存在：
- 需要先开发并部署对应的 native 工具到设备
- 或者使用系统已有的命令（如 `settings`、`cmd`、`am`、`pm` 等）

---

## 第 4 步：编译安装

```bash
# 设置环境变量（Windows）
$env:DEVECO_SDK_HOME = "D:\app\DevEco Studio\sdk"
$env:JAVA_HOME = "D:\app\DevEco Studio\jbr"
$env:Path = "D:\app\DevEco Studio\jbr\bin;$env:Path"

# 编译
& "D:\app\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap

# 安装到设备
hdc install "entry\build\default\outputs\default\entry-default-signed.hap"
```

---

## 自动发现机制

新增 SKILL.md 后 **不需要修改任何代码**，因为：

1. **SkillSnapshot 自动扫描**：`createSkillSnapshot(context)` 在启动时遍历 `rawfile/skills/*/SKILL.md`，解析所有技能定义
2. **SkillIndex 自动索引**：`CliRuntime.match()` 根据所有已加载技能的 `triggers` 建立关键词索引
3. **SkillMatcher 自动加载**：`initSkillSystem()` 将所有技能加载到 `SkillMatcher`，pre-match 自动生效
4. **LLM 自动可见**：`buildSkillsSection()` 将技能列表注入 LLM system prompt，LLM 路径自动可用

---

## 两种执行路径

| 路径 | 触发条件 | 响应速度 | 适用场景 |
|------|----------|----------|----------|
| **Pre-match 快速路径** | SKILL.md 声明了 `triggers` 且用户输入命中关键词 | <1 秒 | 高频、明确的命令（打开蓝牙、关闭WiFi） |
| **LLM 路径** | 未命中 triggers / 得分低 / 有歧义 | 几秒（LLM 推理） | 复杂、模糊的自然语言表达 |

### Pre-match 匹配规则

- `SkillIndex.match()` 对每个 trigger 做子串匹配
- 得分 = 匹配的 trigger 数量 / trigger 总数（归一化）
- 如果最高得分与次高得分差距 < 0.1，认为有歧义，走 LLM 路径
- 无歧义时直接执行 `cli_exec` + FINAL，跳过 LLM

### LLM 路径流程

1. LLM 看到 system prompt 中的技能列表
2. LLM 调用 `read` 工具读取 SKILL.md 全文
3. LLM 分析用户意图，选择合适的 command
4. LLM 调用 `cli_exec` 工具，传入 `{"skill":"xxx","command":"yyy","params":{}}`
5. `CliRuntime.execute()` 执行命令，返回结果

---

## 完整接入示例：WiFi 控制

假设要接入 WiFi 开关功能：

### 1. 创建 `entry/src/main/resources/rawfile/skills/wifi/SKILL.md`

```yaml
---
name: wifi
description: WiFi 适配器管理（打开/关闭）
type: cli_group
version: 1.0.0
schema_version: 1
commands:
  - name: enable
    description: 打开 WiFi
    command: /system/bin/cli_tool/executable/ohos-wifiTool enable-wifi
    triggers:
      - 打开WiFi
      - 开启WiFi
      - 开WiFi
      - turn on wifi
    parameters: []
    required_permissions:
      - ohos.permission.SET_WIFI_INFO
    executor: shell
    risk_level: low
    timeout_ms: 10000

  - name: disable
    description: 关闭 WiFi
    command: /system/bin/cli_tool/executable/ohos-wifiTool disable-wifi
    triggers:
      - 关闭WiFi
      - 关掉WiFi
      - 关WiFi
      - turn off wifi
    parameters: []
    required_permissions:
      - ohos.permission.SET_WIFI_INFO
    executor: shell
    risk_level: low
    timeout_ms: 10000
---
```

### 2. 在 `module.json5` 添加权限

```json5
{
  "name": "ohos.permission.SET_WIFI_INFO"
}
```

### 3. 确认设备上有 `ohos-wifiTool`

```bash
hdc shell ls -la /system/bin/cli_tool/executable/ohos-wifiTool
```

### 4. 编译安装

```bash
hvigorw assembleHap
hdc install entry/build/default/outputs/default/entry-default-signed.hap
```

### 5. 测试

在对话框输入"打开WiFi"，应该瞬间返回"操作已完成"。

---

## 常见问题

### Q: SKILL.md 修改后需要重新编译吗？

A: 是的。SKILL.md 在 `rawfile/` 目录下，打包进 HAP，修改后需要重新 `assembleHap` + `install`。

### Q: 如何查看 pre-match 是否命中？

A: 响应速度是最直观的指标。pre-match 命中 <1 秒返回；LLM 路径需要几秒。也可以在 DevEco Studio Logcat 过滤 `SkillMatcher` / `ReActAgentRunner` / `CliRuntime` 查看日志。

### Q: triggers 不填会怎样？

A: 不填或填空数组 `[]` 时，该命令只走 LLM 路径，LLM 会读取 SKILL.md 全文后决定是否调用。适合低频、复杂参数的命令。

### Q: 命令执行失败怎么排查？

A: 检查日志中 `CliRuntime` 的输出。常见原因：
- binary 路径不存在 → `hdc shell ls` 验证
- 权限未授予 → `PermissionChecker` 日志
- 命令本身出错 → 查看 `CliResult.toObservation()` 返回的 stderr

### Q: 如何添加 user_grant 权限的运行时请求？

A: 如果新增的技能需要 `user_grant` 权限（如 `MICROPHONE`），需要：

1. 在 `EntryAbility.ets` 的 `onWindowStageCreate()` 中添加 `requestPermissionsFromUser()` 调用
2. 在 `PermissionChecker.ets` 的白名单中添加该权限的 `checkAccessToken` 分支

（`system_grant` 权限不需要这些，安装时自动授予）

---

## 文件位置速查

| 文件 | 路径 |
|------|------|
| 技能定义 | `entry/src/main/resources/rawfile/skills/<name>/SKILL.md` |
| 权限声明 | `entry/src/main/module.json5` → `requestPermissions` |
| 权限校验 | `cli_runtime/src/main/ets/PermissionChecker.ets` |
| 运行时权限请求 | `entry/src/main/ets/entryability/EntryAbility.ets` → `onWindowStageCreate` |
| 字符串资源 | `entry/src/main/resources/base/element/string.json` |
