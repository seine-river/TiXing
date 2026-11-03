const MAX_EVENT_NAME_LENGTH: number = 96;
const MAX_KEY_LENGTH: number = 64;
const MAX_VALUE_LENGTH: number = 180;
const MAX_PARAM_COUNT: number = 16;
const RESERVED_KEYS: string[] = [
  'id', 'ts', 'du', 'ds', 'duration', 'pn', 'token', 'device_name', 'device_model',
  'device_brand', 'country', 'city', 'channel', 'province', 'appkey', 'app_version',
  'access', 'launch', 'pre_app_version', 'terminate', 'type'
];
const BLOCKED_KEYS: string[] = [
  'api_key', 'apikey', 'authorization', 'question', 'answer', 'text', 'content',
  'image', 'imageurl', 'audio', 'audiopath', 'nickname', 'student_id', 'studentid', 'name'
];

export class TelemetrySanitizer {
  static eventName(kind: string, name: string): string {
    const normalized: string = name.trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
    const safe: string = normalized.length > 0 ? normalized : 'unknown';
    return `${kind}_${safe}`.substring(0, MAX_EVENT_NAME_LENGTH);
  }

  static params(params: Record<string, string | number | boolean>): Record<string, string | number> {
    const result: Record<string, string | number> = {};
    let count: number = 0;
    const keys: string[] = Object.keys(params);
    for (let i: number = 0; i < keys.length && count < MAX_PARAM_COUNT; i++) {
      const originalKey: string = keys[i];
      const key: string = TelemetrySanitizer.key(originalKey);
      if (key.length === 0 || TelemetrySanitizer.isReserved(key) || TelemetrySanitizer.isBlocked(key)) {
        continue;
      }
      const value: string | number | boolean = params[originalKey];
      if (typeof value === 'boolean') {
        result[key] = value ? 1 : 0;
      } else if (typeof value === 'number' && Number.isFinite(value)) {
        result[key] = Math.round(value);
      } else if (typeof value === 'string') {
        result[key] = TelemetrySanitizer.sanitizeValue(value);
      }
      count++;
    }
    return result;
  }

  static text(value: string, maxLength: number = MAX_VALUE_LENGTH): string {
    return value.replace(/[\r\n\t]+/g, ' ').trim().substring(0, maxLength);
  }

  private static key(raw: string): string {
    return raw.trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '').substring(0, MAX_KEY_LENGTH);
  }

  static sanitizeValue(raw: string): string {
    return TelemetrySanitizer.text(TelemetrySanitizer.maskEmail(TelemetrySanitizer.maskBearer(raw)));
  }

  private static maskBearer(raw: string): string {
    const marker: string = 'Bearer ';
    const markerIndex: number = raw.indexOf(marker);
    if (markerIndex < 0) {
      return raw;
    }
    const valueStart: number = markerIndex + marker.length;
    let valueEnd: number = valueStart;
    while (valueEnd < raw.length) {
      const current: string = raw.charAt(valueEnd);
      if (current === ' ' || current === '\n' || current === '\r' || current === '\t' || current === ',') {
        break;
      }
      valueEnd++;
    }
    return raw.substring(0, valueStart) + '[token]' + raw.substring(valueEnd);
  }

  private static maskEmail(raw: string): string {
    const atIndex: number = raw.indexOf('@');
    if (atIndex < 0) {
      return raw;
    }
    let start: number = atIndex;
    while (start > 0) {
      const current: string = raw.charAt(start - 1);
      if (current === ' ' || current === '\n' || current === '\r' || current === '\t' || current === ',') {
        break;
      }
      start--;
    }
    let end: number = atIndex + 1;
    let dots: number = 0;
    while (end < raw.length) {
      const current: string = raw.charAt(end);
      if (current === ' ' || current === '\n' || current === '\r' || current === '\t' || current === ',') {
        break;
      }
      if (current === '.') {
        dots++;
      }
      end++;
    }
    if (dots === 0) {
      return raw;
    }
    return raw.substring(0, start) + '[email]' + raw.substring(end);
  }

  private static isReserved(key: string): boolean {
    return RESERVED_KEYS.indexOf(key) >= 0;
  }

  private static isBlocked(key: string): boolean {
    const normalized: string = TelemetrySanitizer.key(key);
    const segments: string[] = normalized.split('_');
    for (let i: number = 0; i < BLOCKED_KEYS.length; i++) {
      const blocked: string = BLOCKED_KEYS[i];
      const blockedPrefix: string = blocked + '_';
      const blockedSuffix: string = '_' + blocked;
      const blockedInfix: string = '_' + blocked + '_';
      if (normalized === blocked || normalized.startsWith(blockedPrefix) ||
        normalized.endsWith(blockedSuffix) || normalized.indexOf(blockedInfix) >= 0 ||
        segments.indexOf(blocked) >= 0) {
        return true;
      }
    }
    return false;
  }
}
