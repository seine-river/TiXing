import { bundleManager } from '@kit.AbilityKit';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct AboutPage {
  @State versionName: string = '1.0.3';

  aboutToAppear(): void {
    this.loadBundleInfo();
  }

  private async loadBundleInfo(): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionName = info.versionName;
    } catch (e) {
      // 保持与 AppScope/app.json5 一致的兜底信息，避免系统信息读取失败时页面空白。
    }
  }

  build() {
    Column() {
      PageHeader({ title: AppStrings.PAGE_ABOUT })
      Scroll() {
        Column() {
          Column({ space: 14 }) {
            Image($r('app.media.foreground'))
              .width(76)
              .height(76)
              .borderRadius(22)
              .objectFit(ImageFit.Contain)
            Text(AppStrings.APP_NAME)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text(`智能错题记录与科学复习工具`)
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
            Text(`v${this.versionName}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY)
              .backgroundColor(AppColors.SOFT_PRIMARY)
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 5, bottom: 5 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 18, bottom: 22 })
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_LG)
          .margin({ left: 16, right: 16, top: 8 })
          .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })

          Column() {
            Text('应用信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 4 })
            this.InfoRow('应用名称', AppStrings.APP_NAME)
            this.InfoRow('当前版本', this.versionName)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12 })

          Column() {
            Text('题醒是什么')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })
            Text('题醒是一款面向小学生家庭的智能错题本。孩子拍照录入错题后，AI 会识别题目、学生答案和知识点；系统按遗忘曲线安排复习，并把错题讲解变成更容易理解的动画课程。')
              .fontSize(13)
              .lineHeight(21)
              .fontColor(AppColors.TEXT_REGULAR)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12 })

          Column() {
            Text('主要能力')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })
            this.FeatureRow('📸', 'AI 拍照识别', '自动拆分多道题，并识别学生作答')
            this.FeatureRow('🔁', '科学复习', '按遗忘曲线安排每日复习任务')
            this.FeatureRow('🎬', '动画讲解', '把错题原因和正确解法变成动态课程')
            this.FeatureRow('📊', '家长看板', '查看掌握情况、复习表现和本地统计')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12, bottom: 24 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        Text(value)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .textAlign(TextAlign.End)
          .constraintSize({ minWidth: 88 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      Divider()
        .color(AppColors.DIVIDER)
        .strokeWidth(1)
    }
  }

  @Builder
  FeatureRow(icon: string, title: string, description: string) {
    Row({ space: 10 }) {
      Text(icon)
        .fontSize(17)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColors.SOFT_INFO)
        .borderRadius(12)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(description)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }
}
