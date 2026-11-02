# 底层能力接入设计文档

## 概述

本文档描述 Appless Phone 如何接入底层系统能力（地理围栏、蓝牙控制等），以及接入新底层能力时的标准流程和注意事项。

---

## 一、当前已接入的底层能力

### 1. 地理围栏（@ohos.geofence）

**用途**：基于位置的自动模式切换（到家→回家模式，到公司→公司模式）+ 离开公司自动上报车机 BBP。

**底层模块**：`@ohos.geofence`（NAPI 模块）

**接入链路**：

**链路 A — 模式切换（ENTER 事件）**：
```
用户输入"开始模式识别"
  └─ Index.ets: tryModeSetupGuideTrigger
       └─ ModeManager.subscribeHome / subscribeWork (预制坐标)
            └─ LocationSubscription.subscribe
                 └─ GeofenceApi.subscribe
                      └─ geofence.subscribe(option, callback)  ← NAPI 调用
                           └─ 底层 GeofenceService IPC
                                └─ 回调 GeofenceResponse (ENTER/EXIT)
                                     └─ LocationSubscription.handleEnter
                                          └─ ModeOrchestrator.trigger(kind)
                                               └─ 激活对应模式 + 渲染 surface
```

**链路 B — 离开公司上报车机 BBP（EXIT 事件）**：
```
geofence.subscribe 回调 GeofenceResponse (GEOFENCE_EXIT)
  └─ GeofenceApi.notify(label='公司', transition='exit')
       └─ Index.ets: registerBbpOfficeExitListener 中注册的 'bbp-office-exit' listener
            ├─ exit → reportDetectedOfficeExit
            │         └─ sendBbpOfficeExitMessage → POST {endpoint}/information-center/v1/mobile/messages
            │              └─ pollBbpOfficeExitResult (2s×15 轮询回执)
            └─ enter → reportDetectedOfficeArrival
                      └─ sendBbpOfficeArrivalReset → POST 重置车机场景
```

**关键文件**：
| 文件 | 职责 |
|------|------|
| `entry/src/main/ets/modes/triggers/GeofenceApi.ets` | NAPI 调用封装，实现 `LocationApi` 接口；`setTransitionListener` 支持多 listener 按 `listenerId` 注册 ENTER/EXIT 回调 |
| `entry/src/main/ets/modes/triggers/LocationSubscription.ets` | 围栏订阅管理 + 进入/退出分发（链路 A） |
| `entry/src/main/ets/modes/triggers/ModeGeolocationStore.ets` | 围栏坐标持久化（Preferences） |
| `entry/src/main/ets/modes/ModeManager.ets` | 模式系统入口，管理 registry + orchestrator + subscription |
| `entry/src/main/ets/pages/A2uiHome/Index.ets` | `registerBbpOfficeExitListener` 注册 BBP exit listener + 30s 节流防抖 |

**预制坐标**（v2）：
- 家：`34.152411, 108.850390`
- 公司：`34.196702, 108.834021`
- 半径：200 米

**触发方式**：
- 关键词「开始模式识别」→ 订阅家+公司围栏
- 关键词「关闭模式识别」→ 取消订阅
- 关键词「测试回家」/「测试到公司」→ 手动触发（不依赖围栏）

**权限**：
- `ohos.permission.APPROXIMATELY_LOCATION`（user_grant，运行时弹窗请求）
- `ohos.permission.ACCESS_BLUETOOTH`（user_grant，蓝牙命令时请求）

### 2. 蓝牙控制（CLI 工具）

**用途**：通过语音/文字打开/关闭蓝牙适配器。

**底层模块**：`/system/bin/cli_tool/executable/ohos-bluetoothTool`（系统 CLI 工具）

**接入链路**：
```
用户输入"打开蓝牙"
  └─ Index.ets: submitPrompt
       ├─ 检测蓝牙关键词 → requestPermissionsFromUser(ACCESS_BLUETOOTH)
       └─ callLocalModel → ReActAgentRunner
            └─ SkillMatcher.match → 命中 bluetooth/enable
                 └─ safeRunTool('cli_exec')
                      └─ CliExecTool.run
                           └─ CliRuntime.execute
                                ├─ PermissionChecker.checkAll（权限校验）
                                ├─ CommandBuilder.build（命令拼接）
                                └─ CliExecutor.exec
                                     └─ libcli_bridge.so::execute
                                          └─ popen("sh -c 'ohos-bluetoothTool enable-bt 2>&1'")
                                               └─ 底层蓝牙服务
```

**关键文件**：
| 文件 | 职责 |
|------|------|
| `entry/src/main/cpp/cli_bridge.cpp` | Native 桥接，popen 执行 shell 命令 |
| `entry/src/main/ets/native/NativeCli.ets` | 动态 import libcli_bridge.so |
| `cli_runtime/src/main/ets/CliRuntime.ets` | CLI 运行时：权限→构建→执行→结果 |
| `cli_runtime/src/main/ets/PermissionChecker.ets` | 运行时权限校验 + 请求 |
| `cli_runtime/src/main/ets/CliExecutor.ets` | 命令执行器 |
| `agent_core/src/main/ets/agent/CliExecTool.ets` | AgentTool 实现，LLM/Pre-match 调用入口 |
| `entry/src/main/resources/rawfile/skills/bluetooth/SKILL.md` | 蓝牙 Skill 定义 |

