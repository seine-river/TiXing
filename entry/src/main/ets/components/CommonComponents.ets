import { AppColors, AppSizes, statusColor, subjectColor } from '../common/Constants';

/**
 * 通用组件：胶囊式状态/学科标签 + 页面标题栏。
 * 颜色经语义键在组件内映射资源引用，页面不再传递颜色值。
 */
@Component
export struct StatusTag {
  @Prop statusText: string = '';
  @Prop statusKey: string = '';

  build() {
    Text(this.statusText)
      .fontSize(10.5)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(statusColor(this.statusKey))
      .borderRadius(9)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .accessibilityText(this.statusText)
  }
}

@Component
export struct SubjectTag {
  @Prop subjectText: string = '';
  @Prop subjectKey: string = '';

  build() {
    Text(this.subjectText)
      .fontSize(10.5)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(subjectColor(this.subjectKey))
      .borderRadius(9)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .accessibilityText(this.subjectText)
  }
}

@Component
export struct PageHeader {
  @Prop title: string = '';

  build() {
    Row() {
      Text('‹')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .accessibilityText('返回上一页')
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
      Text(this.title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
        .accessibilityText(this.title)
      Column() {
      }
      .width(44)
    }
    .width('100%')
    .height(52)
    .padding({ left: 6, right: 16 })
    .backgroundColor(AppColors.BG_PAGE)
  }
}
