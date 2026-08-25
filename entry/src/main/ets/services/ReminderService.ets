import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { abilityAccessCtrl, common, Permissions, PermissionRequestResult, bundleManager } from '@kit.AbilityKit';
import { ReminderSettings } from '../models/ReminderSettings';
import { DbResult } from '../common/DbResult';
import { PreferenceService } from './PreferenceService';
import { PerformanceMonitor } from './PerformanceMonitor';

const REMINDER_NOTIFICATION_ID: number = 1001;

/**
 * getValidReminders 返回的 ReminderRequest 在运行时携带 reminderId（类型声明未包含），
 * 经 JSON 透传取出以保持类型安全。
 */
interface ReminderIdLike {
  reminderId?: number;
}

/**
 * 复习提醒服务（T022/D5）：
 * - ensurePermission：运行时申请 PUBLISH_AGENT_REMINDER（拒绝返回 false 供页面引导）；
 * - syncAndApply：getValidReminders 清光重建（幂等，重启不叠加）+ reminderId 写入 Preferences；
 * - 发布/取消失败如实上抛 DbResult；通知点击经 wantAgent 拉起应用。
 */
export class ReminderService {
  static async ensurePermission(context: common.Context): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const perms: Array<Permissions> = ['ohos.permission.PUBLISH_AGENT_REMINDER'];
    try {
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(context, perms);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      PerformanceMonitor.warn('reminder permission request failed: ' + ReminderService.errText(e));
      return false;
    }
  }

  /**
   * 清光重建（FR-010）：先取消本应用全部有效提醒，再按设置重新发布。
   */
  static async syncAndApply(settings: ReminderSettings): Promise<DbResult> {
    const cancelRes: DbResult = await ReminderService.cancelAllPublished();
    if (!cancelRes.success) {
      return cancelRes;
    }
    if (!settings.notificationEnabled || settings.doNotDisturb) {
      PreferenceService.setPublishedReminderId('').catch((_e: Error): void => {
        PerformanceMonitor.warn('clear persisted reminder id failed');
      });
      return DbResult.ok();
    }

    try {
      const bundleName: string = await ReminderService.getBundleName();
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
        wantAgent: {
          pkgName: bundleName,
          abilityName: 'EntryAbility'
        },
        actionButton: [
          { title: '开始复习', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
        ]
      };
      const id: number = await reminderAgentManager.publishReminder(reminder);
      PreferenceService.setPublishedReminderId(`${id}`).catch((e: Error): void => {
        PerformanceMonitor.warn('persist reminder id failed: ' + ReminderService.errText(e));
      });
      return DbResult.ok();
    } catch (e) {
      const reason: string = ReminderService.errText(e);
      PerformanceMonitor.writeFault('reminder_publish_failed', { 'reason': reason.substring(0, 80) });
      return DbResult.fail('reminder.publish', '提醒发布失败: ' + reason);
    }
  }

  /** 查询并取消本应用当前全部有效提醒（含持久化的 id 兜底）。 */
  static async cancelAllPublished(): Promise<DbResult> {
    try {
      const valid: Array<reminderAgentManager.ReminderRequest> = await reminderAgentManager.getValidReminders();
      for (const r of valid) {
        const parsed: ReminderIdLike = JSON.parse(JSON.stringify(r)) as ReminderIdLike;
        if (parsed.reminderId !== undefined) {
          await reminderAgentManager.cancelReminder(parsed.reminderId);
        }
      }
      return DbResult.ok();
    } catch (e) {
      const reason: string = ReminderService.errText(e);
      PerformanceMonitor.warn('reminder cancel-all failed: ' + reason);
      return DbResult.fail('reminder.cancelAll', '旧提醒清理失败: ' + reason);
    }
  }

  private static async getBundleName(): Promise<string> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.name;
    } catch (e) {
      PerformanceMonitor.warn('get bundle name failed for reminder wantAgent');
      return '';
    }
  }

  private static parseIntSafe(s: string, fallback: number): number {
    const v: number = parseInt(s, 10);
    if (isNaN(v)) {
      return fallback;
    }
    return v;
  }

  private static errText(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return `${e}`;
  }
}
