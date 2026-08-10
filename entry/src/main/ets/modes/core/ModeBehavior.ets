import { common } from '@kit.AbilityKit';
import { A2uiSurfaceState } from '@loop/agent-core';
import { ModeKind, ModeBehaviorResult } from './ModeTypes';

export interface ModeContext {
  kind: ModeKind;
  surfaceCallback: (surface: A2uiSurfaceState) => void;
  context: common.UIAbilityContext;
}

export interface ModeBehavior {
  readonly name: string;
  readonly displayName: string;
  execute(ctx: ModeContext): Promise<ModeBehaviorResult>;
}
