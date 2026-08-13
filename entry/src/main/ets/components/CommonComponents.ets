@Component
export struct StatusTag {
  @Prop statusText: string = '';
  @Prop statusColor: string = '#909399';

  build() {
    Text(this.statusText)
      .fontSize(12)
      .fontColor(Color.White)
      .backgroundColor(this.statusColor)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
  }
}

@Component
export struct SubjectTag {
  @Prop subjectText: string = '';
  @Prop subjectColor: string = '#4A90D9';

  build() {
    Text(this.subjectText)
      .fontSize(12)
      .fontColor(Color.White)
      .backgroundColor(this.subjectColor)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
  }
}

@Component
export struct EmptyPlaceholder {
  @Prop message: string = '暂无数据';

  build() {
    Column() {
      Text('📭')
        .fontSize(48)
        .margin({ bottom: 12 })
      Text(this.message)
        .fontSize(16)
        .fontColor('#909399')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct PageTitle {
  @Prop title: string = '';

  build() {
    Text(this.title)
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#303133')
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }
}
