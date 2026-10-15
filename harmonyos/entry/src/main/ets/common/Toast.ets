import { UIContext } from '@kit.ArkUI';
import { AppContextHolder } from './AppContext';

/**
 * Toast（T041）：从 AppContextHolder 实时获取主窗口 UIContext，不再静态持有。
 */
export class Toast {
  static show(message: string): void {
    try {
      const ctx: UIContext | undefined = AppContextHolder.getUiContext();
      if (ctx !== undefined) {
        ctx.getPromptAction().showToast({ message: message, duration: 2000, bottom: 180 });
      }
    } catch (e) {
    }
  }
}
