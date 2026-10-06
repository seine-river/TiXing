import { AppColors, AppSizes } from '../common/Constants';

/**
 * 基础组件库（T043/FR-023）：FilterChip / PrimaryButton / AppCard / SectionCard / EmptyBlock。
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
        .fontColor(this.selected ? Color.White : AppColors.TEXT_REGULAR)
        .padding({ left: 14, right: 14 })
    }
    .constraintSize({ minHeight: AppSizes.TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selected ? AppColors.SOLID_PRIMARY : AppColors.CHIP_BG)
    .borderRadius(22)
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
    Button(this.text)
      .width('100%')
      .height(AppSizes.TOUCH_TARGET)
      .backgroundColor(this.isEnabled ? AppColors.SOLID_PRIMARY : AppColors.DISABLED)
      .fontColor(this.isEnabled ? Color.White : AppColors.TEXT_PRIMARY)
      .borderRadius(22)
      .enabled(this.isEnabled)
      .onClick(() => {
        this.onTap();
      })
      .accessibilityText(this.text + (this.isEnabled ? '' : '，当前不可用'))
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
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
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
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .margin({ bottom: 8 })
          .accessibilityText(this.title)
      }
      this.content()
    }
    .width('100%')
    .padding(AppSizes.PADDING_CARD)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .shadow({ radius: 8, color: AppColors.SHADOW_SOFT, offsetY: 2 })
  }
}

@Component
export struct EmptyBlock {
  @Prop message: string = '暂无数据';

  build() {
    Column() {
      Text('📭')
        .fontSize(56)
        .margin({ bottom: 14 })
      Text(this.message)
        .fontSize(15)
        .fontColor(AppColors.TEXT_SECONDARY)
        .accessibilityText(this.message)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 48, bottom: 48 })
  }
}
