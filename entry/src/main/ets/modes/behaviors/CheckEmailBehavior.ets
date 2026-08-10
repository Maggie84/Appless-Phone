import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';

export class CheckEmailBehavior implements ModeBehavior {
  readonly name = 'check-email';
  readonly displayName = '查看办公邮件';

  async execute(_ctx: ModeContext): Promise<ModeBehaviorResult> {
    // TODO(real-exec): 接入真实邮箱读取（QqMailImapClient / readConfiguredMailDetail）。
    const rows: A2uiGenericToolResultRowData[] = [
      { label: '收件箱', value: '点击刷新按钮查看最新邮件' },
      { label: '未读', value: '待更新' },
    ];

    const actions: A2uiAction[] = [
      {
        id: 'mode.email.refresh',
        label: '刷新收件箱',
        prompt: '检查我的收件箱，看看有没有新邮件',
        variant: 'primary',
        kind: 'prompt',
      },
    ];

    const toolResult: A2uiGenericToolResultData = {
      sourceTag: '邮件',
      toolName: 'check-email',
      title: '查看办公邮件',
      status: 'success',
      summary: '点击刷新按钮检查未读邮件',
      rows: rows,
      rawPreview: '',
      actions: actions,
    };

    return {
      ok: true,
      message: '邮件提醒已准备',
      toolResults: [toolResult],
    };
  }
}