# 家/公司模式系统 — 架构设计方案

## 概述

基于位置触发场景模式：到达家 → 回家模式，到达公司 → 到公司模式。每种模式可扩展地组合多个行为（音乐推荐、智能家电控制、勿扰、邮件提醒等）。

**设计原则**：
- **非侵入式** — 不修改现有 agent/CLI/A2UI 代码，仅新增模块
- **可扩展** — 新增行为只需实现接口 + 注册，不改核心代码
- **声明式** — 模式由 behaviors 组合定义，像拼积木
- **UI 无关** — 行为通过回调推送 UI，不直接依赖 A2UI

---

## 目录结构

```
entry/src/main/ets/modes/
├── core/
│   ├── ModeTypes.ets              # 类型定义（枚举、接口）
│   ├── ModeBehavior.ets           # Behavior 接口 + 上下文
│   ├── ModeDefinition.ets         # Mode 定义类
│   ├── ModeRegistry.ets           # 模式注册表
│   └── ModeOrchestrator.ets       # 编排器：触发 → 查找 → 执行
├── triggers/
│   └── LocationSubscription.ets   # 位置订阅管理（调用外部接口，接收 callback）
├── behaviors/
│   ├── MusicRecommendBehavior.ets     # 推荐舒缓音乐
│   ├── SmartHomeControlBehavior.ets    # 智能家电控制（假 UI）
│   ├── DoNotDisturbBehavior.ets       # 开启勿扰模式
│   └── CheckEmailBehavior.ets         # 提示查看邮件
├── definitions/
│   ├── HomeMode.ets               # 回家模式（组合 behaviors）
│   └── WorkMode.ets               # 到公司模式（组合 behaviors）
└── ModeManager.ets                # 对外入口：init/subscribe/trigger
```

---

## 核心架构

```
用户同意订阅
      │
      ▼
┌──────────────────┐
│  ModeManager      │  ← 对外入口
│  .init(ctx)       │
│  .subscribeHome() │
│  .subscribeWork() │
└────────┬───────────┘
         │ 注册地点 (lat,lng,radius)
         ▼
┌──────────────────────────┐
│ LocationSubscription     │  ← 调用外部 ArkTS 接口订阅
│ subscribe(fence, onEnter) │     到达地点时系统 callback 上报
└────────┬─────────────────┘
         │ callback 到达
         ▼
┌──────────────────┐
│ ModeOrchestrator  │  ← 查找匹配的 ModeDefinition
│ trigger('home')   │
└────────┬───────────┘
         │ 依次执行 behaviors
         ▼
┌──────────────────┐
│ ModeBehavior[]    │  ← 每个行为独立执行
│ MusicRecommend    │     → 推送音乐卡片 UI
│ SmartHomeControl  │     → 推送家电控制 UI
│ DoNotDisturb       │     → 调用系统 API
│ CheckEmail         │     → 推送邮件提醒 UI
└──────────────────┘
```

---

## 核心接口设计

### ModeTypes.ets

```typescript
export enum ModeKind {
  HOME = 'home',
  WORK = 'work',
}

export interface GeoFence {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  label: string;           // '家' / '公司'
}

export interface ModeBehaviorResult {
  ok: boolean;
  message: string;
}
```

### ModeBehavior.ets — 行为接口

```typescript
export interface ModeContext {
  kind: ModeKind;
  surfaceCallback: (surface: A2uiSurfaceState) => void;  // 推送 UI
  context: common.UIAbilityContext;                      // 系统上下文
}

export interface ModeBehavior {
  readonly name: string;           // 'music-recommend'
  readonly displayName: string;    // '推荐舒缓音乐'
  execute(ctx: ModeContext): Promise<ModeBehaviorResult>;
}
```

每个 behavior 是一个独立类，实现 `execute()` 即可。新行为只需加一个类 + 在 ModeDefinition 中引用。

### ModeDefinition.ets — 模式定义

