import { ParamSpec } from './ParamSpec';
import { CliExecutorKind, RiskLevel } from './Enums';

export class OutputFormat {
  readonly successPattern: string | null;
  readonly failurePattern: string | null;
  readonly maxPreviewLength: number;

  constructor(
    successPattern: string | null = null,
    failurePattern: string | null = null,
    maxPreviewLength: number = 200
  ) {
    this.successPattern = successPattern;
    this.failurePattern = failurePattern;
    this.maxPreviewLength = maxPreviewLength;
  }
}

export class CliCommand {
  readonly name: string;
  readonly description: string;
  readonly command: string;
  readonly triggers: string[];
  readonly parameters: ParamSpec[];
  readonly requiredPermissions: string[];
  readonly executor: CliExecutorKind;
  readonly riskLevel: RiskLevel;
  readonly requiresConfirm: boolean;
  readonly timeoutMs: number;
  readonly outputFormat: OutputFormat;
  readonly errorCodes: Map<string, string>;
  readonly audit: boolean;

  constructor(
    name: string,
    description: string,
    command: string,
    triggers: string[],
    parameters: ParamSpec[] = [],
    requiredPermissions: string[] = [],
    executor: CliExecutorKind = CliExecutorKind.SHELL,
    riskLevel: RiskLevel = RiskLevel.LOW,
    requiresConfirm: boolean = false,
    timeoutMs: number = 5000,
    outputFormat: OutputFormat = new OutputFormat(),
    errorCodes: Map<string, string> = new Map(),
    audit: boolean = true
  ) {
    this.name = name;
    this.description = description;
    this.command = command;
    this.triggers = triggers;
    this.parameters = parameters;
    this.requiredPermissions = requiredPermissions;
    this.executor = executor;
    this.riskLevel = riskLevel;
    this.requiresConfirm = requiresConfirm;
    this.timeoutMs = timeoutMs;
    this.outputFormat = outputFormat;
    this.errorCodes = errorCodes;
    this.audit = audit;
  }
}

export class CliSkill {
  readonly name: string;
  readonly description: string;
  readonly type: string;
  readonly version: string;
  readonly schemaVersion: number;
  readonly author: string;
  readonly homepage: string;
  readonly commands: CliCommand[];

  constructor(
    name: string,
    description: string,
    type: string = 'cli_group',
    version: string = '1.0',
    schemaVersion: number = 1,
    author: string = '',
    homepage: string = '',
    commands: CliCommand[] = []
  ) {
    this.name = name;
    this.description = description;
    this.type = type;
    this.version = version;
    this.schemaVersion = schemaVersion;
    this.author = author;
    this.homepage = homepage;
    this.commands = commands;
  }

  findCommand(name: string): CliCommand | null {
    for (const cmd of this.commands) {
      if (cmd.name === name) {
        return cmd;
      }
    }
    return null;
  }
}
