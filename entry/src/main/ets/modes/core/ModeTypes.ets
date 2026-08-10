import { ModeKind, A2uiGenericToolResultData } from '@loop/agent-core';

export { ModeKind } from '@loop/agent-core';

export interface GeoFence {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  label: string;
}

export interface ModeBehaviorResult {
  ok: boolean;
  message: string;
  toolResults: A2uiGenericToolResultData[];
}