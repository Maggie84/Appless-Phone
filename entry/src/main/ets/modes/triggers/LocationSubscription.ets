import { GeoFence, ModeKind } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'LocationSubscription';

export type LocationEnterCallback = (fenceLabel: string) => void;

export interface LocationApi {
  subscribe(fence: GeoFence, onEnter: LocationEnterCallback): string;
  unsubscribe(fence: GeoFence): void;
}

export class LocationSubscription {
  private readonly api: LocationApi;
  private readonly onEnter: (kind: ModeKind) => void;
  private readonly onExit: () => void;
  private readonly fences: Map<ModeKind, GeoFence> = new Map();
  private activeKind: ModeKind | null;

  constructor(api: LocationApi, onEnter: (k: ModeKind) => void, onExit: () => void) {
    this.api = api;
    this.onEnter = onEnter;
    this.onExit = onExit;
    this.activeKind = null;
  }

  subscribe(kind: ModeKind, fence: GeoFence): string {
    this.fences.set(kind, fence);
    const err = this.api.subscribe(fence, (_label: string) => {
      this.handleEnter(kind);
    });
    hilog.info(DOMAIN, LOG_TAG, 'subscribed %{public}s at %{public}s (%{public}f, %{public}f) r=%{public}d err=%{public}s',
      kind, fence.label, `${fence.latitude}`, `${fence.longitude}`, `${fence.radiusMeters}`, err);
    return err;
  }

  unsubscribe(kind: ModeKind): void {
    const fence = this.fences.get(kind);
    if (fence !== undefined) {
      this.api.unsubscribe(fence);
      this.fences.delete(kind);
      hilog.info(DOMAIN, LOG_TAG, 'unsubscribed %{public}s', kind);
    }
  }

  private handleEnter(kind: ModeKind): void {
    if (this.activeKind === kind) {
      return;
    }
    if (this.activeKind !== null) {
      this.onExit();
    }
    this.activeKind = kind;
    this.onEnter(kind);
  }

  clear(): void {
    this.fences.forEach((fence: GeoFence) => {
      this.api.unsubscribe(fence);
    });
    this.fences.clear();
    this.activeKind = null;
  }
}
