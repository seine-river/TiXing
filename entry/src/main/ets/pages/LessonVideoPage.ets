import { Mistake } from '../models/Mistake';
import { Student } from '../models/Student';
import { dbHelper } from '../repository/DatabaseHelper';
import { AiService, AiServiceError, AiLesson, AiLessonScene, AiLessonVisual } from '../services/AiService';
import { AppColors, AppSizes, generateId, subjectLabel } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';
import { EmptyBlock } from '../components/BasicWidgets';
import { LessonVideoParams } from '../common/RouteParams';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Toast } from '../common/Toast';

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
  // 页面首帧就可能渲染；数据尚未加载完成时必须先进入 Loading，不能访问空 scenes。
  @State loading: boolean = true;
  @State loadingStage: string = '正在打开讲解工坊...';
  @State loadingProgress: number = 6;
  @State loadingSeconds: number = 0;
  @State loadError: string = '';
  @State errorDetail: string = '';
  @State notFound: boolean = false;
  @State currentIndex: number = 0;
  @State sceneElapsed: number = 0;
  @State isPlaying: boolean = false;
  @State isFinished: boolean = false;
  @State audioEnabled: boolean = true;
  @State audioAvailable: boolean = false;

  private mistakeId: string = '';
  private timerId: number = -1;
  private loadingTimerId: number = -1;
  private generating: boolean = false;
  private ttsEngine: textToSpeech.TextToSpeechEngine | undefined = undefined;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    const params = this.getUIContext().getRouter().getParams() as LessonVideoParams;
    this.mistakeId = params?.mistakeId ?? '';
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'lesson page appear: mistakeId=%{public}s, hasParams=%{public}b',
      this.mistakeId, params !== undefined);
    if (this.mistakeId.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'lesson page missing mistakeId');
      this.notFound = true;
      return;
    }
    this.loadData();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.stopLoadingPulse();
    this.stopPlayback(false);
    this.shutdownAudio();
  }

  private async loadData(): Promise<void> {
    this.setLoadingStage('正在读取错题信息...', 12);
    try {
      const m: Mistake | undefined = await dbHelper.queryMistakeById(this.mistakeId);
      if (m === undefined) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'lesson mistake not found: mistakeId=%{public}s', this.mistakeId);
        this.notFound = true;
        this.loading = false;
        return;
      }
      this.mistake = m;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'lesson mistake loaded: mistakeId=%{public}s, questionLength=%{public}d, ' +
          'studentAnswerLength=%{public}d, standardAnswerLength=%{public}d, subject=%{public}s',
        m.id, m.ocrText.length, m.studentAnswer.length, m.standardAnswer.length, m.subject);
      this.setLoadingStage('正在获取学生年级...', 20);
      const s: Student | undefined = await dbHelper.queryStudent(m.studentId);
      if (s !== undefined) {
        this.student = s;
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'lesson student loaded: studentId=%{public}s, grade=%{public}s', s.id, s.grade);
      } else {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'lesson student not found, fallback grade: studentId=%{public}s, fallbackGrade=%{public}s',
          m.studentId, this.student.grade);
      }
      await this.generateLesson();
    } catch (e) {
      const detail: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      this.loading = false;
      this.loadError = '读取错题信息失败';
      this.errorDetail = detail;
      this.logLongError('load lesson data failed', detail);
    }
  }

  private async generateLesson(): Promise<void> {
    if (this.generating) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'generateLesson ignored: another generation is running');
      return;
    }
    this.generating = true;
    this.loading = true;
    this.loadingSeconds = 0;
    this.loadError = '';
    this.errorDetail = '';
    this.stopPlayback(false);
    this.startLoadingPulse();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'generateLesson flow start: mistakeId=%{public}s, questionLength=%{public}d, ' +
        'studentAnswerLength=%{public}d, standardAnswerLength=%{public}d, grade=%{public}s',
      this.mistake.id, this.mistake.ocrText.length, this.mistake.studentAnswer.length,
      this.mistake.standardAnswer.length, this.student.grade);
    // TTS 初始化与 GLM 脚本生成并行，最多可节省 5 秒等待。
    const audioReady: Promise<void> = this.initializeAudioWithTimeout();
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
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'generateLesson returned but page disappeared: mistakeId=%{public}s', this.mistake.id);
        return;
      }
      this.lesson = lesson;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'generateLesson flow received script: sceneCount=%{public}d, totalDuration=%{public}d',
        lesson.scenes.length, lesson.totalDuration);
      this.stopLoadingPulse();
      this.setLoadingStage('讲解脚本已生成，正在排版动画...', 82);
      await audioReady;
      if (!this.alive) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'generateLesson audio finished but page disappeared');
        return;
      }
      this.setLoadingStage('马上开始播放...', 97);
      this.loading = false;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'generateLesson flow ready to play: sceneCount=%{public}d, audioAvailable=%{public}b',
        this.lesson.scenes.length, this.audioAvailable);
      this.startPlayback(0);
    } catch (e) {
      if (!this.alive) {
        return;
      }
      this.loadError = e instanceof Error ? e.message : '讲解视频生成失败，请重试';
      this.errorDetail = e instanceof AiServiceError
        ? e.diagnostic
        : (e instanceof Error
          ? `name=${e.name}\nmessage=${e.message}\nstack=${e.stack === undefined ? '' : e.stack}`
          : `${e}`);
      this.logLongError('generate lesson failed',
        `summary=${this.loadError}\n${this.errorDetail}`);
      this.loading = false;
    }
    this.stopLoadingPulse();
    this.generating = false;
  }

  private setLoadingStage(stage: string, progress: number): void {
    this.loadingStage = stage;
    this.loadingProgress = progress;
  }

  private startLoadingPulse(): void {
    this.stopLoadingPulse();
    this.setLoadingStage('正在理解题目和学生答案...', 28);
    this.loadingTimerId = setInterval((): void => {
      this.loadingSeconds++;
      this.loadingProgress = Math.min(this.loadingProgress + 1, 88);
      this.loadingStage = this.generationStageHint();
    }, 1000);
  }

  private stopLoadingPulse(): void {
    if (this.loadingTimerId >= 0) {
      clearInterval(this.loadingTimerId);
      this.loadingTimerId = -1;
    }
  }

  private generationStageHint(): string {
    if (this.loadingSeconds < 4) {
      return '正在理解题目和学生答案...';
    }
    if (this.loadingSeconds < 8) {
      return '正在定位可能的错误原因...';
    }
    if (this.loadingSeconds < 13) {
      return `正在设计适合${this.student.grade}年级的讲解步骤...`;
    }
    if (this.loadingSeconds < 19) {
      return '正在拆解动画章节...';
    }
    if (this.loadingSeconds < 28) {
      return 'AI 还在生成中，通常需要 5-20 秒...';
    }
    return '网络较慢，仍在等待 GLM 返回，请不要退出...';
  }

  private copyErrorDetail(): void {
    const fullReport: string = 'AI视频讲解错误报告\n' +
      `summary=${this.loadError}\n` +
      `detailLength=${this.errorDetail.length}\n` +
      '---\n' +
      this.errorDetail;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        fullReport
      );
      pasteboard.getSystemPasteboard().setDataSync(data);
      Toast.show(`已复制完整报错信息（${fullReport.length} 字符）`);
      return;
    } catch (e) {
      const copyError: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'copy lesson error sync failed: %{public}s',
        copyError);
      this.logLongError('copy lesson error sync failed',
        `clipboardError=${copyError}\nreportLength=${fullReport.length}\nreport=${fullReport}`);
    }

    // 个别设备对同步写剪贴板不稳定时，再尝试一次异步写入。
    try {
      const retryData: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        fullReport
      );
      pasteboard.getSystemPasteboard().setData(retryData)
        .then((): void => {
          Toast.show(`已复制完整报错信息（${fullReport.length} 字符）`);
        })
        .catch((e: Object): void => {
          Toast.show('系统剪贴板暂不可用，请长按诊断内容手动复制');
          const asyncCopyError: string = e instanceof Error
            ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
            : `${e}`;
          hilog.warn(LOG_DOMAIN, LOG_TAG, 'copy lesson error async failed: %{public}s',
            asyncCopyError);
          this.logLongError('copy lesson error async failed',
            `clipboardError=${asyncCopyError}\nreportLength=${fullReport.length}\nreport=${fullReport}`);
        });
    } catch (e) {
      Toast.show('系统剪贴板暂不可用，请长按诊断内容手动复制');
      const fallbackError: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      this.logLongError('copy lesson error create failed',
        `clipboardError=${fallbackError}\nreportLength=${fullReport.length}`);
    }
  }

  /**
   * 分段输出完整错误，避免 HiLog 因单行过长截断关键诊断。
   */
  private logLongError(stage: string, content: string): void {
    const text: string = content.length > 0 ? content : '(empty diagnostic)';
    const chunkLength: number = 800;
    const totalChunks: number = Math.ceil(text.length / chunkLength);
    for (let i: number = 0; i < totalChunks; i++) {
      const start: number = i * chunkLength;
      const end: number = Math.min(start + chunkLength, text.length);
      hilog.error(LOG_DOMAIN, LOG_TAG,
        '%{public}s [%{public}d/%{public}d]: %{public}s',
        stage, i + 1, totalChunks, text.substring(start, end));
    }
  }

  private async initializeAudioWithTimeout(): Promise<void> {
    this.setLoadingStage('正在准备语音朗读...', 88);
    const timeoutMs: number = 5000;
    let timedOut: boolean = false;
    const timeout: Promise<void> = new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        timedOut = true;
        resolve();
      }, timeoutMs);
    });
    await Promise.race([this.initializeAudio(), timeout]);
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'lesson audio initialization race finished: timedOut=%{public}b, audioAvailable=%{public}b, engineReady=%{public}b',
      timedOut, this.audioAvailable, this.ttsEngine !== undefined);
  }

  private async initializeAudio(): Promise<void> {
    if (this.ttsEngine !== undefined || !this.audioEnabled) {
      this.audioAvailable = this.ttsEngine !== undefined;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'lesson TTS init skipped: audioEnabled=%{public}b, engineReady=%{public}b',
        this.audioEnabled, this.ttsEngine !== undefined);
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'lesson TTS init start: language=zh-CN, person=13');
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
      hilog.info(LOG_DOMAIN, LOG_TAG, 'lesson TTS init success');
    } catch (e) {
      this.audioAvailable = false;
      const detail: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      this.logLongError('lesson TTS engine unavailable', detail);
    }
  }

  private speakScene(scene: AiLessonScene): void {
    if (!this.audioEnabled || !this.audioAvailable || this.ttsEngine === undefined) {
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'lesson TTS speak skipped: audioEnabled=%{public}b, audioAvailable=%{public}b, engineReady=%{public}b, sceneId=%{public}s',
        this.audioEnabled, this.audioAvailable, this.ttsEngine !== undefined, scene.id);
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'lesson TTS speak start: sceneId=%{public}s, narrationLength=%{public}d',
      scene.id, scene.narration.length);
    try {
      if (this.ttsEngine.isBusy()) {
        this.ttsEngine.stop();
      }
      const speakParams: textToSpeech.SpeakParams = {
        requestId: generateId()
      };
      this.ttsEngine.speak(scene.narration, speakParams);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'lesson TTS speak submitted');
    } catch (e) {
      const detail: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      this.logLongError('lesson TTS speak failed', detail);
    }
  }

  private shutdownAudio(): void {
    if (this.ttsEngine !== undefined) {
      try {
        this.ttsEngine.stop();
        this.ttsEngine.shutdown();
        hilog.info(LOG_DOMAIN, LOG_TAG, 'lesson TTS shutdown success');
      } catch (e) {
        const detail: string = e instanceof Error
          ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
          : `${e}`;
        this.logLongError('lesson TTS shutdown failed', detail);
      }
      this.ttsEngine = undefined;
    }
    this.audioAvailable = false;
  }

  private startPlayback(index: number): void {
    if (this.lesson.scenes.length === 0) {
      this.logLongError('lesson playback start failed',
        `reason=emptyScenes, requestedIndex=${index}, mistakeId=${this.mistake.id}`);
      return;
    }
    this.stopTimer();
    this.currentIndex = index < this.lesson.scenes.length ? index : this.lesson.scenes.length - 1;
    this.sceneElapsed = 0;
    this.isFinished = false;
    this.isPlaying = true;
    const scene: AiLessonScene = this.lesson.scenes[this.currentIndex];
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'lesson playback start: index=%{public}d, sceneId=%{public}s, duration=%{public}d, sceneCount=%{public}d',
      this.currentIndex, scene.id, scene.duration, this.lesson.scenes.length);
    this.speakScene(scene);
    this.timerId = setInterval((): void => {
      try {
        if (this.currentIndex < 0 || this.currentIndex >= this.lesson.scenes.length) {
          this.logLongError('lesson playback timer index out of range',
            `currentIndex=${this.currentIndex}, sceneCount=${this.lesson.scenes.length}`);
          this.stopPlayback(false);
          return;
        }
        this.sceneElapsed++;
        const current: AiLessonScene = this.lesson.scenes[this.currentIndex];
        if (this.sceneElapsed >= current.duration) {
          hilog.info(LOG_DOMAIN, LOG_TAG,
            'lesson scene finished: index=%{public}d, sceneId=%{public}s, duration=%{public}d',
            this.currentIndex, current.id, current.duration);
          this.advanceScene();
        }
      } catch (e) {
        const detail: string = e instanceof Error
          ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
          : `${e}`;
        this.logLongError('lesson playback timer failed', detail);
        this.stopPlayback(false);
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
        const detail: string = e instanceof Error
          ? `name=${e.name}, message=${e.message}`
          : `${e}`;
        this.logLongError('lesson TTS stop failed', detail);
      }
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'lesson playback stopped: finished=%{public}b, currentIndex=%{public}d, elapsed=%{public}d',
      finished, this.currentIndex, this.sceneElapsed);
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

  private fractionPercent(visual: AiLessonVisual, index: number): number {
    let numerator: number = 0;
    let denominator: number = 1;
    if (index < visual.numerators.length) {
      numerator = visual.numerators[index];
    }
    if (index < visual.denominators.length) {
      denominator = visual.denominators[index];
    }
    if (index === visual.labels.length - 1 &&
      visual.resultDenominator > 0) {
      numerator = visual.resultNumerator;
      denominator = visual.resultDenominator;
    }
    if (denominator <= 0 || numerator < 0) {
      return 0;
    }
    return Math.min(100, Math.round(numerator * 100 / denominator));
  }

  private activeVisualIndex(visual: AiLessonVisual): number {
    const count: number = Math.max(1, this.visualNodes(visual).length);
    if (this.currentIndex < 0 || this.currentIndex >= this.lesson.scenes.length) {
      return 0;
    }
    const duration: number = Math.max(1, this.lesson.scenes[this.currentIndex].duration);
    const ratio: number = Math.min(1, this.sceneElapsed / duration);
    return Math.min(count - 1, Math.floor(ratio * count));
  }

  private numberLinePercent(visual: AiLessonVisual): number {
    const count: number = this.visualNodes(visual).length;
    if (count <= 1) {
      return 100;
    }
    return Math.max(6, Math.round(this.activeVisualIndex(visual) * 100 / (count - 1)));
  }

  private visualNodes(visual: AiLessonVisual): string[] {
    if (visual.nodes.length > 0) {
      return visual.nodes;
    }
    if (visual.labels.length > 0) {
      return visual.labels;
    }
    return visual.captions;
  }

  private visualFromSteps(steps: string[]): AiLessonVisual {
    const visual: AiLessonVisual = new AiLessonVisual();
    visual.type = 'arrow_flow';
    visual.nodes = steps;
    return visual;
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
      } else if (this.lesson.scenes.length > 0) {
        this.PlayerView()
      } else {
        EmptyBlock({ message: '讲解内容为空，请返回重试' })
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
      Text(this.loadingStage)
        .fontSize(13)
        .fontColor('#DDFFFFFF')
      Progress({ value: this.loadingProgress, total: 100, type: ProgressType.Linear })
        .width('68%')
        .height(8)
        .color(Color.White)
        .backgroundColor('33FFFFFF')
        .borderRadius(4)
        .margin({ top: 8 })
      Text(`已等待 ${this.loadingSeconds} 秒 · 可随时点击左上角返回`)
        .fontSize(11)
        .fontColor('#B8FFFFFF')
        .margin({ top: 4 })
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
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Text('😟')
            .fontSize(32)
            .width(54)
            .height(54)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppColors.SOFT_WARNING)
            .borderRadius(18)
          Column() {
            Text('讲解视频生成失败')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text(this.loadError)
              .fontSize(12)
              .fontColor(AppColors.DANGER)
              .lineHeight(18)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        Column() {
          Row() {
            Text('完整诊断信息')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Text(`${this.errorDetail.length} 字符`)
              .fontSize(11)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
          }
          .width('100%')
          .margin({ bottom: 6 })

          Text(this.errorDetail)
            .fontSize(11)
            .fontColor(AppColors.TEXT_REGULAR)
            .lineHeight(17)
            .fontFamily('monospace')
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.BG_PAGE)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)

        Row({ space: 10 }) {
          Button('📋 复制报错')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppColors.BG_CARD)
            .fontColor(AppColors.PRIMARY)
            .borderRadius(22)
            .border({ width: 1.2, color: AppColors.PRIMARY })
            .layoutWeight(1)
            .onClick(() => {
              this.copyErrorDetail();
            })

          Button('🔄 重新生成')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppColors.SOLID_PRIMARY)
            .fontColor(Color.White)
            .borderRadius(22)
            .layoutWeight(1)
            .onClick(() => {
              this.generateLesson();
            })
        }
        .width('100%')
        .margin({ top: 2, bottom: 20 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
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
      Text(scene.screen.title.length > 0 ? scene.screen.title : scene.subtitle)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFF7C9')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (scene.screen.visual.type.length > 0) {
        this.VisualBoard(scene.screen.visual)
      } else {
        this.LegacySceneBoard(scene)
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
  VisualBoard(visual: AiLessonVisual) {
    Column() {
      if (visual.type === 'fraction_bars') {
        this.FractionBars(visual)
      } else if (visual.type === 'number_line') {
        this.NumberLine(visual)
      } else if (visual.type === 'counters') {
        this.CounterVisual(visual)
      } else if (visual.type === 'shape_combo') {
        this.ShapeCombo(visual)
      } else if (visual.type === 'icon_story') {
        this.IconStory(visual)
      } else {
        this.ArrowFlow(visual)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('26FFFFFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  FractionBars(visual: AiLessonVisual) {
    Column({ space: 9 }) {
      ForEach(visual.labels, (label: string, index: number) => {
        Column({ space: 3 }) {
          Text(label)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === visual.labels.length - 1 ? Color.White : '#DDFFFFFF')
            .width('100%')
          Row() {
            Column() {
            }
            .width(`${this.fractionPercent(visual, index)}%`)
            .height(13)
            .linearGradient({
              angle: 0,
              colors: index === visual.labels.length - 1
                ? [[AppColors.MINT_START, 0], [AppColors.MINT_END, 1]]
                : [[AppColors.SUNSET_START, 0], [AppColors.SUNSET_END, 1]]
            })
            .borderRadius(7)
            .animation({ duration: 700, curve: Curve.EaseOut })
          }
          .width('100%')
          .height(13)
          .backgroundColor('33FFFFFF')
          .borderRadius(7)
        }
        .width('100%')
        .opacity(this.sceneElapsed >= index ? 1 : 0.25)
        .translate({ y: this.sceneElapsed >= index ? 0 : 6 })
        .animation({ duration: 400, curve: Curve.EaseOut })
      }, (label: string, index: number) => `${index}_${label}`)
    }
    .width('100%')
  }

  @Builder
  NumberLine(visual: AiLessonVisual) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Start }) {
        Column() {
        }
        .width('100%')
        .height(5)
        .backgroundColor('59FFFFFF')
        .borderRadius(3)

        Column() {
        }
        .width(`${this.numberLinePercent(visual)}%`)
        .height(5)
        .linearGradient({
          angle: 0,
          colors: [[AppColors.SUNSET_START, 0], [AppColors.MINT_END, 1]]
        })
        .borderRadius(3)
        .animation({ duration: 700, curve: Curve.EaseInOut })
      }
      .width('100%')
      .height(5)

      Row() {
        ForEach(visual.nodes, (node: string, index: number) => {
          Column({ space: 3 }) {
            Circle({ width: index <= this.activeVisualIndex(visual) ? 15 : 10,
              height: index <= this.activeVisualIndex(visual) ? 15 : 10 })
              .fill(index <= this.activeVisualIndex(visual) ? AppColors.MINT_START : '#99FFFFFF')
              .animation({ duration: 300 })
            Text(node)
              .fontSize(10)
              .fontColor(Color.White)
              .maxLines(2)
              .textAlign(TextAlign.Center)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (node: string, index: number) => `${index}_${node}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  CounterVisual(visual: AiLessonVisual) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(visual.icons, (icon: string, index: number) => {
        Column({ space: 3 }) {
          Text(icon)
            .fontSize(27)
          if (index < visual.captions.length) {
            Text(visual.captions[index])
              .fontSize(9)
              .fontColor('#DDFFFFFF')
              .maxLines(1)
          }
        }
        .width(62)
        .height(68)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(index <= this.sceneElapsed ? '33FFFFFF' : '14FFFFFF')
        .borderRadius(16)
        .margin(4)
        .scale(this.sceneElapsed >= index ? { x: 1, y: 1 } : { x: 0.8, y: 0.8 })
        .opacity(this.sceneElapsed >= index ? 1 : 0.25)
        .animation({ duration: 350, curve: Curve.EaseOut })
      }, (icon: string, index: number) => `${index}_${icon}`)
    }
    .width('100%')
  }

  @Builder
  ArrowFlow(visual: AiLessonVisual) {
    Column({ space: 6 }) {
      ForEach(this.visualNodes(visual), (node: string, index: number) => {
        Row({ space: 8 }) {
          Text(`${index + 1}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width(25)
            .height(25)
            .textAlign(TextAlign.Center)
            .backgroundColor(index <= this.activeVisualIndex(visual)
              ? AppColors.SOLID_PRIMARY : '#33FFFFFF')
            .borderRadius(13)
            .animation({ duration: 300 })
          Text(node)
            .fontSize(13)
            .fontWeight(index === this.activeVisualIndex(visual) ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(Color.White)
            .lineHeight(18)
            .layoutWeight(1)
          if (index < this.visualNodes(visual).length - 1) {
            Text('↓')
              .fontSize(14)
              .fontColor('#B8FFFFFF')
          }
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(index === this.activeVisualIndex(visual) ? '33FFFFFF' : '14FFFFFF')
        .borderRadius(14)
        .opacity(index <= this.activeVisualIndex(visual) ? 1 : 0.45)
        .animation({ duration: 300 })
      }, (node: string, index: number) => `${index}_${node}`)
    }
    .width('100%')
  }

  @Builder
  ShapeCombo(visual: AiLessonVisual) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(visual.labels, (label: string, index: number) => {
        Column({ space: 5 }) {
          if (index % 2 === 0) {
            Circle({ width: 42, height: 42 })
              .fill(index === this.activeVisualIndex(visual) ? AppColors.MINT_START : '#47FFFFFF')
              .animation({ duration: 350 })
          } else {
            Rect({ width: 46, height: 34 })
              .fill(index === this.activeVisualIndex(visual) ? AppColors.SUNSET_START : '#47FFFFFF')
              .radiusWidth(8)
              .radiusHeight(8)
              .animation({ duration: 350 })
          }
          Text(label)
            .fontSize(10)
            .fontColor(Color.White)
            .maxLines(2)
            .textAlign(TextAlign.Center)
          if (index < visual.nodes.length) {
            Text(visual.nodes[index])
              .fontSize(9)
              .fontColor('#CCFFFFFF')
              .maxLines(1)
          }
        }
        .width(88)
        .height(94)
        .justifyContent(FlexAlign.Center)
        .padding(5)
        .backgroundColor(index === this.activeVisualIndex(visual) ? '33FFFFFF' : '14FFFFFF')
        .borderRadius(16)
        .margin(4)
        .scale(index === this.activeVisualIndex(visual)
          ? { x: 1.04, y: 1.04 }
          : { x: 0.96, y: 0.96 })
        .animation({ duration: 300 })
      }, (label: string, index: number) => `${index}_${label}`)
    }
    .width('100%')
  }

  @Builder
  IconStory(visual: AiLessonVisual) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        ForEach(visual.icons, (icon: string, index: number) => {
          Text(icon)
            .fontSize(index === this.activeVisualIndex(visual) ? 38 : 28)
            .width(index === this.activeVisualIndex(visual) ? 70 : 56)
            .height(index === this.activeVisualIndex(visual) ? 70 : 56)
            .textAlign(TextAlign.Center)
            .backgroundColor(index === this.activeVisualIndex(visual) ? '3DFFFFFF' : '1FFFFFFF')
            .borderRadius(index === this.activeVisualIndex(visual) ? 24 : 19)
            .animation({ duration: 350, curve: Curve.EaseOut })
        }, (icon: string, index: number) => `${index}_${icon}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      ForEach(visual.captions, (caption: string, index: number) => {
        Text(caption)
          .fontSize(index === this.activeVisualIndex(visual) ? 14 : 11)
          .fontWeight(index === this.activeVisualIndex(visual) ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(index === this.activeVisualIndex(visual) ? Color.White : '#B8FFFFFF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(index === this.activeVisualIndex(visual) ? '33FFFFFF' : Color.Transparent)
          .borderRadius(13)
          .margin({ top: index === 0 ? 0 : 4 })
          .animation({ duration: 300 })
      }, (caption: string, index: number) => `${index}_${caption}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LegacySceneBoard(scene: AiLessonScene) {
    Column({ space: 8 }) {
      if (scene.screen.visual.icons.length > 0) {
        this.IconStory(scene.screen.visual)
      } else {
        Text(scene.screen.text.length > 0 ? scene.screen.text : scene.subtitle)
          .fontSize(16)
          .fontColor(Color.White)
          .lineHeight(24)
          .width('100%')
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (scene.screen.type === 'compare') {
        Row({ space: 10 }) {
          this.AnswerCard('我的答案', scene.screen.studentAnswer, AppColors.SOFT_DANGER)
          this.AnswerCard('正确答案', scene.screen.standardAnswer, AppColors.SOFT_SECONDARY)
        }
        .width('100%')
      } else if (scene.screen.type === 'steps') {
        this.ArrowFlow(this.visualFromSteps(scene.screen.steps))
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
