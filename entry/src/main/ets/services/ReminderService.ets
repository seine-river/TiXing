import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { ReminderSettings } from '../models/ReminderSettings';

const REMINDER_NOTIFICATION_ID: number = 1001;

export class ReminderService {
  private static currentReminderId: number = -1;

  static async applySettings(settings: ReminderSettings): Promise<void> {
    try {
      await ReminderService.cancel();
      if (!settings.notificationEnabled || settings.doNotDisturb) {
        return;
      }
      const parts: string[] = settings.reviewTimeStart.split(':');
      const hour: number = parts.length >= 1 ? ReminderService.parseIntSafe(parts[0], 8) : 8;
      const minute: number = parts.length >= 2 ? ReminderService.parseIntSafe(parts[1], 0) : 0;

      const reminder: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '题醒 · 复习提醒',
        content: '你有待复习的错题，快来巩固一下吧！',
        notificationId: REMINDER_NOTIFICATION_ID,
        actionButton: [
          { title: '开始复习', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
        ]
      };
      const id: number = await reminderAgentManager.publishReminder(reminder);
      ReminderService.currentReminderId = id;
    } catch (e) {
    }
  }

  static async cancel(): Promise<void> {
    try {
      if (ReminderService.currentReminderId >= 0) {
        await reminderAgentManager.cancelReminder(ReminderService.currentReminderId);
        ReminderService.currentReminderId = -1;
      }
    } catch (e) {
    }
  }

  private static parseIntSafe(s: string, fallback: number): number {
    const v: number = parseInt(s, 10);
    if (isNaN(v)) {
      return fallback;
    }
    return v;
  }
}
