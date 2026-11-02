export type LocationTransition = 'enter' | 'exit';
export type BbpTriggerSource = 'demo_button' | 'geofence';
export type BbpMockLocation = 'office' | 'home';

export interface BbpLocationTransitionEvent {
  eventId: string;
  eventType: 'phone.location.transition';
  deviceId: string;
  subject: 'appless-phone';
  oldValue: string;
  newValue: string;
  occurredAt: string;
  sourceVersion: 'appless-phone-v1';
  attributes: Record<string, string>;
}

export interface BbpMobileMessage {
  eventId: string;
  deviceId: string;
  sessionId: string;
  message: string;
  occurredAt: string;
  sourceVersion: 'appless-phone-v1';
  ambientTemperatureC: number;
}

export interface CreateLocationTransitionEventInput {
  eventId: string;
  deviceId: string;
  transition: LocationTransition;
  placeId: string;
  placeName: string;
  destinationPlaceId?: string;
  destinationPlaceName?: string;
  ambientTemperatureC?: number;
  targetTemperatureC?: number;
  triggerSource: BbpTriggerSource;
  occurredAt: string;
}

export interface BbpHttpResponse {
  statusCode: number;
  body: string;
}

export interface BbpReportResult {
  ok: boolean;
  duplicate: boolean;
  status: 'accepted' | 'processing' | 'processed' | 'succeeded' | 'cooldown' | 'failed' |
    'duplicate' | 'ignored' | 'invalid' | 'error';
  message: string;
  eventId: string;
  action: string;
}

export interface BbpSettings {
  endpoint: string;
  enabled: boolean;
  mockLocation: BbpMockLocation;
  ambientTemperatureText: string;
  targetTemperatureText: string;
}
