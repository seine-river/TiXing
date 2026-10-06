import { Student } from '../models/Student';
import { Grade, TextbookVersion } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { TabController } from '../common/TabController';
import { GradientHeader } from '../components/GradientHeader';
import { PointsSummary } from '../models/PointsLog';

@Component
export struct ProfilePage {
  controller: TabController = new TabController();
  @State student: Student = new Student();
  @State pointsSummary: PointsSummary = new PointsSummary();
  @State isLoaded: boolean = false;

  aboutToAppear(): void {
    this.controller.reload = (): void => { this.loadData(); };
    this.loadData();
  }

  async loadData(): Promise<void> {
    const s = await dbHelper.queryStudent('stu_default');
    if (s !== undefined) {
      this.student = s;
    } else {
      this.student.id = 'stu_default';
      this.student.nickname = '同学';
      this.student.grade = Grade.G3;
      this.student.textbookVersion = TextbookVersion.PEP;
      this.student.createdAt = Date.now();
      await dbHelper.insertStudent(this.student);
    }
    this.pointsSummary = await dbHelper.queryPointsSummary(this.student.id);
    this.isLoaded = true;
  }

  build() {
    Scroll() {
      Column() {
        this.UserInfoCard()

        Column() {
          this.MenuItem('📚 ' + AppStrings.LEARNING_PROFILE, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/ProfileSettingPage' });
          })
          this.MenuDivider()
          this.MenuItem('⏰ 复习提醒设置', () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderSettingPage' });
          })
          this.MenuDivider()
          this.MenuItem('💰 ' + AppStrings.POINTS_CENTER, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PointsCenterPage' });
          })
          this.MenuDivider()
          this.MenuItem('🔄 导出与导入', () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/DataManagementPage' });
          })
          this.MenuDivider()
          this.MenuItem('👨‍👩‍👧 ' + AppStrings.PARENT_CENTER, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/OpsOverviewPage' });
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 14 })
        .shadow({ radius: 8, color: AppColors.SHADOW_SOFT, offsetY: 2 })
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  UserInfoCard() {
    GradientHeader({
      title: this.student.nickname,
      subtitle: `年级: ${this.student.grade} · 教材: ${this.student.textbookVersion === TextbookVersion.PEP ? '人教版' : '其他'}`,
      badgeText: `⭐ ${this.pointsSummary.totalPoints}`
    }) {
      Row() {
        Text('积分')
          .fontSize(13)
          .fontColor(AppColors.HERO_TEXT)
          .accessibilityText(`当前积分 ${this.pointsSummary.totalPoints}`)
      }
      .width('100%')
      .margin({ top: 14 })
    }
  }

  @Builder
  MenuDivider() {
    Divider()
      .color(AppColors.DIVIDER)
      .strokeWidth(1)
      .margin({ left: 4 })
  }

  @Builder
  MenuItem(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 16, bottom: 16 })
    .onClick(action)
  }
}
