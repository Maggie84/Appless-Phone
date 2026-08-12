import { CliRuntime, CliResult } from '@loop/cli-runtime';
import { AgentTool } from './AgentTool';

export class CliExecTool implements AgentTool {
  private cliRuntime: CliRuntime;

  constructor(cliRuntime: CliRuntime) {
    this.cliRuntime = cliRuntime;
  }

  name(): string {
    return 'cli_exec';
  }

  description(): string {
    return 'Execute a CLI skill registered in cli_runtime. ' +
      'Input JSON: {"skill":"<skill_name>","command":"<command_name>","params":{<param_name>:<param_value>}}. ' +
      'Only skill/command pairs returned by the previous SkillMatcher suggestion are allowed.';
  }

  async run(input: string): Promise<string> {
    const trimmed = input.trim();
    if (trimmed.length === 0) {
      return 'cli_exec: no input provided';
    }

    let parsed: Record<string, Object> | null = null;
    try {
      parsed = JSON.parse(trimmed) as Record<string, Object>;
    } catch (_e) {
      return `cli_exec: invalid JSON input`;
    }
    if (parsed === null) {
      return `cli_exec: invalid JSON input`;
    }

    const skill = (parsed['skill'] as Object) ?? '';
    const command = (parsed['command'] as Object) ?? '';
    const paramsObj = (parsed['params'] as Record<string, Object>) ?? {};

    const skillStr = `${skill}`;
    const commandStr = `${command}`;
    if (skillStr.length === 0 || commandStr.length === 0) {
      return 'cli_exec: skill and command fields are required';
    }

    const params = new Map<string, string>();
    const keys = Object.keys(paramsObj);
    for (const key of keys) {
      const value = paramsObj[key];
      params.set(key, value === null || value === undefined ? '' : `${value}`);
    }

    const result: CliResult = await this.cliRuntime.execute(skillStr, commandStr, params);
    const obs = result.toObservation();
    if (result.stdout.indexOf('ERR_BT_ENABLE_FAILED') >= 0) {
      return '蓝牙已经是开启状态，不能重复打开。';
    }
    if (result.stdout.indexOf('ERR_BT_DISABLE_FAILED') >= 0) {
      return '蓝牙已经是关闭状态，不能重复关闭。';
    }
    return obs;
  }
}
