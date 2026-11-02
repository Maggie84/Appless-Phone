import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BbpSettings } from './BbpTypes';

const STORE_NAME: string = 'aiphone_bbp_settings';
const VERSION_KEY: string = 'version';
const ENDPOINT_KEY: string = 'endpoint';
const ENABLED_KEY: string = 'enabled';
const MOCK_LOCATION_KEY: string = 'mock_location';
const AMBIENT_TEMPERATURE_KEY: string = 'ambient_temperature';
const TARGET_TEMPERATURE_KEY: string = 'target_temperature';
const VERSION: string = 'bbp_settings_v2';
const DEFAULT_ENDPOINT: string = 'http://192.168.43.5:8070';

function defaults(): BbpSettings {
  return {
    endpoint: DEFAULT_ENDPOINT,
    enabled: true,
    mockLocation: 'office',
    ambientTemperatureText: '30',
    targetTemperatureText: '24',
  };
}

function textValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (typeof value === 'string') {
    return value;
  }
  return value === undefined || value === null ? '' : value.toString();
}

export class BbpSettingsStore {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  loadSync(): BbpSettings {
    const store = this.preferences();
    if (store === null) {
      return defaults();
    }
    try {
      const version = textValue(store.getSync(VERSION_KEY, ''));
      if (version !== 'bbp_settings_v1' && version !== VERSION) {
        return defaults();
      }
      const savedEndpoint = textValue(store.getSync(ENDPOINT_KEY, '')).trim();
      return {
        endpoint: savedEndpoint.length > 0 ? savedEndpoint : DEFAULT_ENDPOINT,
        enabled: store.getSync(ENABLED_KEY, false) === true,
        mockLocation: textValue(store.getSync(MOCK_LOCATION_KEY, 'office')) === 'home' ? 'home' : 'office',
        ambientTemperatureText: textValue(store.getSync(AMBIENT_TEMPERATURE_KEY, '30')),
        targetTemperatureText: textValue(store.getSync(TARGET_TEMPERATURE_KEY, '24')),
      };
    } catch (_error) {
      return defaults();
    }
  }

  saveSync(settings: BbpSettings): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(VERSION_KEY, VERSION);
      store.putSync(ENDPOINT_KEY, settings.endpoint.trim());
      store.putSync(ENABLED_KEY, settings.enabled);
      store.putSync(MOCK_LOCATION_KEY, settings.mockLocation);
      store.putSync(AMBIENT_TEMPERATURE_KEY, settings.ambientTemperatureText);
      store.putSync(TARGET_TEMPERATURE_KEY, settings.targetTemperatureText);
      store.flush().catch((_error: Error): void => {});
    } catch (_error) {
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