```typescript
export class ModeDefinition {
  readonly kind: ModeKind;
  readonly displayName: string;       // '回家模式'
  readonly description: string;      // '已到家，切换到放松模式'
  readonly behaviors: ModeBehavior[];
  readonly geoFence: GeoFence;        // 触发地点

  constructor(kind: ModeKind, displayName: string, description: string,
              behaviors: ModeBehavior[], geoFence: GeoFence) {
    this.kind = kind;
    this.displayName = displayName;
    this.description = description;
    this.behaviors = behaviors;
    this.geoFence = geoFence;
  }
}
```

### ModeRegistry.ets — 注册表

```typescript
export class ModeRegistry {
  private readonly modes: Map<ModeKind, ModeDefinition> = new Map();

  register(def: ModeDefinition): void {
    this.modes.set(def.kind, def);
  }

  find(kind: ModeKind): ModeDefinition | null {
    return this.modes.get(kind) ?? null;
  }

  allFences(): GeoFence[] {
    // 返回所有已注册模式的地理围栏
  }
}
```

### ModeOrchestrator.ets — 编排器

```typescript
export class ModeOrchestrator {
  private readonly registry: ModeRegistry;
  private readonly surfaceCallback: (s: A2uiSurfaceState) => void;
  private readonly context: common.UIAbilityContext;
  private activeMode: ModeKind | null = null;

  async trigger(kind: ModeKind): Promise<void> {
    if (this.activeMode === kind) {
      return;  // 已在该模式，不重复触发
    }
    const def = this.registry.find(kind);
    if (def === null) return;

    this.activeMode = kind;
    // 1. 推送模式总览 UI
    this.pushModeSurface(def);
    // 2. 依次执行所有 behaviors
    for (const behavior of def.behaviors) {
      try {
        const result = await behavior.execute({
          kind: kind,
          surfaceCallback: this.surfaceCallback,
          context: this.context,
        });
        // 可选：记录每个 behavior 的执行结果
      } catch (_e) {
        // 单个 behavior 失败不影响其他
      }
    }
  }

  exit(): void {
    this.activeMode = null;
    // 可选：推送退出模式 UI
  }

  private pushModeSurface(def: ModeDefinition): void {
    // 构建并推送 A2UI surface（类似 createSocialHubSurface）
  }
}
```

---

## 位置订阅

### LocationSubscription.ets — 订阅管理

位置检测由外部 ArkTS 接口提供，到地点时系统主动 callback 上报，不需要轮询。`LocationSubscription` 只负责管理订阅和分发回调。

```typescript
// 外部提供的订阅接口（由业务方实现注入）
export type LocationEnterCallback = (fenceLabel: string) => void;

export interface LocationApi {
  // 订阅地点围栏，到达时通过 callback 上报
  subscribe(fence: GeoFence, onEnter: LocationEnterCallback): void;
  // 注销订阅
  unsubscribe(fence: GeoFence): void;
}

export class LocationSubscription {
  private api: LocationApi;
  private fences: Map<ModeKind, GeoFence> = new Map();
  private readonly onEnter: (kind: ModeKind) => void;
  private readonly onExit: () => void;
  private activeKind: ModeKind | null = null;

  constructor(api: LocationApi, onEnter: (k: ModeKind) => void, onExit: () => void) {
    this.api = api;
    this.onEnter = onEnter;
    this.onExit = onExit;
  }

  subscribe(kind: ModeKind, fence: GeoFence): void {
    this.fences.set(kind, fence);
    this.api.subscribe(fence, (label: string) => {
      this.handleEnter(kind);
    });
  }

  unsubscribe(kind: ModeKind): void {
    const fence = this.fences.get(kind);
    if (fence !== undefined) {
      this.api.unsubscribe(fence);
      this.fences.delete(kind);
    }
  }

  private handleEnter(kind: ModeKind): void {
    if (this.activeKind === kind) {
      return;  // 已在该模式，不重复触发
    }
    if (this.activeKind !== null) {
      this.onExit();  // 先退出上一个模式
    }
    this.activeKind = kind;
    this.onEnter(kind);
  }

  clear(): void {
    this.fences.forEach((fence, kind) => this.api.unsubscribe(fence));
    this.fences.clear();
    this.activeKind = null;
  }
}
```

> **接口注入**：`LocationApi` 由业务方实现（可能是 HarmonyOS geofencing 服务、第三方 SDK、或自定义 native bridge）。`ModeManager` 在 `init()` 时注入实现，模式系统本身不关心位置检测的具体方式。

