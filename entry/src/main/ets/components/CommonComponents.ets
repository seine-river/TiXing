@Component
export struct StatusTag {
  @Prop statusText: string = '';
  @Prop statusColor: string = '#86909C';

  build() {
    Text(this.statusText)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor(this.statusColor)
      .borderRadius(8)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}

@Component
export struct SubjectTag {
  @Prop subjectText: string = '';
  @Prop subjectColor: string = '#3A7BD5';

  build() {
    Text(this.subjectText)
      .fontSize(11)
      .fontColor(Color.White)
      .backgroundColor(this.subjectColor)
      .borderRadius(8)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
  }
}

@Component
export struct EmptyPlaceholder {
  @Prop message: string = '暂无数据';

  build() {
    Column() {
      Text('📭')
        .fontSize(56)
        .margin({ bottom: 14 })
      Text(this.message)
        .fontSize(15)
        .fontColor('#86909C')
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
      .fontColor('#1D2129')
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
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
        .fontColor('#1D2129')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
      Text(this.title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D2129')
        .layoutWeight(1)
      Column() {
      }
      .width(40)
    }
    .width('100%')
    .height(50)
    .padding({ left: 4, right: 12 })
    .alignItems(VerticalAlign.Center)
  }
}
