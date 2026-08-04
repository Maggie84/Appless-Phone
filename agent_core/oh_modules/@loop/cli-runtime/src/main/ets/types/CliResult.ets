export class CliResult {
  readonly ok: boolean;
  readonly stdout: string;
  readonly stderr: string;
  readonly exitCode: number;
  readonly durationMs: number;
  readonly error: string | null;

  private constructor(
    ok: boolean,
    stdout: string,
    stderr: string,
    exitCode: number,
    durationMs: number,
    error: string | null
  ) {
    this.ok = ok;
    this.stdout = stdout;
    this.stderr = stderr;
    this.exitCode = exitCode;
    this.durationMs = durationMs;
    this.error = error;
  }

  static success(stdout: string, exitCode: number, durationMs: number): CliResult {
    return new CliResult(true, stdout, '', exitCode, durationMs, null);
  }

  static failure(error: string, exitCode: number = -1): CliResult {
    return new CliResult(false, '', '', exitCode, 0, error);
  }

  static fromExecution(stdout: string, stderr: string, exitCode: number, durationMs: number): CliResult {
    const ok = exitCode === 0;
    return new CliResult(ok, stdout, stderr, exitCode, durationMs, ok ? null : `exit ${exitCode}`);
  }

  toObservation(): string {
    if (this.error !== null && !this.ok) {
      let msg = `操作失败（${this.error}）`;
      if (this.stderr.length > 0) {
        msg += `：${this.stderr}`;
      }
      return msg;
    }
    return '操作已完成';
  }
}
