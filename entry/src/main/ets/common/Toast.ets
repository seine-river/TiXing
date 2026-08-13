import { promptAction } from '@kit.ArkUI';

export class Toast {
  static show(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2000, bottom: 180 });
    } catch (e) {
    }
  }
}
