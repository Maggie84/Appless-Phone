import { ParamType, ParamSource, FallbackStrategy } from './Enums';

export class ParamSourceSpec {
  readonly from: ParamSource;
  readonly hint: string;
  readonly extraction: string;
  readonly fallback: FallbackStrategy;
  readonly defaultValue: string | null;
  readonly configKey: string | null;
  readonly deviceStateQuery: string | null;

  constructor(
    from: ParamSource = ParamSource.USER_INPUT,
    hint: string = '',
    extraction: string = '',
    fallback: FallbackStrategy = FallbackStrategy.ASK_USER,
    defaultValue: string | null = null,
    configKey: string | null = null,
    deviceStateQuery: string | null = null
  ) {
    this.from = from;
    this.hint = hint;
    this.extraction = extraction;
    this.fallback = fallback;
    this.defaultValue = defaultValue;
    this.configKey = configKey;
    this.deviceStateQuery = deviceStateQuery;
  }
}

export class ParamSpec {
  readonly name: string;
  readonly type: ParamType;
  readonly required: boolean;
  readonly defaultValue: string | null;
  readonly range: string | null;
  readonly pattern: string | null;
  readonly description: string;
  readonly source: ParamSourceSpec;
  readonly enumValues: string[] | null;

  constructor(
    name: string,
    type: ParamType,
    required: boolean = true,
    defaultValue: string | null = null,
    range: string | null = null,
    pattern: string | null = null,
    description: string = '',
    source: ParamSourceSpec = new ParamSourceSpec(),
    enumValues: string[] | null = null
  ) {
    this.name = name;
    this.type = type;
    this.required = required;
    this.defaultValue = defaultValue;
    this.range = range;
    this.pattern = pattern;
    this.description = description;
    this.source = source;
    this.enumValues = enumValues;
  }
}
