import geofence from '@ohos.geofence';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GeoFence } from '../core/ModeTypes';
import { LocationApi, LocationEnterCallback } from './LocationSubscription';

const DOMAIN = 0xFF;
const LOG_TAG = 'GeofenceApi';

export class GeofenceApi implements LocationApi {
  private readonly callbacks: Map<string, LocationEnterCallback> = new Map();

  subscribe(fence: GeoFence, onEnter: LocationEnterCallback): string {
    const key = this.fenceKey(fence.label);
    this.callbacks.set(key, onEnter);
    try {
      const option: geofence.SubscribeGeofenceOption = this.option(fence);
      const ret = geofence.subscribe(option, (response: geofence.GeofenceResponse) => {
        hilog.info(DOMAIN, LOG_TAG, 'geofence event type=%{public}d status=%{public}d',
          `${response.type}`, `${response.status}`);
        if (response.status === 0 ||
          response.status === 2) {
          const cb = this.callbacks.get(key);
          if (cb !== undefined) {
            cb(fence.label);
          }
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
}