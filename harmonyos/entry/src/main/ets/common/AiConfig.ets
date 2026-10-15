import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContextHolder } from './AppContext';

const LOG_DOMAIN: number = 0xA003;
const LOG_TAG: string = 'TiXingAiConfig';

const API_CONFIG_FILE: string = 'apiconfig.json';
const FIXED_MODEL: string = 'glm-5.3-flash';
const FIXED_BASE_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

interface ApiConfigFileRaw {
  apiKey?: Object;
  api_key?: Object;
}

function normalizeApiKey(raw: string): string {
  let key: string = raw.trim();
  if (key.startsWith('Bearer ') || key.startsWith('bearer ')) {
    key = key.substring(7).trim();
  }
  return key;
}

function extractApiKeyFromText(text: string): string {
  // 不依赖 JSON.parse 后的动态属性访问。真机日志显示同样的 68 字节文件
  // 偶发解析后 apiKey 为 undefined；regex 直接从原始文本提取可绕开该问题。
  const match: RegExpMatchArray | null = text.match(/"api_?[Kk]ey"\s*:\s*"([^"]+)"/);
  if (match !== null && match.length > 1) {
    return normalizeApiKey(match[1]);
  }
  return '';
}

/**
 * AI 固定配置读取器：
 * - 模型与接口地址固定为智谱 GLM-5.3-Flash；
 * - API Key 只从打包资源 rawfile/apiconfig.json 读取；
 * - 文件缺失或 key 为空时安全降级，不影响应用其他功能。
 */
export class AiConfig {
  private static apiKeyValue: string = '';

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
    // 只有成功读到 key 才允许短路。空 key / 解析异常不能永久锁死当前进程，
    // 否则一次资源读取或解析异常会让后续所有 AI 请求都误报“AI 未配置”。
    if (AiConfig.configured) {
      return;
    }

    const ctx: Context | undefined = AppContextHolder.get();
    if (ctx === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'AppContext not ready, AI config not loaded');
      return;
    }

    try {
      const content: Uint8Array = await ctx.resourceManager.getRawFileContent(API_CONFIG_FILE);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(content);
      const extractedKey: string = extractApiKeyFromText(text);
      if (extractedKey.length > 0) {
        AiConfig.apiKeyValue = extractedKey;
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'apiconfig.json loaded by text extractor: apiKeyLength=%{public}d, model=%{public}s, baseUrl=%{public}s',
          AiConfig.apiKeyValue.length, FIXED_MODEL, FIXED_BASE_URL);
        return;
      }
      const obj: ApiConfigFileRaw = JSON.parse(text) as ApiConfigFileRaw;
      const rawKey: Object | undefined = obj.apiKey !== undefined ? obj.apiKey : obj.api_key;
      if (typeof rawKey !== 'string') {
        AiConfig.apiKeyValue = '';
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'apiconfig.json apiKey is missing or not string: fileLength=%{public}d, hasApiKey=%{public}b, hasApiUnderscoreKey=%{public}b',
          text.length, obj.apiKey !== undefined, obj.api_key !== undefined);
        return;
      }
      const rawText: string = rawKey as string;
      AiConfig.apiKeyValue = normalizeApiKey(rawText);
      if (!AiConfig.configured) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'apiconfig.json apiKey empty, AI features disabled: fileLength=%{public}d, rawKeyLength=%{public}d',
          text.length, rawText.length);
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
