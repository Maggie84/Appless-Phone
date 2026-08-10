import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GeoFence, ModeKind } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'ModeGeolocationStore';

const STORE_NAME: string = 'mode_geolocation_store';
const VERSION_KEY: string = 'mode_geolocation_version';
const VERSION: string = 'mode_geolocation_v1';

function fenceKey(kind: ModeKind): string {
  return kind === ModeKind.HOME ? 'home_fence' : 'work_fence';
}

export class ModeGeolocationStore {
  private context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  saveFence(kind: ModeKind, fence: GeoFence): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(fenceKey(kind), JSON.stringify({
        latitude: fence.latitude,
        longitude: fence.longitude,
        radiusMeters: fence.radiusMeters,
        label: fence.label,
      }));
      store.putSync(VERSION_KEY, VERSION);
      store.flush();
      hilog.info(DOMAIN, LOG_TAG, 'saved %{public}s at (%{public}f, %{public}f) r=%{public}d',
        kind, `${fence.latitude}`, `${fence.longitude}`, `${fence.radiusMeters}`);
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.warn(DOMAIN, LOG_TAG, 'save %{public}s failed: %{public}s', kind, msg);
    }
  }

  loadFence(kind: ModeKind): GeoFence | null {
    const store = this.preferences();
    if (store === null) {
      return null;
    }
    try {
      if (textFromValue(store.getSync(VERSION_KEY, '')) !== VERSION) {
        return null;
      }
      const raw = textFromValue(store.getSync(fenceKey(kind), ''));
      if (raw.trim().length === 0) {
        return null;
      }
      const parsed = JSON.parse(raw) as Record<string, Object | number | string | boolean | undefined>;
      const latitude = parsed['latitude'];
      const longitude = parsed['longitude'];
      const radiusMeters = parsed['radiusMeters'];
      const labelValue = parsed['label'];
      if (typeof latitude === 'number' && typeof longitude === 'number') {
        return {
          latitude: latitude,
          longitude: longitude,
          radiusMeters: typeof radiusMeters === 'number' ? radiusMeters : 200,
          label: typeof labelValue === 'string' ? labelValue : (kind === ModeKind.HOME ? '家' : '公司'),
        };
      }
      return null;
    } catch (_error) {
      return null;
    }
  }

  private preferences(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.context, { name: STORE_NAME });
    } catch (_error) {
      return null;
    }
  }
}

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}