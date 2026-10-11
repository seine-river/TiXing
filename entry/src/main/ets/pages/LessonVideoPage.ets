import { Mistake } from '../models/Mistake';
import { Student } from '../models/Student';
import { dbHelper } from '../repository/DatabaseHelper';
import { AiService, AiLesson, AiLessonScene } from '../services/AiService';
import { AppColors, AppSizes, generateId, subjectLabel } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';
import { PrimaryButton, EmptyBlock } from '../components/BasicWidgets';
import { LessonVideoParams } from '../common/RouteParams';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xA008;
const LOG_TAG: string = 'TiXingLessonVideo';

class LessonSpeakListener implements textToSpeech.SpeakListener {
  onStart(requestId: string, response: textToSpeech.StartResponse): void {
  }

  onComplete(requestId: string, response: textToSpeech.CompleteResponse): void {
  }

  onStop(requestId: string, response: textToSpeech.StopResponse): void {
  }

  onError(requestId: string, errorCode: number, errorMessage: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG,
      'lesson TTS error: requestId=%{public}s, code=%{public}d, message=%{public}s',
      requestId, errorCode, errorMessage);
  }
}

@Entry
@Component
struct LessonVideoPage {
  @State mistake: Mistake = new Mistake();
  @State student: Student = new Student();
  @State lesson: AiLesson = new AiLesson();
  @State loading: boolean = false;
  @State loadError: string = '';
  @State notFound: boolean = false;
  @State currentIndex: number = 0;
  @State sceneElapsed: number = 0;
  @State isPlaying: boolean = false;
  @State isFinished: boolean = false;
  @State audioEnabled: boolean = true;
  @State audioAvailable: boolean = false;

