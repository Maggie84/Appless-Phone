# 模式框架设计文档

## 概述

Appless Phone 的模式框架是一个独立的、可扩展的模式系统，用于根据场景（到家、到公司等）自动激活一组预设行为，并在主界面渲染对应的卡片式 UI。

---

## 一、架构总览

```
┌─────────────────────────────────────────────────────────┐
│                     Index.ets (UI 层)                    │
│  submitPrompt                                            │
│    ├─ tryModeTestTrigger    (手动测试触发)                │
│    ├─ tryModeSetupGuideTrigger (关键词订阅/取消围栏)      │
│    └─ callLocalModel → ReActAgent (LLM 路径)             │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              ModeManager (模式系统入口)                   │
│  ├─ ModeRegistry      (模式注册表)                       │
│  ├─ ModeOrchestrator  (模式编排器：触发/退出/渲染)        │
│  └─ LocationSubscription (围栏订阅管理)                  │
│       └─ LocationApi (接口)                              │
│            └─ GeofenceApi (实现：@ohos.geofence)         │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              HtmlModeHomeRenderer (渲染层)               │
│  intent = "mode-<kind>"                                  │
│  渲染 hero + source 主题卡片                              │
└─────────────────────────────────────────────────────────┘
```

## 二、核心概念

### ModeKind

模式的唯一标识，枚举类型。

```typescript
// agent_core/src/main/ets/agent/ModeKind.ets
export enum ModeKind {
  HOME = 'home',
  WORK = 'work',
}
```

### ModeDefinition

模式定义，包含模式名、显示名、行为列表、围栏坐标。

```typescript
// entry/src/main/ets/modes/core/ModeDefinition.ets
export class ModeDefinition {
  readonly kind: ModeKind;
  readonly displayName: string;      // "回家模式"
  readonly description: string;     // "已到家，切换到放松模式"
  readonly behaviors: ModeBehavior[];
  readonly geoFence: GeoFence;
}
```

### ModeBehavior

模式行为，模式激活时执行的一个动作，返回 `A2uiGenericToolResultData[]`（卡片数据）。

```typescript
// entry/src/main/ets/modes/core/ModeBehavior.ets
export interface ModeBehavior {
  readonly name: string;          // "music-recommend"
  readonly displayName: string;   // "推荐舒缓音乐"
  execute(ctx: ModeContext): Promise<ModeBehaviorResult>;
}
```

`ModeBehaviorResult` 包含 `toolResults: A2uiGenericToolResultData[]`，每个 toolResult 渲染为一张卡片。

### ModeOrchestrator

模式编排器，负责触发模式、执行所有行为、构建 surface、渲染。

```
trigger(kind) 流程:
  1. 查 registry 找 ModeDefinition
  2. 遍历 behaviors，逐个 execute
  3. 收集所有 toolResults
  4. buildModeSurface(构建 A2uiSurfaceState)
  5. surfaceCallback(surface) → 渲染到主页
```

### LocationSubscription

围栏订阅管理，监听进入/退出事件，分发到 orchestrator。

```
geofence 回调 ENTER
  └─ LocationSubscription.handleEnter(kind)
       ├─ 如果已激活该模式 → skip
       ├─ 如果激活了别的模式 → onExit() 先退出
       └─ onEnter(kind) → orchestrator.trigger(kind)
```

---

## 三、当前已实现的模式

### 回家模式（HOME）

| 属性 | 值 |
|------|-----|
| kind | `ModeKind.HOME` |
| displayName | 回家模式 |
| 围栏 | 家坐标，半径 200m |

**行为列表**：

| 行为 | 文件 | 卡片内容 |
|------|------|----------|
| MusicRecommendBehavior | `behaviors/MusicRecommendBehavior.ets` | B站 + YouTube 音乐推荐（含播放器） |
| SmartHomeControlBehavior | `behaviors/SmartHomeControlBehavior.ets` | 智能家电控制卡片 |
| DoNotDisturbBehavior | `behaviors/DoNotDisturbBehavior.ets` | 勿扰开关卡片 |

**定义文件**：`entry/src/main/ets/modes/definitions/HomeMode.ets`

### 到公司模式（WORK）

| 属性 | 值 |
|------|-----|
| kind | `ModeKind.WORK` |
| displayName | 到公司模式 |
| 围栏 | 公司坐标，半径 200m |

**行为列表**：

| 行为 | 文件 | 卡片内容 |
|------|------|----------|
| CheckEmailBehavior | `behaviors/CheckEmailBehavior.ets` | 邮件检查卡片（含刷新按钮） |
| DoNotDisturbBehavior | `behaviors/DoNotDisturbBehavior.ets` | 勿扰开关卡片 |

**定义文件**：`entry/src/main/ets/modes/definitions/WorkMode.ets`

