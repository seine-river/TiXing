import { AppColors } from '../common/Constants';
import { SystemBarHelper } from '../common/SystemBarHelper';

/**
 * 渐变头图（T044/FR-023）：渐变背景 + 状态栏避让高度内聚（SystemBarHelper 静态缓存）。
 * 经 trailing closure 注入主体内容；badge 显示右上角徽标文本。
 */
@Component
export struct GradientHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop badgeText: string = '';
  @State statusBarHeight: number = 38;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  aboutToAppear(): void {
    SystemBarHelper.statusBarHeightVp(this.getUIContext()).then((h: number) => {
      this.statusBarHeight = h;
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Column() {
            Text(this.title)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .accessibilityText(this.title)
            if (this.subtitle.length > 0) {
              Text(this.subtitle)
                .fontSize(13)
                .fontColor(AppColors.HERO_TEXT)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        this.content()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.statusBarHeight + 20, bottom: 24 })

      if (this.badgeText.length > 0) {
        Text(this.badgeText)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor(AppColors.BADGE_BG)
          .margin({ top: this.statusBarHeight + 10, right: 14 })
          .accessibilityText(this.badgeText)
      }
    }
    .width('100%')
    .linearGradient({
      angle: 135,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
    })
  }
}
