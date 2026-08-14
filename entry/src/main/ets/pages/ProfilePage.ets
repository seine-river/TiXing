import { Student } from '../models/Student';
import { Grade, TextbookVersion } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { TabController } from '../common/TabController';
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
        .shadow({ radius: 8, color: '#101F2E26', offsetY: 2 })
      }
      .width('100%')
      .padding({ top: 12, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  UserInfoCard() {
    Row() {
      Column() {
        Text(this.student.nickname)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(`年级: ${this.student.grade} · 教材: ${this.student.textbookVersion === TextbookVersion.PEP ? '人教版' : '其他'}`)
          .fontSize(13)
          .fontColor('#E8F1FF')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Row() {
          Text('⭐')
            .fontSize(14)
          Text(`${this.pointsSummary.totalPoints}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ left: 4 })
        }
        Text('积分')
          .fontSize(12)
          .fontColor('#DCEBFF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#331A2A4D')
      .borderRadius(14)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 26, bottom: 26 })
    .linearGradient({
      angle: 135,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
    })
    .margin({ left: 16, right: 16 })
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
