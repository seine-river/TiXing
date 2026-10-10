import { AppColors, AppSizes } from '../common/Constants';

/**
 * 基础组件库：FilterChip / PrimaryButton / AppCard / SectionCard / EmptyBlock。
 * 统一资源色，触摸目标 ≥44vp，含 accessibilityText。
 */
@Component
export struct FilterChip {
  @Prop text: string = '';
  @Prop selected: boolean = false;
  onTap: () => void = (): void => {
  };

  build() {
    Column() {
      Text(this.text)
        .fontSize(13)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? Color.White : AppColors.TEXT_REGULAR)
        .padding({ left: 14, right: 14 })
    }
    .constraintSize({ minHeight: AppSizes.TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selected ? AppColors.SOLID_PRIMARY : AppColors.CHIP_BG)
    .borderRadius(22)
    .shadow(this.selected ? { radius: 8, color: AppColors.SHADOW_PRIMARY, offsetY: 2 }
      : { radius: 0, color: Color.Transparent })
    .onClick(() => {
      this.onTap();
    })
    .accessibilityText(this.text + (this.selected ? '，已选中' : ''))
  }
}

@Component
export struct PrimaryButton {
  @Prop text: string = '';
  @Prop isEnabled: boolean = true;
  onTap: () => void = (): void => {
  };

  build() {
    if (this.isEnabled) {
      Button(this.text)
        .width('100%')
        .height(AppSizes.TOUCH_TARGET + 6)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .linearGradient({
          angle: 135,
          colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
        })
        .fontColor(Color.White)
        .borderRadius(25)
        .shadow({ radius: 12, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
        .onClick(() => {
          this.onTap();
        })
        .accessibilityText(this.text)
    } else {
      Button(this.text)
        .width('100%')
        .height(AppSizes.TOUCH_TARGET + 6)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppColors.DISABLED)
        .fontColor(AppColors.TEXT_PRIMARY)
        .borderRadius(25)
        .enabled(false)
        .accessibilityText(this.text + '，当前不可用')
    }
  }
}

@Component
export struct AppCard {
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(AppSizes.PADDING_CARD)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
  }
}

@Component
export struct SectionCard {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .margin({ bottom: 10 })
          .accessibilityText(this.title)
      }
      this.content()
    }
    .width('100%')
    .padding(AppSizes.PADDING_CARD + 2)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 12, color: AppColors.SHADOW_SOFT, offsetY: 3 })
  }
}

@Component
export struct EmptyBlock {
  @Prop message: string = '暂无数据';

  build() {
    Column() {
      // 吉祥物「醒醒」陪空状态
      Text('🦉')
        .fontSize(46)
        .width(92)
        .height(92)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppColors.SOFT_PRIMARY)
        .borderRadius(30)
        .margin({ bottom: 14 })
      Text(this.message)
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .accessibilityText(this.message)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 48, bottom: 48 })
  }
}
