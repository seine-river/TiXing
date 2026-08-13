import { Student } from '../models/Student';
import { Grade, TextbookVersion } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct ProfileSettingPage {
  @State student: Student = new Student();
  @State selectedGradeIndex: number = 0;
  @State selectedVersionIndex: number = 0;
  @State communityBrowseEnabled: boolean = false;
  @State communityShareEnabled: boolean = false;

  private grades: string[] = ['三年级', '四年级', '五年级', '六年级'];
  private gradeValues: Grade[] = [Grade.G3, Grade.G4, Grade.G5, Grade.G6];
  private versions: string[] = ['人教版', '北师大版', '苏教版', '其他'];
  private versionValues: TextbookVersion[] = [TextbookVersion.PEP, TextbookVersion.BJ, TextbookVersion.SU, TextbookVersion.OTHER];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const s = await dbHelper.queryStudent('stu_default');
    if (s !== undefined) {
      this.student = s;
      this.communityBrowseEnabled = s.communityBrowseEnabled;
      this.communityShareEnabled = s.communityShareEnabled;
      const gIdx = this.gradeValues.indexOf(s.grade);
      this.selectedGradeIndex = gIdx >= 0 ? gIdx : 0;
      const vIdx = this.versionValues.indexOf(s.textbookVersion);
      this.selectedVersionIndex = vIdx >= 0 ? vIdx : 0;
    }
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({ title: AppStrings.LEARNING_PROFILE })

        Column() {
          Text('昵称')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 4 })
          TextInput({ text: this.student.nickname, placeholder: '输入昵称' })
            .fontSize(16)
            .onChange((value: string) => {
              this.student.nickname = value;
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('年级')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            ForEach(this.grades, (label: string, idx: number) => {
              Button(label)
                .height(36)
                .fontSize(14)
                .borderRadius(18)
                .backgroundColor(this.selectedGradeIndex === idx ? AppColors.PRIMARY : '#E8EAED')
                .fontColor(this.selectedGradeIndex === idx ? Color.White : AppColors.TEXT_REGULAR)
                .layoutWeight(1)
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.selectedGradeIndex = idx;
                  this.student.grade = this.gradeValues[idx];
                })
            }, (label: string, idx: number) => `${idx}`)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('教材版本')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            ForEach(this.versions, (label: string, idx: number) => {
              Button(label)
                .height(36)
                .fontSize(14)
                .borderRadius(18)
                .backgroundColor(this.selectedVersionIndex === idx ? AppColors.PRIMARY : '#E8EAED')
                .fontColor(this.selectedVersionIndex === idx ? Color.White : AppColors.TEXT_REGULAR)
                .layoutWeight(1)
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.selectedVersionIndex = idx;
                  this.student.textbookVersion = this.versionValues[idx];
                })
            }, (label: string, idx: number) => `${idx}`)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('社区权限')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            Text('浏览社区')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.communityBrowseEnabled })
              .onChange((isOn: boolean) => {
                this.communityBrowseEnabled = isOn;
                this.student.communityBrowseEnabled = isOn;
              })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          Row() {
            Text('分享到社区')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.communityShareEnabled })
              .onChange((isOn: boolean) => {
                this.communityShareEnabled = isOn;
                this.student.communityShareEnabled = isOn;
              })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          Text('社区权限默认关闭，需家长主动开启')
            .fontSize(12)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Button('保存')
          .width('90%')
          .height(44)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 32 })
          .onClick(() => {
            this.saveProfile();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
  }

  private async saveProfile(): Promise<void> {
    this.student.communityBrowseEnabled = this.communityBrowseEnabled;
    this.student.communityShareEnabled = this.communityShareEnabled;
    try {
      await dbHelper.updateStudent(this.student);
      Toast.show('档案已保存');
      this.getUIContext().getRouter().back();
    } catch (e) {
      Toast.show('保存失败，请重试');
    }
  }
}
