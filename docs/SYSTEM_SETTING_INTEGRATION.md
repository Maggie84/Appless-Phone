# 系统设置项接入 HAP 指南

## 适用场景

让 HAP（系统级应用）读取/切换设备的系统设置项，例如：

- 勿扰模式（focus_mode_enable / focus_mode_profile）
- 深色模式（ui_night_mode）
- 飞行模式
- 省电模式
- 静音模式（ringer_mode）
- 其他 settings.db 中的键值

## 前置条件

### 1. 系统签名

应用必须以**系统级应用**安装：

```text
appPrivilegeLevel: system_core 或 system_basic
isSystemApp: true
```

普通 debug 签名的应用无法获得 system_grant 类权限。

### 2. 权限声明

在 `entry/src/main/module.json5` 的 `requestPermissions` 中声明：

```json5
{
  "name": "ohos.permission.MANAGE_SETTINGS"
},
{
  "name": "ohos.permission.MANAGE_SECURE_SETTINGS"
}
```

- `MANAGE_SETTINGS`：写 `DEVICE_SHARED` / `USER_PROPERTY` 域
- `MANAGE_SECURE_SETTINGS`：写 `USER_SECURE` 域

这两个权限是 `system_grant` 类型，`availableLevel: system_basic`，普通应用安装会失败，必须系统签名。

## settings.db 结构

数据库路径：

```text
/data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db
```

三张表对应三个域：

| 表名 | 域名（domainName） | 说明 | 所需权限 |
|---|---|---|---|
| `SETTINGSDATA` | `DEVICE_SHARED` | 设备级共享设置 | `MANAGE_SETTINGS` |
| `USER_SETTINGSDATA_100` | `USER_PROPERTY` | 用户级设置 | `MANAGE_SETTINGS` |
| `USER_SETTINGSDATA_SECURE_100` | `USER_SECURE` | 用户安全设置（受保护） | `MANAGE_SECURE_SETTINGS` |

表结构：

```sql
CREATE TABLE USER_SETTINGSDATA_SECURE_100 (
  ID INTEGER PRIMARY KEY AUTOINCREMENT,
  KEYWORD TEXT NOT NULL UNIQUE,
  VALUE TEXT
);
```

列名是 `KEYWORD` 和 `VALUE`（注意不是 `KEY`）。

## 接入流程

### 第一步：确定 key 名和域

**方法**：通过系统设置 UI 手动开关目标功能，对比 settings.db 变化。

1. 用 `hdc shell` 或拉取数据库到本地，记录**关闭状态**下相关 key 的值
2. 在系统设置里手动**开启**目标功能
3. 再次查询，对比哪些 key 的值变化了

```bash
# 推送 SQL 查询脚本到设备
hdc file send query.sql /data/local/tmp/query.sql

# 执行查询
hdc shell "sqlite3 /data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db < /data/local/tmp/query.sql"
```

SQL 示例：

```sql
SELECT KEYWORD, VALUE FROM USER_SETTINGSDATA_SECURE_100
WHERE KEYWORD LIKE '%focus%' OR KEYWORD LIKE '%disturb%' OR KEYWORD LIKE '%mode%';
```

**注意**：某些 key 可能同时存在于多个域。例如勿扰模式：

- `focus_mode_enable`（secure 域）= 开关 0/1
- `focus_mode_profile`（secure 域）= profile 配置 0/1
- 两个都需要同步写入才能完整切换状态

### 第二步：代码接入

```typescript
import settings from '@ohos.settings';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'SettingBehavior';
const SETTING_KEY = 'focus_mode_enable';
const SETTING_KEY2 = 'focus_mode_profile';
const SETTING_DOMAIN = 'USER_SECURE';

class SettingBehavior {

  static async isEnabled(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const value = settings.getValueSync(context, SETTING_KEY, '0', SETTING_DOMAIN);
      hilog.info(DOMAIN, LOG_TAG, 'read value=%{public}s', value);
      return value === '1';
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      hilog.error(DOMAIN, LOG_TAG, 'read failed: %{public}s', msg);
      return false;
    }
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<boolean> {
    try {
      const value = enabled ? '1' : '0';
      // 同步写入所有相关 key
      const ok1 = settings.setValueSync(context, SETTING_KEY, value, SETTING_DOMAIN);
      const ok2 = settings.setValueSync(context, SETTING_KEY2, value, SETTING_DOMAIN);
      hilog.info(DOMAIN, LOG_TAG, 'set enabled=%{public}s ok1=%{public}s ok2=%{public}s',
        '' + enabled, '' + ok1, '' + ok2);
      return ok1 && ok2;
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      hilog.error(DOMAIN, LOG_TAG, 'set failed: %{public}s', msg);
      return false;
    }
  }
}
```

### 第三步：验证

#### 验证写入结果

抓 hilog 确认 `setValueSync` 返回值：

```bash
hdc shell "hilog | grep -E 'SetValueExecuteExt|Settings|focus_mode'"
```

