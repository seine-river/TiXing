import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, formatDate } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';
import { EmptyBlock, FilterChip } from '../components/BasicWidgets';
import {
  VoiceAskRecord, voiceAskSubjectLabel, voiceAskQuestionTypeLabel
} from '../models/VoiceAsk';

class SubjectFilter {
  key: string = '';
  label: string = '';
}

class TypeFilter {
  key: string = '';
  label: string = '';
}

@Entry
@Component
struct VoiceAskListPage {
  @State records: VoiceAskRecord[] = [];
  @State keyword: string = '';
  @State selectedSubject: string = '';
  @State selectedType: string = '';
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.loadRecords();
  }

  onPageShow(): void {
    this.loadRecords();
  }

  build() {
    Column() {
      PageHeader({ title: '我的问一问' })
      Column() {
        TextInput({ placeholder: '搜索问题、回答、主题或标签', text: this.keyword })
          .height(44)
          .fontSize(14)
          .fontColor(AppColors.TEXT_PRIMARY)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(22)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.keyword = value;
            this.loadRecords();
          })

        Scroll(new Scroller()) {
          Row({ space: 8 }) {
            FilterChip({
              text: '全部领域', selected: this.selectedSubject.length === 0,
              onTap: (): void => {
                this.selectedSubject = '';
                this.loadRecords();
              }
            })
            ForEach(this.subjectFilters(), (item: SubjectFilter) => {
              FilterChip({
                text: item.label, selected: this.selectedSubject === item.key,
                onTap: (): void => {
                  this.selectedSubject = item.key;
                  this.loadRecords();
                }
              })
            }, (item: SubjectFilter) => item.key)
          }
          .padding({ top: 10, bottom: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Scroll(new Scroller()) {
          Row({ space: 8 }) {
            FilterChip({
              text: '全部问法', selected: this.selectedType.length === 0,
              onTap: (): void => {
                this.selectedType = '';
                this.loadRecords();
              }
            })
            ForEach(this.typeFilters(), (item: TypeFilter) => {
              FilterChip({
                text: item.label, selected: this.selectedType === item.key,
                onTap: (): void => {
                  this.selectedType = item.key;
                  this.loadRecords();
                }
              })
            }, (item: TypeFilter) => item.key)
          }
          .padding({ top: 8, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(42)
            .height(42)
          Text('正在整理你的问题...')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.records.length === 0) {
        EmptyBlock({ message: '还没有问一问记录，点中间麦克风开始提问' })
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            ForEach(this.records, (item: VoiceAskRecord) => {
              this.RecordCard(item)
            }, (item: VoiceAskRecord) => item.id)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  RecordCard(item: VoiceAskRecord) {
    Column() {
      Row() {
        Text(item.questionText.length > 0 ? item.questionText : '（这条还没有转写文字）')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('🔊')
          .fontSize(18)
          .width(38)
          .height(38)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppColors.SOFT_PRIMARY)
          .borderRadius(13)
          .margin({ left: 10 })
      }
      .width('100%')

      if (item.answerText.length > 0) {
        Text(item.answerText)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }

      Row() {
        Text(voiceAskSubjectLabel(item.subject))
          .fontSize(10.5)
          .fontColor(AppColors.PRIMARY)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(AppColors.SOFT_PRIMARY)
          .borderRadius(9)
        Text(voiceAskQuestionTypeLabel(item.questionType))
          .fontSize(10.5)
          .fontColor(AppColors.TEXT_REGULAR)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(AppColors.CHIP_BG)
          .borderRadius(9)
        if (item.topic.length > 0) {
          Text(item.topic)
            .fontSize(10.5)
            .fontColor(AppColors.TEXT_REGULAR)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(AppColors.CHIP_BG)
            .borderRadius(9)
        }
        Text(formatDate(item.createdAt))
          .fontSize(10.5)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .margin({ top: 10 })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/VoiceAskDetailPage', params: { recordId: item.id }
      });
    })
    .accessibilityText(item.questionText.length > 0 ? item.questionText : '查看语音问答')
  }

  private subjectFilters(): SubjectFilter[] {
    const values: string[] = ['math', 'chinese', 'english', 'science', 'history',
      'geography', 'technology', 'life', 'art', 'sports', 'other'];
    return values.map((value: string): SubjectFilter => {
      const item = new SubjectFilter();
      item.key = value;
      item.label = voiceAskSubjectLabel(value);
      return item;
    });
  }

  private typeFilters(): TypeFilter[] {
    const values: string[] = ['fact', 'reason', 'compare', 'imagine', 'how_to', 'help'];
    return values.map((value: string): TypeFilter => {
      const item = new TypeFilter();
      item.key = value;
      item.label = voiceAskQuestionTypeLabel(value);
      return item;
    });
  }

  private async loadRecords(): Promise<void> {
    this.loading = true;
    this.records = await dbHelper.queryVoiceAskRecords('stu_default', this.keyword,
      this.selectedSubject, this.selectedType);
    this.loading = false;
  }
}
