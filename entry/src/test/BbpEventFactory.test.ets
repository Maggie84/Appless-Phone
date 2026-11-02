import { describe, expect, it } from '@ohos/hypium';
import { createLocationTransitionEvent } from '../main/ets/bbp/BbpEventFactory';

export default function bbpEventFactoryTest() {
  describe('bbpEventFactory', () => {
    it('creates an office exit fact without claiming arrival home', 0, () => {
      const event = createLocationTransitionEvent({
        eventId: 'event-1',
        deviceId: 'demo-device-001',
        transition: 'exit',
        placeId: 'office',
        placeName: '公司',
        destinationPlaceId: 'home',
        destinationPlaceName: '家',
        ambientTemperatureC: 30,
        targetTemperatureC: 24,
        triggerSource: 'demo_button',
        occurredAt: '2026-09-03T10:00:00.000Z',
      });

      expect(event.eventType).assertEqual('phone.location.transition');
      expect(event.subject).assertEqual('appless-phone');
      expect(event.oldValue).assertEqual('office');
      expect(event.newValue).assertEqual('outside');
      expect(event.attributes['transition']).assertEqual('exit');
      expect(event.attributes['placeId']).assertEqual('office');
      expect(event.attributes['destinationPlaceId']).assertEqual('home');
      expect(event.attributes['ambientTemperatureC']).assertEqual('30');
      expect(event.attributes['targetTemperatureC']).assertEqual('24');
    });

    it('creates an office enter fact', 0, () => {
      const event = createLocationTransitionEvent({
        eventId: 'event-2',
        deviceId: 'demo-device-001',
        transition: 'enter',
        placeId: 'office',
        placeName: '公司',
        ambientTemperatureC: 20,
        targetTemperatureC: 24,
        triggerSource: 'demo_button',
        occurredAt: '2026-09-03T10:00:00.000Z',
      });

      expect(event.oldValue).assertEqual('outside');
      expect(event.newValue).assertEqual('office');
    });

    it('rejects a non-finite mock temperature', 0, () => {
      let failed = false;
      try {
        createLocationTransitionEvent({
          eventId: 'event-3',
          deviceId: 'demo-device-001',
          transition: 'exit',
          placeId: 'office',
          placeName: '公司',
          ambientTemperatureC: Number.NaN,
          targetTemperatureC: 24,
          triggerSource: 'demo_button',
          occurredAt: '2026-09-03T10:00:00.000Z',
        });
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });

    it('rejects an out-of-range target temperature', 0, () => {
      let failed = false;
      try {
        createLocationTransitionEvent({
          eventId: 'event-4',
          deviceId: 'demo-device-001',
          transition: 'exit',
          placeId: 'office',
          placeName: '公司',
          ambientTemperatureC: 30,
          targetTemperatureC: 33,
          triggerSource: 'demo_button',
          occurredAt: '2026-09-03T10:00:00.000Z',
        });
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });
  });
}
