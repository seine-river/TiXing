import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'tixing_prefs';
const KEY_CONSENT: string = 'telemetry.consent';
const KEY_DEVICE_ID: string = 'telemetry.deviceId';

export enum TelemetryConsentState {
  UNKNOWN = 'unknown',
  GRANTED = 'granted',
  DENIED = 'denied'
}

export class TelemetryConsentService {
  private static async getStore(context: Context): Promise<preferences.Preferences> {
    return preferences.getPreferences(context, STORE_NAME);
  }

  static async getConsent(context: Context): Promise<TelemetryConsentState> {
    try {
      const store: preferences.Preferences = await TelemetryConsentService.getStore(context);
      const value: preferences.ValueType = await store.get(KEY_CONSENT, TelemetryConsentState.UNKNOWN);
      if (value === TelemetryConsentState.GRANTED) {
        return TelemetryConsentState.GRANTED;
      }
      if (value === TelemetryConsentState.DENIED) {
        return TelemetryConsentState.DENIED;
      }
    } catch (e) {
    }
    return TelemetryConsentState.UNKNOWN;
  }

  static async setConsent(context: Context, state: TelemetryConsentState): Promise<void> {
    try {
      const store: preferences.Preferences = await TelemetryConsentService.getStore(context);
      await store.put(KEY_CONSENT, state);
      await store.flush();
    } catch (e) {
    }
  }

  static async stableDeviceId(context: Context): Promise<string> {
    try {
      const store: preferences.Preferences = await TelemetryConsentService.getStore(context);
      const value: preferences.ValueType = await store.get(KEY_DEVICE_ID, '');
      if (typeof value === 'string' && (value as string).length > 0) {
        return value as string;
      }
      const generated: string = `tixing-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 12)}`;
      await store.put(KEY_DEVICE_ID, generated);
      await store.flush();
      return generated;
    } catch (e) {
      return `volatile-${Date.now().toString(36)}`;
    }
  }
}
