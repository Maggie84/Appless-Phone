import { CliRuntime, CliSkill, SkillMatch } from '@loop/cli-runtime';
import { AgentSkill } from '../skill/AgentSkill';
import { adaptSkillToCli } from '../cli/SkillAdapter';

export class SkillMatcher {
  private cliRuntime: CliRuntime;
  private loaded: boolean = false;

  constructor(cliRuntime: CliRuntime) {
    this.cliRuntime = cliRuntime;
  }

  loadFromSnapshot(skills: AgentSkill[]): void {
    const cliSkills: CliSkill[] = [];
    for (const skill of skills) {
      const adapted = adaptSkillToCli(skill);
      if (adapted !== null) {
        cliSkills.push(adapted);
      }
    }
    this.cliRuntime.loadSkills(cliSkills);
    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  match(userInput: string): SkillMatch[] {
    if (!this.loaded) {
      return [];
    }
    return this.cliRuntime.match(userInput);
  }
}
