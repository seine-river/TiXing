import { AppColors } from '../common/Constants';
import { SystemBarHelper } from '../common/SystemBarHelper';

/**
 * 渐变头图：晨光紫渐变 + 装饰圆 + 圆角底边；
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
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .accessibilityText(this.title)
            if (this.subtitle.length > 0) {
              Text(this.subtitle)
                .fontSize(13)
                .fontColor(AppColors.HERO_TEXT_DIM)
                .margin({ top: 5 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        this.content()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.statusBarHeight + 22, bottom: 26 })
      .zIndex(1)

      // 装饰光斑（不遮挡内容）
      Circle({ width: 190, height: 190 })
        .fill('#22FFFFFF')
        .position({ x: -60, y: this.statusBarHeight - 60 })
      Circle({ width: 120, height: 120 })
        .fill('#14FFFFFF')
        .position({ x: 250, y: this.statusBarHeight + 90 })
      Circle({ width: 52, height: 52 })
        .fill('#2EFFFFFF')
        .position({ x: 40, y: this.statusBarHeight + 130 })

      // 趣味贴纸（与装饰光斑呼应）
      Text('⭐')
        .fontSize(18)
        .position({ x: 296, y: this.statusBarHeight + 26 })
        .rotate({ angle: 15 })
      Text('✨')
        .fontSize(14)
        .position({ x: 36, y: this.statusBarHeight + 4 })
      Text('📚')
        .fontSize(15)
        .position({ x: 250, y: this.statusBarHeight + 150 })
        .rotate({ angle: -12 })

      if (this.badgeText.length > 0) {
        Text(this.badgeText)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(18)
          .backgroundColor(AppColors.BADGE_BG)
          .margin({ top: this.statusBarHeight + 12, right: 14 })
          .accessibilityText(this.badgeText)
          .zIndex(2)
      }
    }
    .width('100%')
    .borderRadius({ bottomLeft: 24, bottomRight: 24 })
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
    })
  }
}
