import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'DoNotDisturbBehavior';
const DB_PATH = '/data/app/el1/0/database/com.ohos.settingsdata/entry/rdb/settingsdata.db';
const FOCUS_MODE_KEY = 'focus_mode_enable';

class DndEnableArgs {
  enabled: boolean;

  constructor(enabled: boolean) {
    this.enabled = enabled;
  }
}

interface DbResult {
  ok: boolean;
  stdout: string;
  error: string;
}

class DoNotDisturbBridge {
  private static mod: Record<string, Object> | null = null;

  private static async ensureMod(): Promise<Record<string, Object> | null> {
    if (DoNotDisturbBridge.mod !== null) {
      return DoNotDisturbBridge.mod;
    }
    try {
      const m = await import('libcli_bridge.so') as Record<string, Object>;
      DoNotDisturbBridge.mod = (m['default'] as Record<string, Object>) ?? m;
      return DoNotDisturbBridge.mod;
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      hilog.error(DOMAIN, LOG_TAG, 'load libcli_bridge failed: %{public}s', msg);
      return null;
    }
  }

  static async query(sql: string): Promise<DbResult> {
    const mod = await DoNotDisturbBridge.ensureMod();
    if (mod === null) {
      return { ok: false, stdout: '', error: 'mod not loaded' };
    }
    try {
      const fn = mod['dbQuery'] as CallableFunction;
      if (typeof fn !== 'function') {
        return { ok: false, stdout: '', error: 'dbQuery not found' };
      }
      const raw = fn(DB_PATH, sql) as Record<string, Object>;
      return {
        ok: (raw['ok'] as boolean) ?? false,
        stdout: (raw['stdout'] as string) ?? '',
        error: (raw['error'] as string) ?? ''
      };
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      return { ok: false, stdout: '', error: msg };
    }
  }

  static async exec(sql: string): Promise<DbResult> {
    const mod = await DoNotDisturbBridge.ensureMod();
    if (mod === null) {
      return { ok: false, stdout: '', error: 'mod not loaded' };
    }
    try {
      const fn = mod['dbExec'] as CallableFunction;
      if (typeof fn !== 'function') {
        return { ok: false, stdout: '', error: 'dbExec not found' };
      }
      const raw = fn(DB_PATH, sql) as Record<string, Object>;
      return {
        ok: (raw['ok'] as boolean) ?? false,
        stdout: '',
        error: (raw['error'] as string) ?? ''
      };
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      return { ok: false, stdout: '', error: msg };
    }
  }
}

export class DoNotDisturbBehavior implements ModeBehavior {
  readonly name = 'do-not-disturb';
  readonly displayName = '开启勿扰模式';

  async execute(ctx: ModeContext): Promise<ModeBehaviorResult> {
    hilog.info(DOMAIN, LOG_TAG, 'do not disturb activated');
    const dndEnabled = await DoNotDisturbBehavior.isEnabled(ctx.context);

    const rows: A2uiGenericToolResultRowData[] = [
      { label: '状态', value: dndEnabled ? '已开启' : '待开启' },
      { label: '说明', value: '屏蔽通知与来电提醒，专注休息' },
    ];

    const dndArgs: DndEnableArgs = new DndEnableArgs(!dndEnabled);
    const actions: A2uiAction[] = [
      {
        id: 'mode.dnd.enable',
        label: dndEnabled ? '关闭勿扰' : '开启勿扰',
        prompt: '开启勿扰模式',
        variant: 'primary',
        kind: 'client',
        args: dndArgs,
      },
    ];

    const toolResult: A2uiGenericToolResultData = {
      sourceTag: '勿扰',
      toolName: 'do-not-disturb',
      title: '开启勿扰模式',
      status: 'success',
      summary: '屏蔽通知与来电提醒',
      rows: rows,
      rawPreview: '',
      actions: actions,
    };

    return {
      ok: true,
      message: dndEnabled ? '已开启勿扰模式' : '勿扰模式已准备，点击按钮开启',
      toolResults: [toolResult],
    };
  }

  static async isEnabled(context: common.UIAbilityContext): Promise<boolean> {
    const sql = 'SELECT VALUE FROM USER_SETTINGSDATA_SECURE_100 WHERE KEYWORD=\'' + FOCUS_MODE_KEY + '\';';
    const result = await DoNotDisturbBridge.query(sql);
    hilog.info(DOMAIN, LOG_TAG, 'read focus_mode_enable ok=%{public}s stdout=%{public}s err=%{public}s', '' + result.ok, result.stdout, result.error);
    return result.ok && result.stdout.trim() === '1';
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<boolean> {
    const val = enabled ? '1' : '0';
    const sql = 'UPDATE USER_SETTINGSDATA_SECURE_100 SET VALUE=\'' + val + '\' WHERE KEYWORD=\'' + FOCUS_MODE_KEY + '\';';
    const result = await DoNotDisturbBridge.exec(sql);
    hilog.info(DOMAIN, LOG_TAG, 'set focus mode enabled=%{public}s ok=%{public}s err=%{public}s', '' + enabled, '' + result.ok, result.error);
    return result.ok;
  }
}
