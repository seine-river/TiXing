import { HomePage } from './HomePage';
import { MistakesPage } from './MistakesPage';
import { ReportPage } from './ReportPage';
import { ProfilePage } from './ProfilePage';
import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { AppColors, AppStrings } from '../common/Constants';
import { AppContextHolder } from '../common/AppContext';
import { TabController } from '../common/TabController';
import { Toast } from '../common/Toast';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { MediaService } from '../services/MediaService';
import { AiConfig } from '../common/AiConfig';
import { ReminderService } from '../services/ReminderService';
import { ReminderSettings } from '../models/ReminderSettings';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State dbInitialized: boolean = false;
  private homeController: TabController = new TabController();
  private mistakesController: TabController = new TabController();
  private reportController: TabController = new TabController();
  private profileController: TabController = new TabController();

  aboutToAppear(): void {
    if (!this.dbInitialized) {
      const ctx = this.getUIContext().getHostContext() as Context;
      AppContextHolder.set(ctx);
      this.dbInitialized = true;
      this.bootstrapApp(ctx);
    }
  }

  /**
   * 冷启动引导（T016/D3）：等待数据库就绪后再触发各 Tab 首次加载；
   * init 失败给出用户可见提示与致命日志；顺带加载本地 AI 配置与应用提醒。
   */
  private async bootstrapApp(ctx: Context): Promise<void> {
    AiConfig.load().catch((_e: Object): void => {
      PerformanceMonitor.warn('ai config load failed');
    });
    MediaService.cleanupTemp().catch((_e: Object): void => {
      PerformanceMonitor.warn('cleanup temp files failed');
    });
    const initResult: DbResult = await dbHelper.init(ctx);
    if (!initResult.success) {
      PerformanceMonitor.errorRaw('db init failed: ' + initResult.reason);
      Toast.show('数据库初始化失败，数据可能暂时不可用，请重启应用');
    }
    // 就绪（或失败提示）后再触发当前 Tab 数据加载，避免首屏空数据假象
    await this.applyReminder();
    this.reloadTab(this.currentTab);
  }

  onPageShow(): void {
    this.reloadTab(this.currentTab);
  }

  private async applyReminder(): Promise<void> {
    try {
      const s: ReminderSettings = await dbHelper.queryReminderSettings('stu_default');
      const result: DbResult = await ReminderService.syncAndApply(s);
      if (!result.success) {
        PerformanceMonitor.warn('startup reminder sync failed: ' + result.reason);
      }
    } catch (e) {
      PerformanceMonitor.warn('apply reminder failed on startup');
    }
  }

  private reloadTab(index: number): void {
    if (index === 0) {
      this.homeController.reload();
    } else if (index === 1) {
      this.mistakesController.reload();
    } else if (index === 2) {
      this.reportController.reload();
    } else if (index === 3) {
      this.profileController.reload();
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        HomePage({ controller: this.homeController })
      }
      .tabBar(this.TabBuilder(0, '🏠', AppStrings.TAB_HOME))

      TabContent() {
        MistakesPage({ controller: this.mistakesController })
      }
      .tabBar(this.TabBuilder(1, '📒', AppStrings.TAB_MISTAKES))

      TabContent() {
        ReportPage({ controller: this.reportController })
      }
      .tabBar(this.TabBuilder(2, '📊', AppStrings.TAB_REPORT))

      TabContent() {
        ProfilePage({ controller: this.profileController })
      }
      .tabBar(this.TabBuilder(3, '👤', AppStrings.TAB_PROFILE))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .barHeight(60)
    .onChange((index: number) => {
      this.currentTab = index;
      this.reloadTab(index);
    })
  }

  @Builder
  TabBuilder(index: number, icon: string, label: string) {
    Column() {
      Text(icon)
        .fontSize(22)
        .opacity(this.currentTab === index ? 1 : 0.5)
      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        .margin({ top: 3 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