关键日志行：

```text
C00501/.../Settings: SetValueExecuteExt key=focus_mode_enable, table=secure, val=1 ret=1
```

- `key`：实际写入的 key 名
- `table`：实际写入的域（secure / system / user）
- `ret`：返回值，1 = 成功

#### 验证数据库值

```bash
hdc shell "sqlite3 /data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db < /data/local/tmp/query.sql"
```

如果 sqlite3 被 WAL 锁阻止（`unable to open database file`），拉取到本地用 Node.js 读：

```bash
hdc file recv /data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db ./s.db
hdc file recv /data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db-wal ./s.db-wal
hdc file recv /data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db-shm ./s.db-shm

node --experimental-sqlite -e "const {DatabaseSync} = require('node:sqlite'); const db = new DatabaseSync('s.db'); console.log(db.prepare('SELECT KEYWORD,VALUE FROM USER_SETTINGSDATA_SECURE_100 WHERE KEYWORD=?').get('focus_mode_enable'));"
```

## 已知限制

### 系统_ui 可能不更新

直接写 `settings.db` 可以改变系统状态（如 `audio_server` 的 `doNotDisturbStatus` 会响应），但**系统 UI（下拉栏图标、状态弹框）可能不会更新**。

原因：系统 UI（sceneboard）的某些状态由对应的系统 SA（如 `IntelligentScene`）通过 eventbus 事件控制，直接写数据库不会触发这些事件。

例如勿扰模式：

- `audio_server` ✅ 响应（`doNotDisturbStatus` 变化）
- `sensors` ✅ 响应（`doNotDisturbSwitch` 变化）
- `sceneboard` 下拉栏图标 ❌ 不更新（需要 `FocusModeSwitchDataEvent` 事件）
- 系统弹框 ❌ 显示旧状态

如果需要 UI 也同步更新，必须通过 **InsightIntent 机制** 触发对应系统应用的 intent，由系统应用内部完成全部操作（写数据库 + 发事件 + 更新 UI）。

### InsightIntent 机制（UI 完整更新）

通过 AIDispatchService 执行 InsightIntent，触发系统应用（如 IntelligentScene）处理：

```text
app → AIDispatchService.executeIntent(bundleName, intentName, executeMode)
    → 系统应用内部处理：
        - 写 settings.db
        - 发 NotificationBridge eventbus 事件
        - 发 LiveView 通知
    → sceneboard 收到事件 → 更新 UI
```

**问题**：公开 SDK（`@hms.ai.insightIntent`）目前只有 `shareIntent`（注册自己的 intent），没有 `executeIntent`（执行别人的 intent）的公开 API。需要系统内部接口或 `startAbility` 触发。

## 调试工具汇总

| 工具 | 用途 |
|---|---|
| `hdc shell sqlite3` | 直接查 settings.db（可能被 WAL 锁阻止） |
| `hdc file recv` + Node.js | 拉取数据库到本地用 Node.js 读 |
| `hdc shell hilog` | 抓系统日志确认写入结果 |
| `hdc shell bm dump -n <bundle>` | 查应用权限授予状态 |
| `hdc shell "hilog -r"` | 清空日志缓冲 |

## 勿扰模式接入实例

### Key 和域

| key | 域 | 值 | 说明 |
|---|---|---|---|
| `focus_mode_enable` | USER_SECURE | `0` / `1` | 勿扰开关 |
| `focus_mode_profile` | USER_SECURE | `0` / `1` | profile 配置（需同步切换） |

### 权限

```json5
{ "name": "ohos.permission.MANAGE_SECURE_SETTINGS" }
```

### 验证过的行为

- 写入 `focus_mode_enable=1` + `focus_mode_profile=1`（secure 域）→ `ret=1`（成功）
- `audio_server` 响应：`doNotDisturbStatus = true`
- `sensors` 响应：`doNotDisturbSwitch = 1`
- 下拉栏图标：❌ 不更新（需要 IntelligentScene 的 eventbus 事件）
- 系统弹框：❌ 显示旧状态

### 完整切换需同步写入的 key

```typescript
settings.setValueSync(context, 'focus_mode_enable', value, 'USER_SECURE');
settings.setValueSync(context, 'focus_mode_profile', value, 'USER_SECURE');
```

## 其他可接入的设置项

用同样的排查方法（手动开关 → 对比数据库变化）可以找到其他设置项的 key：

| 功能 | 可能的 key | 域 |
|---|---|---|
| 深色模式 | `ui_night_mode` | USER_SECURE |
| 静音/响铃模式 | `ringer_mode` | DEVICE_SHARED |
| 省电模式 | `settings.power.smart_mode_status` | DEVICE_SHARED |
| 飞行模式 | - | - |

排查流程：

1. 记录关闭状态基线
2. 系统设置手动开启
3. 对比变化，锁定 key 和域
4. 用 `settings.setValueSync` 写入
5. 抓 hilog 确认 `ret=1`
6. 验证功能是否生效
