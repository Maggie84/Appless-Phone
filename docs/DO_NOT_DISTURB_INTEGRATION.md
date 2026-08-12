# 系统勿扰模式接入建议

## 目标

让家模式和公司模式中的勿扰卡片能够读取并切换设备真实的系统勿扰状态，而不是只展示占位 UI。

## 当前结论

HarmonyOS SDK 中：

- `@ohos.notificationManager` 不能直接开启或关闭系统勿扰模式。
- `notificationSlot.bypassDnd` 只能控制某类应用通知是否绕过勿扰，不能切换系统勿扰状态。
- `@ohos.intelligentScene` 提供 `isDoNotDisturbEnabled()`，只能查询状态。
- `@ohos.settings` 可以读写系统设置项，但写入受保护域需要系统权限。

已调研的设置项方案：

```typescript
settings.setValueSync(
  context,
  'focus_mode_enable',
  enabled ? '1' : '0',
  'USER_SECURE'
);
```

其中：

- `1` 表示开启勿扰。
- `0` 表示关闭勿扰。
- `USER_SECURE` 是受保护的用户安全设置域。

## 已完成的代码接入

`DoNotDisturbBehavior` 已实现：

- 读取 `focus_mode_enable`。
- 点击卡片后写入 `1` 或 `0`。
- 写入成功后重新触发当前模式，刷新卡片状态。
- 写入失败时返回明确错误提示。

相关文件：

- `entry/src/main/ets/modes/behaviors/DoNotDisturbBehavior.ets`
- `entry/src/main/ets/pages/A2uiHome/Index.ets`

## 当前阻塞

向 `module.json5` 添加：

```json5
{
  "name": "ohos.permission.MANAGE_SECURE_SETTINGS"
}
```

后，HAP 安装失败：

```text
install failed due to grant request permissions failed
PermissionName: ohos.permission.MANAGE_SECURE_SETTINGS
```

SDK 权限定义：

```text
grantMode: system_grant
availableLevel: system_basic
availableType: SYSTEM
```

当前应用签名状态：

```text
appPrivilegeLevel: normal
appProvisionType: debug
```

因此普通 debug HAP 无法获得该权限。此权限不能通过 `requestPermissionsFromUser` 弹窗获得。

为保证当前版本仍能正常安装，manifest 中暂未保留 `MANAGE_SECURE_SETTINGS` 声明。

## 可行方案

### 方案一：底层提供最小能力接口（推荐）

系统侧新增最小化的勿扰控制能力：

```text
App 勿扰卡片
  -> FocusModeApi.setEnabled(true/false)
  -> 自定义 NAPI
  -> FocusModeClient
  -> 系统 SA
  -> SettingsData: focus_mode_enable
```

系统 SA 持有：

```text
ohos.permission.MANAGE_SECURE_SETTINGS
```

普通 App 不持有该高权限，只调用受控接口。系统服务应校验调用方：

- bundleName
- tokenId
- 签名
- 自定义权限

建议接口：

```typescript
interface FocusModeApi {
  isEnabled(): Promise<boolean>;
  setEnabled(enabled: boolean): Promise<boolean>;
}
```

优点：

- 最小权限原则。
- 不给普通 App 暴露任意 SettingsData 写入能力。
- 可以复用当前 geofence 的 NAPI + Client + SA 接入方式。
- 可稳定返回业务错误码。

### 方案二：系统 CLI

新增受信任 CLI：

```shell
ohos-focusModeTool get-state
ohos-focusModeTool enable
ohos-focusModeTool disable
```

CLI 自身持有系统设置权限，App 通过现有 `CliRuntime` 接入。

需要注意：

- CLI 必须校验调用者身份。
- 重复开启/关闭应返回幂等成功或明确状态提示。
- stdout 建议使用结构化 JSON。

示例：

```json
{
  "type": "result",
  "status": "success",
  "data": {
    "enabled": true
  }
}
```

### 方案三：系统签名应用

为 App 提供：

- `system_basic` 权限等级的系统证书。
- 允许 `MANAGE_SECURE_SETTINGS` 的 profile。
- 系统预置或受信任安装渠道。

然后在 manifest 中声明权限，直接使用 `settings.setValueSync`。

该方案实现简单，但给整个 App 授予宽泛系统设置写权限，权限范围大于实际需求。

### 方案四：打开系统设置页（降级）

普通应用无法直接开关时，可打开系统通知设置页，让用户手动操作。

设备设置应用：

```text
bundleName: com.huawei.hmos.settings
abilityName: com.huawei.hmos.settings.MainAbility
```

设备内部存在勿扰相关 Ability，但直接启动 `NotDisturbDialogAbility` 已验证会因权限校验失败：

```text
Error Code: 10107102
The specified process permission check failed
```

因此不能依赖设置应用内部私有 Ability。

## 不建议方案

- 直接修改 SettingsData 数据库文件。
- 将 `MANAGE_SECURE_SETTINGS` 从 system_grant 改为 user_grant。
- 使用 root/hdc 代替产品运行时权限。
- 反射或调用设置应用私有 Ability。
- 普通 debug HAP 强行声明系统权限。
- 未校验调用方的系统 CLI 或 NAPI。

## 后续验证清单

实施底层能力后，需要验证：

1. `get-state` 返回真实勿扰状态。
2. `setEnabled(true)` 后 `intelligentScene.isDoNotDisturbEnabled()` 返回 true。
3. `setEnabled(false)` 后状态恢复为 false。
4. 重复开启/关闭行为幂等。
5. App 退出后系统勿扰状态保持正确。
6. 围栏触发家/公司模式时能正确刷新卡片。
7. 非授权应用调用接口会被拒绝。
8. IPC 回调切回 JS 主线程，避免 ecma_vm 多线程 crash。

## 推荐结论

后续优先采用“自定义 NAPI + Client + 系统 SA”方案。它与当前 geofence 底层接入架构一致，权限边界清晰，也最适合长期维护。
