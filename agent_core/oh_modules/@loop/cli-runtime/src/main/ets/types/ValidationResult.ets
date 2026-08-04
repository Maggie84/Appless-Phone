export class ValidationResult {
  readonly ok: boolean;
  readonly finalCommand: string;
  readonly error: string | null;

  private constructor(ok: boolean, finalCommand: string, error: string | null) {
    this.ok = ok;
    this.finalCommand = finalCommand;
    this.error = error;
  }

  static valid(finalCommand: string): ValidationResult {
    return new ValidationResult(true, finalCommand, null);
  }

  static invalid(error: string): ValidationResult {
    return new ValidationResult(false, '', error);
  }
}
