import { window, UIContext } from '@kit.ArkUI';

/**
 * 应用上下文持有者：保存 Ability Context 与主窗口 WindowStage，
 * Toast 等工具类经此实时获取 UIContext（T041），不再静态持有。
 */
export class AppContextHolder {
  private static _context: Context | undefined = undefined;
  private static _windowStage: window.WindowStage | undefined = undefined;

  static set(context: Context): void {
    AppContextHolder._context = context;
  }

  static get(): Context | undefined {
    return AppContextHolder._context;
  }

  static require(): Context {
    const c = AppContextHolder._context;
    if (c === undefined) {
      throw new Error('AppContext not initialized');
    }
    return c;
  }

  static setWindowStage(stage: window.WindowStage): void {
    AppContextHolder._windowStage = stage;
  }

  /** 实时获取主窗口 UIContext（窗口重建后自动取到新实例）。 */
  static getUiContext(): UIContext | undefined {
    const stage = AppContextHolder._windowStage;
    if (stage === undefined) {
      return undefined;
    }
    try {
      return stage.getMainWindowSync().getUIContext();
    } catch (e) {
      return undefined;
    }
  }
}
