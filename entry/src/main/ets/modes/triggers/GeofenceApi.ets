import geofence from '@ohos.geofence';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GeoFence } from '../core/ModeTypes';
import { LocationApi, LocationEnterCallback } from './LocationSubscription';

const DOMAIN = 0xFF;
const LOG_TAG = 'GeofenceApi';

/**
 * The HarmonyOS geofence service reports an explicit enter or exit state.  We
 * keep this small abstraction independent of the mode system so other product
 * features (for example the BBP commute flow) can listen to the same fence.
 */
export type GeofenceTransition = 'enter' | 'exit';
export type GeofenceTransitionCallback = (fenceLabel: string, transition: GeofenceTransition) => void;

export class GeofenceApi implements LocationApi {
  private readonly callbacks: Map<string, Map<string, GeofenceTransitionCallback>> = new Map();

  subscribe(fence: GeoFence, onEnter: LocationEnterCallback): string {
    const key = this.fenceKey(fence.label);
    this.setTransitionListener(fence, 'mode-enter', (label: string, transition: GeofenceTransition): void => {
      if (transition === 'enter') {
        onEnter(label);
      }
    });
    try {
      const option: geofence.SubscribeGeofenceOption = this.option(fence);
      const ret = geofence.subscribe(option, (response: geofence.GeofenceResponse) => {
        hilog.info(DOMAIN, LOG_TAG, 'geofence event label=%{public}s raw=%{public}s',
          fence.label, JSON.stringify(response));
        // Status values follow @ohos.geofence.d.ts: ENTER=0, EXIT=1, ENTER_EXIT=2.
        // Read them as raw numbers because the native module does not export
        // the GeofenceStatus enum at runtime.
        const status = Number(response.status);
        if (status === 0) {
          this.notify(key, fence.label, 'enter');
        } else if (status === 1) {
          this.notify(key, fence.label, 'exit');
        } else if (status === 2) {
          // The platform has not provided a direction for this combined state.
          // Keep the legacy mode behaviour (treat it as an arrival), but never
          // use it to start a potentially costly vehicle action.
          this.notify(key, fence.label, 'enter');
        }
      });
      hilog.info(DOMAIN, LOG_TAG, 'subscribe %{public}s ret=%{public}d', fence.label, `${ret}`);
      return ret === 0 ? '' : 'geofence.subscribe ret=' + ret;
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'subscribe %{public}s failed: %{public}s', fence.label, msg);
      return 'geofence.subscribe error: ' + msg;
    }
  }

  /**
   * Adds or replaces a named listener without issuing a second native
   * subscription.  Call this after subscribe() for the corresponding fence.
   */
  setTransitionListener(fence: GeoFence, listenerId: string, callback: GeofenceTransitionCallback): void {
    const key = this.fenceKey(fence.label);
    let listeners = this.callbacks.get(key);
    if (listeners === undefined) {
      listeners = new Map();
      this.callbacks.set(key, listeners);
    }
    listeners.set(listenerId, callback);
  }

  unsubscribe(fence: GeoFence): void {
    try {
      const option: geofence.SubscribeGeofenceOption = this.option(fence);
      const ret = geofence.unsubscribe(option);
      this.callbacks.delete(this.fenceKey(fence.label));
      hilog.info(DOMAIN, LOG_TAG, 'unsubscribe %{public}s ret=%{public}d', fence.label, `${ret}`);
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'unsubscribe %{public}s failed: %{public}s', fence.label, msg);
    }
  }

  private option(fence: GeoFence): geofence.SubscribeGeofenceOption {
    return {
      scenario: 0,
      type: this.toPointType(fence.label),
      geofenceType: 0,
      info: {
        latitude: fence.latitude,
        longitude: fence.longitude,
        aoi: {
          id: fence.label,
          name: fence.label,
          type: fence.label,
        },
      },
    };
  }

  private toPointType(label: string): geofence.GeofencePointType {
    if (label === '家' || label === 'home') {
      return 0;
    }
    if (label === '公司' || label === 'work') {
      return 1;
    }
    return 2;
  }

  private fenceKey(label: string): string {
    return label;
  }

  private notify(key: string, label: string, transition: GeofenceTransition): void {
    const listeners = this.callbacks.get(key);
    if (listeners === undefined) {
      return;
    }
    listeners.forEach((callback: GeofenceTransitionCallback): void => {
      callback(label, transition);
    });
  }
}
