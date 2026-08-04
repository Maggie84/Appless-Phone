import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CliCommand } from './types/CliSkill';

const DOMAIN = 0xFF;
const LOG_TAG = 'PermissionChecker';

export type PermissionState = 'granted' | 'denied' | 'not_declared';

export interface CheckResult {
  ok: boolean;
  missing: string[];
  reason: string | null;
}

export class PermissionChecker {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async checkAll(command: CliCommand): Promise<CheckResult> {
    if (command.requiredPermissions.length === 0) {
      return { ok: true, missing: [], reason: null };
    }

    // 尝试通过 abilityAccessCtrl 做运行时权限校验
    const missing: string[] = [];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      // ArkTS 的 Permissions 是 string literal union，无法直接传入动态 string，
      // 因此用白名单映射。
      const tokenId = (this.context as Object as Record<string, Object>)['tokenId'] as number;

      if (typeof tokenId === 'number' && tokenId > 0) {
        for (let i = 0; i < command.requiredPermissions.length; i++) {
          const perm = command.requiredPermissions[i];
          try {
            let status: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
            if (perm === 'ohos.permission.ACCESS_BLUETOOTH') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.ACCESS_BLUETOOTH');
            } else if (perm === 'ohos.permission.MICROPHONE') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.MICROPHONE');
            } else if (perm === 'ohos.permission.LOCATION') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.LOCATION');
            } else if (perm === 'ohos.permission.APPROXIMATELY_LOCATION') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.APPROXIMATELY_LOCATION');
            } else if (perm === 'ohos.permission.READ_CALENDAR') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.READ_CALENDAR');
            } else if (perm === 'ohos.permission.WRITE_CALENDAR') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.WRITE_CALENDAR');
            } else if (perm === 'ohos.permission.INTERNET') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.INTERNET');
            } else if (perm === 'ohos.permission.GET_NETWORK_INFO') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.GET_NETWORK_INFO');
            } else if (perm === 'ohos.permission.GET_BUNDLE_INFO') {
              status = await atManager.checkAccessToken(tokenId, 'ohos.permission.GET_BUNDLE_INFO');
            }
            if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
              missing.push(perm);
            }
          } catch (_e1) {
            hilog.warn(DOMAIN, LOG_TAG, 'skip check %{public}s (unchecked)', perm);
          }
        }
      }
    } catch (_e2) {
      hilog.warn(DOMAIN, LOG_TAG, 'permission check skipped (fallback)');
    }

    if (missing.length > 0) {
      return { ok: false, missing: missing, reason: 'missing permissions: ' + missing.join(', ') };
    }
    return { ok: true, missing: [], reason: null };
  }
}
