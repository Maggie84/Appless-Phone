export class AgentSkill {
  readonly name: string;
  readonly description: string;
  readonly homepage: string;
  readonly metadata: string;
  readonly location: string;
  readonly body: string;
  readonly rawFrontmatter: string;

  constructor(
    name: string,
    description: string,
    homepage: string,
    metadata: string,
    location: string,
    body: string,
    rawFrontmatter: string = ''
  ) {
    this.name = name;
    this.description = description;
    this.homepage = homepage;
    this.metadata = metadata;
    this.location = location;
    this.body = body;
    this.rawFrontmatter = rawFrontmatter;
  }

  instructions(): string {
    return this.body.trim();
  }
}
