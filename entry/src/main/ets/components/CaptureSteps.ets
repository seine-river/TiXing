import { Subject, AnswerType, ErrorType, ImageQualityIssue } from '../models/Enums';
import { KnowledgeTag } from '../models/KnowledgeTag';
import { dbHelper } from '../repository/DatabaseHelper';
import { AiService } from '../services/AiService';
import { MediaService } from '../services/MediaService';
import { AppColors, AppSizes, subjectLabel, toFileUri } from '../common/Constants';
import { Toast } from '../common/Toast';
import { FilterChip } from './BasicWidgets';

/**
 * 录入流程步骤组件（AI 全图识别版）：
 * 选图 CaptureSourceStep → AI 识别 AiAnalyzingStep → 核对 AiReviewStep → 完成 CaptureResultStep。
 * 本地 OCR 与手动框选区域环节已移除，整张照片直接交给多模态 AI 识别。
 */

/** 核对页汇总的表单载荷（保存时回传 CapturePage）。 */
export class CaptureFormPayload {
  questionText: string = '';
  knowledgeSummary: string = '';
  standardAnswer: string = '';
  studentAnswer: string = '';
  subject: Subject = Subject.MATH;
  answerType: AnswerType = AnswerType.TEXT;
  errorType: ErrorType = ErrorType.OTHER;
  tagIds: string[] = [];
}

class AnswerTypeOption {
  type: AnswerType = AnswerType.TEXT;
  label: string = '';
}

class ErrorTypeOption {
  type: ErrorType = ErrorType.OTHER;
  label: string = '';
}

class AnalyzeStage {
  icon: string = '';
  title: string = '';
  desc: string = '';
}

function qualityHint(issue: string): string {
  if (issue === ImageQualityIssue.BLUR) {
    return '⚠️ 照片可能模糊，可能影响 AI 识别准确度';
  }
  if (issue === ImageQualityIssue.TILT) {
    return '⚠️ 照片倾斜，建议重新拍摄';
  }
  if (issue === ImageQualityIssue.GLARE) {
    return '⚠️ 照片有反光，建议调整角度重拍';
  }
  if (issue === ImageQualityIssue.LOW_LIGHT) {
    return '⚠️ 光线较暗，建议在明亮处重拍';
  }
  if (issue === 'decode_failed') {
    return '⚠️ 图片读取失败，请重新选择';
  }
  return '';
}

/** 第一步：拍照 / 相册（AI 全图识别入口）。 */
@Component
export struct CaptureSourceStep {
  @Prop qualityIssue: string = '';
  onPick: (fromCamera: boolean) => void = (_f: boolean): void => {
  };

  build() {
    Scroll() {
      Column() {
        // 顶部视觉区：吉祥物「醒醒」+ 对话气泡
        Row({ space: 14 }) {
          Text('🦉')
            .fontSize(40)
            .width(84)
            .height(84)
            .textAlign(TextAlign.Center)
            .linearGradient({
              angle: 135,
              colors: [[AppColors.GRADIENT_START, 0], [AppColors.GRADIENT_END, 1]]
            })
            .borderRadius(30)
            .shadow({ radius: 14, color: AppColors.SHADOW_PRIMARY, offsetY: 6 })
            .accessibilityText('吉祥物醒醒')
          Column() {
            Text('嗨，我是醒醒！')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY)
            Text('拍一道错题照片，我帮你识别题目、\n提取答案、总结知识点')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
              .lineHeight(18)
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor(AppColors.SOFT_PRIMARY)
          .borderRadius(16)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 20, right: 20, top: 32, bottom: 8 })

        Text('AI 智能录题')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ top: 16 })