---

## 行为实现

### MusicRecommendBehavior.ets — 推荐舒缓音乐

```typescript
export class MusicRecommendBehavior implements ModeBehavior {
  readonly name = 'music-recommend';
  readonly displayName = '推荐舒缓音乐';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    // 构建 A2UI 音乐推荐卡片
    const surface = this.buildMusicSurface();
    ctx.surfaceCallback(surface);
    return { ok: true, message: '已推荐舒缓音乐' };
  }

  private buildMusicSurface(): A2uiSurfaceState {
    // 用 A2uiSurfaceStore 构建，类似 createSocialHubSurface()
    // 组件包含：歌曲名、艺术家、播放按钮、封面图
  }
}
```

### SmartHomeControlBehavior.ets — 智能家电控制（假 UI）

```typescript
export class SmartHomeControlBehavior implements ModeBehavior {
  readonly name = 'smart-home-control';
  readonly displayName = '智能家电控制';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    const surface = this.buildSmartHomeSurface();
    ctx.surfaceCallback(surface);
    return { ok: true, message: '已显示智能家电控制面板' };
  }

  private buildSmartHomeSurface(): A2uiSurfaceState {
    // 假 UI：灯光开关、空调温度、窗帘开合、音响控制
  }
}
```

### DoNotDisturbBehavior.ets — 开启勿扰

```typescript
export class DoNotDisturbBehavior implements ModeBehavior {
  readonly name = 'do-not-disturb';
  readonly displayName = '开启勿扰模式';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    // 调用系统 API 开启勿扰
    // 或通过 CLI 执行系统设置命令
    return { ok: true, message: '已开启勿扰模式' };
  }
}
```

### CheckEmailBehavior.ets — 提示查看邮件

```typescript
export class CheckEmailBehavior implements ModeBehavior {
  readonly name = 'check-email';
  readonly displayName = '提示查看邮件';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    const surface = this.buildEmailReminderSurface();
    ctx.surfaceCallback(surface);
    return { ok: true, message: '已推送邮件提醒' };
  }
}
```

---

## 模式定义

### HomeMode.ets — 回家模式

```typescript
export function createHomeMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.HOME,
    '回家模式',
    '已到家，切换到放松模式',
    [
      new MusicRecommendBehavior(),
      new SmartHomeControlBehavior(),
      new DoNotDisturbBehavior(),
    ],
    fence
  );
}
```

### WorkMode.ets — 到公司模式

```typescript
export function createWorkMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.WORK,
    '到公司模式',
    '已到公司，切换到工作模式',
    [
      new CheckEmailBehavior(),
      new DoNotDisturbBehavior(),
    ],
    fence
  );
}
```

### 新增模式只需 2 步

1. 创建 `definitions/CustomMode.ets`，组合 behaviors
2. 在 `ModeManager` 中注册

```typescript
export function createCustomMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.CUSTOM,  // 新增枚举值
    '自定义模式',
    '描述',
    [new SomeBehavior(), new AnotherBehavior()],
    fence
  );
}
```

---

## 对外入口

### ModeManager.ets

```typescript
export class ModeManager {
  private registry: ModeRegistry;
  private orchestrator: ModeOrchestrator;
  private subscription: LocationSubscription;

  constructor(surfaceCallback: (s: A2uiSurfaceState) => void, locationApi: LocationApi) {
    this.registry = new ModeRegistry();
    this.orchestrator = new ModeOrchestrator(this.registry, surfaceCallback);
    this.subscription = new LocationSubscription(
      locationApi,
      (kind) => this.orchestrator.trigger(kind),
      () => this.orchestrator.exit()
    );
  }

  init(context: common.UIAbilityContext): void {
    this.orchestrator.setContext(context);
    // 等待用户订阅后再注册地点
  }

  subscribeHome(latitude: number, longitude: number, radius: number = 200): void {
    const fence: GeoFence = { latitude, longitude, radiusMeters: radius, label: '家' };
    this.registry.register(createHomeMode(fence));
    this.subscription.subscribe(ModeKind.HOME, fence);
  }

  subscribeWork(latitude: number, longitude: number, radius: number = 200): void {
    const fence: GeoFence = { latitude, longitude, radiusMeters: radius, label: '公司' };
    this.registry.register(createWorkMode(fence));
    this.subscription.subscribe(ModeKind.WORK, fence);
  }

  unsubscribe(kind: ModeKind): void {
    this.subscription.unsubscribe(kind);
  }

  manualTrigger(kind: ModeKind): void {
    this.orchestrator.trigger(kind);
  }
}
```

