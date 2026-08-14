import { hiAppEvent } from '@kit.PerformanceAnalysisKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xA001;
const LOG_TAG: string = 'TiXing';
const APP_EVENT_DOMAIN: string = 'tixing';

export class PerformanceMonitor {
  private static initialized: boolean = false;

  static init(): void {
    if (PerformanceMonitor.initialized) {
      return;
    }
    try {
      hiAppEvent.configure({ disable: false, maxStorage: '10M' });
      PerformanceMonitor.addFaultWatcher();
      PerformanceMonitor.initialized = true;
      PerformanceMonitor.info('PerformanceMonitor initialized');
    } catch (e) {
      PerformanceMonitor.errorRaw('PerformanceMonitor init failed');
    }
  }

  private static addFaultWatcher(): void {
    const watcher: hiAppEvent.Watcher = {
      name: 'tixing_fault_watcher',
      appEventFilters: [
        { domain: hiAppEvent.domain.OS, eventTypes: [hiAppEvent.EventType.FAULT] }
      ],
      onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
        PerformanceMonitor.handleReceivedEvents(domain, appEventGroups);
      }
    };
    try {
      hiAppEvent.addWatcher(watcher);
    } catch (e) {
    }
  }

  private static handleReceivedEvents(domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>): void {
    for (const group of appEventGroups) {
      for (const info of group.appEventInfos) {
        if (info.eventType === hiAppEvent.EventType.FAULT) {
          PerformanceMonitor.logFaultEvent(domain, info.name, info.params);
        }
      }
    }
  }

  static writeBehavior(name: string, params: Record<string, string | number | boolean>): void {
    try {
      const info: hiAppEvent.AppEventInfo = {
        domain: APP_EVENT_DOMAIN,
        name: name,
        eventType: hiAppEvent.EventType.BEHAVIOR,
        params: params as object
      };
      hiAppEvent.write(info).then(() => {
      }).catch((e: Error) => {
        PerformanceMonitor.errorRaw('write behavior event failed: ' + name);
      });
    } catch (e) {
    }
  }

  static writeStatistic(name: string, params: Record<string, string | number | boolean>): void {
    try {
      const info: hiAppEvent.AppEventInfo = {
        domain: APP_EVENT_DOMAIN,
        name: name,
        eventType: hiAppEvent.EventType.STATISTIC,
        params: params as object
      };
      hiAppEvent.write(info).then(() => {
      }).catch((e: Error) => {
        PerformanceMonitor.errorRaw('write statistic event failed: ' + name);
      });
    } catch (e) {
    }
  }

  static writeFault(name: string, params: Record<string, string | number | boolean>): void {
    try {
      const info: hiAppEvent.AppEventInfo = {
        domain: APP_EVENT_DOMAIN,
        name: name,
        eventType: hiAppEvent.EventType.FAULT,
        params: params as object
      };
      hiAppEvent.write(info);
    } catch (e) {
    }
  }

  private static logFaultEvent(domain: string, name: string, params: object): void {
    PerformanceMonitor.errorRaw('FAULT captured: ' + domain + '/' + name);

    if (name === 'APP_CRASH' || name === 'APP_FREEZE') {
      PerformanceMonitor.writeStatistic('stability_fault', {
        'fault_type': name, 'domain': domain
      });
    }

    PerformanceMonitor.uploadFaultLog(domain, name, params);
  }

  static uploadFaultLog(domain: string, name: string, params: object): void {
    // 故障日志上传占位：按实际上架后的日志服务实现上传逻辑。
    // 建议：将 domain/name/params 及本地 hiAppEvent 落盘日志路径打包，
    // 经用户授权后通过 HTTPS 上传至日志收集服务端。
    // 上传前需获得用户隐私授权同意，且仅上传脱敏后必要字段。
  }

  static info(msg: string): void {
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', msg);
    } catch (e) {
    }
  }

  static warn(msg: string): void {
    try {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', msg);
    } catch (e) {
    }
  }

  static errorRaw(msg: string): void {
    try {
      hilog.error(LOG_DOMAIN, LOG_TAG, '%{public}s', msg);
    } catch (e) {
    }
  }

  static startTrace(traceName: string): number {
    const start: number = Date.now();
    PerformanceMonitor.info('trace start: ' + traceName);
    return start;
  }

  static endTrace(traceName: string, start: number): void {
    const duration: number = Date.now() - start;
    PerformanceMonitor.writeStatistic('perf_trace', {
      'trace_name': traceName, 'duration_ms': duration
    });
    PerformanceMonitor.info('trace end: ' + traceName + ' ' + duration + 'ms');
  }
}
