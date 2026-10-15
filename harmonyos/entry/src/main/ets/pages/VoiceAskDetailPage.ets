import fs from '@ohos.file.fs';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, formatDate } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';
import { EmptyBlock, PrimaryButton } from '../components/BasicWidgets';
import { Toast } from '../common/Toast';
import { VoiceAskDetailParams } from '../common/RouteParams';
import { AudioPlaybackService } from '../services/AudioPlaybackService';
import { AiService } from '../services/AiService';
import {
  VoiceAskRecord, voiceAskSubjectLabel, voiceAskQuestionTypeLabel, voiceAskSafetyLabel
} from '../models/VoiceAsk';

@Entry
@Component
struct VoiceAskDetailPage {
  @State record: VoiceAskRecord = new VoiceAskRecord();
  @State playing: boolean = false;
  @State notFound: boolean = false;
  @State audioExists: boolean = false;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as VoiceAskDetailParams;
    const id: string = params?.recordId ?? '';
    if (id.length > 0) {
      this.loadRecord(id);
    } else {
      this.notFound = true;
    }
  }

  aboutToDisappear(): void {
    AudioPlaybackService.stop().catch((_e: Object): void => {
    });
  }

  build() {
    Column() {
      PageHeader({ title: '问题回忆' })
      if (this.notFound) {
        EmptyBlock({ message: '没有找到这条问一问记录' })
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            Column() {
              Text('🎧 当时的声音')
                .fontSize(14)
                .fontColor('#E6FFFFFF')
                .width('100%')
                .margin({ bottom: 10 })
              Button(this.playing ? '停止播放' : `播放原始录音 · ${this.record.audioDuration}秒`)
                .height(46)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.HERO_BTN_TEXT)
                .backgroundColor(Color.White)
                .borderRadius(23)
                .padding({ left: 24, right: 24 })
                .enabled(this.audioExists)
                .onClick(() => {
                  this.togglePlayback();
                })
              Text('这段录音会一直保存在本机，并随备份一起导出')
                .fontSize(11)
                .fontColor('#CCFFFFFF')
                .margin({ top: 9 })
            }
            .width('100%')
            .padding(18)
            .alignItems(HorizontalAlign.Start)
            .linearGradient({
              angle: 140,
              colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
            })
            .borderRadius(AppSizes.CORNER_RADIUS_XL)
            .shadow({ radius: 14, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })

            this.InfoCard('我的问题', this.record.questionText.length > 0
              ? this.record.questionText : '这条记录还没有转写文字')
            this.InfoCard('醒醒的回答', this.record.answerText.length > 0
              ? this.record.answerText : '这条记录还没有生成回答')

            Column() {
              Text('归档位置')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 10 })
              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                this.TagPill(voiceAskSubjectLabel(this.record.subject), AppColors.SOLID_PRIMARY)
                this.TagPill(voiceAskQuestionTypeLabel(this.record.questionType), AppColors.SOLID_INFO)
                if (this.record.topic.length > 0) {
                  this.TagPill(this.record.topic, AppColors.SOLID_SECONDARY)
                }
                this.TagPill(voiceAskSafetyLabel(this.record.safetyLevel),
                  this.record.safetyLevel === 'attention' ? AppColors.SOLID_WARNING : AppColors.MINT_START)
              }
              .width('100%')

              if (this.record.interestTags.length > 0) {
                Text('兴趣标签')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .width('100%')
                  .margin({ top: 14, bottom: 6 })
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.record.interestTags, (tag: string) => {
                    Text('#' + tag)
                      .fontSize(12)
                      .fontColor(AppColors.PRIMARY)
                      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                      .backgroundColor(AppColors.SOFT_PRIMARY)
                      .borderRadius(12)
                  }, (tag: string) => tag)
                }
                .width('100%')
              }

              Text(`${formatDate(this.record.createdAt)} · 转写${this.statusText(this.record.asrStatus)} · 回答${this.statusText(this.record.aiStatus)}`)
                .fontSize(11)
                .fontColor(AppColors.TEXT_PLACEHOLDER)
                .margin({ top: 14 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_LG)
            .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
            .margin({ top: 12 })

            PrimaryButton({
              text: '再去问一个',
              isEnabled: true,
              onTap: (): void => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/VoiceAskPage' });
              }
            })
              .margin({ top: 16 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 28 })
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
  InfoCard(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 8 })
      Text(content)
        .fontSize(15)
        .lineHeight(25)
        .fontColor(AppColors.TEXT_REGULAR)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .margin({ top: 12 })
  }

  @Builder
  TagPill(text: string, color: Resource) {
    Text(text)
      .fontSize(11)
      .fontColor(Color.White)
      .padding({ left: 9, right: 9, top: 4, bottom: 4 })
      .backgroundColor(color)
      .borderRadius(10)
  }

  private async loadRecord(id: string): Promise<void> {
    const record: VoiceAskRecord | undefined = await dbHelper.queryVoiceAskRecordById(id);
    if (record === undefined) {
      this.notFound = true;
      return;
    }
    this.record = record;
    this.audioExists = this.checkAudioExists(record.audioPath);
  }

  private async togglePlayback(): Promise<void> {
    if (this.playing) {
      await AudioPlaybackService.stop();
      this.playing = false;
      return;
    }
    try {
      await AudioPlaybackService.play(this.record.audioPath, (): void => {
        this.playing = false;
      });
      this.playing = true;
    } catch (e) {
      Toast.show(AiService.userMessage(e, '原始录音播放失败，请稍后再试'));
    }
  }

  private statusText(status: string): string {
    if (status === 'done') {
      return '成功';
    }
    if (status === 'failed') {
      return '失败';
    }
    return '待处理';
  }

  private checkAudioExists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fs.accessSync(path);
    } catch (e) {
      return false;
    }
  }
}
