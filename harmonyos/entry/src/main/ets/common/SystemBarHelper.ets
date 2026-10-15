import { window } from '@kit.ArkUI';
import { UIContext } from '@kit.ArkUI';

const FALLBACK_STATUS_BAR_VP: number = 38;

/**
 * 状态栏避让（T044）：结果静态缓存（单窗口应用，全进程共享一次测量）。
 */
export class SystemBarHelper {
  private static cachedHeightVp: number = -1;

  static statusBarHeightVp(uiContext: UIContext): Promise<number> {
    if (SystemBarHelper.cachedHeightVp >= 0) {
      return Promise.resolve(SystemBarHelper.cachedHeightVp);
    }
    return new Promise<number>((resolve) => {
      try {
        const ctx = uiContext.getHostContext();
        window.getLastWindow(ctx).then((win: window.Window) => {
          try {
            const area: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
            const height: number = area.topRect.height > 0 ? uiContext.px2vp(area.topRect.height) : 0;
            SystemBarHelper.cachedHeightVp = height;
            resolve(height);
          } catch (e) {
            resolve(FALLBACK_STATUS_BAR_VP);
          }
        }).catch(() => {
          resolve(FALLBACK_STATUS_BAR_VP);
        });
      } catch (e) {
        resolve(FALLBACK_STATUS_BAR_VP);
      }
    });
  }
}
