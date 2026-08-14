import { Mistake } from '../models/Mistake';
import { MistakeStatus, Subject, ErrorType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, statusColor, formatDate, toFileUri } from '../common/Constants';
import { TabController } from '../common/TabController';
import { Toast } from '../common/Toast';
import { StatusTag, SubjectTag, EmptyPlaceholder } from '../components/CommonComponents';

@Component
export struct MistakesPage {
  controller: TabController = new TabController();
  @State mistakes: Mistake[] = [];
  @State filterSubject: string = '';
  @State filterStatus: string = '';
  @State filterErrorType: string = '';
  @State searchKeyword: string = '';
  @State currentTab: number = 0;

  aboutToAppear(): void {
    this.controller.reload = (): void => { this.loadMistakes(); };
    this.loadMistakes();
  }

  async loadMistakes(): Promise<void> {
    const subject = this.filterSubject.length > 0 ? this.filterSubject as Subject : undefined;
    const status = this.filterStatus.length > 0 ? this.filterStatus as MistakeStatus : undefined;
    const errorType = this.filterErrorType.length > 0 ? this.filterErrorType as ErrorType : undefined;
    const keyword = this.searchKeyword.length > 0 ? this.searchKeyword : undefined;
    this.mistakes = await dbHelper.queryMistakes(subject, status, keyword, errorType);
  }

  build() {
    Column() {
      Scroll() {
        Row({ space: 8 }) {
          Button('全部')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterSubject.length === 0 && this.filterStatus.length === 0 ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterSubject.length === 0 && this.filterStatus.length === 0 ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterSubject = ''; this.filterStatus = ''; this.loadMistakes(); })
          Button('数学')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterSubject === Subject.MATH ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterSubject === Subject.MATH ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterSubject = Subject.MATH; this.filterStatus = ''; this.loadMistakes(); })
          Button('语文')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterSubject === Subject.CHINESE ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterSubject === Subject.CHINESE ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterSubject = Subject.CHINESE; this.filterStatus = ''; this.loadMistakes(); })
          Button('未掌握')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterStatus === MistakeStatus.UNMASTERED ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterStatus === MistakeStatus.UNMASTERED ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterStatus = MistakeStatus.UNMASTERED; this.filterSubject = ''; this.loadMistakes(); })
          Button('复习中')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterStatus === MistakeStatus.REVIEWING ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterStatus === MistakeStatus.REVIEWING ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterStatus = MistakeStatus.REVIEWING; this.filterSubject = ''; this.loadMistakes(); })
          Button('已掌握')
            .height(32).fontSize(13).borderRadius(16)
            .backgroundColor(this.filterStatus === MistakeStatus.MASTERED ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterStatus === MistakeStatus.MASTERED ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterStatus = MistakeStatus.MASTERED; this.filterSubject = ''; this.loadMistakes(); })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      Row() {
        TextInput({ text: this.searchKeyword, placeholder: '🔍 搜索错题内容' })
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .onChange((value: string) => {
            this.searchKeyword = value;
          })
        Button('搜索')
          .height(40)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .margin({ left: 8 })
          .onClick(() => { this.loadMistakes(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Scroll() {
        Row({ space: 8 }) {
          Button('概念不清')
            .height(30).fontSize(12).borderRadius(15)
            .backgroundColor(this.filterErrorType === ErrorType.CONCEPT ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterErrorType === ErrorType.CONCEPT ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterErrorType = this.filterErrorType === ErrorType.CONCEPT ? '' : ErrorType.CONCEPT; this.loadMistakes(); })
          Button('粗心')
            .height(30).fontSize(12).borderRadius(15)
            .backgroundColor(this.filterErrorType === ErrorType.CARELESS ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterErrorType === ErrorType.CARELESS ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterErrorType = this.filterErrorType === ErrorType.CARELESS ? '' : ErrorType.CARELESS; this.loadMistakes(); })
          Button('审题错误')
            .height(30).fontSize(12).borderRadius(15)
            .backgroundColor(this.filterErrorType === ErrorType.MISREAD ? AppColors.PRIMARY : '#E8EAED')
            .fontColor(this.filterErrorType === ErrorType.MISREAD ? Color.White : AppColors.TEXT_REGULAR)
            .onClick(() => { this.filterErrorType = this.filterErrorType === ErrorType.MISREAD ? '' : ErrorType.MISREAD; this.loadMistakes(); })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.mistakes.length === 0) {
        EmptyPlaceholder({ message: '还没有错题，快去录入吧' })
      } else {
        List({ space: 8 }) {
          ForEach(this.mistakes, (item: Mistake) => {
            ListItem() {
              Row() {
                Column() {
                  Text(this.displayTitle(item))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  if (item.ocrText.length > 0) {
                    Text(item.ocrText.length > 40 ? item.ocrText.substring(0, 40) + '...' : item.ocrText)
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 4 })
                  }

                  Row({ space: 4 }) {
                    SubjectTag({ subjectText: subjectLabel(item.subject), subjectColor: AppColors.PRIMARY })
                    StatusTag({ statusText: statusLabel(item.status), statusColor: statusColor(item.status) })
                    Text(formatDate(item.createdAt))
                      .fontSize(11)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .margin({ top: 6 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.imageUrl.length > 0) {
                  Image(toFileUri(item.imageUrl))
                    .width(64).height(64).borderRadius(AppSizes.CORNER_RADIUS_XS)
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
              .shadow({ radius: 6, color: '#101F2E26', offsetY: 2 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeDetailPage', params: { mistakeId: item.id } });
              })
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.DeleteAction(item)
                }
              }
            })
          }, (item: Mistake) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  DeleteAction(item: Mistake) {
    Button('删除')
      .height('100%')
      .backgroundColor(AppColors.DANGER)
      .fontColor(Color.White)
      .fontSize(15)
      .borderRadius(0)
      .padding({ left: 20, right: 20 })
      .onClick(() => {
        this.confirmDelete(item);
      })
  }

  private displayTitle(item: Mistake): string {
    if (item.knowledgeSummary.length > 0) {
      return item.knowledgeSummary;
    }
    if (item.ocrText.length > 0) {
      return item.ocrText.length > 30 ? item.ocrText.substring(0, 30) + '...' : item.ocrText;
    }
    return '未命名错题';
  }

  private async confirmDelete(item: Mistake): Promise<void> {
    await dbHelper.deleteMistake(item.id);
    Toast.show('已删除该错题');
    this.loadMistakes();
  }
}
