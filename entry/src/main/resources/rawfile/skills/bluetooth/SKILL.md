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

# Bluetooth Skill

本 Skill 汇集了与蓝牙适配器相关的 CLI 操作命令。

## 命令清单

| 命令 | 功能 | 执行命令 |
|------|------|----------|
| enable | 打开蓝牙 | ohos-bluetoothTool enable-bt |
| disable | 关闭蓝牙 | ohos-bluetoothTool disable-bt |

## 权限

- `ohos.permission.ACCESS_BLUETOOTH`

## 注意

通过 `childProcessManager.startNativeChildProcess("libcli_bridge.so:Main")` 执行。
需要系统签名或开发者设备权限。

## 重复操作报错说明

- **enable**：蓝牙已开启（STATE_TURN_ON）时再执行 enable 会返回 `ERR_BT_ENABLE_FAILED`，因为蓝牙已经是开启状态，不能重复打开。
- **disable**：蓝牙已关闭（STATE_TURN_OFF）时再执行 disable 会返回 `ERR_BT_DISABLE_FAILED`，因为蓝牙已经是关闭状态，不能重复关闭。

当用户请求的操作与当前蓝牙状态一致时，应直接告知用户"蓝牙已经是开启/关闭状态"，无需执行命令。
