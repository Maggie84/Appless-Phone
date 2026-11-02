import { describe, expect, it } from '@ohos/hypium';
import { BbpHttpTransport } from '../main/ets/bbp/BbpHttpTransport';
import { BbpEventReporter } from '../main/ets/bbp/BbpEventReporter';
import { BbpHttpResponse } from '../main/ets/bbp/BbpTypes';
import { createLocationTransitionEvent } from '../main/ets/bbp/BbpEventFactory';
import { BbpLocationTransitionEvent } from '../main/ets/bbp/BbpTypes';
import { createMobileMessage } from '../main/ets/bbp/BbpMobileMessageFactory';

class FakeBbpHttpTransport implements BbpHttpTransport {
  url: string = '';
  headers: Record<string, string> = {};
  body: string = '';
  response: BbpHttpResponse = {
    statusCode: 200,
    body: '{"status":"processed","eventId":"event-1","action":"COOLING","message":"车机已收到"}'
  };
  error: Error | null = null;

  async postJson(url: string, headers: Record<string, string>, body: string): Promise<BbpHttpResponse> {
    this.url = url;
    this.headers = headers;
    this.body = body;
    if (this.error !== null) {
      throw this.error;
    }
    return this.response;
  }

  async getJson(url: string, headers: Record<string, string>): Promise<BbpHttpResponse> {
    this.url = url;
    this.headers = headers;
    if (this.error !== null) {
      throw this.error;
    }
    return this.response;
  }
}

function officeExitEvent(): BbpLocationTransitionEvent {
  return createLocationTransitionEvent({
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
}

export default function bbpEventReporterTest() {
  describe('bbpEventReporter', () => {
    it('posts the exact event to the BBP callback', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      const result = await new BbpEventReporter(transport).report('http://192.168.1.8:8081/', officeExitEvent());

      expect(transport.url).assertEqual('http://192.168.1.8:8081/api/internal/perception/events');
      expect(transport.headers['Content-Type']).assertEqual('application/json; charset=utf-8');
      expect(transport.body.indexOf('phone.location.transition')).assertLarger(-1);
      expect(result.status).assertEqual('processed');
      expect(result.ok).assertTrue();
      expect(result.action).assertEqual('COOLING');
      expect(result.message).assertEqual('车机已收到');
    });

    it('treats duplicate as successful non-delivery', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      transport.response = { statusCode: 200, body: '{"status":"duplicate","eventId":"event-1"}' };
      const result = await new BbpEventReporter(transport).report('http://192.168.1.8:8081', officeExitEvent());

      expect(result.ok).assertTrue();
      expect(result.duplicate).assertTrue();
      expect(result.status).assertEqual('duplicate');
    });

    it('treats a server error status as failure', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      transport.response = { statusCode: 200, body: '{"status":"error","message":"dispatch failed"}' };
      const result = await new BbpEventReporter(transport).report('http://192.168.1.8:8081', officeExitEvent());

      expect(result.ok).assertFalse();
      expect(result.status).assertEqual('error');
    });

    it('reports transport failure without throwing to UI', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      transport.error = new Error('network unavailable');
      const result = await new BbpEventReporter(transport).report('http://192.168.1.8:8081', officeExitEvent());

      expect(result.ok).assertFalse();
      expect(result.message.indexOf('network unavailable')).assertLarger(-1);
    });

    it('rejects a missing endpoint without calling transport', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      const result = await new BbpEventReporter(transport).report('', officeExitEvent());

      expect(result.ok).assertFalse();
      expect(result.message.indexOf('BBP endpoint is required')).assertLarger(-1);
      expect(transport.url).assertEqual('');
    });

    it('posts raw mobile text to the 8070 information center', 0, async () => {
      const transport = new FakeBbpHttpTransport();
      transport.response = {
        statusCode: 202,
        body: '{"status":"accepted","eventId":"event-2","eventType":"phone.office.exited","message":"已识别离开公司，正在评估温控策略"}'
      };
      const message = createMobileMessage('event-2', '我离开公司了', '2026-09-17T06:00:00.000Z');

      const result = await new BbpEventReporter(transport)
        .reportMobileMessage('http://192.168.1.8:8070/', message);

      expect(transport.url).assertEqual('http://192.168.1.8:8070/information-center/v1/mobile/messages');
      expect(transport.body.indexOf('我离开公司了')).assertLarger(-1);
      expect(result.ok).assertTrue();
      expect(result.status).assertEqual('accepted');
    });
  });
}
