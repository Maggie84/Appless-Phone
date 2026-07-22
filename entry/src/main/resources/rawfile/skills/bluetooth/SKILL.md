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
