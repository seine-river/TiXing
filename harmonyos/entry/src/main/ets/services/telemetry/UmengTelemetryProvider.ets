import { preInit, init, InternalPlugin, onEventObject, setLogEnabled } from '@umeng/analytics';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TelemetryEvent, TelemetryErrorReport, TelemetryEventKind, TelemetryProvider } from './TelemetryModels';
import { TelemetrySanitizer } from './TelemetrySanitizer';

export class UmengTelemetryProvider implements TelemetryProvider {
  readonly providerName: string = 'Umeng';
  private static readonly LOG_DOMAIN: number = 0xA004;
  private static readonly LOG_TAG: string = 'TiXingTelemetry';
  private prepared: boolean = false;
  private active: boolean = false;

  prepare(context: Context): void {
    if (this.prepared) {
      return;
    }
    try {
      preInit({
        context: context.getApplicationContext(),
        plugins: [new InternalPlugin()],
        disableScreen: true,
        disablePlmn: true,
        // 儿童产品质量统计不依赖广告标识；使用 SDK 内部匿名设备维度即可。
        disableOAID: true
      });
      setLogEnabled(false);
      this.prepared = true;
      hilog.info(UmengTelemetryProvider.LOG_DOMAIN, UmengTelemetryProvider.LOG_TAG,
        'Umeng pre-initialized: oaid_disabled');
    } catch (e) {
      hilog.error(UmengTelemetryProvider.LOG_DOMAIN, UmengTelemetryProvider.LOG_TAG,
        'Umeng pre-initialization failed: %{public}s', `${e}`);
    }
  }

  async activate(context: Context): Promise<void> {
    if (this.active) {
      return;
    }
    this.prepare(context);
    if (!this.prepared) {
      return;
    }
    try {
      await init();
      this.active = true;
      hilog.info(UmengTelemetryProvider.LOG_DOMAIN, UmengTelemetryProvider.LOG_TAG, 'Umeng activated');
    } catch (e) {
      hilog.error(UmengTelemetryProvider.LOG_DOMAIN, UmengTelemetryProvider.LOG_TAG,
        'Umeng activation failed: %{public}s', `${e}`);
    }
  }

  track(event: TelemetryEvent): void {
    if (!this.prepared) {
      return;
    }
    try {
      onEventObject(TelemetrySanitizer.eventName(event.kind, event.name), TelemetrySanitizer.params(event.params));
    } catch (e) {
    }
  }

  reportError(report: TelemetryErrorReport): void {
    this.track(new TelemetryEvent(TelemetryEventKind.FAULT, 'provider_error', {
      'provider': this.providerName,
      'error_name': report.name,
      'success': 0
    }));
  }
}
