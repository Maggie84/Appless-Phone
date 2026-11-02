import {
  BbpLocationTransitionEvent,
  CreateLocationTransitionEventInput,
} from './BbpTypes';

function requireText(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new Error(name + ' is required');
  }
  return normalized;
}

function requireTemperature(value: number | undefined, name: string): number {
  if (value === undefined || !Number.isFinite(value)) {
    throw new Error(name + ' must be a finite number');
  }
  return value;
}

export function createLocationTransitionEvent(
  input: CreateLocationTransitionEventInput,
): BbpLocationTransitionEvent {
  const eventId = requireText(input.eventId, 'eventId');
  const deviceId = requireText(input.deviceId, 'deviceId');
  const placeId = requireText(input.placeId, 'placeId');
  const placeName = requireText(input.placeName, 'placeName');
  const occurredAt = requireText(input.occurredAt, 'occurredAt');
  const destinationPlaceId = input.destinationPlaceId === undefined ? '' : input.destinationPlaceId.trim();
  const destinationPlaceName = input.destinationPlaceName === undefined ? '' : input.destinationPlaceName.trim();
  const ambientTemperatureC = requireTemperature(input.ambientTemperatureC, 'ambientTemperatureC');
  const targetTemperatureC = requireTemperature(input.targetTemperatureC, 'targetTemperatureC');
  if (targetTemperatureC < 16 || targetTemperatureC > 32) {
    throw new Error('targetTemperatureC must be between 16 and 32');
  }
  if (input.transition !== 'enter' && input.transition !== 'exit') {
    throw new Error('transition must be enter or exit');
  }

  const isExit = input.transition === 'exit';
  const attributes: Record<string, string> = {};
  attributes['transition'] = input.transition;
  attributes['placeId'] = placeId;
  attributes['placeName'] = placeName;
  attributes['triggerSource'] = input.triggerSource;
  attributes['ambientTemperatureC'] = ambientTemperatureC.toString();
  attributes['targetTemperatureC'] = targetTemperatureC.toString();
  if (destinationPlaceId.length > 0) {
    attributes['destinationPlaceId'] = destinationPlaceId;
  }
  if (destinationPlaceName.length > 0) {
    attributes['destinationPlaceName'] = destinationPlaceName;
  }
  const event: BbpLocationTransitionEvent = {
    eventId: eventId,
    eventType: 'phone.location.transition',
    deviceId: deviceId,
    subject: 'appless-phone',
    oldValue: isExit ? placeId : 'outside',
    newValue: isExit ? 'outside' : placeId,
    occurredAt: occurredAt,
    sourceVersion: 'appless-phone-v1',
    attributes: attributes,
  };
  return event;
}
