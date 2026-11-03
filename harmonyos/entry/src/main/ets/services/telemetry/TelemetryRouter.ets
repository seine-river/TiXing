import { hilog } from '@kit.PerformanceAnalysisKit';
import { TelemetryEvent, TelemetryErrorReport, TelemetryEventKind, TelemetryProvider } from './TelemetryModels';
import { UmengTelemetryProvider } from './UmengTelemetryProvider';
import { BuglyTelemetryProvider } from './BuglyTelemetryProvider';
import { MonitoringConfig } from './MonitoringConfig';
import { TelemetryConsentService, TelemetryConsentState } from './TelemetryConsentService';
import { TelemetrySanitizer } from './TelemetrySanitizer';

const LOG_DOMAIN: number = 0xA004;
const LOG_TAG: string = 'TiXingTelemetry';

export class TelemetryRouter {
  private static providers: TelemetryProvider[] = [];
  private static umengProvider: UmengTelemetryProvider = new UmengTelemetryProvider();
  private static buglyProvider: BuglyTelemetryProvider = new BuglyTelemetryProvider();
  private static config: MonitoringConfig = new MonitoringConfig();
  private static initialized: boolean = false;
  private static activating: boolean = false;
  private static activationPromise: Promise<void> | null = null;
  private static active: boolean = false;

  static preInitialize(context: Context): void {
    if (TelemetryRouter.initialized) {
      return;
    }
    TelemetryRouter.initialized = true;
    TelemetryRouter.providers = [TelemetryRouter.buglyProvider, TelemetryRouter.umengProvider];
    const appContext: Context = context.getApplicationContext();
    TelemetryRouter.umengProvider.prepare(appContext);
    MonitoringConfig.load(appContext).then((config: MonitoringConfig): void => {
      TelemetryRouter.config = config;
      TelemetryRouter.buglyProvider.setConfig(config);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'monitoring config loaded: umeng=%{public}b, bugly=%{public}b',
        config.umengAppKey.length > 0, config.buglyConfigured);
    }).catch((_e: Object): void => {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'monitoring config load failed');
    });
    TelemetryRouter.resumeAfterPrivacyCheck(appContext);
  }

  static async resumeAfterPrivacyCheck(context: Context): Promise<void> {
    const appContext: Context = context.getApplicationContext();
    const consent: TelemetryConsentState = await TelemetryConsentService.getConsent(appContext);
    if (consent === TelemetryConsentState.GRANTED) {
      await TelemetryRouter.activate(appContext);
    }
  }

  static async activate(context: Context): Promise<void> {
    if (TelemetryRouter.active) {
      return;
    }
    if (TelemetryRouter.activationPromise !== null) {
      await TelemetryRouter.activationPromise;
      return;
    }
    TelemetryRouter.activating = true;
    const activation: Promise<void> = TelemetryRouter.doActivate(context);
    TelemetryRouter.activationPromise = activation;
    try {
      await activation;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'telemetry activation failed: %{public}s', `${e}`);
    } finally {
      TelemetryRouter.activationPromise = null;
      TelemetryRouter.activating = false;
    }
  }

  private static async doActivate(context: Context): Promise<void> {
    if (!TelemetryRouter.config.buglyConfigured) {
      TelemetryRouter.config = await MonitoringConfig.load(context);
    }
    TelemetryRouter.buglyProvider.setConfig(TelemetryRouter.config);
    // Umeng 文档建议：同时接入多个崩溃捕获 SDK 时，先启动 Bugly，再启动 Umeng。
    for (let i: number = 0; i < TelemetryRouter.providers.length; i++) {
      await TelemetryRouter.providers[i].activate(context);
    }
    TelemetryRouter.active = true;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'telemetry activated: umeng=%{public}b, bugly=%{public}b',
      true, TelemetryRouter.config.buglyConfigured);
  }

  static track(event: TelemetryEvent): void {
    // preInit 只准备 SDK，不代表隐私同意；未激活前不能把业务事件交给第三方 Provider。
    if (!TelemetryRouter.initialized || !TelemetryRouter.active) {
      return;
    }
    for (let i: number = 0; i < TelemetryRouter.providers.length; i++) {
      TelemetryRouter.providers[i].track(event);
    }
  }

  static reportError(report: TelemetryErrorReport): void {
    if (!TelemetryRouter.initialized || !TelemetryRouter.active) {
      return;
    }
    for (let i: number = 0; i < TelemetryRouter.providers.length; i++) {
      TelemetryRouter.providers[i].reportError(report);
    }
  }

  static reportFault(name: string, message: string, params: Record<string, string | number | boolean>): void {
    TelemetryRouter.track(new TelemetryEvent(TelemetryEventKind.FAULT, name, params));
    TelemetryRouter.reportError(new TelemetryErrorReport(
      TelemetrySanitizer.eventName(TelemetryEventKind.FAULT, name),
      TelemetrySanitizer.text(message),
      JSON.stringify(TelemetrySanitizer.params(params))
    ));
  }
}
