import { Mistake } from '../models/Mistake';
import { Subject, AnswerType, ErrorType, PointsActionType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { StreakCalculator } from '../usecases/StreakCalculator';
import { MediaService } from '../services/MediaService';
import { AiService } from '../services/AiService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AppColors, AppStrings, generateId } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';
import { CaptureSourceStep, AiAnalyzingStep, AiReviewStep, CaptureResultStep, CaptureFormPayload } from '../components/CaptureSteps';

/**
 * 录入页（AI 全图识别版）：
 * 选图 → 质检 → AI 直接识别整张照片 → 核对保存。
 * 本页只做流程编排与持久化；本地 OCR 与手动框选环节已完全移除。
 */
@Entry
@Component
struct CapturePage {
  @State currentStep: number = 0; // 0选图 1AI识别 2核对 3完成
  @State qualityIssue: string = '';
  @State imagePath: string = '';
  @State aiError: string = '';
  @State aiRecognized: boolean = false;
  @State aiTagNames: string = '';
  @State pointsEarned: number = PointsCalculator.getPointsForAction(PointsActionType.CAPTURE);

  // 核对步骤表单字段（@Link 双向同步）
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
        CaptureSourceStep({
          qualityIssue: this.qualityIssue,
          onPick: (fromCamera: boolean): void => {
            this.startCapture(fromCamera);
          }
        })
      } else if (this.currentStep === 1) {
        AiAnalyzingStep({
          imagePath: this.imagePath,
          qualityIssue: this.qualityIssue,
          aiError: this.aiError,
          onRetry: (): void => {
            this.startAi();
          },
          onManual: (): void => {
            this.enterManualReview();
          },
          onBack: (): void => {
            this.backToSource();
          }
        })
      } else if (this.currentStep === 2) {
        AiReviewStep({
          imagePath: this.imagePath,
          aiRecognized: this.aiRecognized,
          aiTagNames: this.aiTagNames,
          questionText: $questionText,
          knowledgeSummary: $knowledgeSummary,
          standardAnswer: $standardAnswer,
          studentAnswer: $studentAnswer,
          selectedSubject: $selectedSubject,
          answerType: $answerType,
          selectedErrorType: $selectedErrorType,
          selectedTagIds: $selectedTagIds,
          onRepick: (): void => {
            this.backToSource();
          },
          onSave: (payload: CaptureFormPayload): void => {
            this.saveMistake(payload);
          }
        })
      } else {
        CaptureResultStep({
          pointsEarned: this.pointsEarned,
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

  /** 选图 + 本地轻量质检（解码失败不放行；模糊等仅软提示）。 */
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
        // 质检 fail-closed：解码失败不放行
        this.qualityIssue = quality.issue;
        Toast.show('图片读取失败，请重新选择清晰的图片');
        return;
      }
      this.qualityIssue = quality.issue;
    } else {
      this.qualityIssue = '';
    }
    this.startAi();
  }

  /** AI 全图识别：整张照片直接交给多模态模型，一次性提取题目/答案/分类/知识点。 */
  private async startAi(): Promise<void> {
    this.aiError = '';
    this.aiRecognized = false;
    this.currentStep = 1;
    const traceStart: number = PerformanceMonitor.startTrace('ai_recognize');
    try {
      const ai = await AiService.recognizeQuestion(this.imagePath);
      if (!this.alive) {
        return;
      }
      PerformanceMonitor.endTrace('ai_recognize', traceStart);
      if (ai.ok) {
        this.questionText = ai.question;
        this.aiRecognized = true;
      }
      this.studentAnswer = ai.myAnswer;
      this.standardAnswer = ai.standardAnswer;
      this.knowledgeSummary = ai.knowledgeSummary;
      this.selectedSubject = ai.subject;
      this.answerType = ai.answerType;
      this.selectedErrorType = ai.errorType;
      this.aiTagNames = ai.tags.join('\n');
      PerformanceMonitor.writeStatistic('ai_recognize_result', {
        'ok': ai.ok,
        'question_length': ai.question.length,
        'tags': ai.tags.length
      });
      this.currentStep = 2;
      if (!ai.ok) {
        Toast.show('AI 未能识别出题目，请手动核对填写');
      }
    } catch (e) {
      PerformanceMonitor.endTrace('ai_recognize', traceStart);
      if (!this.alive) {
        return;
      }
      PerformanceMonitor.writeFault('ai_recognize_error', { 'reason': 'request_failed' });
      this.aiRecognized = false;
      this.aiError = e instanceof Error ? e.message : 'AI 识别失败，请检查网络后重试';
    }
  }

  /** AI 失败后的兜底：跳过识别直接进入手动填写（FR 允许仅保存原图流程不阻塞）。 */
  private enterManualReview(): void {
    this.aiRecognized = false;
    this.aiError = '';
    this.currentStep = 2;
  }

  private backToSource(): void {
    this.currentStep = 0;
    this.imagePath = '';
    this.qualityIssue = '';
    this.aiError = '';
    this.aiRecognized = false;
  }

  /**
   * 持久化：写库检查 DbResult，失败如实提示不进入成功页；
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
      mistake.studentAnswer = payload.studentAnswer;
      mistake.knowledgeSummary = payload.knowledgeSummary;
      const insertRes = await dbHelper.insertMistake(mistake);
      if (!insertRes.success) {
        Toast.show('保存失败：' + (insertRes.reason.length > 0 ? insertRes.reason : '请重试'));
        return;
      }

      const pointsLog = PointsCalculator.createPointsLog(generateId(), mistake.studentId, PointsActionType.CAPTURE);
      await dbHelper.insertPointsLog(pointsLog);

      // 连击积分：当日首次学习行为发放 STREAK 分，按日去重
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
      AnalyticsTracker.trackAiConfirm(mistake.studentId, this.aiRecognized, !this.aiRecognized);
      PerformanceMonitor.writeBehavior('capture_mistake', {
        'subject': mistake.subject, 'answer_type': mistake.answerType, 'by_ai': this.aiRecognized
      });

      this.pointsEarned = pointsLog.points;
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
    this.qualityIssue = '';
    this.aiError = '';
    this.aiRecognized = false;
    this.aiTagNames = '';
  }
}
