import { dbHelper } from '../repository/DatabaseHelper';
import { DbResult } from '../common/DbResult';
import { AppColors, AppSizes } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';
import { PrimaryButton, EmptyBlock } from '../components/BasicWidgets';
import { AudioRecorderService, RecordedAudio } from '../services/AudioRecorderService';
import { CoreSpeechService } from '../services/CoreSpeechService';
import { AiService, AiVoiceAnswer } from '../services/AiService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import {
  VoiceAskRecord, voiceAskSubjectLabel, voiceAskQuestionTypeLabel, voiceAskSafetyLabel
} from '../models/VoiceAsk';
import { Student } from '../models/Student';

const MAX_RECORD_SECONDS: number = 30;

@Entry
@Component
struct VoiceAskPage {
  @State recording: boolean = false;
  @State elapsedSeconds: number = 0;
  @State busy: boolean = false;
  @State stage: string = '开口问一个问题';
  @State questionText: string = '';
  @State errorText: string = '';
  @State hasRecord: boolean = false;
  @State hasQuestion: boolean = false;
  @State hasAnswer: boolean = false;
  @State answer: AiVoiceAnswer = new AiVoiceAnswer();
  private record: VoiceAskRecord = new VoiceAskRecord();
  private studentGrade: string = '3';
  private timerId: number = -1;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.loadStudent();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.clearTimer();
    if (this.recording) {
      AudioRecorderService.cancel().catch((_e: Object): void => {
      });
    }
  }

  onBackPress(): boolean {
    if (this.recording) {
      this.cancelRecording();
      return true;
    }
    return false;
  }

  private async loadStudent(): Promise<void> {
    try {
      const student: Student | undefined = await dbHelper.queryStudent('stu_default');
      if (student !== undefined) {
        this.studentGrade = student.grade;
      }
    } catch (e) {
      PerformanceMonitor.warn('voice ask load student failed');
    }
  }

  build() {
    Column() {
      PageHeader({
        title: '问一问',
        onBack: (): void => {
          if (this.recording) {
            this.cancelRecording();
          } else {
            this.getUIContext().getRouter().back();
          }
        }
      })
      Scroll() {
        Column() {
          this.HeroCard()

          if (this.errorText.length > 0) {
            Column() {
              Text('刚才遇到一点小问题')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.DANGER)
                .width('100%')
                .margin({ bottom: 6 })
              Text(this.errorText)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%')
                .maxLines(8)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.SOFT_DANGER)
            .borderRadius(AppSizes.CORNER_RADIUS)
            .margin({ top: 12 })
          }

          if (this.hasRecord) {
            Column() {
              Text(this.hasQuestion ? '醒醒听到的问题' : '也可以自己写下问题')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 8 })
              TextArea({ text: this.questionText, placeholder: '例如：恐龙为什么会灭绝？' })
                .height(96)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .backgroundColor(AppColors.BG_CHIP)
                .borderRadius(AppSizes.CORNER_RADIUS)
                .enabled(!this.busy)
                .onChange((value: string) => {
                  this.questionText = value;
                  this.hasQuestion = value.trim().length > 0;
                })

              if (this.hasAnswer) {
                Column() {
                  Text('醒醒的回答')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .width('100%')
                    .margin({ bottom: 8 })
                  Text(this.answer.answerText)
                    .fontSize(15)
                    .lineHeight(25)
                    .fontColor(AppColors.TEXT_REGULAR)
                    .width('100%')

                  if (this.answer.followUpQuestion.length > 0) {
                    Text('继续想一想：' + this.answer.followUpQuestion)
                      .fontSize(13)
                      .fontColor(AppColors.PRIMARY)
                      .width('100%')
                      .padding({ top: 10, bottom: 10 })
                      .backgroundColor(AppColors.SOFT_PRIMARY)
                      .borderRadius(AppSizes.CORNER_RADIUS_SM)
                  }

                  Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                    this.TagPill(voiceAskSubjectLabel(this.answer.subject), AppColors.SOLID_PRIMARY)
                    this.TagPill(voiceAskQuestionTypeLabel(this.answer.questionType), AppColors.SOLID_INFO)
                    if (this.answer.topic.length > 0) {
                      this.TagPill(this.answer.topic, AppColors.SOLID_SECONDARY)
                    }
                    this.TagPill(voiceAskSafetyLabel(this.answer.safetyLevel),
                      this.answer.safetyLevel === 'attention' ? AppColors.SOLID_WARNING : AppColors.MINT_START)
                  }
                  .width('100%')
                  .margin({ top: 10 })

                  if (this.answer.interestTags.length > 0) {
                    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                      ForEach(this.answer.interestTags, (tag: string) => {
                        Text('#' + tag)
                          .fontSize(12)
                          .fontColor(AppColors.PRIMARY)
                          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                          .backgroundColor(AppColors.SOFT_PRIMARY)
                          .borderRadius(12)
                      }, (tag: string) => tag)
                    }
                    .width('100%')
                    .margin({ top: 8 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(14)
                .backgroundColor(AppColors.BG_CARD)
                .borderRadius(AppSizes.CORNER_RADIUS_LG)
                .shadow({ radius: 12, color: AppColors.SHADOW_SOFT, offsetY: 3 })
                .margin({ top: 12 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_LG)
            .shadow({ radius: 12, color: AppColors.SHADOW_SOFT, offsetY: 3 })
            .margin({ top: 16 })
          } else {
            EmptyBlock({ message: '原始录音会保存在你的手机里，以后可以回听当时的问题' })
          }

          Column() {
            if (!this.busy) {
              PrimaryButton({
                text: this.buttonText(),
                isEnabled: this.buttonEnabled(),
                onTap: (): void => {
                  this.handleMainAction();
                }
              })
            }
            if (this.hasRecord && !this.hasAnswer) {
              Button('放弃这条录音')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontColor(AppColors.DANGER)
                .backgroundColor(AppColors.SOFT_DANGER)
                .borderRadius(22)
                .margin({ top: 10 })
                .enabled(!this.busy && !this.recording)
                .onClick(() => {
                  this.discardRecord();
                })
            }
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  HeroCard() {
    Column() {
      this.RecordButton()
      Text(this.stage)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 16 })
        .textAlign(TextAlign.Center)
      if (this.recording) {
        Text(`${this.elapsedSeconds} / ${MAX_RECORD_SECONDS} 秒`)
          .fontSize(13)
          .fontColor('#E6FFFFFF')
          .margin({ top: 6 })
      } else {
        Text('说完整一个问题，更容易得到好答案')
          .fontSize(13)
          .fontColor('#E6FFFFFF')
          .margin({ top: 6 })
      }
      Row({ space: 5 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6], (index: number) => {
          Column() {
          }
          .width(5)
          .height(this.recording ? (index % 2 === 0 ? 24 : 15) : 8)
          .backgroundColor('#80FFFFFF')
          .borderRadius(3)
          .animation({ duration: 320, curve: Curve.EaseOut })
        }, (index: number) => `wave-${index}-${this.recording}`)
      }
      .height(26)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })
    }
    .width('100%')
    .padding({ top: 28, bottom: 26, left: 18, right: 18 })
    .alignItems(HorizontalAlign.Center)
    .linearGradient({
      angle: 140,
      colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
    })
    .borderRadius(AppSizes.CORNER_RADIUS_XL)
    .shadow({ radius: 16, color: AppColors.SHADOW_PRIMARY, offsetY: 5 })
  }

  @Builder
  RecordButton() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(this.recording ? 138 : 126)
          .height(this.recording ? 138 : 126)
          .backgroundColor('#1FFFFFFF')
          .borderRadius(69)
          .animation({ duration: 420, curve: Curve.EaseInOut })
        Column()
          .width(112)
          .height(112)
          .backgroundColor('#26FFFFFF')
          .borderRadius(56)
          .border({ width: 1, color: '#59FFFFFF' })
        Column()
          .width(88)
          .height(88)
          .linearGradient({
            angle: 145,
            colors: this.recording
              ? [[ '#FF6B6B', 0 ], [ '#F0522D', 0.58 ], [ '#D93025', 1 ]]
              : [[ '#FFD166', 0 ], [ '#FF8A3D', 0.58 ], [ '#F0522D', 1 ]]
          })
          .borderRadius(44)
          .border({ width: 3, color: '#FFFFFFFF' })
          .shadow({ radius: 22, color: '#66F0522D', offsetX: 0, offsetY: 12 })
          .scale({ x: this.recording ? 0.96 : 1, y: this.recording ? 0.96 : 1 })
          .animation({ duration: 420, curve: Curve.EaseInOut })
        Text('🎤')
          .fontSize(43)
          .textAlign(TextAlign.Center)
          .scale({ x: this.recording ? 1.1 : 1, y: this.recording ? 1.1 : 1 })
          .animation({ duration: 420, curve: Curve.EaseInOut })
      }
      .width(140)
      .height(140)

    }
    .alignItems(HorizontalAlign.Center)
    .constraintSize({ minHeight: AppSizes.TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .opacity(this.busy ? 0.65 : 1)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.handleMicrophoneAction();
    })
    .accessibilityText(this.recording ? '结束录音' : '开始录音')
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

  private buttonText(): string {
    if (this.recording) {
      return '说完了，保存声音';
    }
    if (this.busy) {
      return this.stage;
    }
    if (!this.hasRecord) {
      return '开始录音';
    }
    if (!this.hasAnswer) {
      if (this.questionText.trim().length === 0) {
        return '重新录音';
      }
      return '让醒醒回答';
    }
    return '收进好奇星球';
  }

  private buttonEnabled(): boolean {
    if (this.busy) {
      return false;
    }
    if (this.recording) {
      return true;
    }
    if (!this.hasRecord) {
      return true;
    }
    if (!this.hasAnswer) {
      return true;
    }
    return this.questionText.trim().length > 0 && this.answer.answerText.length > 0;
  }

  private async handleMainAction(): Promise<void> {
    if (this.recording) {
      await this.stopAndTranscribe();
      return;
    }
    if (!this.hasRecord) {
      await this.startRecording();
      return;
    }
    if (!this.hasAnswer) {
      if (this.questionText.trim().length === 0) {
        await this.handleMicrophoneAction();
        return;
      }
      await this.generateAnswer();
      return;
    }
    await this.saveAnswer();
  }

  private async handleMicrophoneAction(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.recording) {
      await this.stopAndTranscribe();
      return;
    }
    await this.prepareNewRecording();
    await this.startRecording();
  }

  private async prepareNewRecording(): Promise<void> {
    if (this.record.id.length > 0 && !this.hasAnswer) {
      this.record.status = 'discarded';
      this.record.updatedAt = Date.now();
      await dbHelper.updateVoiceAskRecord(this.record);
    }
    this.resetUi();
  }

  private async startRecording(): Promise<void> {
    this.errorText = '';
    this.busy = true;
    this.stage = '正在打开麦克风…';
    try {
      const path: string = await AudioRecorderService.start();
      this.recording = true;
      this.elapsedSeconds = 0;
      this.stage = '正在听你说…';
      this.startTimer();
      PerformanceMonitor.writeStatistic('voice_ask_record_start', { 'pathLength': path.length });
    } catch (e) {
      this.errorText = AiService.userMessage(e, '录音启动失败，请检查麦克风权限后重试');
      this.stage = '麦克风暂时没有准备好';
      Toast.show(this.errorText);
    }
    this.busy = false;
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      if (!this.recording) {
        this.clearTimer();
        return;
      }
      this.elapsedSeconds += 1;
      if (this.elapsedSeconds >= MAX_RECORD_SECONDS) {
        this.stopAndTranscribe().catch((_e: Object): void => {
        });
      }
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private async stopAndTranscribe(): Promise<void> {
    if (!this.recording || this.busy) {
      return;
    }
    this.busy = true;
    this.recording = false;
    this.clearTimer();
    this.stage = '正在保存原始录音…';
    let audio: RecordedAudio = new RecordedAudio();
    try {
      audio = await AudioRecorderService.stop();
      this.hasRecord = true;
      this.record = VoiceAskRecord.create('stu_default', this.studentGrade,
        audio.path, audio.durationSeconds);
      this.record.asrStatus = 'processing';
      this.record.aiStatus = 'pending';
      const inserted: DbResult = await dbHelper.insertVoiceAskRecord(this.record);
      if (!inserted.success) {
        throw new Error(inserted.reason);
      }
    } catch (e) {
      this.errorText = AiService.userMessage(e, '录音保存失败，请重新录制');
      this.stage = '录音没有保存成功';
      this.busy = false;
      return;
    }

    this.stage = '正在转换为文字…';
    try {
      this.questionText = await CoreSpeechService.transcribeAudio(audio.path,
        (fedSeconds: number, totalSeconds: number): void => {
          this.stage = `正在转换为文字… ${fedSeconds}/${totalSeconds}秒`;
        });
      this.hasQuestion = this.questionText.trim().length > 0;
      this.record.questionText = this.questionText;
      this.record.asrStatus = 'done';
      this.record.status = 'active';
      this.record.updatedAt = Date.now();
      await dbHelper.updateVoiceAskRecord(this.record);
      this.stage = '确认一下醒醒听到的问题';
    } catch (e) {
      this.record.asrStatus = 'failed';
      this.record.status = 'discarded';
      this.record.updatedAt = Date.now();
      await dbHelper.updateVoiceAskRecord(this.record);
      this.errorText = AiService.userMessage(e, '语音转文字失败，请重新录制或手动输入问题');
      this.stage = '没听清？点大麦克风重说，也可以手动写问题';
      Toast.show(this.errorText);
    }
    this.busy = false;
  }

  private async generateAnswer(): Promise<void> {
    const question: string = this.questionText.trim();
    if (question.length === 0) {
      Toast.show('先写下或重新录一次问题');
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.stage = '醒醒正在思考…';
    try {
      this.answer = await AiService.answerVoiceQuestion(question, this.record.gradeLevel);
      this.hasAnswer = true;
      this.record.status = 'active';
      this.record.questionText = question;
      this.record.answerText = this.answer.answerText;
      this.record.subject = this.answer.subject;
      this.record.topic = this.answer.topic;
      this.record.interestTags = this.answer.interestTags;
      this.record.questionType = this.answer.questionType;
      this.record.safetyLevel = this.answer.safetyLevel;
      this.record.aiStatus = 'done';
      this.record.updatedAt = Date.now();
      await dbHelper.updateVoiceAskRecord(this.record);
      this.stage = '回答好了，看看要不要收进好奇星球';
    } catch (e) {
      this.record.aiStatus = 'failed';
      this.record.updatedAt = Date.now();
      await dbHelper.updateVoiceAskRecord(this.record);
      this.errorText = AiService.userMessage(e, 'AI 回答失败，请稍后重试');
      this.stage = '这次回答没有成功，可以再试一次';
      Toast.show(this.errorText);
    }
    this.busy = false;
  }

  private async saveAnswer(): Promise<void> {
    this.busy = true;
    this.stage = '正在收进好奇星球…';
    const result: DbResult = await dbHelper.updateVoiceAskRecord(this.record);
    this.busy = false;
    if (!result.success) {
      this.errorText = this.cleanUserText(result.reason, '保存失败，请重试');
      Toast.show('保存失败，请重试');
      return;
    }
    PerformanceMonitor.writeStatistic('voice_ask_saved', {
      'audioDuration': this.record.audioDuration,
      'subject': this.record.subject
    });
    Toast.show('已收进好奇星球');
    this.getUIContext().getRouter().back();
  }

  private async cancelRecording(): Promise<void> {
    this.clearTimer();
    this.recording = false;
    this.busy = false;
    this.stage = '已取消这次录音';
    await AudioRecorderService.cancel();
  }

  private async discardRecord(): Promise<void> {
    if (this.record.id.length === 0) {
      this.resetUi();
      return;
    }
    this.record.status = 'discarded';
    this.record.updatedAt = Date.now();
    const result: DbResult = await dbHelper.updateVoiceAskRecord(this.record);
    if (!result.success) {
      Toast.show('暂时无法放弃，请稍后再试');
      return;
    }
    this.resetUi();
  }

  private resetUi(): void {
    this.record = new VoiceAskRecord();
    this.answer = new AiVoiceAnswer();
    this.questionText = '';
    this.errorText = '';
    this.hasRecord = false;
    this.hasQuestion = false;
    this.hasAnswer = false;
    this.stage = '开口问一个问题';
  }

  private cleanUserText(raw: string, fallback: string): string {
    if (raw.length === 0 || raw.indexOf('[object Object]') >= 0 ||
      raw.indexOf('object Object') >= 0) {
      return fallback;
    }
    return raw;
  }
}
