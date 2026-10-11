import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common, bundleManager } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReminderSettings } from '../models/ReminderSettings';
import { DbResult } from '../common/DbResult';
import { PreferenceService } from './PreferenceService';
import { PerformanceMonitor } from './PerformanceMonitor';
import { CalendarReminderService } from './CalendarReminderService';

const REMINDER_NOTIFICATION_ID: number = 1001;
const LOG_DOMAIN: number = 0xA005;
const LOG_TAG: string = 'TiXingReminder';

/** 用于把系统 BusinessError 转成可日志、可展示的文本。 */
interface BusinessErrorLike {
  code?: number;
  message?: string;
}

/**
 * 复习提醒服务（T022/D5）：
 * - PUBLISH_AGENT_REMINDER 为 normal/system_grant 权限，只需在 module.json5 声明，
 *   安装后由系统授予，不能也不需要调用 requestPermissionsFromUser；
 * - ensureNotificationEnabled：运行时仅需确认/申请应用通知开关；
 * - syncAndApply：优先代理提醒；设备管控导致发布失败时自动降级到系统日历；
 * - 冷启动只复用已授权日历权限，不在后台弹敏感权限窗。
 */
export class ReminderService {
  /**
   * publishReminder 明确要求先开启应用通知。
   * 用户主动保存设置时先请求通知开关；若授权弹窗已不可再弹，则引导到系统通知设置页。
   */
  static async ensureNotificationEnabled(context: common.Context): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'notification status checked: enabled=%{public}b', enabled);
      if (enabled) {
        return true;
      }
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'notification status check failed: %{public}s', ReminderService.errText(e));
    }

    const abilityContext = context as common.UIAbilityContext;
    try {
      await notificationManager.requestEnableNotification(abilityContext);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'request notification enable failed: %{public}s', ReminderService.errText(e));
      try {
        const setting = await notificationManager.openNotificationSettingsWithResult(abilityContext);
        const enabledInSetting: boolean = setting.notificationEnabled === true;
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'notification settings result: enabled=%{public}b', enabledInSetting);
        return enabledInSetting;
      } catch (settingsError) {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'open notification settings failed: %{public}s', ReminderService.errText(settingsError));
        return false;
      }
    }

    try {
      const enabledAfterRequest: boolean = await notificationManager.isNotificationEnabled();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'notification status after request: enabled=%{public}b', enabledAfterRequest);
      return enabledAfterRequest;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'notification status recheck failed: %{public}s', ReminderService.errText(e));
      return false;
    }
  }

  /**
   * 清光重建（FR-010）：先取消代理提醒，再按设置重建；
   * 代理提醒不可用时自动写入应用专属系统日历。
   */
  static async syncAndApply(
    settings: ReminderSettings,
    context?: common.Context
  ): Promise<DbResult> {
    const cancelRes: DbResult = await ReminderService.cancelAllPublished();
    if (!cancelRes.success) {
      return cancelRes;
    }
    if (!settings.notificationEnabled) {
      PreferenceService.setPublishedReminderId('').catch((_e: Error): void => {
        PerformanceMonitor.warn('clear persisted reminder id failed');
      });
      const calendarCancel: DbResult = await CalendarReminderService.removeAll(context);
      if (!calendarCancel.success) {
        PerformanceMonitor.warn('calendar reminder cleanup failed: ' + calendarCancel.reason);
      }
      return DbResult.ok();
    }

    let notificationEnabled: boolean = true;
    try {
      notificationEnabled = await notificationManager.isNotificationEnabled();
      if (!notificationEnabled) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'agent reminder skipped because app notification is disabled, try calendar fallback');
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'notification status check before publish failed: %{public}s', ReminderService.errText(e));
    }

    if (!notificationEnabled) {
      const calendarResult: DbResult =
        await CalendarReminderService.applyReminder(settings, context, context !== undefined);
      if (calendarResult.success) {
        return calendarResult;
      }
      return DbResult.fail('reminder.notificationDisabled',
        '应用通知未开启，且日历提醒不可用：' + calendarResult.reason);
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
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'publish reminder request: bundleName=%{public}s, hour=%{public}d, minute=%{public}d, notificationId=%{public}d',
        bundleName, hour, minute, REMINDER_NOTIFICATION_ID);
      const id: number = await reminderAgentManager.publishReminder(reminder);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'publish reminder success: reminderId=%{public}d', id);
      PreferenceService.setPublishedReminderId(`${id}`).catch((e: Error): void => {
        PerformanceMonitor.warn('persist reminder id failed: ' + ReminderService.errText(e));
      });
      const calendarCleanup: DbResult = await CalendarReminderService.removeAll(context);
      if (!calendarCleanup.success) {
        PerformanceMonitor.warn('calendar reminder cleanup after agent success failed: ' +
          calendarCleanup.reason);
      }
      return DbResult.okWithMode('agent');
    } catch (e) {
      const errorCode: number = ReminderService.errorCode(e);
      const reason: string = ReminderService.errText(e);
      const userReason: string = ReminderService.publishFailureReason(errorCode);
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'publish reminder failed: code=%{public}d, error=%{public}s, userReason=%{public}s',
        errorCode, reason, userReason);
      PerformanceMonitor.writeFault('reminder_publish_failed', { 'reason': reason.substring(0, 160) });

      const calendarResult: DbResult =
        await CalendarReminderService.applyReminder(settings, context, context !== undefined);
      if (calendarResult.success) {
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'calendar fallback enabled after agent reminder failure, agentCode=%{public}d', errorCode);
        return calendarResult;
      }
      return DbResult.fail('reminder.publishAndFallback',
        `${userReason}；日历降级也失败：${calendarResult.reason}`);
    }
  }

  /** 取消本应用全部有效提醒，避免启动/保存时不断新增导致 30 个上限溢出。 */
  static async cancelAllPublished(): Promise<DbResult> {
    try {
      const before: Array<reminderAgentManager.ReminderRequest> = await reminderAgentManager.getValidReminders();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'cancel all reminders start: validCount=%{public}d', before.length);
      await reminderAgentManager.cancelAllReminders();
      const after: Array<reminderAgentManager.ReminderRequest> = await reminderAgentManager.getValidReminders();
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'cancel all reminders end: validCount=%{public}d', after.length);
      if (after.length > 0) {
        return DbResult.fail('reminder.cancelAll',
          `旧提醒清理不完整，剩余 ${after.length} 条，请稍后重试`);
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

  private static errorCode(e: Object): number {
    try {
      const errorLike: BusinessErrorLike = JSON.parse(JSON.stringify(e)) as BusinessErrorLike;
      if (errorLike.code !== undefined) {
        return errorLike.code;
      }
    } catch (parseError) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'serialize reminder error code failed');
    }
    return -1;
  }

  private static publishFailureReason(code: number): string {
    if (code === 1700002) {
      return '提醒发布失败(1700002)：当前设备限制三方应用使用代理提醒';
    }
    if (code === 1700001) {
      return '提醒发布失败(1700001)：应用通知未开启，请开启通知后重试';
    }
    return `提醒发布失败(${code})，请稍后重试`;
  }

  private static errText(e: Object): string {
    try {
      const errorLike: BusinessErrorLike = JSON.parse(JSON.stringify(e)) as BusinessErrorLike;
      if (errorLike.message !== undefined) {
        const code: string = errorLike.code !== undefined ? `${errorLike.code}` : 'unknown';
        return `code=${code}, message=${errorLike.message}`;
      }
    } catch (parseError) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'serialize reminder error failed');
    }
    return `${e}`;
  }
}
