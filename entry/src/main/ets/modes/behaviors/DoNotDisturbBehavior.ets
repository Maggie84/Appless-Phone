import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import settings from '@ohos.settings';

const DOMAIN = 0xFF;
const LOG_TAG = 'DoNotDisturbBehavior';
const FOCUS_MODE_KEY = 'focus_mode_enable';
const USER_SECURE_DOMAIN = 'USER_SECURE';

class DndEnableArgs {
  enabled: boolean;

  constructor(enabled: boolean) {
    this.enabled = enabled;
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
    try {
      const value = settings.getValueSync(context, FOCUS_MODE_KEY, '0', USER_SECURE_DOMAIN);
      hilog.info(DOMAIN, LOG_TAG, 'read focus mode value=%{public}s', value);
      return value === '1';
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      hilog.error(DOMAIN, LOG_TAG, 'read focus mode failed: %{public}s', msg);
      return false;
    }
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<boolean> {
    try {
      const value = enabled ? '1' : '0';
      const ok = settings.setValueSync(context, FOCUS_MODE_KEY, value, USER_SECURE_DOMAIN);
      hilog.info(DOMAIN, LOG_TAG, 'set focus mode enabled=%{public}s ok=%{public}s', '' + enabled, '' + ok);
      return ok;
    } catch (e) {
      const msg = e instanceof Error ? e.message : '' + e;
      hilog.error(DOMAIN, LOG_TAG, 'set focus mode failed: %{public}s', msg);
      return false;
    }
  }
}