---

## 四、渲染层

### HtmlModeHomeRenderer

模式专属渲染器，当 surface 的 `intent` 为 `mode-<kind>` 时触发。

**文件**：`entry/src/main/ets/pages/A2uiHome/html/HtmlModeHomeRenderer.ets`

**渲染结构**：
```
hero 区域
  ├─ 模式标题 + 描述
  └─ 统计数据（音乐/家电/勿扰/邮件数量）

卡片列表（按 source 主题色）
  ├─ 哔哩哔哩 (data-source=bilibili)  → 粉色主题 + 播放器
  ├─ YouTube (data-source=youtube)    → 红色主题 + iframe 播放器
  ├─ 智能家电 (data-source=home)       → 绿色主题
  ├─ 勿扰 (data-source=dnd)           → 紫色主题
  └─ 邮件 (data-source=mail)          → 蓝色主题
```

**分发入口**：`HtmlHomeRenderer.ets` → `shouldRenderModeHomeDocument` / `renderModeHomeDocument`

**HtmlHomeKind**：`HtmlHomeTypes.ets` 中 `HtmlHomeKind` 包含 `'mode'`

---

## 五、触发方式

### 1. 关键词触发（围栏订阅）

| 关键词 | 动作 |
|--------|------|
| 开始模式识别 / 开启模式识别 / 识别模式 | 订阅家+公司围栏（预制坐标） |
| 关闭模式识别 / 取消模式识别 / 取消订阅 | 取消家+公司围栏订阅 |

**代码**：`Index.ets` → `tryModeSetupGuideTrigger`

### 2. 手动测试触发

| 关键词 | 动作 |
|--------|------|
| 测试回家 / 回家模式 | 手动激活回家模式（不依赖围栏） |
| 测试到公司 / 测试公司 / 到公司模式 | 手动激活公司模式（不依赖围栏） |

**代码**：`Index.ets` → `tryModeTestTrigger` → `modeManager.manualTrigger(kind)`

### 3. 围栏自动触发

围栏订阅后，设备进入围栏范围 → 底层 `geofence.subscribe` 回调 → `LocationSubscription.handleEnter` → `orchestrator.trigger(kind)`

---

## 六、新增模式指南

以新增「健身房模式」（gym）为例：

### 步骤 1：添加 ModeKind

```typescript
// agent_core/src/main/ets/agent/ModeKind.ets
export enum ModeKind {
  HOME = 'home',
  WORK = 'work',
  GYM = 'gym',        // ← 新增
}
```

### 步骤 2：创建行为

在 `entry/src/main/ets/modes/behaviors/` 下新建行为文件：

```typescript
// entry/src/main/ets/modes/behaviors/WorkoutMusicBehavior.ets
import { A2uiGenericToolResultData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';

export class WorkoutMusicBehavior implements ModeBehavior {
  readonly name = 'workout-music';
  readonly displayName = '运动音乐';

  async execute(_ctx: ModeContext): Promise<ModeBehaviorResult> {
    const toolResult: A2uiGenericToolResultData = {
      sourceTag: '运动音乐',
      toolName: 'workout-music',
      title: '高强度运动歌单',
      status: 'success',
      summary: '节拍 140-160 BPM',
      rows: [
        { label: '歌单', value: '硬核运动歌单' },
        { label: 'BPM', value: '140-160' },
      ],
      rawPreview: '',
      actions: [],
    };

    return {
      ok: true,
      message: '运动音乐已准备',
      toolResults: [toolResult],
    };
  }
}
```

### 步骤 3：创建模式定义

在 `entry/src/main/ets/modes/definitions/` 下新建：

```typescript
// entry/src/main/ets/modes/definitions/GymMode.ets
import { ModeDefinition } from '../core/ModeDefinition';
import { ModeKind, GeoFence } from '../core/ModeTypes';
import { WorkoutMusicBehavior } from '../behaviors/WorkoutMusicBehavior';
import { DoNotDisturbBehavior } from '../behaviors/DoNotDisturbBehavior';

export function createGymMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.GYM,
    '健身房模式',
    '已到健身房，切换到运动模式',
    [
      new WorkoutMusicBehavior(),
      new DoNotDisturbBehavior(),
    ],
    fence
  );
}
```

### 步骤 4：注册到 ModeManager

在 `ModeManager.ets` 添加：

```typescript
import { createGymMode } from './definitions/GymMode';

// registerDefaultModes() 里添加：
this.registry.register(createGymMode({ latitude: 0, longitude: 0, radiusMeters: 200, label: '健身房' }));

// 添加 subscribeGym 方法：
subscribeGym(latitude: number, longitude: number, radius: number = 200): string {
  const fence: GeoFence = { latitude, longitude, radiusMeters: radius, label: '健身房' };
  this.registry.register(createGymMode(fence));
  return this.subscription.subscribe(ModeKind.GYM, fence);
}
```

