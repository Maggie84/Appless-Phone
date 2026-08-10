import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'SmartHomeControlBehavior';

const STORE_NAME = 'mode_smart_home';
const KEY_PREFIX = 'device_';

interface DeviceSwitch {
  key: string;
  name: string;
  defaultOn: boolean;
}

const DEVICES: DeviceSwitch[] = [
  { key: 'bedroom_light', name: '卧室灯', defaultOn: false },
  { key: 'living_room_light', name: '客厅灯', defaultOn: false },
  { key: 'curtain', name: '窗帘', defaultOn: false },
  { key: 'ac', name: '空调', defaultOn: false },
];

class SmartHomeToggleArgs {
  device: string;
  name: string;
  next: boolean;

  constructor(device: string, name: string, next: boolean) {
    this.device = device;
    this.name = name;
    this.next = next;
  }
}

export class SmartHomeControlBehavior implements ModeBehavior {
  readonly name = 'smart-home-control';
  readonly displayName = '智能家电控制';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    const rows: A2uiGenericToolResultRowData[] = [];
    const actions: A2uiAction[] = [];

    DEVICES.forEach((device: DeviceSwitch) => {
      const on = this.readDeviceState(ctx, device);
      rows.push({
        label: device.name,
        value: on ? '已开启' : '已关闭',
      });
      const toggleArgs: SmartHomeToggleArgs = new SmartHomeToggleArgs(device.key, device.name, !on);
      actions.push({
        id: 'mode.smart_home.toggle',
        label: '切换' + device.name,
        prompt: '切换智能设备：' + device.name,
        variant: on ? 'danger' : 'primary',
        kind: 'client',
        args: toggleArgs,
      });
    });

    const toolResult: A2uiGenericToolResultData = {
      sourceTag: '智能家电',
      toolName: 'smart-home-control',
      title: '智能家电控制',
      status: 'success',
      summary: '点击按钮切换设备开关状态',
      rows: rows,
      rawPreview: '',
      actions: actions,
    };

    return {
      ok: true,
      message: '智能家电控制面板已就绪',
      toolResults: [toolResult],
    };
  }

  private readDeviceState(ctx: ModeContext, device: DeviceSwitch): boolean {
    try {
      const store = preferences.getPreferencesSync(ctx.context, { name: STORE_NAME });
      return store.getSync(KEY_PREFIX + device.key, device.defaultOn) as boolean;
    } catch (error) {
      hilog.warn(DOMAIN, LOG_TAG, 'read device state failed: %{public}s', `${error}`);
      return device.defaultOn;
    }
  }

  static writeDeviceState(ctx: common.UIAbilityContext, deviceKey: string, next: boolean): boolean {
    try {
      const store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
      store.putSync(KEY_PREFIX + deviceKey, next);
      store.flush();
      hilog.info(DOMAIN, LOG_TAG, 'device %{public}s -> %{public}s', deviceKey, next ? 'on' : 'off');
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, LOG_TAG, 'write device state failed: %{public}s', `${error}`);
      return false;
    }
  }
}