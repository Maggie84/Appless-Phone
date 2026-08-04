export enum CliExecutorKind {
  SHELL = 'shell',
  SYSTEM_API = 'system_api',
  AUTO = 'auto'
}

export enum RiskLevel {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high'
}

export enum ParamType {
  STRING = 'string',
  NUMBER = 'number',
  BOOLEAN = 'boolean'
}

export enum ParamSource {
  USER_INPUT = 'user_input',
  CONFIG = 'config',
  DEVICE_STATE = 'device_state',
  FIXED = 'fixed'
}

export enum FallbackStrategy {
  ASK_USER = 'ask_user',
  ABORT = 'abort',
  DEFAULT = 'default',
  SKIP = 'skip'
}