### 步骤 5：添加触发关键词

在 `Index.ets` 的 `tryModeSetupGuideTrigger` 里添加关键词和坐标：

```typescript
if (lower.indexOf('开始模式识别') >= 0 || ...) {
  // ...
  const GYM_LAT = 34.19;
  const GYM_LNG = 108.83;
  const gymResult = await this.modeGuideSubscribeCoord(ModeKind.GYM, GYM_LAT, GYM_LNG);
  // ...
}
```

在 `tryModeTestTrigger` 里添加测试触发：

```typescript
const isGym = lower.indexOf('测试健身房') >= 0 || lower.indexOf('健身房模式') >= 0;
```

### 步骤 6：GeofenceApi 的 toPointType

`GeofenceApi.toPointType` 依赖围栏 label 匹配 `ModeKind`。新模式的 label 需要在 `toPointType` 里加映射：

```typescript
private toPointType(label: string): geofence.GeofencePointType {
  if (label === '家' || label === 'home') return 0;      // GEOFENCE_HOME
  if (label === '公司' || label === 'work') return 1;     // GEOFENCE_COMPANY
  return 2;                                                // GEOFENCE_OTHERS
}
```

如果新模式不是家/公司类型，用 `GEOFENCE_OTHERS (2)` 即可，不影响功能。

### 步骤 7：渲染（可选）

`HtmlModeHomeRenderer` 是通用的，会根据 `toolResults` 的 `sourceTag` 自动渲染卡片。新模式的卡片数据会自动渲染，**通常不需要改渲染器**。

如果需要新模式有独特样式（如新的 source 主题色），在 `HtmlModeHomeRenderer.ets` 的 CSS 里加 `--<source>: <color>` 和 `--<source>-soft: rgba(...)`。

### 步骤 8：更新 ModeApi（如需 LLM 工具调用）

如果希望 LLM 能通过工具调用触发新模式，在 `agent_core` 里更新：

```typescript
// agent_core/src/main/ets/agent/ModeApi.ets
export interface ModeApi {
  subscribeHome(...): string;
  subscribeWork(...): string;
  subscribeGym(...): string;    // ← 新增
  manualTrigger(kind: ModeKind): void;
}
```

---

## 七、文件结构速查

```
entry/src/main/ets/modes/
  ├─ ModeManager.ets              # 模式系统入口
  ├─ core/
  │   ├─ ModeTypes.ets            # GeoFence / ModeBehaviorResult
  │   ├─ ModeDefinition.ets       # 模式定义类
  │   ├─ ModeBehavior.ets          # 行为接口 + ModeContext
  │   ├─ ModeRegistry.ets         # 模式注册表
  │   └─ ModeOrchestrator.ets     # 编排器：触发/执行/渲染
  ├─ definitions/
  │   ├─ HomeMode.ets             # 回家模式定义
  │   └─ WorkMode.ets             # 到公司模式定义
  ├─ behaviors/
  │   ├─ MusicRecommendBehavior.ets
  │   ├─ SmartHomeControlBehavior.ets
  │   ├─ DoNotDisturbBehavior.ets
  │   └─ CheckEmailBehavior.ets
  └─ triggers/
      ├─ LocationSubscription.ets  # 围栏订阅管理
      ├─ GeofenceApi.ets           # @ohos.geofence NAPI 封装
      └─ ModeGeolocationStore.ets  # 坐标持久化

entry/src/main/ets/pages/A2uiHome/html/
  ├─ HtmlHomeTypes.ets            # HtmlHomeKind 含 'mode'
  ├─ HtmlHomeRenderer.ets         # 分发到 ModeHomeRenderer
  └─ HtmlModeHomeRenderer.ets     # 模式专属渲染器

agent_core/src/main/ets/agent/
  ├─ ModeKind.ets                 # ModeKind 枚举
  ├─ ModeApi.ets                  # ModeApi 接口
  └─ ModeSubscribeTool.ets        # LLM 可调用的订阅工具
```

---

## 八、设计原则

1. **模式独立**：每个模式是独立的 `ModeDefinition`，包含自己的行为列表，互不干扰
2. **行为可复用**：`DoNotDisturbBehavior` 被家和公司模式共用，新模式也可复用
3. **触发解耦**：围栏触发、手动触发、LLM 触发三条路径都最终走 `orchestrator.trigger(kind)`
4. **渲染通用**：`HtmlModeHomeRenderer` 按 `sourceTag` 主题色渲染，新模式不需改渲染器
5. **NAPI 封装**：底层能力通过 `LocationApi` 接口抽象，可替换实现（geofence / 持续定位 / 其他）