        // 主操作
        Column() {
          Button('📷  拍照识别')
            .width('100%')
            .height(52)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppColors.SOLID_PRIMARY)
            .fontColor(Color.White)
            .borderRadius(26)
            .accessibilityText('拍照识别错题')
            .onClick(() => {
              this.onPick(true);
            })
          Button('🖼️  从相册选取')
            .width('100%')
            .height(48)
            .fontSize(15)
            .backgroundColor(AppColors.BG_CARD)
            .fontColor(AppColors.PRIMARY)
            .borderRadius(24)
            .border({ width: 1, color: AppColors.PRIMARY })
            .margin({ top: 12 })
            .accessibilityText('从相册选取错题照片')
            .onClick(() => {
              this.onPick(false);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        // AI 能力说明
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          this.FeatureChip('🧠', '全图智能识别', AppColors.SOFT_PRIMARY)
          this.FeatureChip('✍️', '答案提取', AppColors.SOFT_WARNING)
          this.FeatureChip('📚', '学科判断', AppColors.SOFT_INFO)
          this.FeatureChip('🏷️', '知识点总结', AppColors.SOFT_SECONDARY)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18 })

        // 拍摄小贴士
        Column() {
          Row() {
            Text('💡 拍摄小贴士')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
          }
          .width('100%')
          .margin({ bottom: 8 })
          this.TipRow('光线充足，整道题目完整入镜')
          this.TipRow('尽量包含作答与红笔批改痕迹，AI 可提取答案')
          this.TipRow('手写作答也能识别，拍清晰即可')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 18 })

        if (this.qualityIssue.length > 0 && qualityHint(this.qualityIssue).length > 0) {
          Text(qualityHint(this.qualityIssue))
            .fontSize(14)
            .fontColor(AppColors.WARNING)
            .padding({ left: 16, right: 16, top: 16 })
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  FeatureChip(icon: string, text: string, softBg: Resource) {
    Row({ space: 4 }) {
      Text(icon)
        .fontSize(14)
      Text(text)
        .fontSize(12)
        .fontColor(AppColors.TEXT_REGULAR)
    }
    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
    .backgroundColor(softBg)
    .borderRadius(16)
    .margin(4)
  }

  @Builder
  TipRow(text: string) {
    Row({ space: 8 }) {
      Text('·')
        .fontSize(14)
        .fontColor(AppColors.PRIMARY)
        .fontWeight(FontWeight.Bold)
      Text(text)
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 6 })
  }
}

/** 第二步：AI 全图识别中 / 失败兜底。 */
@Component
export struct AiAnalyzingStep {
  @Prop imagePath: string = '';
  @Prop @Watch('onErrorChange') aiError: string = '';
  @Prop qualityIssue: string = '';
  onRetry: () => void = (): void => {
  };
  onManual: () => void = (): void => {
  };
  onBack: () => void = (): void => {
  };