**权限**：
- `ohos.permission.ACCESS_BLUETOOTH`（user_grant，运行时弹窗请求）

---

## 二、底层能力接入排查指南

### 问题排查方法论

当底层能力调用失败时，按以下层次排查：

#### 层次 1：NAPI 模块是否加载

**现象**：`Cannot read property XXX of undefined`

**排查**：
```bash
# 查 NAPI 模块入口 .so 是否存在
hdc shell "ls /system/lib64/module/ | grep <模块名>"

# 查 syscap 是否声明
hdc shell "cat /system/etc/syscap.json" | grep "<SystemCapability>"
```

**根因**：
- NAPI 模块 .so 不在 `/system/lib64/module/`
- syscap.json 没声明对应 `SystemCapability`
- .so 里没有 `napi_module_register` 符号

**解决**：
- 放 NAPI 模块 .so 到 `/system/lib64/module/`（文件名 `lib<模块名>.z.so`）
- 在 syscap.json 加 `SystemCapability.XXX`
- 重启设备

#### 层次 2：系统服务（SA）是否注册

**现象**：NAPI 调用成功但返回非零错误码（如 `ret=60882950`）

**排查**：
```bash
# 查 SA 是否注册
hdc shell "hidumper -ls" | grep "<服务名>"

# 查服务进程是否在跑
hdc shell "ps -ef | grep <服务进程名>"
```

**根因**：系统服务 SA 没注册到 samgr

**解决**：在系统服务进程里 `AddSystemAbility(SA_ID, Service)` 注册 SA

#### 层次 3：权限是否授权

**现象**：`exit 1` + `ERR_XXX_FAILED` + `suggestion: check permission`

**排查**：
```bash
# 查 app 权限授权状态
hdc shell "bm dump -n com.example.loop" | grep -A5 "reqPermissionStates"
# 0 = PERMISSION_GRANTED, -1 = 未授权
```

**根因**：
- 权限是 `user_grant` 但没运行时请求
- 权限是 `system_grant` 但 HAP 签名不够（需要系统签名）

**解决**：
- user_grant 权限：在调用前 `requestPermissionsFromUser`
- system_grant 权限：确认 HAP 系统签名

#### 层次 4：CLI 工具本身是否可用

**现象**：`exit 1` + 工具返回 JSON 错误

**排查**：
```bash
# 用 root shell 手动执行
hdc shell "/system/bin/cli_tool/executable/<工具名> <命令> 2>&1; echo exit=$?"
```

**根因**：
- 工具 binary 不存在
- 工具内部调系统服务失败
- 重复操作（如蓝牙已开再开）

**解决**：根据工具返回的 JSON `errCode`/`suggestion` 修复

### 关键知识点

| 知识点 | 说明 |
|--------|------|
| syscap.json | 设备能力声明，决定运行时哪些 NAPI 模块可用 |
| NAPI 模块加载 | `.so` 在 `/system/lib64/module/` + syscap 声明 + `napi_module_register` |
| 权限 grant mode | `system_grant` 声明即生效；`user_grant` 需运行时弹窗 |
| `pclose()` 返回值 | 原始 waitpid 状态字，需 `WEXITSTATUS()` 解码真实退出码 |
| `requestPermissionsFromUser` | 必须在 UI 线程调用，否则静默失败 |

---

## 三、接入新底层能力的标准流程

### 场景 A：接入新的 NAPI 系统模块

1. **确认设备支持**：
   ```bash
   hdc shell "cat /system/etc/syscap.json" | grep "<SystemCapability>"
   ```
   如果没声明，需要在 syscap.json 添加 + 重启设备

2. **确认 NAPI 模块 .so 存在**：
   ```bash
   hdc shell "ls /system/lib64/module/ | grep <模块名>"
   ```
   如果不存在，需要放 .so + 重启

3. **在 app 侧封装 API**：
   - 创建 `entry/src/main/ets/<domain>/triggers/<XxxApi>.ets`
   - `import xxx from '@ohos.xxx'`
   - 实现 `subscribe`/`unsubscribe` 等方法
   - 用 try/catch 包裹 NAPI 调用，返回错误信息字符串

4. **权限处理**：
   - 在 `module.json5` 声明权限
   - 查 `PermissionDefinitions.json` 确认 grant mode
   - 如果是 `user_grant`，在调用前 `requestPermissionsFromUser`

5. **接入模式系统**（如果能力用于模式触发）：
   - 实现 `LocationApi` 接口或新建 trigger 接口
   - 在 `ModeManager` 里注册

### 场景 B：接入新的 CLI 工具

1. **确认工具可用**：
   ```bash
   hdc shell "/system/bin/cli_tool/executable/<工具名> <命令> 2>&1; echo exit=$?"
   ```

2. **创建 Skill 定义**：
   - 在 `entry/src/main/resources/rawfile/skills/<skill>/SKILL.md` 定义命令
   - 声明 `command`、`triggers`、`required_permissions`

3. **权限处理**：
   - 在 `module.json5` 声明权限
   - 如果是 `user_grant`，在 `submitPrompt` 里加关键词拦截 + `requestPermissionsFromUser`

4. **错误处理**：
   - 在 `CliExecTool.run` 里检查 stdout 的错误码，返回友好提示
   - 避免重复操作（如状态已达标）

5. **更新 `cli_bridge.cpp`**：
   - 确认 `WEXITSTATUS` 解码正确
   - stderr 通过 `2>&1` 重定向到 stdout 捕获
