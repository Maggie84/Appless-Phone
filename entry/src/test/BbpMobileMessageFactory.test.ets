import { describe, expect, it } from '@ohos/hypium';
import { createMobileMessage, isOfficeExitMessage } from '../main/ets/bbp/BbpMobileMessageFactory';

export default function bbpMobileMessageFactoryTest() {
  describe('bbpMobileMessageFactory', () => {
    it('recognizes supported office exit phrases', 0, () => {
      expect(isOfficeExitMessage('我离开公司回家了')).assertTrue();
      expect(isOfficeExitMessage('下班回家')).assertTrue();
      expect(isOfficeExitMessage('准备从公司回家')).assertTrue();
    });

    it('rejects negated and unrelated phrases', 0, () => {
      expect(isOfficeExitMessage('我还没离开公司')).assertFalse();
      expect(isOfficeExitMessage('不要离开公司')).assertFalse();
      expect(isOfficeExitMessage('今天天气不错')).assertFalse();
    });

    it('creates the mobile message wire payload', 0, () => {
      const message = createMobileMessage('event-1', '我离开公司了', '2026-09-17T06:00:00.000Z');
      expect(message.eventId).assertEqual('event-1');
      expect(message.deviceId).assertEqual('demo-device-001');
      expect(message.sessionId).assertEqual('appless-phone-001');
      expect(message.sourceVersion).assertEqual('appless-phone-v1');
    });
  });
}