  @State stage: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.startStageTimer();
  }

  aboutToDisappear(): void {
    this.stopStageTimer();
  }

  /** 重试时错误态清空，进度阶段从头播放。 */
  onErrorChange(): void {
    if (this.aiError.length === 0) {
      this.startStageTimer();
    } else {
      this.stopStageTimer();
    }
  }

  private startStageTimer(): void {
    this.stopStageTimer();
    this.stage = 0;
    this.timerId = setInterval((): void => {
      if (this.stage < 2) {
        this.stage = this.stage + 1;
      }
    }, 3500);
  }

  private stopStageTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private stages(): AnalyzeStage[] {
    const s1 = new AnalyzeStage();
    s1.icon = '📷';
    s1.title = '读取照片';
    s1.desc = '已完成图像质量检测';
    const s2 = new AnalyzeStage();
    s2.icon = '🧠';
    s2.title = 'AI 识别题目与答案';
    s2.desc = '理解整张图片，提取题目和作答';
    const s3 = new AnalyzeStage();
    s3.icon = '🏷️';
    s3.title = '总结知识点';
    s3.desc = '判断学科题型，生成知识标签';
    return [s1, s2, s3];
  }

  build() {
    Scroll() {
      Column() {
        // 照片预览
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(toFileUri(this.imagePath))
            .width('100%')
            .height(280)
            .objectFit(ImageFit.Contain)
            .sourceSize({ width: 1080, height: 1080 })
            .draggable(false)
            .accessibilityText('待识别的错题照片')
        }
        .width('100%')
        .backgroundColor(AppColors.IMAGE_VIEWER_BG)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .clip(true)
        .margin({ left: 16, right: 16, top: 12 })

        if (this.qualityIssue.length > 0 && qualityHint(this.qualityIssue).length > 0) {
          Text(qualityHint(this.qualityIssue))
            .fontSize(13)
            .fontColor(AppColors.WARNING)
            .margin({ left: 16, right: 16, top: 10 })
        }

        if (this.aiError.length > 0) {
          this.ErrorCard()
        } else {
          this.ProgressCard()
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  ProgressCard() {
    Column() {
      Row({ space: 10 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(AppColors.PRIMARY)
        Column() {
          Text('AI 正在全图识别')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
          Text('通常需要几秒钟，请保持网络畅通')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ bottom: 14 })

      Divider()
        .color(AppColors.DIVIDER)

      ForEach(this.stages(), (item: AnalyzeStage, index: number) => {
        Row({ space: 12 }) {
          if (index < this.stage) {
            Text('✓')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width(30)
              .height(30)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.MASTERY_MASTERED)
              .borderRadius(15)
          } else if (index === this.stage) {
            LoadingProgress()
              .width(30)
              .height(30)
              .color(AppColors.PRIMARY)
          } else {
            Text(item.icon)
              .fontSize(15)
              .width(30)
              .height(30)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.CHIP_BG)
              .borderRadius(15)
          }
          Column() {
            Text(item.title)
              .fontSize(14)
              .fontColor(index <= this.stage ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
              .fontWeight(index === this.stage ? FontWeight.Medium : FontWeight.Normal)
            Text(item.desc)
              .fontSize(11)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
              .margin({ top: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 12 })
      }, (item: AnalyzeStage, index: number) => `${index}_${item.title}`)

      Button('放弃本次识别')
        .height(40)
        .fontSize(14)
        .backgroundColor(AppColors.BG_CARD)
        .fontColor(AppColors.TEXT_SECONDARY)
        .borderRadius(20)
        .margin({ top: 20 })
        .onClick(() => {
          this.onBack();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 16 })
  }

  @Builder
  ErrorCard() {
    Column() {
      Text('😟')
        .fontSize(44)
      Text('AI 识别失败')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 8 })
      Text(this.aiError)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .lineHeight(18)
        .margin({ top: 6 })

      Button('🔄 重新识别')
        .width('100%')
        .height(46)
        .fontSize(15)
        .backgroundColor(AppColors.SOLID_PRIMARY)
        .fontColor(Color.White)
        .borderRadius(23)
        .margin({ top: 18 })
        .onClick(() => {
          this.onRetry();
        })
      Button('✏️ 手动填写')
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor(AppColors.BG_CARD)
        .fontColor(AppColors.PRIMARY)
        .borderRadius(22)
        .border({ width: 1, color: AppColors.PRIMARY })
        .margin({ top: 10 })
        .onClick(() => {
          this.onManual();
        })
      Button('重新选图')
        .height(38)
        .fontSize(13)
        .backgroundColor(Color.Transparent)
        .fontColor(AppColors.TEXT_SECONDARY)
        .borderRadius(19)
        .margin({ top: 6 })
        .onClick(() => {
          this.onBack();
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 16 })
  }
}

/** 第三步：AI 识别结果核对（字段经 @Link 与 CapturePage 同步）。 */
@Component
export struct AiReviewStep {
  imagePath: string = '';
  @Prop aiRecognized: boolean = false;
  @Prop aiTagNames: string = '';

  @Link questionText: string;
  @Link knowledgeSummary: string;
  @Link standardAnswer: string;
  @Link studentAnswer: string;
  @Link selectedSubject: Subject;
  @Link answerType: AnswerType;
  @Link selectedErrorType: ErrorType;
  @Link selectedTagIds: string[];

  onRepick: () => void = (): void => {
  };
  onSave: (payload: CaptureFormPayload) => void = (_p: CaptureFormPayload): void => {
  };

  @State knowledgeTags: KnowledgeTag[] = [];
  @State compareBusy: boolean = false;
  @State compareResult: string = '';
  @State stdPhotoBusy: boolean = false;
  @State myPhotoBusy: boolean = false;
  private alive: boolean = true;
  private answerTypeOptions: AnswerTypeOption[] = [];
  private errorTypeOptions: ErrorTypeOption[] = [];

  aboutToAppear(): void {
    this.alive = true;
    const o1 = new AnswerTypeOption();
    o1.type = AnswerType.CHOICE;
    o1.label = '选择题';
    const o2 = new AnswerTypeOption();
    o2.type = AnswerType.NUMERIC;
    o2.label = '填空/计算';
    const o3 = new AnswerTypeOption();
    o3.type = AnswerType.TEXT;
    o3.label = '文字题';
    const o4 = new AnswerTypeOption();
    o4.type = AnswerType.SUBJECTIVE;
    o4.label = '主观题';
    this.answerTypeOptions = [o1, o2, o3, o4];

    const e1 = new ErrorTypeOption();
    e1.type = ErrorType.CONCEPT;
    e1.label = '概念不清';
    const e2 = new ErrorTypeOption();
    e2.type = ErrorType.CARELESS;
    e2.label = '粗心';
    const e3 = new ErrorTypeOption();
    e3.type = ErrorType.MISREAD;
    e3.label = '审题错误';
    const e4 = new ErrorTypeOption();
    e4.type = ErrorType.OTHER;
    e4.label = '其他';
    this.errorTypeOptions = [e1, e2, e3, e4];
    this.loadTags().then((): void => {
      if (this.alive && this.aiTagNames.length > 0) {
        this.selectTagsByName(this.aiTagNames.split('\n'));
      }
    });
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  private async loadTags(): Promise<void> {
    const tags = await dbHelper.queryKnowledgeTags(this.selectedSubject);
    this.knowledgeTags = tags;
  }

  selectTagsByName(names: string[]): void {
    this.selectedTagIds = [];
    for (const tag of this.knowledgeTags) {
      for (const name of names) {
        if (tag.name === name || tag.name.indexOf(name) >= 0 || name.indexOf(tag.name) >= 0) {
          if (this.selectedTagIds.indexOf(tag.id) < 0) {
            this.selectedTagIds.push(tag.id);
          }
        }
      }
    }
    this.selectedTagIds = this.selectedTagIds.slice();
  }

  private toggleTag(tagId: string): void {
    const idx: number = this.selectedTagIds.indexOf(tagId);
    if (idx >= 0) {
      this.selectedTagIds.splice(idx, 1);
    } else {
      this.selectedTagIds.push(tagId);
    }
    this.selectedTagIds = this.selectedTagIds.slice();
  }

  /** 拍照/选图后由 AI 全图识别，直接填入答案框（无框选、无本地 OCR）。 */
  private async fillAnswerFromPhoto(target: string, fromCamera: boolean): Promise<void> {
    const path: string | undefined = fromCamera ? await MediaService.capturePhoto()
      : await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未获取到图片，请重试');
      return;
    }
    if (target === 'standard') {
      this.stdPhotoBusy = true;
    } else {
      this.myPhotoBusy = true;
    }
    try {
      const text: string = await AiService.recognizeImage(path);
      if (!this.alive) {
        return;
      }
      const cleaned: string = text.trim();
      if (cleaned.length === 0) {
        Toast.show('AI 未识别到文字，请手动输入');
      } else if (target === 'standard') {
        this.standardAnswer = cleaned;
      } else {
        this.studentAnswer = cleaned;
      }
    } catch (e) {
      Toast.show(e instanceof Error ? e.message : 'AI 识别失败，请检查网络');
    }
    if (this.alive) {
      if (target === 'standard') {
        this.stdPhotoBusy = false;
      } else {
        this.myPhotoBusy = false;
      }
    }
  }

  private async runCompare(): Promise<void> {
    const s: string = this.standardAnswer.trim();
    const m: string = this.studentAnswer.trim();
    if (s.length === 0 || m.length === 0) {
      Toast.show('请先填写标准答案和我的答案');
      return;
    }
    this.compareBusy = true;
    this.compareResult = '🔍 AI 正在分析...';
    try {
      const analysis = await AiService.analyzeMistake(this.questionText, m, s);
      if (!this.alive) {
        return;
      }
      let msg: string = '🔍 AI 分析：\n' + analysis.analysis;
      if (analysis.tags.length > 0) {
        msg += '\n知识点：' + analysis.tags.join('、');
      }
      this.compareResult = msg;
    } catch (e) {
      this.compareResult = diffAnswers(s, m);
      Toast.show('AI 分析失败，已使用本地对比');
    }
    if (this.alive) {
      this.compareBusy = false;
    }
  }

  private onSaveClick(): void {
    const payload = new CaptureFormPayload();
    payload.questionText = this.questionText;
    payload.knowledgeSummary = this.knowledgeSummary;
    payload.standardAnswer = this.standardAnswer;
    payload.studentAnswer = this.studentAnswer;
    payload.subject = this.selectedSubject;
    payload.answerType = this.answerType;
    payload.errorType = this.selectedErrorType;
    payload.tagIds = this.selectedTagIds.slice();
    this.onSave(payload);
  }

  build() {
    Scroll() {
      Column() {
        // 照片 + AI 状态
        Column() {
          Image(toFileUri(this.imagePath))
            .width('100%')
            .height(150)
            .objectFit(ImageFit.Contain)
            .sourceSize({ width: 720, height: 720 })
            .draggable(false)
            .backgroundColor(AppColors.IMAGE_VIEWER_BG)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .accessibilityText('错题照片')
          Row() {
            Text(this.aiRecognized ? '✨ AI 已识别，请核对' : '✏️ 请补充题目信息')
              .fontSize(12)
              .fontColor(AppColors.PRIMARY)
              .layoutWeight(1)
            Text('换一张照片')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => {
                this.onRepick();
              })
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        this.QuestionCard()
        this.AnswerCard()
        this.CategoryCard()
        this.KnowledgeCard()

        Button(this.questionText.length > 0 ? '✔  保存错题' : '请先填写题目内容')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.questionText.length > 0 ? AppColors.SOLID_PRIMARY : AppColors.DISABLED)
          .fontColor(this.questionText.length > 0 ? Color.White : AppColors.TEXT_PRIMARY)
          .borderRadius(25)
          .margin({ left: 16, right: 16, top: 20, bottom: 32 })
          .enabled(this.questionText.length > 0)
          .accessibilityText('保存错题')
          .onClick(() => {
            this.onSaveClick();
          })
      }
      .width('100%')
    }
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  SectionTitle(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      if (hint.length > 0) {
        Text(hint)
          .fontSize(11)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  QuestionCard() {
    Column() {
      this.SectionTitle('题目内容', 'AI 已识别，可修改')
      TextArea({ text: this.questionText, placeholder: 'AI 将自动识别题目内容' })
        .fontSize(15)
        .constraintSize({ minHeight: 96 })
        .borderRadius(AppSizes.CORNER_RADIUS_XS)
        .backgroundColor(AppColors.BG_PAGE)
        .onChange((v: string) => {
          this.questionText = v;
        })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  AnswerCard() {
    Column() {
      this.SectionTitle('答案对比', 'AI 从照片提取，可修改')

      this.AnswerField('我的答案', 'mine')
      this.AnswerField('标准答案', 'standard')

      Button(this.compareBusy ? '🔍 AI 分析中...' : '🔍 AI 智能对比分析')
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor(this.compareBusy ? AppColors.DISABLED : AppColors.SECONDARY)
        .fontColor(this.compareBusy ? AppColors.TEXT_PRIMARY : Color.White)
        .borderRadius(21)
        .margin({ top: 12 })
        .enabled(!this.compareBusy)
        .onClick(() => {
          this.runCompare();
        })

      if (this.compareResult.length > 0) {
        Text(this.compareResult)
          .fontSize(13)
          .fontColor(AppColors.TEXT_REGULAR)
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppSizes.CORNER_RADIUS_XS)
          .margin({ top: 10 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  AnswerField(label: string, target: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if (target === 'standard' && this.stdPhotoBusy) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(AppColors.PRIMARY)
            .margin({ right: 6 })
        }
        if (target === 'mine' && this.myPhotoBusy) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(AppColors.PRIMARY)
            .margin({ right: 6 })
        }
        Text('📷 AI识别')
          .fontSize(12)
          .fontColor(AppColors.PRIMARY)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(AppColors.CHIP_BG)
          .borderRadius(12)
          .onClick(() => {
            this.fillAnswerFromPhoto(target, true);
          })
        Text('🖼️')
          .fontSize(12)
          .fontColor(AppColors.PRIMARY)
          .padding({ left: 6, right: 6, top: 5, bottom: 5 })
          .backgroundColor(AppColors.CHIP_BG)
          .borderRadius(12)
          .margin({ left: 6 })
          .onClick(() => {
            this.fillAnswerFromPhoto(target, false);
          })
      }
      .width('100%')
      .margin({ bottom: 6 })

      if (target === 'standard') {
        TextArea({ text: this.standardAnswer, placeholder: '正确的答案（可拍照由AI识别）' })
          .fontSize(15)
          .constraintSize({ minHeight: 64 })
          .borderRadius(AppSizes.CORNER_RADIUS_XS)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.standardAnswer = v;
          })
      } else {
        TextArea({ text: this.studentAnswer, placeholder: '我当时的答案（可拍照由AI识别）' })
          .fontSize(15)
          .constraintSize({ minHeight: 64 })
          .borderRadius(AppSizes.CORNER_RADIUS_XS)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.studentAnswer = v;
          })
      }
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  CategoryCard() {
    Column() {
      this.SectionTitle('学科', 'AI 已判断')
      Row({ space: 6 }) {
        FilterChip({
          text: subjectLabel(Subject.MATH), selected: this.selectedSubject === Subject.MATH,
          onTap: (): void => {
            this.selectedSubject = Subject.MATH;
            this.loadTags();
          }
        })
        FilterChip({
          text: subjectLabel(Subject.CHINESE), selected: this.selectedSubject === Subject.CHINESE,
          onTap: (): void => {
            this.selectedSubject = Subject.CHINESE;
            this.loadTags();
          }
        })
        FilterChip({
          text: subjectLabel(Subject.ENGLISH), selected: this.selectedSubject === Subject.ENGLISH,
          onTap: (): void => {
            this.selectedSubject = Subject.ENGLISH;
            this.loadTags();
          }
        })
        FilterChip({
          text: subjectLabel(Subject.SCIENCE), selected: this.selectedSubject === Subject.SCIENCE,
          onTap: (): void => {
            this.selectedSubject = Subject.SCIENCE;
            this.loadTags();
          }
        })
      }
      .width('100%')

      Column() {
        this.SectionTitle('题型', '')
      }
      .width('100%')
      .margin({ top: 14 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.answerTypeOptions, (item: AnswerTypeOption) => {
          FilterChip({
            text: item.label, selected: this.answerType === item.type,
            onTap: (): void => {
              this.answerType = item.type;
            }
          })
        }, (item: AnswerTypeOption) => item.type as string)
      }

      Column() {
        this.SectionTitle('错误原因', '可选')
      }
      .width('100%')
      .margin({ top: 14 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.errorTypeOptions, (item: ErrorTypeOption) => {
          FilterChip({
            text: item.label, selected: this.selectedErrorType === item.type,
            onTap: (): void => {
              this.selectedErrorType = item.type;
            }
          })
        }, (item: ErrorTypeOption) => item.type as string)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12 })
  }

  @Builder
  KnowledgeCard() {
    Column() {
      this.SectionTitle('知识点', 'AI 已总结')
      TextInput({ text: this.knowledgeSummary, placeholder: '不超过10字，可修改' })
        .fontSize(15)
        .borderRadius(AppSizes.CORNER_RADIUS_XS)
        .backgroundColor(AppColors.BG_PAGE)
        .onChange((v: string) => {
          this.knowledgeSummary = v;
        })

      if (this.knowledgeTags.length === 0) {
        Text('暂无匹配标签，可跳过')
          .fontSize(12)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
          .margin({ top: 8 })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.knowledgeTags, (tag: KnowledgeTag) => {
            FilterChip({
              text: tag.name, selected: this.selectedTagIds.indexOf(tag.id) >= 0,
              onTap: (): void => {
                this.toggleTag(tag.id);
              }
            })
          }, (tag: KnowledgeTag) => tag.id)
        }
        .margin({ top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12 })
  }
}

/** 第四步：保存成功。 */
@Component
export struct CaptureResultStep {
  @Prop pointsEarned: number = 0;
  onContinue: () => void = (): void => {
  };
  onExit: () => void = (): void => {
  };

  build() {
    Column() {
      Text('🎉 ✨ 🎉')
        .fontSize(20)
        .margin({ top: 40 })
      Column() {
        Text('✓')
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        if (this.pointsEarned > 0) {
          Text(`+${this.pointsEarned} 积分`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.SECONDARY)
            .backgroundColor(Color.White)
            .borderRadius(10)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .margin({ top: 8 })
        }
      }
      .width(112)
      .height(112)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(AppColors.MASTERY_MASTERED)
      .borderRadius(56)
      .margin({ top: 16 })

      Text('录入成功！')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 18 })
      Text('AI 已根据遗忘曲线安排复习计划\n明天记得来复习这道错题哦')
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
        .margin({ top: 8 })

      Button('📷  继续录入')
        .width('80%')
        .height(48)
        .fontSize(16)
        .backgroundColor(AppColors.SOLID_PRIMARY)
        .fontColor(Color.White)
        .borderRadius(24)
        .margin({ top: 40 })
        .onClick(() => {
          this.onContinue();
        })
      Button('完成')
        .width('80%')
        .height(44)
        .fontSize(15)
        .backgroundColor(AppColors.BG_CARD)
        .fontColor(AppColors.PRIMARY)
        .borderRadius(22)
        .border({ width: 1, color: AppColors.PRIMARY })
        .margin({ top: 12 })
        .onClick(() => {
          this.onExit();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}

/** 本地答案对比（AI 失败时的降级）。 */
function diffAnswers(standard: string, mine: string): string {
  if (standard === mine) {
    return '✅ 智能对比：答案一致，未发现错误点。';
  }
  let pre: number = 0;
  while (pre < standard.length && pre < mine.length && standard.charAt(pre) === mine.charAt(pre)) {
    pre++;
  }
  let suf: number = 0;
  while (suf < standard.length - pre && suf < mine.length - pre &&
    standard.charAt(standard.length - 1 - suf) === mine.charAt(mine.length - 1 - suf)) {
    suf++;
  }
  const sDiff: string = standard.substring(pre, standard.length - suf);
  const mDiff: string = mine.substring(pre, mine.length - suf);
  let msg: string = '⚠️ 智能对比发现差异：\n';
  if (sDiff.length > 0) {
    msg += `· 标准答案关键处：「${sDiff}」\n`;
  }
  if (mDiff.length > 0) {
    msg += `· 你的作答处：「${mDiff}」\n`;
  }
  if (sDiff.length === 0 && mDiff.length > 0) {
    msg += '· 你的答案多写了内容\n';
  }
  if (mDiff.length === 0 && sDiff.length > 0) {
    msg += '· 你的答案遗漏了内容\n';
  }
  msg += '建议针对以上差异点重点复习。';
  return msg;
}
