import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { AnswerType, GradingMethod, InputMethod, PointsActionType, Subject } from '../models/Enums';
import { ReminderSettings } from '../models/ReminderSettings';
import { dbHelper } from '../repository/DatabaseHelper';
import { ReviewSubmitter, ReviewSubmitResult } from '../usecases/ReviewSubmitter';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AppColors, AppSizes, AppStrings, generateId, isAnswerEqual } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';

function enabledSubjects(settings: ReminderSettings): Subject[] {
  const list: Subject[] = [];
  if (settings.mathEnabled) {
    list.push(Subject.MATH);
  }
  if (settings.chineseEnabled) {
    list.push(Subject.CHINESE);
  }
  if (settings.englishEnabled) {
    list.push(Subject.ENGLISH);
  }
  if (settings.scienceEnabled) {
    list.push(Subject.SCIENCE);
  }
  return list;
}

@Entry
@Component
struct ReviewPage {
  @State reviewList: Mistake[] = [];
  @State currentIndex: number = 0;
  @State studentAnswer: string = '';
  @State isCorrect: boolean = false;
  @State showResult: boolean = false;
  @State submitBusy: boolean = false;
  @State correctCount: number = 0;
  @State totalCount: number = 0;
  @State totalPoints: number = 0;
  @State isFinished: boolean = false;
  @State startTime: number = 0;
  @State selectedAnswer: number = -1;
  @State showSelfEval: boolean = false;
  private alive: boolean = true;
  private profileDirty: boolean = false;

  aboutToAppear(): void {
    this.startTime = Date.now();
    this.loadReviewList();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.recomputeProfileIfDirty();
  }

  /**
   * 画像重算移至会话结束（T018/FR-021）：onBackPress / 完成时一次性触发。
   */
  private async recomputeProfileIfDirty(): Promise<void> {
    if (!this.profileDirty) {
      return;
    }
    this.profileDirty = false;
    try {
      await KnowledgeProfileAggregator.recomputeForStudent('stu_default');
    } catch (e) {
      PerformanceMonitor.warn('recompute profile at session end failed');
    }
  }

  /**
   * 复习队列（T034/FR-012）：按当前学生 + 每日上限 + 科目开关消费。
   */
  async loadReviewList(): Promise<void> {
    const settings: ReminderSettings = await dbHelper.queryReminderSettings('stu_default');
    const subjects: Subject[] = enabledSubjects(settings);
    this.reviewList = await dbHelper.queryTodayReviewMistakes('stu_default', settings.dailyLimit, subjects);
    this.totalCount = this.reviewList.length;
  }

  onBackPress(): boolean {
    if (this.isFinished || this.reviewList.length === 0 || this.currentIndex >= this.totalCount) {
      return false;
    }
    this.confirmExit();
    return true;
  }

  private confirmExit(): void {
    this.getUIContext().showAlertDialog({
      title: '退出复习',
      message: '本次复习尚未完成，退出后已提交的记录会保留，确定退出吗？',
      primaryButton: {
        value: '继续复习',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '退出',
        action: (): void => {
          this.exitNow();
        }
      }
    });
  }

  private exitNow(): void {
    this.recomputeProfileIfDirty();
    this.getUIContext().getRouter().back();
  }

