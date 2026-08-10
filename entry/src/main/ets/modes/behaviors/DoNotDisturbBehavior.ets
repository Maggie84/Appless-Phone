import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'DoNotDisturbBehavior';

class DndEnableArgs {
  enabled: boolean;

  constructor(enabled: boolean) {
    this.enabled = enabled;
  }
}

export class DoNotDisturbBehavior implements ModeBehavior {
  readonly name = 'do-not-disturb';
  readonly displayName = '开启勿扰模式';

  async execute(_ctx: ModeContext): Promise<ModeBehaviorResult> {
    hilog.info(DOMAIN, LOG_TAG, 'do not disturb activated');

    // TODO(real-exec): HarmonyOS 普通应用没有系统级勿扰 API。
    // 真正的执行方式待后续确认，可能方案：
    //   1. context.startAbility 拉起系统勿扰/专注模式设置页
    //   2. notificationManager.publish 推一条真实系统通知
    //   3. 或本地持久化勿扰开关状态
    const dndEnabled = await this.applyDoNotDisturb(_ctx);

    const rows: A2uiGenericToolResultRowData[] = [
      { label: '状态', value: dndEnabled ? '已开启' : '待开启' },
      { label: '说明', value: '屏蔽通知与来电提醒，专注休息' },
    ];

    const dndArgs: DndEnableArgs = new DndEnableArgs(!dndEnabled);
    const actions: A2uiAction[] = [
      {
        id: 'mode.dnd.enable',
        label: '开启勿扰',
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

  // TODO(real-exec): 真正的系统勿扰执行入口，当前为占位桩。
  private async applyDoNotDisturb(_ctx: ModeContext): Promise<boolean> {
    return false;
  }
}