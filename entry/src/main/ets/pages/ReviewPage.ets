import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { MistakeStatus, Subject, AnswerType, GradingMethod, InputMethod, PointsActionType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { ReviewScheduler } from '../usecases/ReviewScheduler';
import { MasteryEvaluator } from '../usecases/MasteryEvaluator';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { AppColors, AppSizes, AppStrings, subjectLabel, generateId } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct ReviewPage {
  @State reviewList: Mistake[] = [];
  @State currentIndex: number = 0;
  @State studentAnswer: string = '';
  @State isCorrect: boolean = false;
  @State showResult: boolean = false;
  @State correctCount: number = 0;
  @State totalCount: number = 0;
  @State totalPoints: number = 0;
  @State isFinished: boolean = false;
  @State startTime: number = 0;
  @State reviewMode: string = 'today';
  @State selectedAnswer: number = -1;
  @State showSelfEval: boolean = false;

  aboutToAppear(): void {
    this.startTime = Date.now();
    this.loadReviewList();
  }

  async loadReviewList(): Promise<void> {
    this.reviewList = await dbHelper.queryTodayReviewMistakes();
    this.totalCount = this.reviewList.length;
  }

  build() {
    Column() {
      if (this.isFinished) {
        this.SummaryView()
      } else {
        PageHeader({ title: '复习错题' })
        if (this.reviewList.length === 0) {
          Column() {
            Text('📭')
              .fontSize(48)
              .margin({ bottom: 12 })
            Text(AppStrings.NO_REVIEW_TODAY)
              .fontSize(16)
              .fontColor('#909399')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.currentIndex < this.reviewList.length) {
          this.ReviewQuestionView()
        } else {
          this.SummaryView()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  ReviewQuestionView() {
    Column() {
      Row() {
        Text(`第 ${this.currentIndex + 1} / ${this.totalCount} 题`)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
        Progress({ value: this.currentIndex + 1, total: this.totalCount, type: ProgressType.Linear })
          .layoutWeight(1)
          .margin({ left: 12 })
          .color(AppColors.PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      Column() {
        Text(this.reviewList[this.currentIndex].ocrText)
          .fontSize(18)
          .fontColor(AppColors.TEXT_PRIMARY)
          .lineHeight(28)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColors.BG_CARD)
      .borderRadius(AppSizes.CORNER_RADIUS_SM)
      .margin({ left: 16, right: 16, top: 12 })

      if (!this.showResult) {
        this.AnswerInput(this.reviewList[this.currentIndex])
      } else {
        this.AnswerResult(this.reviewList[this.currentIndex])
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  AnswerInput(mistake: Mistake) {
    Column() {
      Text('作答')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .padding({ left: 16, top: 12 })

      if (this.showSelfEval) {
        this.SubjectiveSelfEval(mistake)
      } else {
        if (mistake.answerType === AnswerType.CHOICE) {
          this.ChoiceInput(mistake)
        } else if (mistake.answerType === AnswerType.NUMERIC) {
          this.NumericInput()
        } else {
          this.TextInput()
        }

        if (mistake.answerType === AnswerType.TEXT) {
          Text('💡 可使用输入法的语音/手写输入，无需逐字打字')
            .fontSize(11)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
            .width('100%')
            .padding({ left: 16, top: 4 })
        }

        Button(mistake.answerType === AnswerType.SUBJECTIVE ? AppStrings.REVIEW_SUBMIT : AppStrings.REVIEW_SUBMIT)
          .width('90%')
          .height(44)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 24 })
          .onClick(() => {
            this.onSubmitTap(mistake);
          })
      }
    }
    .width('100%')
  }

  @Builder
  SubjectiveSelfEval(mistake: Mistake) {
    Column() {
      Text('参考答案')
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ bottom: 4 })
      Text(mistake.standardAnswer.length > 0 ? mistake.standardAnswer : '（无参考答案）')
        .fontSize(16)
        .fontColor(AppColors.SECONDARY)
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.BG_PAGE)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ bottom: 16 })

      Text('你的回答与参考一致吗？')
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ bottom: 12 })

      Row() {
        Button('✓ 一致，已掌握')
          .layoutWeight(1)
          .height(44)
          .backgroundColor(AppColors.SECONDARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ right: 8 })
          .onClick(() => {
            this.recordSubjective(mistake, true);
          })
        Button('✗ 不一致')
          .layoutWeight(1)
          .height(44)
          .backgroundColor(AppColors.DANGER)
          .fontColor(Color.White)
          .borderRadius(22)
          .onClick(() => {
            this.recordSubjective(mistake, false);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  ChoiceInput(mistake: Mistake) {
    Column() {
      ForEach(['A', 'B', 'C', 'D'], (option: string, idx: number) => {
        Row() {
          Radio({ value: option, group: 'choice' })
            .checked(this.selectedAnswer === idx)
            .onChange((isChecked: boolean) => {
              if (isChecked) {
                this.selectedAnswer = idx;
                this.studentAnswer = option;
              }
            })
          Text(option)
            .fontSize(16)
            .fontColor(AppColors.TEXT_PRIMARY)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.selectedAnswer === idx ? '#EBF1FA' : AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ top: 6 })
      }, (option: string) => option)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  NumericInput() {
    Column() {
      TextInput({ text: this.studentAnswer, placeholder: '请输入数字答案' })
        .type(InputType.Number)
        .fontSize(24)
        .textAlign(TextAlign.Center)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_CARD)
        .onChange((value: string) => {
          this.studentAnswer = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  TextInput() {
    Column() {
      TextInput({ text: this.studentAnswer, placeholder: '请输入答案' })
        .fontSize(18)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_CARD)
        .onChange((value: string) => {
          this.studentAnswer = value;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  AnswerResult(mistake: Mistake) {
    Column() {
      if (this.isCorrect) {
        Text('✓ ' + AppStrings.CORRECT_ANSWER)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.SECONDARY)
      } else {
        Text('✗ ' + AppStrings.WRONG_ANSWER)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.DANGER)
        Text('正确答案: ' + mistake.standardAnswer)
          .fontSize(16)
          .fontColor(AppColors.TEXT_REGULAR)
          .margin({ top: 8 })
      }

      Button(this.currentIndex + 1 < this.totalCount ? AppStrings.REVIEW_NEXT : AppStrings.REVIEW_FINISH)
        .width('90%')
        .height(44)
        .backgroundColor(AppColors.PRIMARY)
        .fontColor(Color.White)
        .borderRadius(22)
        .margin({ top: 24 })
        .onClick(() => {
          this.nextQuestion();
        })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  SummaryView() {
    Column() {
      Text(AppStrings.REVIEW_SUMMARY)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 40 })

      Text(this.totalCount > 0 ? `${Math.round(this.correctCount / this.totalCount * 100)}%` : '0%')
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.PRIMARY)
        .margin({ top: 24 })

      Text(AppStrings.ACCURACY)
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)

      Row() {
        Column() {
          Text(`${this.correctCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.SECONDARY)
          Text('正确')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.totalCount - this.correctCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.DANGER)
          Text('错误')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .layoutWeight(1)

        Column() {
          Text(`+${this.totalPoints}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.WARNING)
          Text(AppStrings.POINTS_EARNED)
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 32 })

      Text('继续加油，每天进步一点点！')
        .fontSize(16)
        .fontColor(AppColors.TEXT_REGULAR)
        .margin({ top: 32 })

      Button('返回首页')
        .width('60%')
        .height(44)
        .backgroundColor(AppColors.PRIMARY)
        .fontColor(Color.White)
        .borderRadius(22)
        .margin({ top: 32 })
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  private onSubmitTap(mistake: Mistake): void {
    const answer = this.studentAnswer.trim();
    if (mistake.answerType === AnswerType.SUBJECTIVE) {
      this.showSelfEval = true;
      return;
    }
    if (answer.length === 0) {
      return;
    }
    let correct = answer === mistake.standardAnswer;
    this.recordReview(mistake, correct, GradingMethod.OBJECTIVE_AUTO);
  }

  private recordSubjective(mistake: Mistake, correct: boolean): void {
    this.recordReview(mistake, correct, GradingMethod.SUBJECTIVE_SELFREPORT);
  }

  private recordReview(mistake: Mistake, correct: boolean, gradingMethod: GradingMethod): void {
    const durationSeconds = Math.round((Date.now() - this.startTime) / 1000);

    this.isCorrect = correct;
    this.showResult = true;

    if (correct) {
      this.correctCount++;
    }

    ReviewScheduler.scheduleNextReview(mistake, correct);

    const logId = generateId();
    const inputMethod = this.getInputMethod(mistake.answerType);
    const pointsAwarded = correct ? PointsCalculator.getPointsForAction(PointsActionType.ON_TIME_REVIEW) : 0;
    this.totalPoints += pointsAwarded;

    const log = ReviewLog.create(logId, mistake.id, gradingMethod, inputMethod, correct, durationSeconds, pointsAwarded);
    dbHelper.insertReviewLog(log);
    if (mistake.firstReviewDuration === 0) {
      mistake.firstReviewDuration = durationSeconds;
    }
    dbHelper.updateMistake(mistake);

    AnalyticsTracker.trackReviewSubmit(mistake.studentId, correct, inputMethod);

    const existingLogs = dbHelper.queryReviewLogs(mistake.id);
    existingLogs.then((logs: ReviewLog[]) => {
      const newStatus = MasteryEvaluator.evaluateMastery(mistake, logs);
      if (newStatus === MistakeStatus.MASTERED && mistake.status !== MistakeStatus.MASTERED) {
        mistake.status = MistakeStatus.MASTERED;
        dbHelper.updateMistake(mistake);
        const pointsLog = PointsCalculator.createPointsLog(generateId(), mistake.studentId, PointsActionType.MASTERY_ACHIEVED);
        dbHelper.insertPointsLog(pointsLog);
        this.totalPoints += pointsLog.points;
        AnalyticsTracker.trackMastery(mistake.studentId);
      }
      KnowledgeProfileAggregator.recomputeForStudent(mistake.studentId);
    });
  }

  private nextQuestion(): void {
    this.currentIndex++;
    this.showResult = false;
    this.showSelfEval = false;
    this.studentAnswer = '';
    this.selectedAnswer = -1;
    this.startTime = Date.now();
    if (this.currentIndex >= this.totalCount) {
      this.isFinished = true;
    }
  }

  private getInputMethod(answerType: AnswerType): InputMethod {
    if (answerType === AnswerType.CHOICE) return InputMethod.SELECT;
    if (answerType === AnswerType.NUMERIC) return InputMethod.NUMERIC_KEYPAD;
    return InputMethod.KEYBOARD;
  }
}
