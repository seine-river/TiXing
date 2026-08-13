import { dbHelper } from '../repository/DatabaseHelper';
import { ReminderSettings } from '../models/ReminderSettings';
import { ReminderService } from '../services/ReminderService';
import { AppColors, AppSizes } from '../common/Constants';

@Entry
@Component
struct ReminderSettingPage {
  @State reviewTimeStart: string = '08:00';
  @State reviewTimeEnd: string = '21:00';
  @State dailyLimit: number = 10;
  @State mathEnabled: boolean = true;
  @State chineseEnabled: boolean = true;
  @State englishEnabled: boolean = false;
  @State scienceEnabled: boolean = false;
  @State doNotDisturb: boolean = false;
  @State notificationEnabled: boolean = true;
  @State saved: boolean = false;
  private studentId: string = 'stu_default';

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    const s: ReminderSettings = await dbHelper.queryReminderSettings(this.studentId);
    this.reviewTimeStart = s.reviewTimeStart;
    this.reviewTimeEnd = s.reviewTimeEnd;
    this.dailyLimit = s.dailyLimit;
    this.mathEnabled = s.mathEnabled;
    this.chineseEnabled = s.chineseEnabled;
    this.englishEnabled = s.englishEnabled;
    this.scienceEnabled = s.scienceEnabled;
    this.doNotDisturb = s.doNotDisturb;
    this.notificationEnabled = s.notificationEnabled;
  }

  build() {
    Scroll() {
      Column() {
        Text('复习提醒设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })

        Column() {
          Row() {
            Text('开启复习提醒')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
              .onChange((isOn: boolean) => { this.notificationEnabled = isOn; })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('复习时间段')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            Text('开始时间')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Text(this.reviewTimeStart)
              .fontSize(15)
              .fontColor(AppColors.PRIMARY)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          Row() {
            Text('结束时间')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Text(this.reviewTimeEnd)
              .fontSize(15)
              .fontColor(AppColors.PRIMARY)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          Text('每日提醒将在开始时间推送（点击时间可修改）')
            .fontSize(12)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('每日复习题量上限')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            Button('-')
              .width(40).height(40).fontSize(20).borderRadius(20)
              .backgroundColor('#E8EAED').fontColor(AppColors.TEXT_PRIMARY)
              .onClick(() => {
                if (this.dailyLimit > 3) { this.dailyLimit -= 1; }
              })
            Text(`${this.dailyLimit}`)
              .fontSize(24).fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY).width(60).textAlign(TextAlign.Center)
            Button('+')
              .width(40).height(40).fontSize(20).borderRadius(20)
              .backgroundColor('#E8EAED').fontColor(AppColors.TEXT_PRIMARY)
              .onClick(() => {
                if (this.dailyLimit < 20) { this.dailyLimit += 1; }
              })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('学科开关')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          this.SubjectToggle('数学', this.mathEnabled, (v: boolean) => { this.mathEnabled = v; })
          this.SubjectToggle('语文', this.chineseEnabled, (v: boolean) => { this.chineseEnabled = v; })
          this.SubjectToggle('英语', this.englishEnabled, (v: boolean) => { this.englishEnabled = v; })
          this.SubjectToggle('科学', this.scienceEnabled, (v: boolean) => { this.scienceEnabled = v; })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Row() {
            Text('免打扰模式')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.doNotDisturb })
              .onChange((isOn: boolean) => { this.doNotDisturb = isOn; })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        if (this.saved) {
          Text('✅ 设置已保存')
            .fontSize(13)
            .fontColor(AppColors.SECONDARY)
            .margin({ top: 12 })
        }

        Button('保存设置')
          .width('90%')
          .height(44)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 32 })
          .onClick(() => {
            this.saveSettings();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
  }

  @Builder
  SubjectToggle(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((v: boolean) => { onChange(v); })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  private async saveSettings(): Promise<void> {
    const s = ReminderSettings.create(this.studentId);
    s.reviewTimeStart = this.reviewTimeStart;
    s.reviewTimeEnd = this.reviewTimeEnd;
    s.dailyLimit = this.dailyLimit;
    s.mathEnabled = this.mathEnabled;
    s.chineseEnabled = this.chineseEnabled;
    s.englishEnabled = this.englishEnabled;
    s.scienceEnabled = this.scienceEnabled;
    s.doNotDisturb = this.doNotDisturb;
    s.notificationEnabled = this.notificationEnabled;
    await dbHelper.saveReminderSettings(s);
    await ReminderService.applySettings(s);
    this.saved = true;
  }
}
