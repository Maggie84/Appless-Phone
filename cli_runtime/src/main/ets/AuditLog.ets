import { CliCommand } from './types/CliSkill';

const DOMAIN = 0xFF;

export interface AuditEntry {
  timestamp: number;
  skill: string;
  command: string;
  commandLine: string;
  exitCode: number;
  durationMs: number;
  stdoutPreview: string;
  stderrPreview: string;
  ok: boolean;
}

export class AuditLog {
  private entries: AuditEntry[] = [];
  private readonly maxEntries: number;

  constructor(maxEntries: number = 100) {
    this.maxEntries = maxEntries;
  }

  logCommand(skillName: string, command: CliCommand, finalCommand: string): void {
    const entry: AuditEntry = {
      timestamp: Date.now(),
      skill: skillName,
      command: command.name,
      commandLine: finalCommand,
      exitCode: -1,
      durationMs: 0,
      stdoutPreview: '',
      stderrPreview: '',
      ok: false
    };
    this.append(entry);
  }

  logResult(skillName: string, command: CliCommand, finalCommand: string, exitCode: number, durationMs: number, stdout: string, stderr: string, ok: boolean): void {
    const entry: AuditEntry = {
      timestamp: Date.now(),
      skill: skillName,
      command: command.name,
      commandLine: finalCommand,
      exitCode,
      durationMs,
      stdoutPreview: this.truncate(stdout, 500),
      stderrPreview: this.truncate(stderr, 500),
      ok
    };
    this.append(entry);
  }

  recent(count: number = 20): AuditEntry[] {
    const start = Math.max(0, this.entries.length - count);
    return this.entries.slice(start);
  }

  clear(): void {
    this.entries = [];
  }

  private append(entry: AuditEntry): void {
    this.entries.push(entry);
    while (this.entries.length > this.maxEntries) {
      this.entries.shift();
    }
  }

  private truncate(text: string, max: number): string {
    if (text.length <= max) {
      return text;
    }
    return text.substring(0, max) + '...';
  }
}
