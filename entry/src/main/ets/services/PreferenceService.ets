import { preferences } from '@kit.ArkData';
import { AppContextHolder } from '../common/AppContext';

const STORE_NAME: string = 'tixing_prefs';
const KEY_LEADERBOARD: string = 'leaderboard_enabled';

export class PreferenceService {
  private static async getStore(): Promise<preferences.Preferences> {
    const ctx: Context | undefined = AppContextHolder.get();
    if (ctx === undefined) {
      throw new Error('AppContext not initialized');
    }
    try {
      return await preferences.getPreferences(ctx, STORE_NAME);
    } catch (e) {
      throw new Error('preference store unavailable');
    }
  }

  static async getLeaderboardEnabled(): Promise<boolean> {
    try {
      const store = await PreferenceService.getStore();
      const val: preferences.ValueType = await store.get(KEY_LEADERBOARD, true);
      return val === true || val === 'true';
    } catch (e) {
      return true;
    }
  }

  static async setLeaderboardEnabled(enabled: boolean): Promise<void> {
    try {
      const store = await PreferenceService.getStore();
      await store.put(KEY_LEADERBOARD, enabled);
      await store.flush();
    } catch (e) {
    }
  }
}
