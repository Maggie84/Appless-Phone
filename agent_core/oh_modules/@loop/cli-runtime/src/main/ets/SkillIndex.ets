import { CliSkill, CliCommand } from './types/CliSkill';
import { SkillMatch } from './types/SkillMatch';
import { CliExecutorKind } from './types/Enums';

const MIN_SCORE = 0.1;
const STRONG_SCORE = 0.5;
const TIE_BREAK_DELTA = 0.1;

export class SkillIndex {
  private skills: CliSkill[] = [];
  private triggerIndex: Map<string, SkillMatch[]> = new Map();
  private commandIndex: Map<string, CliCommand> = new Map();

  load(skills: CliSkill[]): void {
    this.skills = [];
    this.triggerIndex.clear();
    this.commandIndex.clear();

    for (const skill of skills) {
      if (!this.isCliSkill(skill)) {
        continue;
      }
      this.skills.push(skill);
      for (const command of skill.commands) {
        const key = `${skill.name}/${command.name}`;
        this.commandIndex.set(key, command);
        for (const trigger of command.triggers) {
          const list = this.triggerIndex.get(trigger) ?? [];
          list.push(new SkillMatch(skill, command, 0, []));
          this.triggerIndex.set(trigger, list);
        }
      }
    }
  }

  match(userInput: string): SkillMatch[] {
    const input = userInput.toLowerCase();
    const candidates: SkillMatch[] = [];

    for (const skill of this.skills) {
      for (const command of skill.commands) {
        const matched: string[] = [];
        let bestScore = 0;
        for (const trigger of command.triggers) {
          if (input.indexOf(trigger.toLowerCase()) >= 0) {
            const contextLen = this.extractRelevantLen(userInput, trigger);
            const score = trigger.length / Math.max(contextLen, 1);
            if (score > bestScore) {
              bestScore = score;
            }
            matched.push(trigger);
          }
        }
        if (bestScore >= MIN_SCORE && matched.length > 0) {
          candidates.push(new SkillMatch(skill, command, bestScore, matched));
        }
      }
    }

    candidates.sort((a, b) => b.score - a.score);
    return candidates;
  }

  findCommand(skillName: string, commandName: string): CliCommand | null {
    const key = `${skillName}/${commandName}`;
    return this.commandIndex.get(key) ?? null;
  }

  findSkill(name: string): CliSkill | null {
    for (const s of this.skills) {
      if (s.name === name) {
        return s;
      }
    }
    return null;
  }

  listSkills(): CliSkill[] {
    return this.skills.slice();
  }

  isStrongMatch(match: SkillMatch): boolean {
    return match.score >= STRONG_SCORE;
  }

  needsTieBreak(candidates: SkillMatch[]): boolean {
    if (candidates.length < 2) {
      return false;
    }
    return Math.abs(candidates[0].score - candidates[1].score) < TIE_BREAK_DELTA;
  }

  /** If the input has a [TYPE]-style wrapper, score against just the content after the last ] line. */
  private extractRelevantLen(input: string, trigger: string): number {
    const lines = input.split(/\r?\n/);
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i].trim();
      if (line.length > 0 && !line.startsWith('[')) {
        return line.length;
      }
    }
    return input.length;
  }

  private isCliSkill(skill: CliSkill): boolean {
    if (skill.type === 'cli' || skill.type === 'cli_group' || skill.type === 'system_api') {
      return skill.commands.length > 0;
    }
    return false;
  }
}