  build() {
    Column() {
      if (this.isFinished) {
        this.SummaryView()
      } else {
        PageHeader({ title: AppStrings.PAGE_REVIEW })
        if (this.reviewList.length === 0) {
          Column() {
            Text('📭')
              .fontSize(48)
              .margin({ bottom: 12 })
            Text(AppStrings.NO_REVIEW_TODAY)
              .fontSize(16)
              .fontColor(AppColors.TEXT_SECONDARY)
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
    Scroll() {
      Column() {
        Row({ space: 10 }) {
          Text(`${this.currentIndex + 1}/${this.totalCount}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.PRIMARY)
          Stack({ alignContent: Alignment.Start }) {
            Column() {
            }
            .width('100%')
            .height(8)
            .backgroundColor(AppColors.BG_CHIP)
            .borderRadius(4)
            Progress({ value: this.currentIndex + 1, total: this.totalCount, type: ProgressType.Linear })
              .width('100%')
              .height(8)
              .color(AppColors.PRIMARY)
              .backgroundColor(Color.Transparent)
              .borderRadius(4)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 6 })

        Column() {
          Text(this.reviewList[this.currentIndex].ocrText)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .lineHeight(28)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_LG)
        .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
        .margin({ left: 16, right: 16, top: 10 })

        if (!this.showResult) {
          this.AnswerInput(this.reviewList[this.currentIndex])
        } else {
          this.AnswerResult(this.reviewList[this.currentIndex])
        }
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
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

        Button(this.submitBusy ? '提交中...' : AppStrings.REVIEW_SUBMIT)
          .width('90%')
          .height(44)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppColors.SOLID_PRIMARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .shadow({ radius: 10, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
          .margin({ top: 24, bottom: 24 })
          .enabled(!this.submitBusy)
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
          .backgroundColor(AppColors.SOLID_SECONDARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ right: 8 })
          .enabled(!this.submitBusy)
          .onClick(() => {
            this.recordReview(mistake, true, GradingMethod.SUBJECTIVE_SELFREPORT);
          })
        Button('✗ 不一致')
          .layoutWeight(1)
          .height(44)
          .backgroundColor(AppColors.SOLID_DANGER)
          .fontColor(Color.White)
          .borderRadius(22)
          .enabled(!this.submitBusy)
          .onClick(() => {
            this.recordReview(mistake, false, GradingMethod.SUBJECTIVE_SELFREPORT);
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
        .backgroundColor(this.selectedAnswer === idx ? AppColors.ROW_SELECTED : AppColors.BG_CARD)
        .borderRadius(22)
        .border({ width: this.selectedAnswer === idx ? 1.5 : 0, color: AppColors.PRIMARY })
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
        Text('🎉 ' + AppStrings.CORRECT_ANSWER)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.SECONDARY)
      } else {
        Text('💪 ' + AppStrings.WRONG_ANSWER)
          .fontSize(21)
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
        .backgroundColor(AppColors.SOLID_PRIMARY)
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
    Scroll() {
      Column() {
        // 彩带庆祝
        Text('🎉 ✨ 🎈 ✨ 🎉')
          .fontSize(20)
          .margin({ top: 48 })

        // 渐变奖杯徽章
        Column() {
          Text('🏆')
            .fontSize(44)
        }
        .width(112)
        .height(112)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
        })
        .borderRadius(40)
        .shadow({ radius: 18, color: AppColors.SHADOW_PRIMARY, offsetY: 8 })
        .margin({ top: 18 })

        Text(AppStrings.REVIEW_SUMMARY)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ top: 18 })

        // 星星评价（正确率 80%/50% 对应 3/2 星）
        Row({ space: 6 }) {
          Text(this.starAt(0) ? '⭐' : '☆')
            .fontSize(26)
          Text(this.starAt(1) ? '⭐' : '☆')
            .fontSize(26)
          Text(this.starAt(2) ? '⭐' : '☆')
            .fontSize(26)
        }
        .margin({ top: 10 })

        Text(this.totalCount > 0 ? `${Math.round(this.correctCount / this.totalCount * 100)}%` : '0%')
          .fontSize(54)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.PRIMARY)
          .margin({ top: 14 })
          .accessibilityText(`正确率 ${this.totalCount > 0 ? Math.round(this.correctCount / this.totalCount * 100) : 0}%`)

        Text(AppStrings.ACCURACY)
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)

        // 撞色渐变统计瓦片
        Row() {
          this.SummaryTile(`${this.correctCount}`, '答对了', AppColors.MINT_START, AppColors.MINT_END)
          this.SummaryTile(`${this.totalCount - this.correctCount}`, '再练练', AppColors.SUNSET_START, AppColors.SUNSET_END)
          this.SummaryTile(`+${this.totalPoints}`, '赢积分', AppColors.PRIMARY_LIGHT, AppColors.GRADIENT_END)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 28 })

        Text(this.summaryMessage())
          .fontSize(15)
          .fontColor(AppColors.TEXT_REGULAR)
          .margin({ top: 24 })

        Button('返回首页')
          .width('70%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .linearGradient({
            angle: 135,
            colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.55], [AppColors.GRADIENT_END, 1]]
          })
          .fontColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 12, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
          .margin({ top: 32, bottom: 48 })
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Center)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  /** 星星评价：第 idx 颗星是否点亮（正确率 80%→3星、50%→2星、其余1星）。 */
  private starAt(idx: number): boolean {
    const rate: number = this.totalCount > 0 ? this.correctCount / this.totalCount : 0;
    const stars: number = rate >= 0.8 ? 3 : (rate >= 0.5 ? 2 : 1);
    return idx < stars;
  }

  private summaryMessage(): string {
    const rate: number = this.totalCount > 0 ? this.correctCount / this.totalCount : 0;
    if (rate >= 0.8) {
      return '太棒了！错题正在被你一个个消灭 🦉';
    }
    if (rate >= 0.5) {
      return '有进步！把错的题再看看，明天会更好 💪';
    }
    return '别灰心，每道错题都是进步的台阶 🌱';
  }

  @Builder
  SummaryTile(value: string, label: string, gradStart: Resource, gradEnd: Resource) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text(label)
        .fontSize(11)
        .fontColor('#E6FFFFFF')
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 16, bottom: 16 })
    .linearGradient({ angle: 140, colors: [[gradStart, 0], [gradEnd, 1]] })
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .margin({ left: 4, right: 4 })
    .accessibilityText(`${label} ${value}`)
  }

  private onSubmitTap(mistake: Mistake): void {
    if (this.submitBusy) {
      return;
    }
    const answer = this.studentAnswer.trim();
    if (mistake.answerType === AnswerType.SUBJECTIVE) {
      this.showSelfEval = true;
      return;
    }
    if (answer.length === 0) {
      Toast.show('请先输入答案');
      return;
    }
    // 归一化判分（T035/FR-017）：不受全半角/空格/大小写差异影响
    this.recordReview(mistake, isAnswerEqual(mistake.standardAnswer, answer), GradingMethod.OBJECTIVE_AUTO);
  }

  /**
   * 提交走 ReviewSubmitter（T018/FR-006）：页面不再直接编排多步 DB 写。
   */
  private async recordReview(mistake: Mistake, correct: boolean, gradingMethod: GradingMethod): Promise<void> {
    if (this.submitBusy) {
      return;
    }
    this.submitBusy = true;
    const durationSeconds = Math.round((Date.now() - this.startTime) / 1000);
    const inputMethod = this.getInputMethod(mistake.answerType);
    const pointsAwarded = correct ? PointsCalculator.getPointsForAction(PointsActionType.ON_TIME_REVIEW) : 0;
    const log: ReviewLog = ReviewLog.create(generateId(), mistake.id, gradingMethod, inputMethod,
      correct, durationSeconds, pointsAwarded);
    const result: ReviewSubmitResult = await ReviewSubmitter.submit(mistake, log);
    if (!this.alive) {
      return;
    }
    this.submitBusy = false;
    if (!result.success) {
      Toast.show('提交失败，请重试');
      PerformanceMonitor.warn('review submit failed: ' + result.reason);
      return;
    }
    this.isCorrect = correct;
    if (correct) {
      this.correctCount++;
    }
    this.totalPoints += result.pointsAwarded;
    this.profileDirty = true;
    this.showResult = true;
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
      this.recomputeProfileIfDirty();
    }
  }

  private getInputMethod(answerType: AnswerType): InputMethod {
    if (answerType === AnswerType.CHOICE) {
      return InputMethod.SELECT;
    }
    if (answerType === AnswerType.NUMERIC) {
      return InputMethod.NUMERIC_KEYPAD;
    }
    return InputMethod.KEYBOARD;
  }
}
