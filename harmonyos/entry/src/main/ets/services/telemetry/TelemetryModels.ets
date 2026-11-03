export enum TelemetryEventKind {
  BEHAVIOR = 'behavior',
  METRIC = 'metric',
  FAULT = 'fault'
}

export class TelemetryEvent {
  readonly kind: TelemetryEventKind;
  readonly name: string;
  readonly params: Record<string, string | number | boolean>;

  constructor(kind: TelemetryEventKind, name: string, params: Record<string, string | number | boolean>) {
    this.kind = kind;
    this.name = name;
    this.params = params;
  }
}

export class TelemetryErrorReport {
  readonly name: string;
  readonly message: string;
  readonly detail: string;

  constructor(name: string, message: string, detail: string) {
    this.name = name;
    this.message = message;
    this.detail = detail;
  }
}

export interface TelemetryProvider {
  readonly providerName: string;
  prepare(context: Context): void;
  activate(context: Context): Promise<void>;
  track(event: TelemetryEvent): void;
  reportError(report: TelemetryErrorReport): void;
}
