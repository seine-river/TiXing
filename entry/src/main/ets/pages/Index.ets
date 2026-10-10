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

/**
 * Dock 导航项（独立组件 + @Prop active 驱动）：
 * @Builder 按值传参不会随状态刷新，颜色/药丸底必须在组件内部响应 active。
 */
@Component
struct DockTabItem {
  @Prop active: boolean = false;
  @Prop kind: string = '';
  @Prop label: string = '';
  onTabClick: () => void = (): void => {
  };

  private iconColor(): Resource {
    return this.active ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY;
  }

  build() {
    Column() {
      Stack() {
        if (this.active) {
          // 选中态药丸底
          Column() {
          }
          .width(44)
          .height(30)
          .backgroundColor(AppColors.SOFT_PRIMARY)
          .borderRadius(15)
        }
        this.TabIconShape()
        if (this.active) {
          Circle({ width: 4, height: 4 })
            .fill(AppColors.PRIMARY)
            .position({ x: 10, y: 26 })
        }
      }
      .width(24)
      .height(30)

      Text(this.label)
        .fontSize(10.5)
        .fontWeight(this.active ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.active ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        .margin({ top: 1 })
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(this.label + (this.active ? '，已选中' : ''))
    .onClick(() => {
      this.onTabClick();
    })
  }

  @Builder
  TabIconShape() {
    Stack() {
      if (this.kind === 'home') {
        // 圆角小屋：屋顶/房身/门均以 x=12 居中对齐
        Polygon()
          .points([[3, 10], [12, 1.5], [21, 10]])
          .fill(this.iconColor())
          .width(24)
          .height(24)
        Rect()
          .fill(this.iconColor())
          .width(13)
          .height(11)
          .radius(3)
          .position({ x: 5.5, y: 9.5 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(4.5)
          .height(6.5)
          .radius(1.5)
          .position({ x: 9.75, y: 14 })
      } else if (this.kind === 'book') {
        // 错题本：双页书本
        Rect()
          .fill(this.iconColor())
          .width(20)
          .height(16)
          .radius(3)
          .position({ x: 2, y: 4 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(1.6)
          .height(14)
          .position({ x: 11.2, y: 5 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(6)
          .height(1.5)
          .radius(0.75)
          .position({ x: 4.5, y: 8 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(6)
          .height(1.5)
          .radius(0.75)
          .position({ x: 13, y: 8 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(6)
          .height(1.5)
          .radius(0.75)
          .position({ x: 4.5, y: 12 })
        Rect()
          .fill(AppColors.BG_CARD)
          .width(6)
          .height(1.5)
          .radius(0.75)
          .position({ x: 13, y: 12 })
      } else if (this.kind === 'chart') {
        // 圆角柱状图
        Rect()
          .fill(this.iconColor())
          .width(4.5)
          .height(9)
          .radius(2)
          .position({ x: 3.5, y: 12 })
        Rect()
          .fill(this.iconColor())
          .width(4.5)
          .height(15)
          .radius(2)
          .position({ x: 9.8, y: 6 })
        Rect()
          .fill(this.iconColor())
          .width(4.5)
          .height(12)
          .radius(2)
          .position({ x: 16, y: 9 })
      } else {
        // 用户
        Circle({ width: 8.5, height: 8.5 })
          .fill(this.iconColor())
          .position({ x: 7.75, y: 2.5 })
        Rect()
          .fill(this.iconColor())
          .width(15)
          .height(9.5)
          .radiusWidth(7.5)
          .radiusHeight(7.5)
          .position({ x: 4.5, y: 13 })
      }
    }
    .width(24)
    .height(24)
  }
}

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

  private selectTab(index: number): void {
    if (this.currentTab !== index) {
      this.currentTab = index;
      this.reloadTab(index);
    }
    this.swiperController.changeIndex(index, true);
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

      // 悬浮 Dock：两侧导航 + 中央渐变录入 FAB
      Row() {
        DockTabItem({
          active: this.currentTab === 0, kind: 'home', label: AppStrings.TAB_HOME,
          onTabClick: (): void => {
            this.selectTab(0);
          }
        })
        DockTabItem({
          active: this.currentTab === 1, kind: 'book', label: AppStrings.TAB_MISTAKES,
          onTabClick: (): void => {
            this.selectTab(1);
          }
        })
        this.CaptureFab()
        DockTabItem({
          active: this.currentTab === 2, kind: 'chart', label: AppStrings.TAB_REPORT,
          onTabClick: (): void => {
            this.selectTab(2);
          }
        })
        DockTabItem({
          active: this.currentTab === 3, kind: 'user', label: AppStrings.TAB_PROFILE,
          onTabClick: (): void => {
            this.selectTab(3);
          }
        })
      }
      .width('100%')
      .height(64)
      .padding({ left: 6, right: 6 })
      .backgroundColor(AppColors.BG_CARD)
      .shadow({ radius: 20, color: AppColors.SHADOW_CARD, offsetY: -4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  /** 中央 AI 录入 FAB：几何绘制十字保证精确居中，整圆在 Dock 内垂直居中。 */
  @Builder
  CaptureFab() {
    Stack() {
      // 横竖圆角矩形拼出「＋」，不受字体基线影响
      Rect()
        .fill(Color.White)
        .width(22)
        .height(3.5)
        .radius(1.75)
      Rect()
        .fill(Color.White)
        .width(3.5)
        .height(22)
        .radius(1.75)
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .linearGradient({
      angle: 135,
      colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
    })
    .shadow({ radius: 12, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
    .accessibilityText('AI 录入错题')
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CapturePage' });
    })
  }
}
