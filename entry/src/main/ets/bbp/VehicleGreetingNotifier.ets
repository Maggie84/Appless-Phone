import { common, Want } from '@kit.AbilityKit';
import notificationManager from '@ohos.notificationManager';
import notification from '@ohos.notification';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { emitter } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const LOG_TAG = 'AIPhone';

export const VEHICLE_GREETING_EVENT_ID: number = 9527;
export const VEHICLE_GREETING_WANT_PARAM: string = 'vehicleGreeting';
export const VEHICLE_GREETING_CONFIRM_VALUE: string = 'yes';
export const VEHICLE_GREETING_DISMISS_VALUE: string = 'dismiss';

export interface VehicleGreetingState {
  pending: boolean;
}

export const vehicleGreetingState: VehicleGreetingState = { pending: false };

const NOTIFICATION_ID: number = 2001;

export async function requestVehicleGreetingNotificationPermission(
  context: common.UIAbilityContext
): Promise<boolean> {
  try {
    const enabled = await notificationManager.isNotificationEnabled();
    if (enabled) {
      return true;
    }
    await notificationManager.requestEnableNotification(context);
    const granted = await notificationManager.isNotificationEnabled();
    hilog.info(DOMAIN, LOG_TAG, 'vehicle greeting notification permission granted=%{public}s', `${granted}`);
    return granted;
  } catch (error) {
    const msg = error instanceof Error ? error.message : `${error}`;
    hilog.error(DOMAIN, LOG_TAG, 'request notification permission failed: %{public}s', msg);
    return false;
  }
}

export async function showVehicleGreetingNotification(
  context: common.UIAbilityContext
): Promise<void> {
  try {
    const bundleName = context.abilityInfo.bundleName;
    const abilityName = context.abilityInfo.name;

    const confirmParams: Record<string, Object> = {};
    confirmParams[VEHICLE_GREETING_WANT_PARAM] = VEHICLE_GREETING_CONFIRM_VALUE;
    const confirmWant: Want = {
      bundleName: bundleName,
      abilityName: abilityName,
      parameters: confirmParams,
    };

    const dismissParams: Record<string, Object> = {};
    dismissParams[VEHICLE_GREETING_WANT_PARAM] = VEHICLE_GREETING_DISMISS_VALUE;
    const dismissWant: Want = {
      bundleName: bundleName,
      abilityName: abilityName,
      parameters: dismissParams,
    };

    const confirmAgent: WantAgent = await wantAgent.getWantAgent({
      wants: [confirmWant],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
    });
    const dismissAgent: WantAgent = await wantAgent.getWantAgent({
      wants: [dismissWant],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
    });

    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      content: {
        contentType: notification.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '离开公司提醒',
          text: '检测到您已经离开公司，是否需要用车，提前打开迎宾模式？',
          additionalText: '点击「需要用车」将通知车机提前准备',
        },
      },
      actionButtons: [
        { title: '需要用车', wantAgent: confirmAgent },
        { title: '暂不需要', wantAgent: dismissAgent },
      ],
    };
    notificationManager.publish(request);
    hilog.info(DOMAIN, LOG_TAG, 'vehicle greeting notification published');
  } catch (error) {
    const msg = error instanceof Error ? error.message : `${error}`;
    hilog.error(DOMAIN, LOG_TAG, 'publish vehicle greeting notification failed: %{public}s', msg);
  }
}

export function emitVehicleGreetingConfirmed(): void {
  vehicleGreetingState.pending = true;
  const innerEvent: emitter.InnerEvent = {
    eventId: VEHICLE_GREETING_EVENT_ID,
    priority: emitter.EventPriority.HIGH,
  };
  emitter.emit(innerEvent);
}
