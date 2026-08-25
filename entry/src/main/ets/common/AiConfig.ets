import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContextHolder } from './AppContext';

const LOG_DOMAIN: number = 0xA003;
const LOG_TAG: string = 'TiXingAiConfig';

const DEFAULT_MODEL: string = 'glm-4.6v';
const DEFAULT_BASE_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const CONFIG_FILE: string = 'ai_config.json';

interface AiConfigFile {
  apiKey: string;
  model: string;
  baseUrl: string;
}

/**
 * 密钥配置读取器（D1）：从 rawfile/ai_config.json 读取本地密钥。
 * 文件缺失或密钥为空时安全降级（configured=false），不崩溃，由调用方给出配置指引。
 */
export class AiConfig {
  private static apiKeyValue: string = '';
  private static modelValue: string = DEFAULT_MODEL;
  private static baseUrlValue: string = DEFAULT_BASE_URL;
  private static loaded: boolean = false;

  static get apiKey(): string {
    return AiConfig.apiKeyValue;
  }

  static get model(): string {
    return AiConfig.modelValue;
  }

  static get baseUrl(): string {
    return AiConfig.baseUrlValue;
  }

  static get configured(): boolean {
    return AiConfig.apiKeyValue.length > 0;
  }

  static async load(): Promise<void> {
    if (AiConfig.loaded) {
      return;
    }
    AiConfig.loaded = true;
    const ctx = AppContextHolder.get();
    if (ctx === undefined) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'AppContext not ready, ai config not loaded');
      return;
    }
    try {
      const content: Uint8Array = await ctx.resourceManager.getRawFileContent(CONFIG_FILE);
      const textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = textDecoder.decodeToString(content);
      const obj: AiConfigFile = JSON.parse(text) as AiConfigFile;
      AiConfig.apiKeyValue = obj.apiKey !== undefined ? obj.apiKey.trim() : '';
      if (obj.model !== undefined && obj.model.length > 0) {
        AiConfig.modelValue = obj.model;
      }
      if (obj.baseUrl !== undefined && obj.baseUrl.length > 0) {
        AiConfig.baseUrlValue = obj.baseUrl;
      }
      if (!AiConfig.configured) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'ai_config.json apiKey empty, AI features disabled');
      }
    } catch (e) {
      // 缺失配置文件属预期场景（不入库），安全降级
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'ai_config.json missing or invalid, AI features disabled');
    }
  }
}
