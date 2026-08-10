import { ModeBehavior } from './ModeBehavior';
import { ModeKind, GeoFence } from './ModeTypes';

export class ModeDefinition {
  readonly kind: ModeKind;
  readonly displayName: string;
  readonly description: string;
  readonly behaviors: ModeBehavior[];
  readonly geoFence: GeoFence;

  constructor(
    kind: ModeKind,
    displayName: string,
    description: string,
    behaviors: ModeBehavior[],
    geoFence: GeoFence
  ) {
    this.kind = kind;
    this.displayName = displayName;
    this.description = description;
    this.behaviors = behaviors;
    this.geoFence = geoFence;
  }
}
