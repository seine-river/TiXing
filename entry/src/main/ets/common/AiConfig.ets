import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContextHolder } from './AppContext';

const LOG_DOMAIN: number = 0xA003;
const LOG_TAG: string = 'TiXingAiConfig';

const API_CONFIG_FILE: string = 'apiconfig.json';
const FIXED_MODEL: string = 'glm-5.3-flash';
const FIXED_BASE_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

interface ApiConfigFile {
  apiKey: string;
}

function normalizeApiKey(raw: string): string {
  let key: string = raw.trim();
  if (key.startsWith('Bearer ') || key.startsWith('bearer ')) {
    key = key.substring(7).trim();
  }
  return key;
}

/**
 * AI 固定配置读取器：
 * - 模型与接口地址固定为智谱 GLM-5.3-Flash；
 * - API Key 只从打包资源 rawfile/apiconfig.json 读取；
 * - 文件缺失或 key 为空时安全降级，不影响应用其他功能。
 */
export class AiConfig {
  private static apiKeyValue: string = '';
  private static loaded: boolean = false;

  static get apiKey(): string {
    return AiConfig.apiKeyValue;
  }

  static get model(): string {
    return FIXED_MODEL;
  }

  static get baseUrl(): string {
    return FIXED_BASE_URL;
  }

  static get configured(): boolean {
    return AiConfig.apiKeyValue.length > 0;
  }

  static async load(): Promise<void> {
    if (AiConfig.loaded) {
      return;
    }
    AiConfig.loaded = true;

    const ctx: Context | undefined = AppContextHolder.get();
    if (ctx === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'AppContext not ready, AI config not loaded');
      return;
    }

    try {
      const content: Uint8Array = await ctx.resourceManager.getRawFileContent(API_CONFIG_FILE);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(content);
      const obj: ApiConfigFile = JSON.parse(text) as ApiConfigFile;
      AiConfig.apiKeyValue = obj.apiKey !== undefined ? normalizeApiKey(obj.apiKey) : '';
      if (!AiConfig.configured) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'apiconfig.json apiKey empty, AI features disabled: fileLength=%{public}d', text.length);
      } else {
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'apiconfig.json loaded: apiKeyLength=%{public}d, model=%{public}s, baseUrl=%{public}s',
          AiConfig.apiKeyValue.length, FIXED_MODEL, FIXED_BASE_URL);
      }
    } catch (e) {
      AiConfig.apiKeyValue = '';
      const detail: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}`
        : `${e}`;
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'apiconfig.json missing or invalid, AI features disabled: %{public}s', detail);
    }
  }
}
