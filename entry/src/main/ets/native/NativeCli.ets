import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'NativeCli';

interface CliOut {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}

let _execFn: ((cmd: string) => CliOut) | null = null;
let _initError: string = '';

async function tryInit(): Promise<void> {
  try {
    const mod = (await import('libcli_bridge.so')) as Record<string, Object>;
    const exports = (mod['default'] as Record<string, Object>) ?? mod;
    const keys: string[] = Object.keys(exports);
    const execCallable = exports['execute'] as CallableFunction;
    if (typeof execCallable !== 'function') {
      _initError = `no execute fn, keys=[${keys.join(',')}]`;
      return;
    }
    _execFn = (cmd: string): CliOut => {
      const raw = execCallable(cmd) as Record<string, Object>;
      const out: CliOut = {
        stdout: (raw['stdout'] as string) ?? '',
        stderr: (raw['error'] as string) ?? '',
        exitCode: (raw['exitCode'] as number) ?? -1,
        durationMs: 0
      };
      return out;
    };
  } catch (e) {
    _initError = e instanceof Error ? e.message : `${e}`;
    hilog.error(DOMAIN, LOG_TAG, 'init failed: %{public}s', _initError);
  }
}

let _initPromise: Promise<void> | null = null;

export function ensureInit(): Promise<void> {
  if (_execFn !== null) {
    return Promise.resolve();
  }
  if (_initPromise === null) {
    _initPromise = tryInit();
  }
  return _initPromise;
}

export function getExecFn(): ((cmd: string) => CliOut) | null {
  return _execFn;
}

export function getError(): string {
  return _initError;
}
