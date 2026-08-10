import { ModeDefinition } from './ModeDefinition';
import { ModeKind, GeoFence } from './ModeTypes';

export class ModeRegistry {
  private readonly modes: Map<ModeKind, ModeDefinition> = new Map();

  register(def: ModeDefinition): void {
    this.modes.set(def.kind, def);
  }

  find(kind: ModeKind): ModeDefinition | null {
    const def = this.modes.get(kind);
    return def === undefined ? null : def;
  }

  allFences(): GeoFence[] {
    const fences: GeoFence[] = [];
    this.modes.forEach((def: ModeDefinition) => {
      fences.push(def.geoFence);
    });
    return fences;
  }

  clear(): void {
    this.modes.clear();
  }
}
