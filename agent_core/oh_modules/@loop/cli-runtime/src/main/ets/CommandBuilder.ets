import { CliCommand } from './types/CliSkill';
import { ParamSpec } from './types/ParamSpec';
import { ParamType } from './types/Enums';
import { ValidationResult } from './types/ValidationResult';

const PLACEHOLDER_PATTERN = /\{\{(\w+)\}\}/g;
const DANGEROUS_CHARS = /[;&|`$()<>]/;

interface CheckResult {
  ok: boolean;
  error: string;
}

function checkResultOk(): CheckResult {
  return { ok: true, error: '' };
}

function checkResultFail(error: string): CheckResult {
  return { ok: false, error };
}

export class CommandBuilder {
  build(command: CliCommand, params: Map<string, string>): ValidationResult {
    let finalCommand = command.command;
    const missingRequired: string[] = [];

    const placeholderNames = this.extractPlaceholderNames(command.command);
    for (const name of placeholderNames) {
      const spec = this.findParam(command, name);
      if (spec === null) {
        return ValidationResult.invalid(`placeholder {{${name}}} has no matching parameter spec`);
      }

      let value = params.get(name);
      if (value === undefined || value === null || value.length === 0) {
        if (spec.required) {
          if (spec.defaultValue !== null && spec.defaultValue.length > 0) {
            value = spec.defaultValue;
          } else {
            missingRequired.push(name);
            continue;
          }
        } else {
          if (spec.defaultValue !== null && spec.defaultValue.length > 0) {
            value = spec.defaultValue;
          } else {
            value = '';
          }
        }
      }

      const typeCheck = this.checkType(spec, value);
      if (!typeCheck.ok) {
        return ValidationResult.invalid(`param ${name}: ${typeCheck.error}`);
      }

      const rangeCheck = this.checkRange(spec, value);
      if (!rangeCheck.ok) {
        return ValidationResult.invalid(`param ${name}: ${rangeCheck.error}`);
      }

      const patternCheck = this.checkPattern(spec, value);
      if (!patternCheck.ok) {
        return ValidationResult.invalid(`param ${name}: ${patternCheck.error}`);
      }

      const enumCheck = this.checkEnum(spec, value);
      if (!enumCheck.ok) {
        return ValidationResult.invalid(`param ${name}: ${enumCheck.error}`);
      }

      const injectionCheck = this.checkInjection(value);
      if (!injectionCheck.ok) {
        return ValidationResult.invalid(`param ${name}: ${injectionCheck.error}`);
      }

      const escaped = this.escapeShellValue(value, spec.type);
      finalCommand = this.replaceAll(finalCommand, `{{${name}}}`, escaped);
    }

    if (missingRequired.length > 0) {
      return ValidationResult.invalid(`missing required params: ${missingRequired.join(', ')}`);
    }

    return ValidationResult.valid(finalCommand);
  }

  private extractPlaceholderNames(commandTemplate: string): string[] {
    const names: string[] = [];
    let match: RegExpExecArray | null;
    const pattern = new RegExp(PLACEHOLDER_PATTERN);
    while ((match = pattern.exec(commandTemplate)) !== null) {
      const name = match[1];
      if (names.indexOf(name) < 0) {
        names.push(name);
      }
    }
    return names;
  }

  private findParam(command: CliCommand, name: string): ParamSpec | null {
    for (const p of command.parameters) {
      if (p.name === name) {
        return p;
      }
    }
    return null;
  }

  private checkType(spec: ParamSpec, value: string): CheckResult {
    if (spec.type === ParamType.NUMBER) {
      const num = Number(value);
      if (!Number.isFinite(num)) {
        return checkResultFail(`expected number, got "${value}"`);
      }
    } else if (spec.type === ParamType.BOOLEAN) {
      const lower = value.toLowerCase();
      if (lower !== 'true' && lower !== 'false' && lower !== '1' && lower !== '0' && lower !== 'yes' && lower !== 'no') {
        return checkResultFail(`expected boolean, got "${value}"`);
      }
    }
    return checkResultOk();
  }

  private checkRange(spec: ParamSpec, value: string): CheckResult {
    if (spec.range === null || spec.range.length === 0) {
      return checkResultOk();
    }
    const parts = spec.range.split('-');
    if (parts.length !== 2) {
      return checkResultOk();
    }
    if (spec.type === ParamType.NUMBER) {
      const min = Number(parts[0]);
      const max = Number(parts[1]);
      const v = Number(value);
      if (v < min || v > max) {
        return checkResultFail(`value ${v} out of range [${min}, ${max}]`);
      }
    } else {
      const minLen = Number(parts[0]);
      const maxLen = Number(parts[1]);
      const len = value.length;
      if (len < minLen || len > maxLen) {
        return checkResultFail(`length ${len} out of range [${minLen}, ${maxLen}]`);
      }
    }
    return checkResultOk();
  }

  private checkPattern(spec: ParamSpec, value: string): CheckResult {
    if (spec.pattern === null || spec.pattern.length === 0) {
      return checkResultOk();
    }
    try {
      const re = new RegExp(spec.pattern);
      if (!re.test(value)) {
        return checkResultFail(`value "${value}" does not match pattern ${spec.pattern}`);
      }
    } catch (e) {
      return checkResultFail(`invalid pattern in skill: ${spec.pattern}`);
    }
    return checkResultOk();
  }

  private checkEnum(spec: ParamSpec, value: string): CheckResult {
    if (spec.enumValues === null || spec.enumValues.length === 0) {
      return checkResultOk();
    }
    if (spec.enumValues.indexOf(value) < 0) {
      return checkResultFail(`value "${value}" not in enum [${spec.enumValues.join(', ')}]`);
    }
    return checkResultOk();
  }

  private checkInjection(value: string): CheckResult {
    if (DANGEROUS_CHARS.test(value)) {
      return checkResultFail('value contains forbidden shell metacharacters');
    }
    return checkResultOk();
  }

  private escapeShellValue(value: string, type: ParamType): string {
    if (type === ParamType.NUMBER) {
      const num = Number(value);
      return `${num}`;
    }
    if (type === ParamType.BOOLEAN) {
      return value.toLowerCase();
    }
    return `"${value.replace(/"/g, '\\"')}"`;
  }

  private replaceAll(haystack: string, needle: string, replacement: string): string {
    if (needle.length === 0) {
      return haystack;
    }
    let result = haystack;
    const needleLower = needle.toLowerCase();
    while (result.toLowerCase().indexOf(needleLower) >= 0) {
      const idx = result.toLowerCase().indexOf(needleLower);
      result = result.substring(0, idx) + replacement + result.substring(idx + needle.length);
    }
    return result;
  }
}
