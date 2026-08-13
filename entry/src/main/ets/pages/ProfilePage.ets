import { Student } from '../models/Student';
import { Grade, TextbookVersion } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { PointsSummary } from '../models/PointsLog';

@Component
export struct ProfilePage {
  @State student: Student = new Student();
  @State pointsSummary: PointsSummary = new PointsSummary();
  @State isLoaded: boolean = false;

  aboutToAppear(): void {
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
          this.MenuItem('⏰ 复习提醒设置', () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderSettingPage' });
          })
          this.MenuItem('💰 ' + AppStrings.POINTS_CENTER, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PointsCenterPage' });
          })
          this.MenuItem('🔄 导出与导入', () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/DataManagementPage' });
          })
          this.MenuItem('👨‍👩‍👧 ' + AppStrings.PARENT_CENTER, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/OpsOverviewPage' });
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
  }

  @Builder
  UserInfoCard() {
    Row() {
      Column() {
        Text(this.student.nickname)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(`年级: ${this.student.grade} · 教材: ${this.student.textbookVersion === TextbookVersion.PEP ? '人教版' : '其他'}`)
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text(`${this.pointsSummary.totalPoints}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.WARNING)
        Text('积分')
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 8 })
  }

  @Builder
  MenuItem(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      Text('>')
        .fontSize(16)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(action)
  }
}
