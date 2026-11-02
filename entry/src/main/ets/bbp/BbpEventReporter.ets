import { BbpHttpTransport } from './BbpHttpTransport';
import { BbpHttpResponse, BbpLocationTransitionEvent, BbpMobileMessage, BbpReportResult } from './BbpTypes';

function callbackUrl(endpoint: string): string {
  const normalized = endpoint.trim().replace(/\/+$/, '');
  if (normalized.length === 0) {
    throw new Error('BBP endpoint is required');
  }
  return normalized.endsWith('/api/internal/perception/events')
    ? normalized
    : normalized + '/api/internal/perception/events';
}

function mobileMessageUrl(endpoint: string): string {
  const normalized = endpoint.trim().replace(/\/+$/, '');
  if (normalized.length === 0) {
    throw new Error('BBP endpoint is required');
  }
  return normalized.endsWith('/information-center/v1/mobile/messages')
    ? normalized
    : normalized + '/information-center/v1/mobile/messages';
}

function mobileMessageStatusUrl(endpoint: string, eventId: string): string {
  return mobileMessageUrl(endpoint) + '/' + encodeURIComponent(eventId) + '/status';
}

function errorResult(eventId: string, message: string): BbpReportResult {
  return {
    ok: false,
    duplicate: false,
    status: 'error',
    message: message,
    eventId: eventId,
    action: '',
  };
}

export class BbpEventReporter {
  private readonly transport: BbpHttpTransport;

  constructor(transport: BbpHttpTransport) {
    this.transport = transport;
  }

  async report(endpoint: string, event: BbpLocationTransitionEvent): Promise<BbpReportResult> {
    try {
      return await this.post(callbackUrl(endpoint), event.eventId, event);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      return errorResult(event.eventId, message);
    }
  }

  async reportMobileMessage(endpoint: string, message: BbpMobileMessage): Promise<BbpReportResult> {
    try {
      return await this.post(mobileMessageUrl(endpoint), message.eventId, message);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : `${error}`;
      return errorResult(message.eventId, errorMessage);
    }
  }

  async getMobileMessageStatus(endpoint: string, eventId: string): Promise<BbpReportResult> {
    try {
      const response = await this.transport.getJson(mobileMessageStatusUrl(endpoint, eventId), {
        'Accept': 'application/json',
      });
      return this.parse(response, eventId);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : `${error}`;
      return errorResult(eventId, errorMessage);
    }
  }

  private async post(url: string, eventId: string,
    payload: BbpLocationTransitionEvent | BbpMobileMessage): Promise<BbpReportResult> {
    try {
      const response = await this.transport.postJson(
        url,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        JSON.stringify(payload),
      );
      return this.parse(response, eventId);
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      return errorResult(eventId, message);
    }
  }

  private parse(response: BbpHttpResponse, eventId: string): BbpReportResult {
      let parsed: Record<string, Object | string | number | boolean | null> = {};
      try {
        parsed = JSON.parse(response.body) as Record<string, Object | string | number | boolean | null>;
      } catch (_error) {
        return errorResult(eventId, 'BBP returned a non-JSON response');
      }

      const statusValue = parsed['status'];
      const status = typeof statusValue === 'string' ? statusValue : '';
      const messageValue = parsed['message'];
      const message = typeof messageValue === 'string' ? messageValue : '';
      const actionValue = parsed['action'];
      const action = typeof actionValue === 'string' ? actionValue : '';
      if (response.statusCode >= 200 && response.statusCode < 300 &&
        (status === 'accepted' || status === 'processed' || status === 'processing' || status === 'succeeded' ||
          status === 'cooldown' || status === 'failed')) {
        return {
          ok: true,
          duplicate: false,
          status: status as 'accepted' | 'processing' | 'processed' | 'succeeded' | 'cooldown' | 'failed',
          message: message.length > 0 ? message : 'BBP accepted event',
          eventId: eventId,
          action: action,
        };
      }
      if (response.statusCode >= 200 && response.statusCode < 300 && status === 'duplicate') {
        return {
          ok: true,
          duplicate: true,
          status: 'duplicate',
          message: message.length > 0 ? message : 'BBP already processed event',
          eventId: eventId,
          action: action,
        };
      }
      if (response.statusCode >= 200 && response.statusCode < 300 && status === 'ignored') {
        return {
          ok: true,
          duplicate: false,
          status: 'ignored',
          message: message.length > 0 ? message : 'BBP ignored message',
          eventId: eventId,
          action: action,
        };
      }
      return {
        ok: false,
        duplicate: false,
        status: status === 'invalid' ? 'invalid' : 'error',
        message: message.length > 0 ? message : `BBP request failed with HTTP ${response.statusCode}`,
        eventId: eventId,
        action: action,
      };
  }
}
