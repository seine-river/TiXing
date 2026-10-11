import { calendarManager } from '@kit.CalendarKit';
import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReminderSettings } from '../models/ReminderSettings';
import { DbResult } from '../common/DbResult';
import { AppContextHolder } from '../common/AppContext';

const LOG_DOMAIN: number = 0xA006;
const LOG_TAG: string = 'TiXingCalendar';
const CALENDAR_ACCOUNT_NAME: string = 'com.tixing.me.review';

/** 用于把系统 BusinessError 转成可日志、可展示的文本。 */
interface BusinessErrorLike {
  code?: number;
  message?: string;
}

/**
 * 系统日历提醒降级通道。
 * 代理提醒被设备管控时，把每天一次的复习提醒写入应用专属日历，
 * 由系统日历负责提醒，避免应用常驻后台。
 */
export class CalendarReminderService {
  /**
   * Calendar Kit 的读写属于用户敏感授权。
   * 只在用户主动保存提醒设置时调用，冷启动降级不弹权限窗。
   */
  static async ensurePermissions(context: common.Context): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = [
        'ohos.permission.READ_CALENDAR',
        'ohos.permission.WRITE_CALENDAR'
      ];
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, permissions);
      const granted: boolean = result.authResults.length >= 2 &&
        result.authResults[0] === 0 && result.authResults[1] === 0;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'calendar permissions requested: granted=%{public}b, results=%{public}s',
        granted, JSON.stringify(result.authResults));
      return granted;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'calendar permission request failed: %{public}s', CalendarReminderService.errText(e));
      return false;
    }
  }

  /**
   * 重建应用专属日历中的每日复习日程，保证同一时间只有一条循环提醒。
   */
  static async applyReminder(
    settings: ReminderSettings,
    context?: common.Context,
    requestPermission: boolean = false
  ): Promise<DbResult> {
    const ctx: common.Context | undefined = context ?? AppContextHolder.get();
    if (ctx === undefined) {
      return DbResult.fail('reminder.calendarContext', '暂无法访问系统日历，请重新打开应用后再试');
    }
    if (requestPermission) {
      const granted: boolean = await CalendarReminderService.ensurePermissions(ctx);
      if (!granted) {
        return DbResult.fail('reminder.calendarPermission', '未获得日历权限，无法启用日历提醒降级方案');
      }
    }

    try {
      const calendar: calendarManager.Calendar =
        await CalendarReminderService.getOrCreateCalendar(ctx);
      await CalendarReminderService.clearCalendarEvents(calendar);

      const start: Date = CalendarReminderService.nextOccurrence(settings.reviewTimeStart);
      const end: Date = new Date(start.getTime() + 30 * 60 * 1000);
      const event: calendarManager.Event = {
        type: calendarManager.EventType.NORMAL,
        title: '题醒 · 复习提醒',
        startTime: start.getTime(),
        endTime: end.getTime(),
        reminderTime: [0],
        recurrenceRule: {
          recurrenceFrequency: calendarManager.RecurrenceFrequency.DAILY,
          interval: 1
        },
        description: '打开题醒，完成今天待复习的错题吧！'
      };
      const eventId: number = await calendar.addEvent(event);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'calendar reminder created: eventId=%{public}d, start=%{public}d',
        eventId, start.getTime());
      return DbResult.okWithMode('calendar');
    } catch (e) {
      const reason: string = CalendarReminderService.errText(e);
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'calendar reminder create failed: %{public}s', reason);
      return DbResult.fail('reminder.calendar', '日历提醒创建失败: ' + reason);
    }
  }

  /** 只清理本应用专属日历，不触碰用户其他日程。 */
  static async removeAll(context?: common.Context): Promise<DbResult> {
    const ctx: common.Context | undefined = context ?? AppContextHolder.get();
    if (ctx === undefined) {
      return DbResult.fail('reminder.calendarContext', '暂无法访问系统日历');
    }

    try {
      const calendar: calendarManager.Calendar | undefined =
        await CalendarReminderService.findCalendar(ctx);
      if (calendar !== undefined) {
        await CalendarReminderService.clearCalendarEvents(calendar);
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'calendar reminders removed');
      return DbResult.ok();
    } catch (e) {
      const reason: string = CalendarReminderService.errText(e);
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'calendar reminders remove failed: %{public}s', reason);
      return DbResult.fail('reminder.calendarCancel', '日历提醒清理失败: ' + reason);
    }
  }

  private static async getOrCreateCalendar(
    context: common.Context
  ): Promise<calendarManager.Calendar> {
    const existing: calendarManager.Calendar | undefined =
      await CalendarReminderService.findCalendar(context);
    if (existing !== undefined) {
      return existing;
    }

    const manager = calendarManager.getCalendarManager(context);
    const account: calendarManager.CalendarAccount = {
      name: CALENDAR_ACCOUNT_NAME,
      type: calendarManager.CalendarType.LOCAL,
      displayName: '题醒复习提醒'
    };

    hilog.info(LOG_DOMAIN, LOG_TAG, 'review calendar not found, create it');
    const calendar = await manager.createCalendar(account);
    await calendar.setConfig({
      enableReminder: true
    });
    return calendar;
  }

  private static async findCalendar(
    context: common.Context
  ): Promise<calendarManager.Calendar | undefined> {
    const manager = calendarManager.getCalendarManager(context);
    const account: calendarManager.CalendarAccount = {
      name: CALENDAR_ACCOUNT_NAME,
      type: calendarManager.CalendarType.LOCAL,
      displayName: '题醒复习提醒'
    };
    try {
      return await manager.getCalendar(account);
    } catch (_e) {
      return undefined;
    }
  }

  private static async clearCalendarEvents(calendar: calendarManager.Calendar): Promise<void> {
    const events: Array<calendarManager.Event> = await calendar.getEvents();
    const ids: number[] = [];
    for (const event of events) {
      if (event.id !== undefined) {
        ids.push(event.id);
      }
    }
    if (ids.length > 0) {
      await calendar.deleteEvents(ids);
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'calendar events cleared: count=%{public}d', ids.length);
  }

  private static nextOccurrence(hhmm: string): Date {
    const parts: string[] = hhmm.split(':');
    const hour: number = parts.length >= 1 ? CalendarReminderService.parseIntSafe(parts[0], 8) : 8;
    const minute: number = parts.length >= 2 ? CalendarReminderService.parseIntSafe(parts[1], 0) : 0;
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0);
    if (start.getTime() <= now.getTime()) {
      start.setDate(start.getDate() + 1);
    }
    return start;
  }

  private static parseIntSafe(s: string, fallback: number): number {
    const value: number = parseInt(s, 10);
    return isNaN(value) ? fallback : value;
  }

  private static errText(e: Object): string {
    try {
      const errorLike: BusinessErrorLike = JSON.parse(JSON.stringify(e)) as BusinessErrorLike;
      if (errorLike.message !== undefined) {
        const code: string = errorLike.code !== undefined ? `${errorLike.code}` : 'unknown';
        return `code=${code}, message=${errorLike.message}`;
      }
    } catch (_parseError) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'serialize calendar error failed');
    }
    return `${e}`;
  }
}
