import { UIContext } from '@kit.ArkUI';

export class Toast {
  private static uiContext: UIContext | undefined = undefined;

  static setContext(ctx: UIContext): void {
    Toast.uiContext = ctx;
  }

  static show(message: string): void {
    try {
      if (Toast.uiContext !== undefined) {
        Toast.uiContext.getPromptAction().showToast({ message: message, duration: 2000, bottom: 180 });
      }
    } catch (e) {
    }
  }
}
