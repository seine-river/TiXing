import { Mistake } from '../models/Mistake';
import { dbHelper } from '../repository/DatabaseHelper';
import { MistakeStatus, Subject } from '../models/Enums';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, statusColor } from '../common/Constants';
import { StatusTag, SubjectTag, EmptyPlaceholder } from '../components/CommonComponents';

@Component
export struct HomePage {
  @State todayReviewCount: number = 0;
  @State totalMistakes: number = 0;
  @State masteredCount: number = 0;
  @State reviewingCount: number = 0;
  @State recentMistakes: Mistake[] = [];
  @State studentPoints: number = 0;
  private studentId: string = 'stu_default';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const todayList = await dbHelper.queryTodayReviewMistakes();
    this.todayReviewCount = todayList.length;
    const allMistakes = await dbHelper.queryMistakes();
    this.totalMistakes = allMistakes.length;
    this.masteredCount = allMistakes.filter((m: Mistake) => m.status === MistakeStatus.MASTERED).length;
    this.reviewingCount = allMistakes.filter((m: Mistake) => m.status === MistakeStatus.REVIEWING || m.status === MistakeStatus.UNMASTERED).length;
    this.recentMistakes = allMistakes.slice(0, 5);
    const summary = await dbHelper.queryPointsSummary(this.studentId);
    this.studentPoints = summary.totalPoints;
  }

  build() {
    Scroll() {
      Column() {
        this.HeroBanner()

        Row() {
          this.StatCard('总错题', `${this.totalMistakes}`, AppColors.PRIMARY, '📒')
          this.StatCard('已掌握', `${this.masteredCount}`, AppColors.MASTERY_MASTERED, '✓')
          this.StatCard('复习中', `${this.reviewingCount}`, AppColors.WARNING, '🔁')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .justifyContent(FlexAlign.SpaceBetween)

        Button('📷  录入错题')
          .width('100%')
          .height(50)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .shadow({ radius: 12, color: '#263A7BD5', offsetY: 4 })
          .margin({ left: 16, right: 16, top: 16 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/CapturePage' });
          })

        Row() {
          Text('最近错题')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 8 })

        if (this.recentMistakes.length === 0) {
          EmptyPlaceholder({ message: '还没有错题，点击上方按钮录入吧' })
        } else {
          ForEach(this.recentMistakes, (item: Mistake) => {
            this.RecentCard(item)
          }, (item: Mistake) => item.id)
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  HeroBanner() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          Column() {
            Text(AppStrings.APP_NAME)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('今日学习概览，加油进步每一天')
              .fontSize(13)
              .fontColor('#E8F1FF')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        Row() {
          Column() {
            Text(`${this.todayReviewCount}`)
              .fontSize(44)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text('今日待复习')
              .fontSize(13)
              .fontColor('#DCEBFF')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button(this.todayReviewCount > 0 ? '开始复习' : '暂无待复习')
            .height(44)
            .backgroundColor(Color.White)
            .fontColor(AppColors.PRIMARY)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .borderRadius(22)
            .padding({ left: 24, right: 24 })
            .enabled(this.todayReviewCount > 0)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/ReviewPage' });
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 24 })

      Row() {
        Text('⭐')
          .fontSize(14)
        Text(`${this.studentPoints}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 4 })
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .backgroundColor('#331A2A4D')
      .margin({ top: 14, right: 14 })
    }
    .width('100%')
    .linearGradient({
      angle: 135,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
    })
  }

  @Builder
  StatCard(label: string, value: string, color: string, icon: string) {
    Column() {
      Text(icon)
        .fontSize(22)
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 6 })
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 4, right: 4 })
    .shadow({ radius: 8, color: '#14223640', offsetY: 2 })
  }

  @Builder
  RecentCard(item: Mistake) {
    Row() {
      Column() {
        Text(item.ocrText.length > 36 ? item.ocrText.substring(0, 36) + '...' : item.ocrText)
          .fontSize(15)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(22)
        Row({ space: 6 }) {
          SubjectTag({ subjectText: subjectLabel(item.subject) })
          StatusTag({ statusText: statusLabel(item.status), statusColor: statusColor(item.status) })
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (item.imageUrl.length > 0) {
        Image(item.imageUrl)
          .width(64)
          .height(64)
          .borderRadius(AppSizes.CORNER_RADIUS_XS)
          .objectFit(ImageFit.Cover)
          .margin({ left: 10 })
      } else {
        Column() {
          Text('📷')
            .fontSize(28)
        }
        .width(64)
        .height(64)
        .borderRadius(AppSizes.CORNER_RADIUS_XS)
        .backgroundColor(AppColors.BG_CHIP)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: 10 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 16, right: 16, top: 6, bottom: 6 })
    .shadow({ radius: 6, color: '#101F2E30', offsetY: 2 })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeDetailPage', params: { mistakeId: item.id } });
    })
  }
}
