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
  private swiperController: SwiperController = new SwiperController();

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
    Column() {
      Swiper(this.swiperController) {
        HomePage({ controller: this.homeController })
        MistakesPage({ controller: this.mistakesController })
        ReportPage({ controller: this.reportController })
        ProfilePage({ controller: this.profileController })
      }
      .loop(false)
      .indicator(false)
      .effectMode(EdgeEffect.Spring)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        if (this.currentTab !== index) {
          this.currentTab = index;
          this.reloadTab(index);
        }
      })

      Row() {
        this.TabBarItem(0, 'home', AppStrings.TAB_HOME)
        this.TabBarItem(1, 'book', AppStrings.TAB_MISTAKES)
        this.TabBarItem(2, 'chart', AppStrings.TAB_REPORT)
        this.TabBarItem(3, 'user', AppStrings.TAB_PROFILE)
      }
      .width('100%')
      .height(60)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  TabIcon(kind: string, color: Resource) {
    Stack() {
      if (kind === 'home') {
        Polygon()
          .points([[2, 9], [12, 0], [22, 9]])
          .fill(color)
          .width(20)
          .height(9)
          .position({ x: 2, y: 2 })
        Rect()
          .fill(color)
          .width(13)
          .height(10)
          .position({ x: 5.5, y: 11 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(4)
          .height(6)
          .position({ x: 10, y: 15 })
      } else if (kind === 'book') {
        Rect()
          .fill(color)
          .width(16)
          .height(19)
          .radius(2.5)
          .position({ x: 4, y: 2 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(1.5)
          .height(15)
          .position({ x: 11.25, y: 4 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(6.5)
          .height(1.4)
          .position({ x: 5.5, y: 7 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(6.5)
          .height(1.4)
          .position({ x: 12, y: 7 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(6.5)
          .height(1.4)
          .position({ x: 5.5, y: 11 })
        Rect()
          .fill(AppColors.BG_PAGE)
          .width(6.5)
          .height(1.4)
          .position({ x: 12, y: 11 })
      } else if (kind === 'chart') {
        Rect()
          .fill(color)
          .width(4)
          .height(8)
          .position({ x: 4, y: 13 })
        Rect()
          .fill(color)
          .width(4)
          .height(15)
          .position({ x: 10, y: 6 })
        Rect()
          .fill(color)
          .width(4)
          .height(11)
          .position({ x: 16, y: 10 })
      } else {
        Circle({ width: 8.5, height: 8.5 })
          .fill(color)
          .position({ x: 7.75, y: 2 })
        Rect()
          .fill(color)
          .width(14)
          .height(9)
          .radiusWidth(7)
          .radiusHeight(7)
          .position({ x: 5, y: 13.5 })
      }
    }
    .width(24)
    .height(24)
  }

  @Builder
  TabBarItem(index: number, kind: string, label: string) {
    Column() {
      this.TabIcon(kind, this.currentTab === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .height(60)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.currentTab !== index) {
        this.currentTab = index;
        this.reloadTab(index);
      }
      this.swiperController.changeIndex(index, true);
    })
  }
}
