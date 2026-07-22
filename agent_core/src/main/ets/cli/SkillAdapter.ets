import { AgentSkill } from '../skill/AgentSkill';
import {
  CliSkill,
  CliCommand,
  OutputFormat
} from '@loop/cli-runtime';
import {
  CliExecutorKind,
  RiskLevel,
  ParamType,
  ParamSource,
  FallbackStrategy,
  ParamSpec,
  ParamSourceSpec
} from '@loop/cli-runtime';

const TEMPLATE_DANGEROUS_PATTERN = /[;&|`$()<>]/;

enum Section {
  NONE,
  TRIGGERS,
  REQUIRED_PERMISSIONS,
  PARAMETERS,
  OUTPUT_FORMAT,
  ERROR_CODES,
}

function getIndent(line: string): number {
  let count = 0;
  for (const ch of line) {
    if (ch === ' ') {
      count++;
    } else {
      break;
    }
  }
  return count;
}

export function adaptSkillToCli(skill: AgentSkill): CliSkill | null {
  const lines = skill.rawFrontmatter.split(/\r?\n/);
  const fields = parseTopLevelFields(lines);

  const type = fields.get('type') ?? 'instruction';
  if (type !== 'cli' && type !== 'cli_group' && type !== 'system_api') {
    return null;
  }

  const commands = parseCommands(lines);
  if (commands.length === 0) {
    return null;
  }

  return new CliSkill(
    skill.name,
    skill.description,
    type,
    fields.get('version') ?? '1.0',
    parseNumber(fields.get('schemaVersion'), 1),
    fields.get('author') ?? '',
    fields.get('homepage') ?? skill.homepage,
    commands
  );
}

function parseTopLevelFields(lines: string[]): Map<string, string> {
  const fields: Map<string, string> = new Map();
  for (const line of lines) {
    if (line.startsWith(' ') || line.startsWith('-')) {
      continue;
    }
    const colon = line.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    const key = line.substring(0, colon).trim();
    const value = line.substring(colon + 1).trim();
    if (key === 'commands' || key === 'parameters' || key === 'source' || key === 'output_format' || key === 'error_codes') {
      fields.set(key, '__block__');
      continue;
    }
    fields.set(key, value);
  }
  return fields;
}

function parseCommands(lines: string[]): CliCommand[] {
  const commands: CliCommand[] = [];
  const cmdStarts: number[] = [];

  for (let i = 0; i < lines.length; i++) {
    if (isCommandHeaderLine(lines[i])) {
      cmdStarts.push(i);
    }
  }
  cmdStarts.push(lines.length);

  for (let i = 0; i + 1 < cmdStarts.length; i++) {
    const start = cmdStarts[i];
    const end = cmdStarts[i + 1];
    const block = lines.slice(start, end);
    const cmd = parseCommandBlock(block);
    if (cmd !== null) {
      commands.push(cmd);
    }
  }
  return commands;
}

function isCommandHeaderLine(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed.startsWith('- ')) {
    return false;
  }
  const rest = trimmed.substring(2);
  const colon = rest.indexOf(':');
  if (colon <= 0) {
    return false;
  }
  const key = rest.substring(0, colon).trim();
  return key === 'name';
}

function parseCommandBlock(block: string[]): CliCommand | null {
  const fields = new Map<string, string>();
  const triggers: string[] = [];
  const parameters: ParamSpec[] = [];
  const requiredPermissions: string[] = [];
  const errorCodes: Map<string, string> = new Map();
  let outputFormat = new OutputFormat();
  let section = Section.NONE;
  let i = 0;

  while (i < block.length) {
    const line = block[i];
    const trimmed = line.trim();

    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      i++;
      continue;
    }

    if (trimmed.startsWith('- ')) {
      const content = trimmed.substring(2).trim();
      if (section === Section.TRIGGERS) {
        triggers.push(content);
        i++;
        continue;
      }
      if (section === Section.REQUIRED_PERMISSIONS) {
        requiredPermissions.push(content);
        i++;
        continue;
      }
      if (section === Section.PARAMETERS) {
        const param = parseParameterSpec(block, i);
        if (param !== null) {
          parameters.push(param);
        }
        const paramIndent = getIndent(line);
        i++;
        while (i < block.length) {
          const nextIndent = getIndent(block[i]);
          if (nextIndent <= paramIndent) {
            break;
          }
          i++;
        }
        continue;
      }
      if (section === Section.NONE) {
        const rest = trimmed.substring(2);
        const colon = rest.indexOf(':');
        if (colon > 0) {
          const key = rest.substring(0, colon).trim();
          if (key === 'name') {
            fields.set('name', rest.substring(colon + 1).trim());
          }
        }
      }
      i++;
      continue;
    }

    const colon = trimmed.indexOf(':');
    if (colon <= 0) {
      i++;
      continue;
    }
    const key = trimmed.substring(0, colon).trim();
    const value = trimmed.substring(colon + 1).trim();

    if (key === 'triggers') {
      section = Section.TRIGGERS;
      i++;
      continue;
    }
    if (key === 'required_permissions') {
      section = Section.REQUIRED_PERMISSIONS;
      i++;
      continue;
    }
    if (key === 'parameters') {
      section = value === '[]' ? Section.NONE : Section.PARAMETERS;
      i++;
      continue;
    }
    if (key === 'output_format') {
      section = Section.OUTPUT_FORMAT;
      i++;
      continue;
    }
    if (key === 'error_codes') {
      section = Section.ERROR_CODES;
      i++;
      continue;
    }

    if (section === Section.OUTPUT_FORMAT) {
      if (key === 'success_pattern') {
        outputFormat = new OutputFormat(value, outputFormat.failurePattern, outputFormat.maxPreviewLength);
      } else if (key === 'failure_pattern') {
        outputFormat = new OutputFormat(outputFormat.successPattern, value, outputFormat.maxPreviewLength);
      } else if (key === 'max_preview_length') {
        const len = parseInt(value, 10);
        if (Number.isFinite(len)) {
          outputFormat = new OutputFormat(outputFormat.successPattern, outputFormat.failurePattern, len);
        }
      }
      i++;
      continue;
    }

    if (section === Section.ERROR_CODES) {
      errorCodes.set(key.replace(/"/g, ''), value);
      i++;
      continue;
    }

    section = Section.NONE;
    fields.set(key, value);
    i++;
  }

  const name = fields.get('name');
  const description = fields.get('description') ?? '';
  const command = fields.get('command') ?? '';
  if (name === undefined || name.length === 0 || command.length === 0) {
    return null;
  }
  if (TEMPLATE_DANGEROUS_PATTERN.test(command)) {
    return null;
  }

  const executorStr = fields.get('executor') ?? 'shell';
  const riskStr = fields.get('risk_level') ?? 'low';
  const requiresConfirmStr = fields.get('requires_confirm');
  const timeoutMs = parseNumber(fields.get('timeout_ms'), 5000);

  const executor = parseExecutorKind(executorStr);
  const risk = parseRiskLevel(riskStr);
  const requiresConfirm = requiresConfirmStr === null
    ? risk === RiskLevel.HIGH
    : requiresConfirmStr === 'true';

  return new CliCommand(
    name,
    description,
    command,
    triggers.length === 0 ? ['default'] : triggers,
    parameters,
    requiredPermissions,
    executor,
    risk,
    requiresConfirm,
    timeoutMs,
    outputFormat,
    errorCodes,
    true
  );
}

function parseParameterSpec(block: string[], startIdx: number): ParamSpec | null {
  const headerLine = block[startIdx].trim();
  const rest = headerLine.substring(2).trim();
  const colon = rest.indexOf(':');
  if (colon <= 0) {
    return null;
  }
  const headerKey = rest.substring(0, colon).trim();
  if (headerKey !== 'name') {
    return null;
  }
  const paramName = rest.substring(colon + 1).trim();
  if (paramName.length === 0) {
    return null;
  }
  const baseIndent = getIndent(block[startIdx]);

  let paramType = ParamType.STRING;
  let required = true;
  let defaultValue: string | null = null;
  let range: string | null = null;
  let pattern: string | null = null;
  let description = '';
  let enumValues: string[] | null = null;

  let sourceFrom = ParamSource.USER_INPUT;
  let sourceHint = '';
  let sourceExtraction = '';
  let sourceFallback = FallbackStrategy.ASK_USER;
  let sourceDefault: string | null = null;
  let sourceConfigKey: string | null = null;
  let sourceDeviceQuery: string | null = null;
  let inSource = false;

  for (let i = startIdx + 1; i < block.length; i++) {
    const ln = block[i];
    const indent = getIndent(ln);
    if (indent <= baseIndent) {
      break;
    }
    const t = ln.trim();
    if (t.length === 0 || t.startsWith('#')) {
      continue;
    }
    const c = t.indexOf(':');
    if (c <= 0) {
      continue;
    }
    const k = t.substring(0, c).trim();
    const v = t.substring(c + 1).trim();

    if (k === 'source') {
      inSource = true;
      continue;
    }
    if (k === 'name') {
      break;
    }

    if (inSource) {
      switch (k) {
        case 'from':
          sourceFrom = parseParamSource(v);
          break;
        case 'hint':
          sourceHint = v;
          break;
        case 'extraction':
          sourceExtraction = v;
          break;
        case 'fallback':
          sourceFallback = parseFallback(v);
          break;
        case 'default':
          sourceDefault = v;
          break;
        case 'config_key':
          sourceConfigKey = v;
          break;
        case 'device_state_query':
          sourceDeviceQuery = v;
          break;
      }
    } else {
      switch (k) {
        case 'type':
          paramType = parseParamType(v);
          break;
        case 'required':
          required = v === 'true';
          break;
        case 'default':
          defaultValue = v;
          break;
        case 'range':
          range = v;
          break;
        case 'pattern':
          pattern = v;
          break;
        case 'description':
          description = v;
          break;
        case 'enum':
          enumValues = parseEnumList(block, i, baseIndent);
          break;
      }
    }
  }

  if (inSource) {
    if (sourceFrom === ParamSource.FIXED && sourceDefault !== null) {
      defaultValue = sourceDefault;
    }
  }
  if (sourceDefault !== null && defaultValue === null && sourceFrom === ParamSource.FIXED) {
    defaultValue = sourceDefault;
  }
  if (defaultValue !== null && required) {
    required = false;
  }

  const source = new ParamSourceSpec(
    sourceFrom,
    sourceHint,
    sourceExtraction,
    sourceFallback,
    sourceDefault,
    sourceConfigKey,
    sourceDeviceQuery
  );

  return new ParamSpec(
    paramName,
    paramType,
    required,
    defaultValue,
    range,
    pattern,
    description,
    source,
    enumValues
  );
}

function parseEnumList(lines: string[], startIdx: number, baseIndent: number): string[] | null {
  const values: string[] = [];
  for (let i = startIdx + 1; i < lines.length; i++) {
    const indent = getIndent(lines[i]);
    if (indent <= baseIndent) {
      break;
    }
    const t = lines[i].trim();
    if (!t.startsWith('- ')) {
      continue;
    }
    values.push(t.substring(2).trim());
  }
  return values.length > 0 ? values : null;
}

function parseParamType(value: string): ParamType {
  if (value === 'number') return ParamType.NUMBER;
  if (value === 'boolean') return ParamType.BOOLEAN;
  return ParamType.STRING;
}

function parseParamSource(from: string): ParamSource {
  if (from === 'config') return ParamSource.CONFIG;
  if (from === 'device_state') return ParamSource.DEVICE_STATE;
  if (from === 'fixed') return ParamSource.FIXED;
  return ParamSource.USER_INPUT;
}

function parseFallback(value: string): FallbackStrategy {
  if (value === 'abort') return FallbackStrategy.ABORT;
  if (value === 'default') return FallbackStrategy.DEFAULT;
  if (value === 'skip') return FallbackStrategy.SKIP;
  return FallbackStrategy.ASK_USER;
}

function parseOutputFormat(block: string[], startIdx: number): OutputFormat {
  let successPattern: string | null = null;
  let failurePattern: string | null = null;
  let maxPreview = 200;

  for (let i = startIdx + 1; i < block.length; i++) {
    const line = block[i];
    const trimmed = line.trim();
    if (line.length > 0 && !line.startsWith(' ') && !line.startsWith('-')) {
      break;
    }
    const colon = trimmed.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    const key = trimmed.substring(0, colon).trim();
    const value = trimmed.substring(colon + 1).trim();
    if (key === 'success_pattern') {
      successPattern = value;
    } else if (key === 'failure_pattern') {
      failurePattern = value;
    } else if (key === 'max_preview_length') {
      maxPreview = parseNumber(value, 200);
    }
  }
  return new OutputFormat(successPattern, failurePattern, maxPreview);
}

function parseExecutorKind(value: string): CliExecutorKind {
  if (value === 'system_api') {
    return CliExecutorKind.SYSTEM_API;
  }
  if (value === 'auto') {
    return CliExecutorKind.AUTO;
  }
  return CliExecutorKind.SHELL;
}

function parseRiskLevel(value: string): RiskLevel {
  if (value === 'medium') {
    return RiskLevel.MEDIUM;
  }
  if (value === 'high') {
    return RiskLevel.HIGH;
  }
  return RiskLevel.LOW;
}

function parseNumber(value: string | undefined, fallback: number): number {
  if (value === undefined || value.length === 0) {
    return fallback;
  }
  const num = Number(value);
  if (!Number.isFinite(num)) {
    return fallback;
  }
  return num;
}