---

## 集成方式

### 1. 在 Index.ets 中初始化（不修改现有逻辑）

```typescript
// aboutToAppear() 中新增一行
this.initModeSystem();

// 新增方法
private initModeSystem(): void {
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
  // locationApi 由业务方提供，到达地点时 callback 上报
  const locationApi = createLocationApi(ctx);  // 外部实现
  this.modeManager = new ModeManager(
    (surface) => this.applySurface(surface),
    locationApi
  );
  this.modeManager.init(ctx);
  // 如果用户之前已订阅，恢复订阅
  this.restoreModeSubscriptions();
}
```

### 2. 用户订阅流程

```
用户输入 "订阅家在公司附近"
    │
    ▼
LLM 解析意图 → 获取当前位置
    │
    ├── 家：用户确认地址 → 反地理编码 → lat,lng → subscribeHome()
    └── 公司：同上 → subscribeWork()
    │
    ▼
LocationApi 注册围栏订阅
    │
    ▼
到达地点 → 系统主动 callback → 触发对应模式
```

### 3. UI 展示

模式触发时通过 `surfaceCallback` 推送 A2UI surface，复用现有 `applySurface()` 方法，不需要新 UI 组件。

---

## 权限需求

| 权限 | 类型 | 用途 | 现有状态 |
|------|------|------|----------|
| `ohos.permission.APPROXIMATELY_LOCATION` | user_grant | 获取粗略位置 | 已声明 + 已请求 |
| `ohos.permission.LOCATION` | user_grant | 获取精确位置 | 已声明 + 已请求 |

**无需新增权限** — 现有位置权限已覆盖需求。

---

## 不影响现有功能的保障

| 现有功能 | 影响 | 原因 |
|----------|------|------|
| Agent ReAct 循环 | 无 | 模式系统独立运行，不注册新的 AgentTool |
| CLI Skill 系统 | 无 | 模式系统不与 CliRuntime 交互 |
| A2UI surface 渲染 | 共用 | 通过 `surfaceCallback` 推送，复用 `applySurface()`，不修改渲染逻辑 |
| 位置权限请求 | 共用 | 复用现有 `requestLocationPermissionOnLaunch()`，不重复请求 |
| Persona/对话历史 | 无 | 模式系统不读写对话状态 |

---

## 扩展场景

### 新增行为

```typescript
// behaviors/WeatherReportBehavior.ets
export class WeatherReportBehavior implements ModeBehavior {
  readonly name = 'weather-report';
  readonly displayName = '播报天气';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    // 获取天气 → 推送 UI
    return { ok: true, message: '已播报天气' };
  }
}
```

在 `HomeMode.ets` 的 behaviors 数组中加一行即可。

### 新增模式

如"健身房模式"、"学校模式"，只需：
1. `ModeKind` 枚举加值
2. 创建 `definitions/GymMode.ets`
3. 在 `ModeManager` 中加 `subscribeGym()` 方法

### 新增触发方式

未来支持时间触发（如"每天 9 点切工作模式"），只需新增 `TimeTrigger` 类，实现同样的 `onEnter/onExit` 回调。

---

## 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 位置检测方式 | 外部接口 callback | 业务方提供 ArkTS 接口，到达地点主动上报，无需轮询 |
| 位置接口注入 | `LocationApi` 接口抽象 | 模式系统不绑定具体实现，可替换为不同 SDK |
| 行为执行方式 | 串行 + try-catch | 单个失败不影响其他，串行避免 UI 竞争 |
| UI 推送方式 | 回调推送 A2UI surface | 复用现有渲染管道，不需要新组件 |
| 模式去重 | `activeMode` 状态 | 已在家中不重复触发 |
| 围栏半径 | 默认 200m | 可配置，平衡误触和灵敏度 |
