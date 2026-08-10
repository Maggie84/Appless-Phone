import { ModeKind } from './ModeKind';

export interface ModeApi {
  subscribeHome(latitude: number, longitude: number, radius: number): string;
  subscribeWork(latitude: number, longitude: number, radius: number): string;
  manualTrigger(kind: ModeKind): void;
}
