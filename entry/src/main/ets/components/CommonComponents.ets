import { AppColors, statusColor, subjectColor } from '../common/Constants';

/**
 * 通用组件（T045/FR-022）：颜色经语义键在组件内映射资源引用，
 * 页面不再传递颜色值（@Prop 不支持 Resource 联合，颜色收敛到组件内部）。
 */
@Component
export struct StatusTag {
  @Prop statusText: string = '';
  @Prop statusKey: string = '';

  build() {
    Text(this.statusText)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor(statusColor(this.statusKey))
      .borderRadius(8)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}

@Component
export struct SubjectTag {
  @Prop subjectText: string = '';
  @Prop subjectKey: string = '';

  build() {
    Text(this.subjectText)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor(subjectColor(this.subjectKey))
      .borderRadius(8)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}

@Component
export struct PageHeader {
  @Prop title: string = '';

  build() {
    Row() {
      Text('‹')
        .fontSize(34)
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
    .padding({ left: 4, right: 12 })
    .alignItems(VerticalAlign.Center)
  }
}
