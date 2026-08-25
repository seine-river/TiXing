import { Mistake, CropFracs } from '../models/Mistake';
import { Subject, AnswerType, ErrorType, PointsActionType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { StreakCalculator } from '../usecases/StreakCalculator';
import { MediaService } from '../services/MediaService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AppColors, AppStrings, generateId } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';
import { SourceSelectStep, RegionSelectStep, OcrConfirmStep, ResultStep, CaptureFormPayload } from '../components/CaptureSteps';

/**
 * 录入页（T046/FR-024）：拆分为 CaptureSteps 四步子组件后，
 * 本页只保留流程编排（选图→质检→区域→OCR→确认）与持久化；
 * 跨步骤表单字段由本页持有，经 @Link 与确认步骤同步。
 */
@Entry
@Component
struct CapturePage {
  @State currentStep: number = 0;
  @State qualityIssue: string = '';
  @State imagePath: string = '';
  @State ocrText: string = '';
  @State ocrConfidence: number = 0;

  // 区域步骤上下文
  @State regionTarget: string = 'question';
  @State regionImagePath: string = '';
  @State regionBusy: boolean = false;
  @State imageAspectRatio: number = 0.75;
  @State regionInitLeft: number = 0.08;
  @State regionInitTop: number = 0.08;
  @State regionInitRight: number = 0.92;
  @State regionInitBottom: number = 0.92;
  private questionFracs: CropFracs | undefined = undefined;

  // 答案图片（标准/我的）
  @State stdImage: string = '';
  @State myImage: string = '';
  private stdFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
  private myFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);

  // 确认步骤表单字段（@Link 双向同步）
  @State questionText: string = '';
  @State knowledgeSummary: string = '';
  @State standardAnswer: string = '';
  @State studentAnswer: string = '';
  @State selectedSubject: Subject = Subject.MATH;
  @State answerType: AnswerType = AnswerType.TEXT;
  @State selectedErrorType: ErrorType = ErrorType.OTHER;
  @State selectedTagIds: string[] = [];

  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  build() {
    Column() {
      PageHeader({ title: AppStrings.PAGE_CAPTURE })

      if (this.currentStep === 0) {
        SourceSelectStep({
          qualityIssue: this.qualityIssue,
          onPick: (fromCamera: boolean): void => {
            this.startCapture(fromCamera);
          }
        })
      } else if (this.currentStep === 1) {
        RegionSelectStep({
          imagePath: this.regionImagePath,
          imageRatio: this.imageAspectRatio,
          regionHint: this.regionTarget === 'question' ? '拖动四角调整题目识别区域' : '拖动四角框选答案区域',
          confirmLabel: this.regionTarget === 'question' ? '识别此区域' : '确认区域',
          fullLabel: this.regionTarget === 'question' ? '识别全图' : '使用全图',
          busy: this.regionBusy,
          initialLeftFrac: this.regionInitLeft,
          initialTopFrac: this.regionInitTop,
          initialRightFrac: this.regionInitRight,
          initialBottomFrac: this.regionInitBottom,
          onConfirm: (fracs: CropFracs | undefined): void => {
            this.onRegionConfirm(fracs);
          },
          onBack: (): void => {
            this.onRegionBack();
          }
        })
      } else if (this.currentStep === 2) {
        OcrConfirmStep({
          imagePath: this.imagePath,
          questionFracs: this.questionFracs,
          ocrConfidence: this.ocrConfidence,
          stdImagePath: this.stdImage,
          myImagePath: this.myImage,
          stdFracs: this.stdFracs,
          myFracs: this.myFracs,
          questionText: $questionText,
          knowledgeSummary: $knowledgeSummary,
          standardAnswer: $standardAnswer,
          studentAnswer: $studentAnswer,
          selectedSubject: $selectedSubject,
          answerType: $answerType,
          selectedErrorType: $selectedErrorType,
          selectedTagIds: $selectedTagIds,
          onRepickQuestion: (): void => {
            this.currentStep = 0;
          },
          onRegionSelect: (target: string): void => {
            this.enterRegion(target);
          },
          onAnswerImagePicked: (target: string, path: string): void => {
            if (target === 'standard') {
              this.stdImage = path;
              this.stdFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
            } else {
              this.myImage = path;
              this.myFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
            }
          },
          onFracsChanged: (target: string, fracs: CropFracs): void => {
            if (target === 'standard') {
              this.stdFracs = fracs;
            } else if (target === 'mine') {
              this.myFracs = fracs;
            }
          },
          onSave: (payload: CaptureFormPayload): void => {
            this.saveMistake(payload);
          }
        })
      } else {
        ResultStep({
          onContinue: (): void => {
            this.resetFlow();
          },
          onExit: (): void => {
            this.getUIContext().getRouter().back();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  private async startCapture(fromCamera: boolean): Promise<void> {
    let path: string | undefined = undefined;
    try {
      path = fromCamera ? await MediaService.capturePhoto() : await MediaService.pickFromAlbum();
    } finally {
      if (!this.alive) {
        return;
      }
    }
    if (path === undefined || path.length === 0) {
      Toast.show(fromCamera ? '相机不可用或未拍照，请改用相册选取' : '未选取图片，请重试');
      this.qualityIssue = '';
      return;
    }
    this.imagePath = path;
    const quality = await CaptureOrchestrator.checkImageQuality(path);
    if (!this.alive) {
      return;
    }
    if (!quality.passed) {
      if (quality.issue === 'decode_failed') {
        // 质检 fail-closed（T032/FR-015）：解码失败不放行
        this.qualityIssue = quality.issue;
        Toast.show('图片读取失败，请重新选择清晰的图片');
        return;
      }
      this.qualityIssue = quality.issue;
    } else {
      this.qualityIssue = '';
    }
    this.enterRegion('question');
  }

  private async enterRegion(target: string): Promise<void> {
    this.regionTarget = target;
    if (target === 'question') {
      this.regionImagePath = this.imagePath;
      this.setRegionInit(0.08, 0.08, 0.92, 0.92);
    } else if (target === 'standard') {
      this.regionImagePath = this.stdImage;
      this.setRegionInit(this.stdFracs.leftFrac, this.stdFracs.topFrac, this.stdFracs.rightFrac, this.stdFracs.bottomFrac);
    } else {
      this.regionImagePath = this.myImage;
      this.setRegionInit(this.myFracs.leftFrac, this.myFracs.topFrac, this.myFracs.rightFrac, this.myFracs.bottomFrac);
    }
    await this.loadRegionImageSize();
    this.currentStep = 1;
  }

  private setRegionInit(left: number, top: number, right: number, bottom: number): void {
    this.regionInitLeft = left;
    this.regionInitTop = top;
    this.regionInitRight = right;
    this.regionInitBottom = bottom;
  }

  private async loadRegionImageSize(): Promise<void> {
    const pm = await MediaService.loadScaledPixelMap(this.regionImagePath, 320);
    if (pm !== undefined) {
      try {
        const info = await pm.getImageInfo();
        this.imageAspectRatio = info.size.width > 0 && info.size.height > 0
          ? info.size.width / info.size.height : 0.75;
        await pm.release();
      } catch (e) {
      }
    }
  }

  private onRegionBack(): void {
    if (this.regionTarget === 'question') {
      this.currentStep = 0;
    } else {
      this.currentStep = 2;
    }
  }

  private onRegionConfirm(fracs: CropFracs | undefined): void {
    if (this.regionTarget === 'question') {
      this.runOcr(fracs);
      return;
    }
    if (this.regionTarget === 'standard') {
      this.stdFracs = fracs !== undefined ? fracs : new CropFracs(0, 0, 1, 1);
    } else if (this.regionTarget === 'mine') {
      this.myFracs = fracs !== undefined ? fracs : new CropFracs(0, 0, 1, 1);
    }
    this.currentStep = 2;
  }

  private async runOcr(fracs: CropFracs | undefined): Promise<void> {
    this.regionBusy = true;
    const localResult = await CaptureOrchestrator.performOcr(this.imagePath, fracs);
    if (!this.alive) {
      this.regionBusy = false;
      return;
    }
    this.ocrText = localResult.questionText.text;
    this.ocrConfidence = localResult.questionText.confidence;
    this.questionText = localResult.questionText.text;
    this.questionFracs = fracs;
    this.regionBusy = false;
    this.currentStep = 2;
    if (this.ocrText.length === 0) {
      Toast.show('本地识别未提取到文字，正在用AI识别图片...');
    }
  }

  /**
   * 持久化（T019/T033）：写库检查 DbResult，失败如实提示不进入成功页；
   * 当日首次学习行为发放连击积分。
   */
  private async saveMistake(payload: CaptureFormPayload): Promise<void> {
    try {
      const mistake = Mistake.create(
        generateId(),
        'stu_default',
        this.imagePath,
        payload.questionText,
        payload.subject,
        payload.tagIds.slice(),
        payload.answerType,
        payload.standardAnswer
      );
      mistake.isConfirmed = true;
      mistake.errorType = payload.errorType;
      mistake.ocrConfidence = payload.ocrConfidence;
      mistake.studentAnswer = payload.studentAnswer;
      mistake.knowledgeSummary = payload.knowledgeSummary;
      const insertRes = await dbHelper.insertMistake(mistake);
      if (!insertRes.success) {
        Toast.show('保存失败：' + (insertRes.reason.length > 0 ? insertRes.reason : '请重试'));
        return;
      }

      const pointsLog = PointsCalculator.createPointsLog(generateId(), mistake.studentId, PointsActionType.CAPTURE);
      await dbHelper.insertPointsLog(pointsLog);

      // 连击积分（T033/FR-016）：当日首次学习行为发放 STREAK 分，按日去重
      const activeDays: string[] = await dbHelper.queryActiveDays(mistake.studentId);
      const lastStreakDay: string = await dbHelper.queryLastPointsActionDay(mistake.studentId,
        PointsActionType.STREAK);
      if (StreakCalculator.shouldAwardToday(activeDays, lastStreakDay)) {
        const streakLog = PointsCalculator.createPointsLog(
          `pts_streak_${StreakCalculator.todayIso()}`, mistake.studentId, PointsActionType.STREAK);
        await dbHelper.insertPointsLog(streakLog);
      }

      await KnowledgeProfileAggregator.recomputeForStudent(mistake.studentId);
      AnalyticsTracker.trackCapture(mistake.studentId);
      AnalyticsTracker.trackOcrConfirm(mistake.studentId, mistake.ocrConfidence,
        this.ocrConfidence < CaptureOrchestrator.getConfidenceThreshold() && this.ocrText.length > 0);
      PerformanceMonitor.writeBehavior('capture_mistake', {
        'subject': mistake.subject, 'answer_type': mistake.answerType
      });

      this.currentStep = 3;
    } catch (e) {
      Toast.show('保存失败，请重试');
    }
  }

  private resetFlow(): void {
    this.currentStep = 0;
    this.questionText = '';
    this.knowledgeSummary = '';
    this.standardAnswer = '';
    this.studentAnswer = '';
    this.answerType = AnswerType.TEXT;
    this.selectedErrorType = ErrorType.OTHER;
    this.selectedTagIds = [];
    this.imagePath = '';
    this.stdImage = '';
    this.myImage = '';
    this.stdFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
    this.myFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
    this.regionTarget = 'question';
    this.regionImagePath = '';
    this.qualityIssue = '';
    this.ocrText = '';
    this.ocrConfidence = 0;
    this.questionFracs = undefined;
    this.imageAspectRatio = 0.75;
  }
}
