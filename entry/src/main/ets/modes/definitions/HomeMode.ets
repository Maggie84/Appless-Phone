import { ModeDefinition } from '../core/ModeDefinition';
import { ModeKind, GeoFence } from '../core/ModeTypes';
import { MusicRecommendBehavior } from '../behaviors/MusicRecommendBehavior';
import { SmartHomeControlBehavior } from '../behaviors/SmartHomeControlBehavior';
import { DoNotDisturbBehavior } from '../behaviors/DoNotDisturbBehavior';

export function createHomeMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.HOME,
    '回家模式',
    '已到家，切换到放松模式',
    [
      new MusicRecommendBehavior(),
      new SmartHomeControlBehavior(),
      new DoNotDisturbBehavior(),
    ],
    fence
  );
}
