import { BbpMobileMessage } from './BbpTypes';

const EXIT_PHRASES: string[] = ['离开公司', '下班回家', '从公司回家'];
const NEGATED_PHRASES: string[] = ['不要离开公司', '别离开公司', '还没离开公司', '没有离开公司', '未离开公司'];

export function isOfficeExitMessage(message: string): boolean {
  const normalized = message.trim().replace(/\s+/g, '');
  if (normalized.length === 0) {
    return false;
  }
  for (const phrase of NEGATED_PHRASES) {
    if (normalized.indexOf(phrase) >= 0) {
      return false;
    }
  }
  for (const phrase of EXIT_PHRASES) {
    if (normalized.indexOf(phrase) >= 0) {
      return true;
    }
  }
  return false;
}

export function createMobileMessage(
  eventId: string,
  message: string,
  occurredAt: string,
  sessionId: string = 'appless-phone-001',
  ambientTemperatureC: number = 25,
): BbpMobileMessage {
  const normalizedEventId = eventId.trim();
  const normalizedMessage = message.trim();
  if (normalizedEventId.length === 0) {
    throw new Error('eventId is required');
  }
  if (normalizedMessage.length === 0) {
    throw new Error('message is required');
  }
  if (!Number.isFinite(ambientTemperatureC)) {
    throw new Error('ambientTemperatureC must be a finite number');
  }
  return {
    eventId: normalizedEventId,
    deviceId: 'demo-device-001',
    sessionId: sessionId,
    message: normalizedMessage,
    occurredAt: occurredAt,
    sourceVersion: 'appless-phone-v1',
    ambientTemperatureC: ambientTemperatureC,
  };
}
