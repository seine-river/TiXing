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
import { TelemetryConsentService, TelemetryConsentState } from '../services/telemetry/TelemetryConsentService';
import { TelemetryRouter } from '../services/telemetry/TelemetryRouter';

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
  @State showTelemetryConsent: boolean = false;
  // Swiper 会提前构建子节点；只挂载已访问 Tab，避免启动时执行错题本/报告/我的查询。
  @State loadedTabs: boolean[] = [true, false, false, false];
  private homeController: TabController = new TabController();
  private mistakesController: TabController = new TabController();
  private reportController: TabController = new TabController();
  private profileController: TabController = new TabController();
  private swiperController: SwiperController = new SwiperController();
  private skipNextPageShowReload: boolean = true;

  aboutToAppear(): void {
    if (!this.dbInitialized) {
      const ctx = this.getUIContext().getHostContext() as Context;
      AppContextHolder.set(ctx);
      this.dbInitialized = true;
      this.bootstrapApp(ctx);
      this.checkTelemetryConsent(ctx);
    }
  }

  /** 首次启动先说明匿名质量统计；用户选择前不激活第三方 SDK。 */
  private async checkTelemetryConsent(ctx: Context): Promise<void> {
    const state: TelemetryConsentState = await TelemetryConsentService.getConsent(ctx);
    this.showTelemetryConsent = state === TelemetryConsentState.UNKNOWN;
  }

  private async acceptTelemetry(ctx: Context, granted: boolean): Promise<void> {
    this.showTelemetryConsent = false;
    await TelemetryConsentService.setConsent(ctx,
      granted ? TelemetryConsentState.GRANTED : TelemetryConsentState.DENIED);
    if (granted) {
      await TelemetryRouter.activate(ctx);
    }
    PerformanceMonitor.writeBehavior('telemetry_consent', { 'granted': granted });
  }

  /**
   * 冷启动引导（T016/D3）：数据库 ready 后不再等待提醒系统；
   * 首页数据由 HomePage 自己等待 DB ready，提醒同步延迟到首帧之后。
   */
  private async bootstrapApp(ctx: Context): Promise<void> {
    const bootstrapTrace = PerformanceMonitor.startTrace('app_bootstrap');
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
    PerformanceMonitor.endTrace('app_bootstrap', bootstrapTrace);
    // 首页 aboutToAppear 已发起加载，awaitStore 会等待本次 init 完成。
    // 提醒/日历链路耗时可达数百毫秒，不能阻塞首页数据和首帧。
    setTimeout((): void => {
      this.applyReminder();
    }, 200);
  }

  onPageShow(): void {
    if (this.skipNextPageShowReload) {
      // 首次 onPageShow 与 Index aboutToAppear/Home aboutToAppear 重叠，避免首页重复查询。
      this.skipNextPageShowReload = false;
      return;
    }
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
      const firstMount: boolean = !this.loadedTabs[index];
      this.mountTab(index);
      this.currentTab = index;
      // 首次挂载的页面会在 aboutToAppear 中加载；已访问页面切换回来时刷新。
      if (!firstMount) {
        this.reloadTab(index);
      }
    }
    this.swiperController.changeIndex(index, true);
  }

  build() {
    Stack() {
      Column() {
      Swiper(this.swiperController) {
        Stack() {
          if (this.loadedTabs[0]) {
            HomePage({ controller: this.homeController })
          }
        }
        Stack() {
          if (this.loadedTabs[1]) {
            MistakesPage({ controller: this.mistakesController })
          }
        }
        Stack() {
          if (this.loadedTabs[2]) {
            ReportPage({ controller: this.reportController })
          }
        }
        Stack() {
          if (this.loadedTabs[3]) {
            ProfilePage({ controller: this.profileController })
          }
        }
      }
      .loop(false)
      .indicator(false)
      .effectMode(EdgeEffect.Spring)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        if (this.currentTab !== index) {
          const firstMount: boolean = !this.loadedTabs[index];
          this.mountTab(index);
          this.currentTab = index;
          if (!firstMount) {
            this.reloadTab(index);
          }
        }
      })

      // 悬浮 Dock：两侧导航 + 中央“问一问”语音 FAB；拍照录错题只保留在首页。
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
        this.VoiceAskFab()
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

      if (this.showTelemetryConsent) {
        this.TelemetryConsentSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  TelemetryConsentSheet() {
    Column({ space: 14 }) {
      Text('🛡️')
        .fontSize(38)
      Text('帮助题醒变得更稳定')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text('我们会匿名统计启动、页面、性能和崩溃信息。不会上传题目照片、语音内容、答案、姓名或联系方式。')
        .fontSize(13.5)
        .lineHeight(21)
        .textAlign(TextAlign.Center)
        .fontColor(AppColors.TEXT_SECONDARY)
      Button('同意并帮助改进')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(AppColors.SOLID_PRIMARY)
        .borderRadius(22)
        .width('100%')
        .onClick(() => {
          const ctx = this.getUIContext().getHostContext() as Context;
          this.acceptTelemetry(ctx, true);
        })
      Button('暂不')
        .height(38)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
        .backgroundColor(AppColors.SOFT_PRIMARY)
        .borderRadius(19)
        .width('100%')
        .onClick(() => {
          const ctx = this.getUIContext().getHostContext() as Context;
          this.acceptTelemetry(ctx, false);
        })
    }
    .width('82%')
    .padding(22)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(24)
    .shadow({ radius: 28, color: AppColors.SHADOW_CARD, offsetY: 8 })
  }

  private mountTab(index: number): void {
    if (index < 0 || index >= this.loadedTabs.length || this.loadedTabs[index]) {
      return;
    }
    const next: boolean[] = this.loadedTabs.slice(0);
    next[index] = true;
    this.loadedTabs = next;
  }

  /** 中央语音问答 FAB：麦克风图形精确居中，不再承担拍照录题入口。 */
  @Builder
  VoiceAskFab() {
    Stack() {
      Stack() {
        // 麦克风头、支架、底座都在 28x28 图形区内，避免图标上下偏移。
        Rect()
          .fill(Color.White)
          .width(14)
          .height(21)
          .radius(7)
          .position({ x: 7, y: 1.5 })
        Rect()
          .fill(Color.White)
          .width(3)
          .height(6)
          .position({ x: 12.5, y: 21 })
        Rect()
          .fill(Color.White)
          .width(12)
          .height(2.8)
          .radius(1.4)
          .position({ x: 8, y: 25.6 })
      }
      .width(28)
      .height(28)
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .linearGradient({
      angle: 135,
      colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
    })
    .shadow({ radius: 12, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
    .accessibilityText('问一问')
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/VoiceAskPage' });
    })
  }
}
