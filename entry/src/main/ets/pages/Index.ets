import { HomePage } from './HomePage';
import { MistakesPage } from './MistakesPage';
import { ReportPage } from './ReportPage';
import { ProfilePage } from './ProfilePage';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppStrings } from '../common/Constants';
import { AppContextHolder } from '../common/AppContext';
import { TabController } from '../common/TabController';
import { Toast } from '../common/Toast';
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
    Toast.setContext(this.getUIContext());
    if (!this.dbInitialized) {
      const ctx = this.getUIContext().getHostContext() as Context;
      AppContextHolder.set(ctx);
      dbHelper.init(ctx).then(() => {
        this.applyReminder();
      });
      this.dbInitialized = true;
    }
  }

  onPageShow(): void {
    this.reloadTab(this.currentTab);
  }

  private async applyReminder(): Promise<void> {
    const s: ReminderSettings = await dbHelper.queryReminderSettings('stu_default');
    await ReminderService.applySettings(s);
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
