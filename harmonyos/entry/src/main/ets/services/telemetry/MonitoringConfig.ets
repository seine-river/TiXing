import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xA004;
const LOG_TAG: string = 'TiXingTelemetry';
const CONFIG_FILE: string = 'monitoringconfig.json';

interface MonitoringConfigRaw {
  buglyAppId?: Object;
  buglyAppKey?: Object;
  channel?: Object;
}

export class MonitoringConfig {
  readonly umengAppKey: string = '6ae5a2846545637cd62c8fb5';
  channel: string = 'AppGallery';
  buglyAppId: string = '';
  buglyAppKey: string = '';

  get buglyConfigured(): boolean {
    return this.buglyAppId.length > 0 && this.buglyAppKey.length > 0;
  }

  static async load(context: Context): Promise<MonitoringConfig> {
    const config: MonitoringConfig = new MonitoringConfig();
    try {
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(CONFIG_FILE);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const raw: MonitoringConfigRaw = JSON.parse(text) as MonitoringConfigRaw;
      if (typeof raw.buglyAppId === 'string') {
        config.buglyAppId = (raw.buglyAppId as string).trim();
      }
      if (typeof raw.buglyAppKey === 'string') {
        config.buglyAppKey = (raw.buglyAppKey as string).trim();
      }
      if (typeof raw.channel === 'string' && (raw.channel as string).trim().length > 0) {
        config.channel = (raw.channel as string).trim();
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'monitoringconfig.json unavailable, Bugly remains disabled');
    }
    return config;
  }
}
