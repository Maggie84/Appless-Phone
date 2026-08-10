import { ModeDefinition } from '../core/ModeDefinition';
import { ModeKind, GeoFence } from '../core/ModeTypes';
import { CheckEmailBehavior } from '../behaviors/CheckEmailBehavior';
import { DoNotDisturbBehavior } from '../behaviors/DoNotDisturbBehavior';

export function createWorkMode(fence: GeoFence): ModeDefinition {
  return new ModeDefinition(
    ModeKind.WORK,
    '到公司模式',
    '已到公司，切换到工作模式',
    [
      new CheckEmailBehavior(),
      new DoNotDisturbBehavior(),
    ],
    fence
  );
}
