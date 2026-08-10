import { common } from '@kit.AbilityKit';
import {
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiSurfaceState,
  A2uiSurfaceStore,
  A2UI_VERSION,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_TEXT,
} from '@loop/agent-core';
import { ModeRegistry } from './ModeRegistry';
import { ModeDefinition } from './ModeDefinition';
import { ModeKind, ModeBehaviorResult } from './ModeTypes';
import { ModeContext } from './ModeBehavior';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF;
const LOG_TAG = 'ModeOrchestrator';

interface ModeBehaviorCard {
  name: string;
  displayName: string;
  result: ModeBehaviorResult;
}

export class ModeOrchestrator {
  private readonly registry: ModeRegistry;
  private readonly surfaceCallback: (s: A2uiSurfaceState) => void;
  private context: common.UIAbilityContext | null;
  private activeMode: ModeKind | null;

  constructor(registry: ModeRegistry, surfaceCallback: (s: A2uiSurfaceState) => void) {
    this.registry = registry;
    this.surfaceCallback = surfaceCallback;
    this.context = null;
    this.activeMode = null;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async trigger(kind: ModeKind, force: boolean = false): Promise<string> {
    if (!force && this.activeMode === kind) {
      hilog.info(DOMAIN, LOG_TAG, 'already in mode %{public}s, skip', kind);
      return '';
    }
    const def = this.registry.find(kind);
    if (def === null) {
      hilog.warn(DOMAIN, LOG_TAG, 'no mode registered for %{public}s', kind);
      return '';
    }
    if (this.context === null) {
      hilog.error(DOMAIN, LOG_TAG, 'context not set, cannot trigger %{public}s', kind);
      return '';
    }

    hilog.info(DOMAIN, LOG_TAG, 'triggering mode %{public}s, %{public}d behaviors',
      kind, `${def.behaviors.length}`);
    this.activeMode = kind;

    const ctx: ModeContext = {
      kind: kind,
      surfaceCallback: this.surfaceCallback,
      context: this.context,
    };

    const cards: ModeBehaviorCard[] = [];
    const allToolResults: A2uiGenericToolResultData[] = [];
    for (let i = 0; i < def.behaviors.length; i++) {
      const behavior = def.behaviors[i];
      try {
        hilog.info(DOMAIN, LOG_TAG, 'executing behavior %{public}s', behavior.name);
        const result = await behavior.execute(ctx);
        hilog.info(DOMAIN, LOG_TAG, 'behavior %{public}s ok=%{public}s results=%{public}d',
          behavior.name, `${result.ok}`, `${result.toolResults.length}`);
        cards.push({
          name: behavior.name,
          displayName: behavior.displayName,
          result: result,
        });
        result.toolResults.forEach((item: A2uiGenericToolResultData) => {
          allToolResults.push(item);
        });
      } catch (error) {
        const msg = error instanceof Error ? error.message : `${error}`;
        hilog.error(DOMAIN, LOG_TAG, 'behavior %{public}s failed: %{public}s', behavior.name, msg);
        allToolResults.push({
          sourceTag: behavior.displayName,
          toolName: behavior.name,
          title: behavior.displayName,
          status: 'error',
          summary: '执行失败：' + msg.substring(0, 120),
          rows: [],
          rawPreview: '',
          actions: [],
        });
      }
    }

    const surface = this.buildModeSurface(def, allToolResults);
    this.surfaceCallback(surface);

    return def.displayName + '已激活';
  }

  private buildModeSurface(def: ModeDefinition, toolResults: A2uiGenericToolResultData[]): A2uiSurfaceState {
    const surfaceId = 'surface_mode_' + def.kind;
    const store = new A2uiSurfaceStore();
    const titles: string[] = [];
    toolResults.forEach((item: A2uiGenericToolResultData) => {
      titles.push(item.title);
    });
    const debugTitle = def.displayName + '已激活';

    const nonMediaResults: A2uiGenericToolResultData[] = [];
    const mediaResults: A2uiGenericToolResultData[] = [];
    toolResults.forEach((item: A2uiGenericToolResultData) => {
      if (item.sourceTag === '哔哩哔哩' || item.sourceTag === 'YouTube Data API') {
        mediaResults.push(item);
      } else {
        nonMediaResults.push(item);
      }
    });
    const orderedResults = nonMediaResults.concat(mediaResults);

    store.apply({
      version: A2UI_VERSION,
      createSurface: {
        surfaceId: surfaceId,
        root: 'root',
        title: debugTitle,
        intent: 'mode-' + def.kind,
        status: 'ready',
        sendDataModel: true,
      },
    });

    const dataModel: Record<string, Object> = {};
    if (orderedResults.length > 0) {
      dataModel['genericToolResults'] = orderedResults;
    }
    const dataModelJson = JSON.stringify(dataModel);

    const components: A2uiComponent[] = [
      {
        id: 'root',
        component: A2UI_COMPONENT_SURFACE_ROOT,
        child: 'mode_column',
        title: def.displayName,
        status: 'ready',
      },
      {
        id: 'mode_column',
        component: A2UI_COMPONENT_COLUMN,
        children: ['mode_media'],
        title: def.displayName,
        status: 'ready',
      },
      {
        id: 'mode_media',
        component: A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
        title: def.displayName,
        status: 'ready',
      },
    ];

    store.apply({
      version: A2UI_VERSION,
      updateComponents: {
        surfaceId: surfaceId,
        components: components,
      },
    });

    const finalSurface = store.getSurface();
    finalSurface.dataModelJson = dataModelJson;

    return finalSurface;
  }

  exit(): void {
    if (this.activeMode !== null) {
      hilog.info(DOMAIN, LOG_TAG, 'exiting mode %{public}s', this.activeMode);
      this.activeMode = null;
    }
  }

  getActiveMode(): ModeKind | null {
    return this.activeMode;
  }
}