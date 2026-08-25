import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { ReminderSettings } from '../models/ReminderSettings';
import { ReminderService } from '../services/ReminderService';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';

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
  @State saving: boolean = false;
  @State statusMsg: string = '';
  @State statusOk: boolean = false;
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
    Column() {
      PageHeader({ title: AppStrings.PAGE_REMINDER })
      Scroll() {
        Column() {
          Column() {
            Row() {
              Text('开启复习提醒')
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
                .onChange((isOn: boolean) => {
                  this.notificationEnabled = isOn;
                })
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
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.PRIMARY)
            }
            .width('100%')
            .height(AppSizes.TOUCH_TARGET)
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              this.editTime(true);
            })
            Row() {
              Text('结束时间')
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1)
              Text(this.reviewTimeEnd)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.PRIMARY)
            }
            .width('100%')
            .height(AppSizes.TOUCH_TARGET)
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              this.editTime(false);
            })
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
                .backgroundColor(AppColors.CHIP_BG).fontColor(AppColors.TEXT_PRIMARY)
                .onClick(() => {
                  if (this.dailyLimit > 3) {
                    this.dailyLimit -= 1;
                  }
                })
              Text(`${this.dailyLimit}`)
                .fontSize(24).fontWeight(FontWeight.Bold)
                .fontColor(AppColors.PRIMARY).width(60).textAlign(TextAlign.Center)
              Button('+')
                .width(40).height(40).fontSize(20).borderRadius(20)
                .backgroundColor(AppColors.CHIP_BG).fontColor(AppColors.TEXT_PRIMARY)
                .onClick(() => {
                  if (this.dailyLimit < 20) {
                    this.dailyLimit += 1;
                  }
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
            this.SubjectToggle('数学', this.mathEnabled, (v: boolean) => {
              this.mathEnabled = v;
            })
            this.SubjectToggle('语文', this.chineseEnabled, (v: boolean) => {
              this.chineseEnabled = v;
            })
            this.SubjectToggle('英语', this.englishEnabled, (v: boolean) => {
              this.englishEnabled = v;
            })
            this.SubjectToggle('科学', this.scienceEnabled, (v: boolean) => {
              this.scienceEnabled = v;
            })
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
                .onChange((isOn: boolean) => {
                  this.doNotDisturb = isOn;
                })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .margin({ left: 16, right: 16, top: 8 })

          if (this.statusMsg.length > 0) {
            Text(this.statusMsg)
              .fontSize(13)
              .fontColor(this.statusOk ? AppColors.SECONDARY : AppColors.DANGER)
              .margin({ top: 12 })
          }

          Button(this.saving ? '保存中...' : '保存设置')
            .width('90%')
            .height(44)
            .backgroundColor(AppColors.PRIMARY)
            .fontColor(Color.White)
            .borderRadius(22)
            .margin({ top: 24, bottom: 32 })
            .enabled(!this.saving)
            .onClick(() => {
              this.saveSettings();
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  /**
   * 时间段编辑（T023/FR-011）：点击弹 TimePicker，修改后保存生效。
   */
  private editTime(isStart: boolean): void {
    const current: string = isStart ? this.reviewTimeStart : this.reviewTimeEnd;
    this.getUIContext().showTimePickerDialog({
      selected: this.timeToDate(current),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const text: string = `${value.hour < 10 ? '0' + value.hour : value.hour}:${value.minute < 10 ? '0' + value.minute : value.minute}`;
        if (isStart) {
          this.reviewTimeStart = text;
        } else {
          this.reviewTimeEnd = text;
        }
      }
    });
  }

  private timeToDate(hhmm: string): Date {
    const parts: string[] = hhmm.split(':');
    const d = new Date();
    d.setHours(parts.length >= 1 ? this.parseIntSafe(parts[0], 8) : 8, parts.length >= 2 ? this.parseIntSafe(parts[1], 0) : 0, 0, 0);
    return d;
  }

  private parseIntSafe(s: string, fallback: number): number {
    const v: number = parseInt(s, 10);
    if (isNaN(v)) {
      return fallback;
    }
    return v;
  }

  @Builder
  SubjectToggle(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((v: boolean) => {
          onChange(v);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  /**
   * 保存（T023/FR-009）：先运行时权限申请，再按真实发布结果提示。
   */
  private async saveSettings(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
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

    const saveRes: DbResult = await dbHelper.saveReminderSettings(s);
    if (!saveRes.success) {
      this.saving = false;
      this.statusOk = false;
      this.statusMsg = '❌ 设置保存失败，请重试';
      Toast.show('设置保存失败，请重试');
      return;
    }

    if (!this.notificationEnabled || this.doNotDisturb) {
      const cancelRes: DbResult = await ReminderService.syncAndApply(s);
      this.saving = false;
      if (cancelRes.success) {
        this.statusOk = true;
        this.statusMsg = '✅ 设置已保存，提醒已关闭';
        Toast.show('设置已保存');
      } else {
        this.statusOk = false;
        this.statusMsg = '❌ ' + cancelRes.reason;
        Toast.show('旧提醒清理失败，请重试');
      }
      return;
    }

    const ctx = this.getUIContext().getHostContext() as Context;
    const granted: boolean = await ReminderService.ensurePermission(ctx);
    if (!granted) {
      this.saving = false;
      this.statusOk = false;
      this.statusMsg = '⚠️ 未获得通知权限，提醒不会生效；请在系统设置中开启后重试';
      Toast.show('未获得通知权限，提醒不会生效');
      return;
    }
    const applyRes: DbResult = await ReminderService.syncAndApply(s);
    this.saving = false;
    if (applyRes.success) {
      this.statusOk = true;
      this.statusMsg = '✅ 设置已保存，提醒已生效';
      Toast.show('提醒设置已保存并生效');
    } else {
      this.statusOk = false;
      this.statusMsg = '❌ ' + applyRes.reason;
      Toast.show('提醒发布失败，请重试');
    }
  }
}
