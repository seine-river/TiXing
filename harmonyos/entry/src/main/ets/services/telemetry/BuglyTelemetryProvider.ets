import { Bugly, BuglyBuilder, AppVersionMode, ModuleName } from 'bugly';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TelemetryEvent, TelemetryErrorReport, TelemetryProvider } from './TelemetryModels';
import { TelemetrySanitizer } from './TelemetrySanitizer';
import { MonitoringConfig } from './MonitoringConfig';
import { TelemetryConsentService } from './TelemetryConsentService';

export class BuglyTelemetryProvider implements TelemetryProvider {
  readonly providerName: string = 'Bugly';
  private static readonly LOG_DOMAIN: number = 0xA004;
  private static readonly LOG_TAG: string = 'TiXingTelemetry';
  private config: MonitoringConfig = new MonitoringConfig();
  private active: boolean = false;

  setConfig(config: MonitoringConfig): void {
    this.config = config;
  }

  prepare(_context: Context): void {
    // Bugly only starts after privacy consent; no pre-init collection.
  }

  async activate(context: Context): Promise<void> {
    if (this.active || !this.config.buglyConfigured) {
      if (!this.config.buglyConfigured) {
        hilog.info(BuglyTelemetryProvider.LOG_DOMAIN, BuglyTelemetryProvider.LOG_TAG,
          'Bugly disabled: credentials absent');
      }
      return;
    }
    try {
      const builder: BuglyBuilder = new BuglyBuilder();
      builder.appId = this.config.buglyAppId;
      builder.appKey = this.config.buglyAppKey;
      builder.deviceId = await TelemetryConsentService.stableDeviceId(context);
      builder.platform = BuglyBuilder.PLATFORM_PRO;
      builder.appVersion = '1.0.3';
      builder.appVersionMode = AppVersionMode.RELEASE;
      builder.buildNum = '1000003';
      builder.appChannel = this.config.channel;
      builder.enablePrivacyInfoAuthorized = true;
      builder.enablePerfModules = ModuleName.AllModules;
      builder.debugMode = false;
      builder.sdkLogMode = false;
      builder.enableJsCrashProtect = false;
      await Bugly.init(context.getApplicationContext(), builder);
      this.active = true;
      hilog.info(BuglyTelemetryProvider.LOG_DOMAIN, BuglyTelemetryProvider.LOG_TAG, 'Bugly activated');
    } catch (e) {
      hilog.error(BuglyTelemetryProvider.LOG_DOMAIN, BuglyTelemetryProvider.LOG_TAG,
        'Bugly activation failed: %{public}s', TelemetrySanitizer.sanitizeValue(`${e}`));
    }
  }

  track(event: TelemetryEvent): void {
    if (!this.active) {
      return;
    }
    try {
      Bugly.putUserData('last_event', TelemetrySanitizer.eventName(event.kind, event.name));
    } catch (e) {
    }
  }

  reportError(report: TelemetryErrorReport): void {
    if (!this.active) {
      return;
    }
    try {
      Bugly.postCustomError(
        TelemetrySanitizer.text(report.name, 128),
        TelemetrySanitizer.text(report.message),
        TelemetrySanitizer.text(report.detail, 1024),
        false
      );
    } catch (e) {
    }
  }
}