  private mistakeId: string = '';
  private timerId: number = -1;
  private ttsEngine: textToSpeech.TextToSpeechEngine | undefined = undefined;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    const params = this.getUIContext().getRouter().getParams() as LessonVideoParams;
    this.mistakeId = params?.mistakeId ?? '';
    if (this.mistakeId.length === 0) {
      this.notFound = true;
      return;
    }
    this.loadData();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.stopPlayback(false);
    this.shutdownAudio();
  }

  private async loadData(): Promise<void> {
    const m: Mistake | undefined = await dbHelper.queryMistakeById(this.mistakeId);
    if (m === undefined) {
      this.notFound = true;
      return;
    }
    this.mistake = m;
    const s: Student | undefined = await dbHelper.queryStudent(m.studentId);
    if (s !== undefined) {
      this.student = s;
    }
    this.generateLesson();
  }

  private async generateLesson(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.loadError = '';
    this.stopPlayback(false);
    try {
      const lesson: AiLesson = await AiService.generateLesson(
        this.mistake.ocrText,
        this.mistake.studentAnswer,
        this.mistake.standardAnswer,
        this.student.grade,
        subjectLabel(this.mistake.subject),
        this.mistake.knowledgeSummary,
        this.mistake.errorType
      );
      if (!this.alive) {
        return;
      }
      this.lesson = lesson;
      await this.initializeAudio();
      if (!this.alive) {
        return;
      }
      this.startPlayback(0);
    } catch (e) {
      if (!this.alive) {
        return;
      }
      this.loadError = e instanceof Error ? e.message : '讲解视频生成失败，请重试';
      hilog.error(LOG_DOMAIN, LOG_TAG, 'generate lesson failed: %{public}s',
        e instanceof Error ? e.message : `${e}`);
    }
    this.loading = false;
  }

  private async initializeAudio(): Promise<void> {
    if (this.ttsEngine !== undefined || !this.audioEnabled) {
      this.audioAvailable = this.ttsEngine !== undefined;
      return;
    }
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 13,
        online: 1,
        extraParams: {
          'style': 'interaction-broadcast',
          'locate': 'CN'
        }
      };
      this.ttsEngine = await textToSpeech.createEngine(params);
      this.ttsEngine.setListener(new LessonSpeakListener());
      this.audioAvailable = true;
    } catch (e) {
      this.audioAvailable = false;
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'lesson TTS engine unavailable: %{public}s',
        e instanceof Error ? e.message : `${e}`);
    }
  }

  private speakScene(scene: AiLessonScene): void {
    if (!this.audioEnabled || !this.audioAvailable || this.ttsEngine === undefined) {
      return;
    }
    try {
      if (this.ttsEngine.isBusy()) {
        this.ttsEngine.stop();
      }
      const speakParams: textToSpeech.SpeakParams = {
        requestId: generateId()
      };
      this.ttsEngine.speak(scene.narration, speakParams);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'lesson TTS speak failed: %{public}s',
        e instanceof Error ? e.message : `${e}`);
    }
  }

  private shutdownAudio(): void {
    if (this.ttsEngine !== undefined) {
      try {
        this.ttsEngine.stop();
        this.ttsEngine.shutdown();
      } catch (e) {
      }
      this.ttsEngine = undefined;
    }
    this.audioAvailable = false;
  }

  private startPlayback(index: number): void {
    if (this.lesson.scenes.length === 0) {
      return;
    }
    this.stopTimer();
    this.currentIndex = index < this.lesson.scenes.length ? index : this.lesson.scenes.length - 1;
    this.sceneElapsed = 0;
    this.isFinished = false;
    this.isPlaying = true;
    const scene: AiLessonScene = this.lesson.scenes[this.currentIndex];
    this.speakScene(scene);
    this.timerId = setInterval((): void => {
      this.sceneElapsed++;
      const current: AiLessonScene = this.lesson.scenes[this.currentIndex];
      if (this.sceneElapsed >= current.duration) {
        this.advanceScene();
      }
    }, 1000);
  }

  private advanceScene(): void {
    const next: number = this.currentIndex + 1;
    if (next < this.lesson.scenes.length) {
      this.startPlayback(next);
    } else {
      this.stopPlayback(true);
    }
  }

  private stopPlayback(finished: boolean): void {
    this.stopTimer();
    this.isPlaying = false;
    this.isFinished = finished;
    if (this.ttsEngine !== undefined) {
      try {
        this.ttsEngine.stop();
      } catch (e) {
      }
    }
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private completedSeconds(): number {
    let seconds: number = 0;
    for (let i: number = 0; i < this.currentIndex && i < this.lesson.scenes.length; i++) {
      seconds += this.lesson.scenes[i].duration;
    }
    if (this.currentIndex < this.lesson.scenes.length) {
      seconds += Math.min(this.sceneElapsed, this.lesson.scenes[this.currentIndex].duration);
    }
    return seconds;
  }

  build() {
    Column() {
      PageHeader({ title: 'AI 讲解视频' })

      if (this.notFound) {
        EmptyBlock({ message: '错题不存在或已被删除' })
      } else if (this.loading) {
        this.LoadingView()
      } else if (this.loadError.length > 0) {
        this.ErrorView()
      } else {
        this.PlayerView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  LoadingView() {
    Column({ space: 14 }) {
      Text('🦉')
        .fontSize(52)
        .width(110)
        .height(110)
        .textAlign(TextAlign.Center)
        .backgroundColor('33FFFFFF')
        .borderRadius(38)
        .translate({ y: this.loading ? -4 : 4 })
        .animation({ duration: 700, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
      Text('醒醒正在为你准备讲解视频...')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text('会根据年级调整讲法，还会分析这次的答案')
        .fontSize(13)
        .fontColor('#DDFFFFFF')
      Progress({ value: 40, total: 100, type: ProgressType.Linear })
        .width('68%')
        .height(8)
        .color(Color.White)
        .backgroundColor('33FFFFFF')
        .borderRadius(4)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(24)
    .linearGradient({
      angle: 145,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
    })
  }

  @Builder
  ErrorView() {
    Column({ space: 14 }) {
      EmptyBlock({ message: this.loadError })
      PrimaryButton({
        text: '🔄 重新生成',
        onTap: (): void => {
          this.generateLesson();
        }
      })
        .width('72%')
    }
    .width('100%')
    .padding(24)
  }

  @Builder
  PlayerView() {
    Scroll() {
      Column() {
        this.VideoStage()
        this.ControlBar()
        this.SceneList()

        Row({ space: 8 }) {
          Text(this.audioAvailable ? '🔊 语音讲解' : '🔇 当前设备语音不可用')
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
            .layoutWeight(1)
          Text(this.audioEnabled ? '关闭语音' : '开启语音')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.PRIMARY)
            .padding({ top: 6, bottom: 6 })
            .onClick(() => {
              this.audioEnabled = !this.audioEnabled;
              if (!this.audioEnabled && this.ttsEngine !== undefined) {
                try {
                  this.ttsEngine.stop();
                } catch (e) {
                }
              } else if (this.audioEnabled && this.ttsEngine === undefined) {
                this.initializeAudio().then((): void => {
                  if (this.isPlaying && this.currentIndex < this.lesson.scenes.length) {
                    this.speakScene(this.lesson.scenes[this.currentIndex]);
                  }
                });
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 20 })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  VideoStage() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Column() {
            Text(this.lesson.title)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.lesson.gradeLevel} · ${this.completedSeconds()}/${this.lesson.totalDuration}秒`)
              .fontSize(11)
              .fontColor('#D8FFFFFF')
              .margin({ top: 3 })
          }
          .layoutWeight(1)

          Text('🦉')
            .fontSize(25)
            .width(48)
            .height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor('26FFFFFF')
            .borderRadius(18)
            .translate({
              x: this.sceneElapsed % 2 === 0 ? 2 : -2,
              y: this.sceneElapsed % 2 === 0 ? -2 : 2
            })
            .animation({ duration: 500, curve: Curve.EaseInOut })
        }
        .width('100%')

        Column() {
          this.SceneContent(this.lesson.scenes[this.currentIndex])
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')

        Column() {
          Text(this.lesson.scenes[this.currentIndex].narration)
            .fontSize(14)
            .fontColor(Color.White)
            .lineHeight(21)
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('66000000')
        .borderRadius(14)
        .margin({ top: 10 })
      }
      .width('100%')
      .height(390)
      .padding(16)

      if (this.isFinished) {
        Column() {
          Text('🎉')
            .fontSize(44)
          Text('讲解完成')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 6 })
          Text('再看一遍，巩固一下！')
            .fontSize(13)
            .fontColor('#E7FFFFFF')
            .margin({ top: 4 })
        }
        .width('100%')
        .height(390)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('66000000')
      }
    }
    .width('100%')
    .height(390)
    .linearGradient({
      angle: 145,
      colors: [[AppColors.GRADIENT_START, 0], [AppColors.PRIMARY, 0.5], [AppColors.GRADIENT_END, 1]]
    })
    .clip(true)
  }

  @Builder
  SceneContent(scene: AiLessonScene) {
    Column({ space: 10 }) {
      if (scene.screen.type === 'cover') {
        Text('🦉')
          .fontSize(58)
          .margin({ bottom: 4 })
        Text(scene.screen.title.length > 0 ? scene.screen.title : this.lesson.title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(scene.screen.text)
          .fontSize(14)
          .fontColor('#E0FFFFFF')
          .textAlign(TextAlign.Center)
      } else if (scene.screen.type === 'question') {
        Text(scene.screen.title.length > 0 ? scene.screen.title : '我们先读题')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF7C9')
          .width('100%')
        Text(scene.screen.text)
          .fontSize(18)
          .fontColor(Color.White)
          .lineHeight(28)
          .width('100%')
      } else if (scene.screen.type === 'compare') {
        Text(scene.screen.title.length > 0 ? scene.screen.title : '看看两个答案')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF7C9')
          .width('100%')
        Row({ space: 10 }) {
          this.AnswerCard('我的答案', scene.screen.studentAnswer, AppColors.SOFT_DANGER)
          this.AnswerCard('正确答案', scene.screen.standardAnswer, AppColors.SOFT_SECONDARY)
        }
        .width('100%')
      } else if (scene.screen.type === 'steps') {
        Text(scene.screen.title.length > 0 ? scene.screen.title : '一步一步来')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF7C9')
          .width('100%')
        ForEach(scene.screen.steps, (step: string, index: number) => {
          Row({ space: 10 }) {
            Text(`${index + 1}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY)
              .width(28)
              .height(28)
              .textAlign(TextAlign.Center)
              .backgroundColor(Color.White)
              .borderRadius(14)
            Text(step)
              .fontSize(15)
              .fontColor(Color.White)
              .lineHeight(22)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }, (step: string) => step)
      } else {
        Text('💡')
          .fontSize(48)
          .margin({ bottom: 4 })
        Text(scene.screen.title.length > 0 ? scene.screen.title : scene.subtitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(scene.screen.text)
          .fontSize(15)
          .fontColor('#E0FFFFFF')
          .lineHeight(23)
          .textAlign(TextAlign.Center)
      }

      if (scene.screen.highlight.length > 0) {
        Text(scene.screen.highlight)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('66000000')
          .borderRadius(15)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  AnswerCard(label: string, value: string, color: Resource) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
      Text(value.length > 0 ? value : '未提供')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor(color)
    .borderRadius(14)
  }

  @Builder
  ControlBar() {
    Column({ space: 10 }) {
      Progress({
        value: this.completedSeconds(),
        total: this.lesson.totalDuration,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(8)
        .color(AppColors.PRIMARY)
        .backgroundColor(AppColors.BG_CHIP)
        .borderRadius(4)

      Row({ space: 10 }) {
        Button('⏮')
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(AppColors.BG_CARD)
          .fontColor(AppColors.PRIMARY)
          .borderRadius(22)
          .enabled(this.currentIndex > 0 || this.isFinished)
          .onClick(() => {
            this.startPlayback(this.currentIndex > 0 ? this.currentIndex - 1 : 0);
          })

        Button(this.isFinished ? '🔄 重播' : (this.isPlaying ? '⏸ 暂停' : '▶ 播放'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .height(44)
          .linearGradient({
            angle: 135,
            colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.6], [AppColors.GRADIENT_END, 1]]
          })
          .fontColor(Color.White)
          .borderRadius(22)
          .onClick(() => {
            if (this.isFinished) {
              this.startPlayback(0);
            } else if (this.isPlaying) {
              this.stopPlayback(false);
            } else if (this.currentIndex < this.lesson.scenes.length) {
              this.startPlayback(this.currentIndex);
            }
          })

        Button('⏭')
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(AppColors.BG_CARD)
          .fontColor(AppColors.PRIMARY)
          .borderRadius(22)
          .enabled(this.currentIndex + 1 < this.lesson.scenes.length)
          .onClick(() => {
            this.startPlayback(this.currentIndex + 1);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  SceneList() {
    Column() {
      Text('讲解章节')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 8 })

      ForEach(this.lesson.scenes, (scene: AiLessonScene, index: number) => {
        Row({ space: 10 }) {
          Text(`${index + 1}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === this.currentIndex ? Color.White : AppColors.PRIMARY)
            .width(28)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor(index === this.currentIndex ? AppColors.SOLID_PRIMARY : AppColors.SOFT_PRIMARY)
            .borderRadius(14)
          Column() {
            Text(scene.subtitle)
              .fontSize(14)
              .fontColor(index === this.currentIndex ? AppColors.TEXT_PRIMARY : AppColors.TEXT_REGULAR)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(`${scene.duration}秒 · ${scene.screen.type}`)
              .fontSize(11)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          Text(index === this.currentIndex && this.isPlaying ? '▶' : '›')
            .fontSize(16)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .borderRadius(14)
        .backgroundColor(index === this.currentIndex ? AppColors.SOFT_PRIMARY : Color.Transparent)
        .onClick(() => {
          this.startPlayback(index);
        })
      }, (scene: AiLessonScene) => scene.id + scene.subtitle)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .margin({ left: 16, right: 16, top: 12 })
  }
}
