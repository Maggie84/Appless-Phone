import { common } from '@kit.AbilityKit';
import { A2uiSurfaceState, ModeApi } from '@loop/agent-core';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ModeRegistry } from './core/ModeRegistry';
import { ModeOrchestrator } from './core/ModeOrchestrator';
import { ModeKind, GeoFence } from './core/ModeTypes';
import { LocationSubscription, LocationApi } from './triggers/LocationSubscription';
import { createHomeMode } from './definitions/HomeMode';
import { createWorkMode } from './definitions/WorkMode';

const DOMAIN = 0xFF;
const LOG_TAG = 'ModeManager';

export class ModeManager implements ModeApi {
  private readonly registry: ModeRegistry;
  private readonly orchestrator: ModeOrchestrator;
  private readonly subscription: LocationSubscription;

  constructor(surfaceCallback: (s: A2uiSurfaceState) => void, locationApi: LocationApi) {
    this.registry = new ModeRegistry();
    this.orchestrator = new ModeOrchestrator(this.registry, surfaceCallback);
    this.subscription = new LocationSubscription(
      locationApi,
      (kind: ModeKind) => {
        this.orchestrator.trigger(kind).catch((e: Object) => {
          hilog.error(DOMAIN, LOG_TAG, 'trigger failed: %{public}s', `${e}`);
        });
      },
      () => this.orchestrator.exit()
    );
  }

  init(context: common.UIAbilityContext): void {
    this.orchestrator.setContext(context);
    hilog.info(DOMAIN, LOG_TAG, 'mode system initialized');
  }

  registerDefaultModes(): void {
    this.registry.register(createHomeMode({ latitude: 0, longitude: 0, radiusMeters: 200, label: '家' }));
    this.registry.register(createWorkMode({ latitude: 0, longitude: 0, radiusMeters: 200, label: '公司' }));
    hilog.info(DOMAIN, LOG_TAG, 'default modes registered');
  }

  subscribeHome(latitude: number, longitude: number, radius: number = 200): string {
    const fence: GeoFence = { latitude, longitude, radiusMeters: radius, label: '家' };
    this.registry.register(createHomeMode(fence));
    return this.subscription.subscribe(ModeKind.HOME, fence);
  }

  subscribeWork(latitude: number, longitude: number, radius: number = 200): string {
    const fence: GeoFence = { latitude, longitude, radiusMeters: radius, label: '公司' };
    this.registry.register(createWorkMode(fence));
    return this.subscription.subscribe(ModeKind.WORK, fence);
  }

  unsubscribe(kind: ModeKind): void {
    this.subscription.unsubscribe(kind);
  }

  manualTrigger(kind: ModeKind): Promise<string> {
    return this.orchestrator.trigger(kind);
  }

  reTrigger(kind: ModeKind): Promise<string> {
    return this.orchestrator.trigger(kind, true);
  }

  activeModeKind(): ModeKind | null {
    return this.orchestrator.getActiveMode();
  }
}
