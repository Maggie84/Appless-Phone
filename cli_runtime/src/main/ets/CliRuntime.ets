import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CliSkill, CliCommand } from './types/CliSkill';
import { CliResult } from './types/CliResult';
import { SkillMatch } from './types/SkillMatch';
import { ValidationResult } from './types/ValidationResult';
import { SkillIndex } from './SkillIndex';
import { CommandBuilder } from './CommandBuilder';
import { CliExecutor, ExecutedCommand, CliExecFn } from './CliExecutor';
import { AuditLog, AuditEntry } from './AuditLog';
import { PermissionChecker } from './PermissionChecker';

const DOMAIN = 0xFF;
const LOG_TAG = 'CliRuntime';

export class CliRuntime {
  private readonly index: SkillIndex;
  private readonly builder: CommandBuilder;
  private readonly executor: CliExecutor;
  private readonly audit: AuditLog;
  private readonly permissions: PermissionChecker;
  private readonly executing: Set<string> = new Set();

  constructor(context: common.UIAbilityContext, execFn: CliExecFn) {
    this.index = new SkillIndex();
    this.builder = new CommandBuilder();
    this.executor = new CliExecutor(execFn);
    this.audit = new AuditLog();
    this.permissions = new PermissionChecker(context);
  }

  loadSkills(skills: CliSkill[]): void {
    this.index.load(skills);
    hilog.info(DOMAIN, LOG_TAG, 'CliRuntime: loaded skills count=%{public}d', `${this.index.listSkills().length}`);
  }

  match(userInput: string): SkillMatch[] {
    return this.index.match(userInput);
  }

  findCommand(skillName: string, commandName: string): CliCommand | null {
    return this.index.findCommand(skillName, commandName);
  }

  listSkills(): CliSkill[] {
    return this.index.listSkills();
  }

  async execute(
    skillName: string,
    commandName: string,
    params: Map<string, string>
  ): Promise<CliResult> {
    const command = this.index.findCommand(skillName, commandName);
    if (command === null) {
      return CliResult.failure(`unknown skill/command: ${skillName}/${commandName}`);
    }

    const dedupKey = `${skillName}:${commandName}`;
    if (this.executing.has(dedupKey)) {
      return CliResult.failure('command already in progress, please wait');
    }
    this.executing.add(dedupKey);

    try {
      const permCheck = await this.permissions.checkAll(command);
      if (!permCheck.ok) {
        return CliResult.failure(permCheck.reason ?? 'permission denied');
      }

      const validation = this.builder.build(command, params);
      if (!validation.ok) {
        return CliResult.failure(`validation failed: ${validation.error}`);
      }

      const executed: ExecutedCommand = await this.executor.exec(validation.finalCommand, command.timeoutMs);
      const result = CliResult.fromExecution(executed.stdout, executed.stderr, executed.exitCode, executed.durationMs);

      if (command.audit) {
        this.audit.logResult(
          skillName,
          command,
          validation.finalCommand,
          executed.exitCode,
          executed.durationMs,
          executed.stdout,
          executed.stderr,
          result.ok
        );
      }
      hilog.info(DOMAIN, LOG_TAG, 'CliRuntime: exec %{public}s/%{public}s exit=%{public}d duration=%{public}d',
        skillName, commandName, `${executed.exitCode}`, `${executed.durationMs}`);

      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : `${error}`;
      hilog.error(DOMAIN, LOG_TAG, 'CliRuntime: exec failed %{public}s/%{public}s: %{public}s',
        skillName, commandName, message);
      return CliResult.failure(`execution error: ${message}`);
    } finally {
      this.executing.delete(dedupKey);
    }
  }

  auditRecent(count: number = 20): AuditEntry[] {
    return this.audit.recent(count);
  }

  clearAudit(): void {
    this.audit.clear();
  }
}
