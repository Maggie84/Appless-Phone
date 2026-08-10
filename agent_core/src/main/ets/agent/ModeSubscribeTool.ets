import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AgentTool } from './AgentTool';
import { ModeApi } from './ModeApi';
import { ModeKind } from './ModeKind';

const DOMAIN = 0xFF;
const LOG_TAG = 'ModeSubscribeTool';

export class ModeSubscribeHomeTool implements AgentTool {
  private readonly modeApi: ModeApi;

  constructor(modeApi: ModeApi) {
    this.modeApi = modeApi;
  }

  name(): string {
    return 'mode.subscribe_home';
  }

  description(): string {
    return 'Subscribe home location for auto mode switching. Call this when the user confirms they are currently at home. ' +
      'Captures current device GPS location and registers a geofence. ' +
      'When the device enters the home area, home mode (music, smart home, do-not-disturb) triggers automatically. ' +
      'No input parameters needed — just call it when the user says they are at home.';
  }

  async run(_input: string): Promise<string> {
    try {
      const loc = await geoLocationManager.getCurrentLocation();
      if (loc.latitude === undefined || loc.longitude === undefined) {
        return '订阅失败：无法获取当前位置';
      }
      this.modeApi.subscribeHome(loc.latitude, loc.longitude, 200);
      hilog.info(DOMAIN, LOG_TAG, 'subscribed home at %{public}f, %{public}f',
        `${loc.latitude}`, `${loc.longitude}`);
      return '已订阅回家模式。到家时会自动切换：推荐舒缓音乐、显示智能家电控制、开启勿扰。';
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'subscribe home failed: %{public}s', msg);
      return `订阅失败：${msg}`;
    }
  }
}

export class ModeSubscribeWorkTool implements AgentTool {
  private readonly modeApi: ModeApi;

  constructor(modeApi: ModeApi) {
    this.modeApi = modeApi;
  }

  name(): string {
    return 'mode.subscribe_work';
  }

  description(): string {
    return 'Subscribe work/company location for auto mode switching. Call this when the user confirms they are currently at the office. ' +
      'Captures current device GPS location and registers a geofence. ' +
      'When the device enters the company area, work mode (email reminder, do-not-disturb) triggers automatically. ' +
      'No input parameters needed — just call it when the user says they are at the office.';
  }

  async run(_input: string): Promise<string> {
    try {
      const loc = await geoLocationManager.getCurrentLocation();
      if (loc.latitude === undefined || loc.longitude === undefined) {
        return '订阅失败：无法获取当前位置';
      }
      this.modeApi.subscribeWork(loc.latitude, loc.longitude, 200);
      hilog.info(DOMAIN, LOG_TAG, 'subscribed work at %{public}f, %{public}f',
        `${loc.latitude}`, `${loc.longitude}`);
      return '已订阅到公司模式。到公司时会自动切换：提示查看邮件、开启勿扰。';
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'subscribe work failed: %{public}s', msg);
      return `订阅失败：${msg}`;
    }
  }
}

export class ModeManualTriggerTool implements AgentTool {
  private readonly modeApi: ModeApi;

  constructor(modeApi: ModeApi) {
    this.modeApi = modeApi;
  }

  name(): string {
    return 'mode.trigger';
  }

  description(): string {
    return 'Manually trigger a mode for testing. Input: {"mode":"home"} or {"mode":"work"}. ' +
      'Use this when the user says "测试回家模式" or "测试到公司模式".';
  }

  async run(input: string): Promise<string> {
    const trimmed = input.trim();
    let kind: ModeKind = ModeKind.HOME;
    if (trimmed.indexOf('work') >= 0 || trimmed.indexOf('公司') >= 0) {
      kind = ModeKind.WORK;
    }
    this.modeApi.manualTrigger(kind);
    return kind === ModeKind.HOME ? '已手动触发回家模式' : '已手动触发到公司模式';
  }
}
