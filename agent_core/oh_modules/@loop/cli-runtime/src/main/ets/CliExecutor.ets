import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'CliExecutor';

export interface CliOut {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}
export type CliExecFn = (command: string) => CliOut;

export interface ExecutedCommand {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}

export class CliExecutor {
  private readonly execFn: CliExecFn;

  constructor(execFn: CliExecFn) {
    this.execFn = execFn;
  }

  async exec(command: string, _timeoutMs: number = 30000): Promise<ExecutedCommand> {
    const start = Date.now();
    try {
      const result = this.execFn(command);
      return {
        stdout: result.stdout ?? '',
        stderr: result.stderr ?? '',
        exitCode: result.exitCode ?? -1,
        durationMs: Date.now() - start
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'exec failed: %{public}s', msg);
      return { stdout: '', stderr: msg, exitCode: -1, durationMs: Date.now() - start };
    }
  }
}
