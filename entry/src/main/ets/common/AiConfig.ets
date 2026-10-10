import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { asset } from '@kit.AssetStoreKit';
import { AppContextHolder } from './AppContext';

const LOG_DOMAIN: number = 0xA003;
const LOG_TAG: string = 'TiXingAiConfig';

const DEFAULT_MODEL: string = 'glm-4.6v';
const DEFAULT_BASE_URL: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const PREF_STORE_NAME: string = 'tixing_ai_prefs';
const PREF_KEY_MODEL: string = 'ai_model';
const PREF_KEY_BASE_URL: string = 'ai_base_url';
const ASSET_ALIAS: string = 'tixing_ai_api_key';

function strToBytes(s: string): Uint8Array {
  const encoder: util.TextEncoder = new util.TextEncoder();
  return encoder.encodeInto(s);
}

function bytesToStr(bytes: Uint8Array): string {
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(bytes);
}

/**
 * AI 配置（应用内配置版）：
 * - API Key：写入系统 Asset Store（端侧加密存储、设备绑定、卸载不清除），绝不落明文文件；
 * - 模型 / 接口地址：非敏感信息，存 preferences；
 * - 不再从 rawfile 或代码读取任何密钥。
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

  static get defaultModel(): string {
    return DEFAULT_MODEL;
  }

  static get defaultBaseUrl(): string {
    return DEFAULT_BASE_URL;
  }

  static async load(): Promise<void> {
    if (AiConfig.loaded) {
      return;
    }
    AiConfig.loaded = true;
    // 1) 非敏感配置：模型 / 接口地址
    try {
      const ctx: Context | undefined = AppContextHolder.get();
      if (ctx !== undefined) {
        const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_STORE_NAME);
        const model: preferences.ValueType = await store.get(PREF_KEY_MODEL, DEFAULT_MODEL);
        if (typeof model === 'string' && model.length > 0) {
          AiConfig.modelValue = model;
        }
        const url: preferences.ValueType = await store.get(PREF_KEY_BASE_URL, DEFAULT_BASE_URL);
        if (typeof url === 'string' && url.length > 0) {
          AiConfig.baseUrlValue = url;
        }
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'load ai prefs failed');
    }
    // 2) 敏感配置：API Key（Asset Store 加密存储）
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      query.set(asset.Tag.ALIAS, strToBytes(ASSET_ALIAS));
      const result: Array<asset.AssetMap> = await asset.query(query);
      if (result.length > 0) {
        const secret: boolean | number | Uint8Array | undefined = result[0].get(asset.Tag.SECRET);
        if (secret !== undefined && secret instanceof Uint8Array) {
          AiConfig.apiKeyValue = bytesToStr(secret).trim();
        }
      }
    } catch (e) {
      // 未配置过密钥时查询无结果，属预期场景
      hilog.info(LOG_DOMAIN, LOG_TAG, 'asset query empty or failed, ai key not configured');
    }
  }

  /**
   * 保存配置：API Key 经系统密钥库加密落盘；OVERWRITE 语义天然支持覆盖更新。
   */
  static async save(apiKey: string, model: string, baseUrl: string): Promise<void> {
    const key: string = apiKey.trim();
    if (key.length === 0) {
      throw new Error('API Key 不能为空');
    }
    const modelVal: string = model.trim().length > 0 ? model.trim() : DEFAULT_MODEL;
    const urlVal: string = baseUrl.trim().length > 0 ? baseUrl.trim() : DEFAULT_BASE_URL;

    try {
      const attrs: asset.AssetMap = new Map();
      attrs.set(asset.Tag.ALIAS, strToBytes(ASSET_ALIAS));
      attrs.set(asset.Tag.SECRET, strToBytes(key));
      attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      attrs.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(attrs);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'asset add failed: %{public}s',
        e instanceof Error ? e.message : 'unknown');
      throw new Error('密钥安全存储失败，请重试');
    }

    const ctx: Context | undefined = AppContextHolder.get();
    if (ctx === undefined) {
      throw new Error('应用未就绪，请稍后重试');
    }
    const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_STORE_NAME);
    await store.put(PREF_KEY_MODEL, modelVal);
    await store.put(PREF_KEY_BASE_URL, urlVal);
    await store.flush();

    AiConfig.apiKeyValue = key;
    AiConfig.modelValue = modelVal;
    AiConfig.baseUrlValue = urlVal;
    AiConfig.loaded = true;
  }

  /** 清除全部 AI 配置（含安全存储中的密钥）。 */
  static async clear(): Promise<void> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, strToBytes(ASSET_ALIAS));
      await asset.remove(query);
    } catch (e) {
      // 密钥本就不存在时忽略
    }
    try {
      const ctx: Context | undefined = AppContextHolder.get();
      if (ctx !== undefined) {
        const store: preferences.Preferences = await preferences.getPreferences(ctx, PREF_STORE_NAME);
        await store.delete(PREF_KEY_MODEL);
        await store.delete(PREF_KEY_BASE_URL);
        await store.flush();
      }
    } catch (e) {
    }
    AiConfig.apiKeyValue = '';
    AiConfig.modelValue = DEFAULT_MODEL;
    AiConfig.baseUrlValue = DEFAULT_BASE_URL;
  }
}
