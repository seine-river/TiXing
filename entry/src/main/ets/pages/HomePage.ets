import { Mistake } from '../models/Mistake';
import { dbHelper } from '../repository/DatabaseHelper';
import { MistakeStatus, Subject } from '../models/Enums';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, statusColor, generateId } from '../common/Constants';
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
        Row() {
          Column() {
            Text(AppStrings.APP_NAME)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text('今日学习概览')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Row() {
            Text(`${this.studentPoints}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.WARNING)
            Text(' 积分')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        Column() {
          Row() {
            Column() {
              Text(`${this.todayReviewCount}`)
                .fontSize(36)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.PRIMARY)
              Text('待复习')
                .fontSize(14)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Center)
            Blank()
            Button(this.todayReviewCount > 0 ? AppStrings.START_REVIEW : AppStrings.NO_REVIEW_TODAY)
              .backgroundColor(this.todayReviewCount > 0 ? AppColors.PRIMARY : '#C0C4CC')
              .fontColor(Color.White)
              .borderRadius(20)
              .height(40)
              .enabled(this.todayReviewCount > 0)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReviewPage' });
              })
          }
          .width('100%')
          .padding(16)
        }
        .width('100%')
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 8 })
        .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })

        Button('📷 录入错题')
          .width('100%')
          .height(48)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/CapturePage' });
          })

        Row() {
          Column() {
            Text(`${this.totalMistakes}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY)
            Text(AppStrings.TOTAL_MISTAKES)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .padding({ top: 12, bottom: 12 })

          Column() {
            Text(`${this.masteredCount}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.MASTERY_MASTERED)
            Text(AppStrings.MASTERED_COUNT)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .padding({ top: 12, bottom: 12 })

          Column() {
            Text(`${this.reviewingCount}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.MASTERY_REVIEWING)
            Text(AppStrings.REVIEWING_COUNT)
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .padding({ top: 12, bottom: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .justifyContent(FlexAlign.SpaceBetween)

        Text('最近错题')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        if (this.recentMistakes.length === 0) {
          EmptyPlaceholder({ message: '还没有错题，快去录入吧' })
        } else {
          ForEach(this.recentMistakes, (item: Mistake) => {
            Row() {
              Column() {
                Text(item.ocrText.length > 30 ? item.ocrText.substring(0, 30) + '...' : item.ocrText)
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 6 }) {
                  SubjectTag({ subjectText: subjectLabel(item.subject), subjectColor: AppColors.PRIMARY })
                  StatusTag({ statusText: statusLabel(item.status), statusColor: statusColor(item.status) })
                }
                .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Image(item.imageUrl)
                .width(60)
                .height(60)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .margin({ left: 16, right: 16, top: 6, bottom: 6 })
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeDetailPage', params: { mistakeId: item.id } });
            })
          }, (item: Mistake) => item.id)
        }
      }
      .width('100%')
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Off)
  }
}
