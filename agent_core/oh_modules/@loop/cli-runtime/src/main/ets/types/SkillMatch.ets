import { CliSkill, CliCommand } from './CliSkill';

export class SkillMatch {
  readonly skill: CliSkill;
  readonly command: CliCommand;
  readonly score: number;
  readonly matchedTriggers: string[];

  constructor(
    skill: CliSkill,
    command: CliCommand,
    score: number,
    matchedTriggers: string[]
  ) {
    this.skill = skill;
    this.command = command;
    this.score = score;
    this.matchedTriggers = matchedTriggers;
  }
}
