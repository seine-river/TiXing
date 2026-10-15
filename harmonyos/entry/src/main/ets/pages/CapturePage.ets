import { Mistake } from '../models/Mistake';
import { KnowledgeTag } from '../models/KnowledgeTag';
import { Subject, AnswerType, ErrorType, PointsActionType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { StreakCalculator } from '../usecases/StreakCalculator';
import { MediaService } from '../services/MediaService';
import { AiService, AiQuestionResult } from '../services/AiService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AppColors, AppStrings, generateId } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';
import { CaptureSourceStep, AiAnalyzingStep, QuestionSelectStep, AiReviewStep, CaptureResultStep, CaptureFormPayload } from '../components/CaptureSteps';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LOG_DOMAIN: number = 0xA005;
const LOG_TAG: string = 'TiXingCapture';

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
  @State questionItems: AiQuestionResult[] = [];
  @State selectedQuestionIndexes: number[] = [];
  @State batchSaving: boolean = false;
  @State savedQuestionCount: number = 1;
  @State failedQuestionCount: number = 0;
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

  onBackPress(): boolean {
    return this.handleBack();
  }

  build() {
    Column() {
      PageHeader({
        title: AppStrings.PAGE_CAPTURE,
        onBack: (): void => {
          this.handleHeaderBack();
        }
      })

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
      } else if (this.currentStep === 4) {
        QuestionSelectStep({
          imagePath: this.imagePath,
          questionItems: this.questionItems,
          selectedIndexes: this.selectedQuestionIndexes,
          batchSaving: this.batchSaving,
          onToggleSelect: (index: number): void => {
            this.toggleQuestionSelection(index);
          },
          onSelect: (item: AiQuestionResult): void => {
            this.applyQuestionResult(item);
          },
          onSaveSelected: (items: AiQuestionResult[]): void => {
            this.saveQuestionResults(items);
          },
          onSelectAll: (): void => {
            this.selectAllQuestions();
          },
          onClearSelect: (): void => {
            this.clearQuestionSelection();
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
          savedCount: this.savedQuestionCount,
          failedCount: this.failedQuestionCount,
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

  /**
   * 标题栏返回：优先处理页面内部步骤；未接管的场景沿用路由返回。
   */
  private handleHeaderBack(): void {
    if (!this.handleBack()) {
      this.getUIContext().getRouter().back();
    }
  }

  /**
   * 系统返回：返回 true 表示已由当前页面接管。
   * 多题核对页返回时必须回到题目列表，而不是直接退出录入流程。
   */
  private handleBack(): boolean {
    if (this.batchSaving) {
      return true;
    }
    if (this.currentStep === 2 && this.questionItems.length > 1) {
      this.currentStep = 4;
      return true;
    }
    if (this.currentStep === 1 || this.currentStep === 2) {
      this.backToSource();
      return true;
    }
    return false;
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
      const batch = await AiService.recognizeQuestions(this.imagePath);
      if (!this.alive) {
        return;
      }
      PerformanceMonitor.endTrace('ai_recognize', traceStart);
      this.questionItems = batch.items;
      this.clearQuestionSelection();
      PerformanceMonitor.writeStatistic('ai_recognize_result', {
        'ok': batch.ok,
        'question_count': batch.items.length
      });
      if (batch.items.length > 1) {
        this.currentStep = 4;
        Toast.show(`识别到 ${batch.items.length} 道题，请选择`);
        return;
      }
      if (batch.items.length === 1 && batch.items[0].ok) {
        this.applyQuestionResult(batch.items[0]);
        return;
      }
      this.aiRecognized = false;
      this.currentStep = 2;
      this.aiError = batch.error.length > 0 ? batch.error : 'AI 未能识别出题目';
      Toast.show('AI 未能识别出题目，请手动核对填写');
    } catch (e) {
      PerformanceMonitor.endTrace('ai_recognize', traceStart);
      if (!this.alive) {
        return;
      }
      const detail: string = e instanceof Error
        ? `name=${e.name}, message=${e.message}, stack=${e.stack === undefined ? '' : e.stack}`
        : `${e}`;
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'AI recognize question failed: imagePath=%{public}s, error=%{public}s',
        this.imagePath, detail);
      PerformanceMonitor.writeFault('ai_recognize_error', {
        'reason': 'request_failed',
        'error': e instanceof Error ? e.message : 'non_error_exception'
      });
      this.aiRecognized = false;
      this.aiError = AiService.userMessage(e, 'AI 识别失败，请检查网络后重试');
    }
  }

  private applyQuestionResult(ai: AiQuestionResult): void {
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
    this.currentStep = 2;
  }

  private toggleQuestionSelection(index: number): void {
    if (index < 0 || index >= this.questionItems.length) {
      return;
    }
    const selected: number[] = this.selectedQuestionIndexes.slice();
    const pos: number = selected.indexOf(index);
    if (pos >= 0) {
      selected.splice(pos, 1);
    } else {
      selected.push(index);
    }
    this.selectedQuestionIndexes = selected;
  }

  private selectAllQuestions(): void {
    const selected: number[] = [];
    for (let i: number = 0; i < this.questionItems.length; i++) {
      selected.push(i);
    }
    this.selectedQuestionIndexes = selected;
  }

  private clearQuestionSelection(): void {
    this.selectedQuestionIndexes = [];
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
    this.questionItems = [];
    this.clearQuestionSelection();
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

  /** 多题批量保存：一张照片中的多道题共用原图，分别生成独立错题记录。 */
  private async saveQuestionResults(items: AiQuestionResult[]): Promise<void> {
    if (this.batchSaving) {
      return;
    }
    if (items.length === 0) {
      Toast.show('请先勾选要录入的题目');
      return;
    }

    this.batchSaving = true;
    let successCount: number = 0;
    let failedCount: number = 0;
    const studentId: string = 'stu_default';

    try {
      for (const item of items) {
        if (!item.ok || item.question.trim().length === 0) {
          failedCount++;
          continue;
        }

        const tagIds: string[] = await this.matchTagIds(item.subject, item.tags);
        const mistake = Mistake.create(
          generateId(),
          studentId,
          this.imagePath,
          item.question,
          item.subject,
          tagIds,
          item.answerType,
          item.standardAnswer
        );
        mistake.isConfirmed = true;
        mistake.errorType = item.errorType;
        mistake.studentAnswer = item.myAnswer;
        mistake.knowledgeSummary = item.knowledgeSummary;

        const insertRes = await dbHelper.insertMistake(mistake);
        if (!insertRes.success) {
          failedCount++;
          continue;
        }

        const pointsLog = PointsCalculator.createPointsLog(
          generateId(), studentId, PointsActionType.CAPTURE);
        await dbHelper.insertPointsLog(pointsLog);
        AnalyticsTracker.trackCapture(studentId);
        AnalyticsTracker.trackAiConfirm(studentId, true, false);
        PerformanceMonitor.writeBehavior('capture_mistake', {
          'subject': mistake.subject,
          'answer_type': mistake.answerType,
          'by_ai': true
        });
        successCount++;
      }

      if (successCount > 0) {
        await this.awardDailyStreakIfNeeded(studentId);
        await KnowledgeProfileAggregator.recomputeForStudent(studentId);
        this.pointsEarned = successCount *
          PointsCalculator.getPointsForAction(PointsActionType.CAPTURE);
        this.savedQuestionCount = successCount;
        this.failedQuestionCount = failedCount;
        this.currentStep = 3;
        if (failedCount > 0) {
          Toast.show(`成功录入 ${successCount} 道，${failedCount} 道失败`);
        } else {
          Toast.show(`成功录入 ${successCount} 道错题`);
        }
      } else {
        Toast.show('批量录入失败，请重试');
      }
    } catch (e) {
      Toast.show('批量录入失败，请重试');
      hilog.error(LOG_DOMAIN, LOG_TAG, 'batch save mistakes failed: %{public}s',
        e instanceof Error ? e.message : `${e}`);
    }
    this.batchSaving = false;
  }

  private async matchTagIds(subject: Subject, names: string[]): Promise<string[]> {
    if (names.length === 0) {
      return [];
    }
    const tags: KnowledgeTag[] = await dbHelper.queryKnowledgeTags(subject);
    const ids: string[] = [];
    for (const tag of tags) {
      for (const name of names) {
        if (tag.name === name || tag.name.indexOf(name) >= 0 || name.indexOf(tag.name) >= 0) {
          if (ids.indexOf(tag.id) < 0) {
            ids.push(tag.id);
          }
        }
      }
    }
    return ids;
  }

  private async awardDailyStreakIfNeeded(studentId: string): Promise<void> {
    const activeDays: string[] = await dbHelper.queryActiveDays(studentId);
    const lastStreakDay: string = await dbHelper.queryLastPointsActionDay(studentId,
      PointsActionType.STREAK);
    if (StreakCalculator.shouldAwardToday(activeDays, lastStreakDay)) {
      const streakLog = PointsCalculator.createPointsLog(
        `pts_streak_${StreakCalculator.todayIso()}`, studentId, PointsActionType.STREAK);
      await dbHelper.insertPointsLog(streakLog);
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
    this.clearQuestionSelection();
    this.batchSaving = false;
    this.savedQuestionCount = 1;
    this.failedQuestionCount = 0;
  }
}
