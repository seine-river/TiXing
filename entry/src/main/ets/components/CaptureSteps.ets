import { CropFracs, OcrFieldResult } from '../models/Mistake';
import { Subject, AnswerType, ErrorType, ImageQualityIssue, ContentType } from '../models/Enums';
import { KnowledgeTag } from '../models/KnowledgeTag';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { AiService } from '../services/AiService';
import { MediaService } from '../services/MediaService';
import { AppColors, AppSizes, AppStrings, subjectLabel, toFileUri } from '../common/Constants';
import { Toast } from '../common/Toast';
import { FilterChip } from './BasicWidgets';
/**
 * CapturePage 四步子组件（T046/FR-024）：
 * SourceSelect / RegionSelect / OcrConfirm / Result。
 * 各步骤自持步骤内 UI 状态；跨步骤表单数据由 CapturePage 持有（经 @Link 双向同步）。
 */

/** 确认页汇总的表单载荷（保存时回传 CapturePage）。 */
export class CaptureFormPayload {
  questionText: string = '';
  knowledgeSummary: string = '';
  standardAnswer: string = '';
  studentAnswer: string = '';
  subject: Subject = Subject.MATH;
  answerType: AnswerType = AnswerType.TEXT;
  errorType: ErrorType = ErrorType.OTHER;
  tagIds: string[] = [];
  ocrConfidence: number = 0;
}

class AnswerTypeOption {
  type: AnswerType = AnswerType.TEXT;
  label: string = '';
}

class ErrorTypeOption {
  type: ErrorType = ErrorType.OTHER;
  label: string = '';
}

function clamp(v: number, min: number, max: number): number {
  if (v < min) {
    return min;
  }
  if (v > max) {
    return max;
  }
  return v;
}

function toPixels(len: Length): number {
  if (typeof len === 'number') {
    return len;
  }
  if (typeof len === 'string') {
    return parseFloat(len);
  }
  return 0;
}

/** 第一步：来源选择。 */
@Component
export struct SourceSelectStep {
  @Prop qualityIssue: string = '';
  onPick: (fromCamera: boolean) => void = (_f: boolean): void => {
  };

  private qualityHint(issue: string): string {
    if (issue === ImageQualityIssue.BLUR) {
      return '⚠️ 图片可能模糊，建议重新拍摄以获得更清晰的识别';
    }
    if (issue === ImageQualityIssue.TILT) {
      return '⚠️ 图片倾斜，建议重新拍摄';
    }
    if (issue === ImageQualityIssue.GLARE) {
      return '⚠️ 图片有反光，建议调整角度重拍';
    }
    if (issue === ImageQualityIssue.LOW_LIGHT) {
      return '⚠️ 光线较暗，建议在明亮处重拍';
    }
    if (issue === 'decode_failed') {
      return '⚠️ 图片读取失败，请重新选择';
    }
    return '';
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Text('📷')
            .fontSize(40)
          Text('录入错题')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .margin({ top: 8 })
          Text('选择图片来源，系统将自动识别题目并判断学科')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 6 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 32, bottom: 24 })
        .alignItems(HorizontalAlign.Center)

        Row() {
          this.SourceTile('📷', AppStrings.CAPTURE_PHOTO, '拍摄试卷或练习册', true)
          this.SourceTile('🖼️', AppStrings.CAPTURE_ALBUM, '从相册选取已有图片', false)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        if (this.qualityIssue.length > 0 && this.qualityHint(this.qualityIssue).length > 0) {
          Text(this.qualityHint(this.qualityIssue))
            .fontSize(14)
            .fontColor(AppColors.WARNING)
            .padding({ left: 16, right: 16, top: 16 })
        }
      }
      .width('100%')
    }
    .scrollBar(BarState.Auto)
  }

  @Builder
  SourceTile(icon: string, title: string, subtitle: string, fromCamera: boolean) {
    Column() {
      Text(icon)
        .fontSize(40)
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 10 })
      Text(subtitle)
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 4 })
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(150)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 4, right: 4 })
    .shadow({ radius: 8, color: AppColors.SHADOW_CARD, offsetY: 2 })
    .accessibilityText(title)
    .onClick(() => {
      this.onPick(fromCamera);
    })
  }
}

/** 第二步：区域框选（步骤内自持拖拽与选区状态）。 */
@Component
export struct RegionSelectStep {
  imagePath: string = '';
  imageRatio: number = 0.75;
  @Prop regionHint: string = '拖动四角调整题目识别区域';
  @Prop confirmLabel: string = '识别此区域';
  @Prop fullLabel: string = '识别全图';
  @Prop busy: boolean = false;
  initialLeftFrac: number = 0.08;
  initialTopFrac: number = 0.08;
  initialRightFrac: number = 0.92;
  initialBottomFrac: number = 0.92;
  onConfirm: (fracs: CropFracs | undefined) => void = (_f: CropFracs | undefined): void => {
  };
  onBack: () => void = (): void => {
  };

  @State cropLeftFrac: number = 0.08;
  @State cropTopFrac: number = 0.08;
  @State cropRightFrac: number = 0.92;
  @State cropBottomFrac: number = 0.92;
  @State dragStartLeft: number = 0;
  @State dragStartTop: number = 0;
  @State dragStartRight: number = 0;
  @State dragStartBottom: number = 0;
  @State dispW: number = 0;
  @State dispH: number = 0;

  aboutToAppear(): void {
    this.cropLeftFrac = this.initialLeftFrac;
    this.cropTopFrac = this.initialTopFrac;
    this.cropRightFrac = this.initialRightFrac;
    this.cropBottomFrac = this.initialBottomFrac;
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回上一步')
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .height(AppSizes.TOUCH_TARGET)
          .padding({ left: 8, right: 8 })
          .margin({ left: 8, top: 4 })
          .accessibilityText('返回上一步')
          .onClick(() => {
            this.onBack();
          })
        Text(this.regionHint)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .padding({ right: 16 })
      }
      .width('100%')
      .padding({ top: 4 })

      Stack() {
        Image(toFileUri(this.imagePath))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .sourceSize({ width: 1080, height: 1080 })
          .draggable(false)

        Column() {
        }
        .width((this.cropRightFrac - this.cropLeftFrac) * this.dispW)
        .height((this.cropBottomFrac - this.cropTopFrac) * this.dispH)
        .position({ x: this.cropLeftFrac * this.dispW, y: this.cropTopFrac * this.dispH })
        .border({ width: 2, color: AppColors.PRIMARY })
        .backgroundColor(AppColors.CROP_MASK)
        .hitTestBehavior(HitTestMode.Transparent)

        this.DragHandle(this.cropLeftFrac, this.cropTopFrac, true)
        this.DragHandle(this.cropRightFrac, this.cropBottomFrac, false)
      }
      .width('100%')
      .aspectRatio(this.imageRatio)
      .margin({ left: 16, right: 16, top: 8 })
      .backgroundColor(AppColors.IMAGE_VIEWER_BG)
      .borderRadius(AppSizes.CORNER_RADIUS_SM)
      .clip(true)
      .onAreaChange((_o: Area, n: Area) => {
        this.dispW = toPixels(n.width);
        this.dispH = toPixels(n.height);
      })

      Row() {
        Button(this.fullLabel)
          .height(40)
          .backgroundColor(AppColors.BG_CARD)
          .fontColor(AppColors.PRIMARY)
          .borderRadius(20)
          .margin({ right: 12 })
          .enabled(!this.busy)
          .onClick(() => {
            this.onConfirm(undefined);
          })
        Button(this.confirmLabel)
          .height(40)
          .backgroundColor(this.busy ? AppColors.DISABLED : AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(20)
          .enabled(!this.busy)
          .onClick(() => {
            this.onConfirm(new CropFracs(this.cropLeftFrac, this.cropTopFrac, this.cropRightFrac, this.cropBottomFrac));
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16 })

      if (this.busy) {
        Text('正在识别...')
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  DragHandle(posX: number, posY: number, isStart: boolean) {
    Stack() {
      Column() {
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor(AppColors.PRIMARY)
      .border({ width: 3, color: Color.White })
    }
    .width(44)
    .height(44)
    .position({ x: posX * this.dispW - 22, y: posY * this.dispH - 22 })
    .gesture(
      PanGesture()
        .onActionStart(() => {
          if (isStart) {
            this.dragStartLeft = this.cropLeftFrac;
            this.dragStartTop = this.cropTopFrac;
          } else {
            this.dragStartRight = this.cropRightFrac;
            this.dragStartBottom = this.cropBottomFrac;
          }
        })
        .onActionUpdate((e) => {
          const dx: number = e.offsetX / (this.dispW > 0 ? this.dispW : 1);
          const dy: number = e.offsetY / (this.dispH > 0 ? this.dispH : 1);
          if (isStart) {
            this.cropLeftFrac = clamp(this.dragStartLeft + dx, 0, this.cropRightFrac - 0.05);
            this.cropTopFrac = clamp(this.dragStartTop + dy, 0, this.cropBottomFrac - 0.05);
          } else {
            this.cropRightFrac = clamp(this.dragStartRight + dx, this.cropLeftFrac + 0.05, 1);
            this.cropBottomFrac = clamp(this.dragStartBottom + dy, this.cropTopFrac + 0.05, 1);
          }
        })
    )
  }
}

/** 第三步：OCR 核对与 AI 分析（表单字段经 @Link 与 CapturePage 同步）。 */
@Component
export struct OcrConfirmStep {
  imagePath: string = '';
  questionFracs: CropFracs | undefined = undefined;
  @Prop ocrConfidence: number = 0;
  stdImagePath: string = '';
  myImagePath: string = '';
  stdFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
  myFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);

  @Link questionText: string;
  @Link knowledgeSummary: string;
  @Link standardAnswer: string;
  @Link studentAnswer: string;
  @Link selectedSubject: Subject;
  @Link answerType: AnswerType;
  @Link selectedErrorType: ErrorType;
  @Link selectedTagIds: string[];

  onRepickQuestion: () => void = (): void => {
  };
  onRegionSelect: (target: string) => void = (_t: string): void => {
  };
  onAnswerImagePicked: (target: string, path: string) => void = (_t: string, _p: string): void => {
  };
  onFracsChanged: (target: string, fracs: CropFracs) => void = (_t: string, _f: CropFracs): void => {
  };
  onSave: (payload: CaptureFormPayload) => void = (_p: CaptureFormPayload): void => {
  };

  @State knowledgeBusy: boolean = false;
  @State stdAnalyzing: boolean = false;
  @State myAnalyzing: boolean = false;
  @State compareBusy: boolean = false;
  @State compareResult: string = '';
  @State knowledgeTags: KnowledgeTag[] = [];
  private answerTypeOptions: AnswerTypeOption[] = [];
  private errorTypeOptions: ErrorTypeOption[] = [];
  private alive: boolean = true;
  private aiStarted: boolean = false;

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
    this.loadTags();
    this.runAiRecognize();
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  private async loadTags(): Promise<void> {
    const tags = await dbHelper.queryKnowledgeTags(this.selectedSubject);
    if (!this.alive) {
      return;
    }
    this.knowledgeTags = tags;
  }

  private async runAiRecognize(): Promise<void> {
    if (this.aiStarted) {
      return;
    }
    this.aiStarted = true;
    this.knowledgeBusy = true;
    try {
      const ai = await AiService.recognizeQuestion(this.imagePath, this.questionFracs, this.questionText);
      if (!this.alive) {
        return;
      }
      if (ai.ok) {
        this.questionText = ai.question;
      }
      if (ai.knowledgeSummary.length > 0) {
        this.knowledgeSummary = ai.knowledgeSummary;
      }
      this.selectedSubject = ai.subject;
      this.answerType = ai.answerType;
      this.selectedErrorType = ai.errorType;
      await this.loadTags();
      if (ai.tags.length > 0) {
        this.selectTagsByName(ai.tags);
      }
      if (ai.ok) {
        Toast.show('AI识别完成');
      } else {
        Toast.show('AI未能解析题目，请手动核对');
      }
    } catch (e) {
      if (!this.alive) {
        return;
      }
      if (this.knowledgeSummary.length === 0) {
        this.knowledgeSummary = subjectLabel(this.selectedSubject) + '错题';
      }
      Toast.show(e instanceof Error ? e.message : 'AI识别失败，请检查网络，可手动修改');
    }
    if (this.alive) {
      this.knowledgeBusy = false;
    }
  }

  private selectTagsByName(names: string[]): void {
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

  private answerImageOf(target: string): string {
    if (target === 'standard') {
      return this.stdImagePath;
    }
    return this.myImagePath;
  }

  private answerAnalyzing(target: string): boolean {
    if (target === 'standard') {
      return this.stdAnalyzing;
    }
    return this.myAnalyzing;
  }

  private fracsOf(target: string): CropFracs {
    if (target === 'standard') {
      return this.stdFracs;
    }
    return this.myFracs;
  }

  private async pickAnswerImage(target: string, fromCamera: boolean): Promise<void> {
    const path = fromCamera ? await MediaService.capturePhoto() : await MediaService.pickFromAlbum();
    if (!this.alive) {
      return;
    }
    if (path === undefined || path.length === 0) {
      Toast.show('未获取到图片，请重试');
      return;
    }
    this.onAnswerImagePicked(target, path);
    this.onRegionSelect(target);
  }

  private async analyzeAnswer(target: string): Promise<void> {
    const img: string = this.answerImageOf(target);
    if (img.length === 0) {
      Toast.show('请先选择图片');
      return;
    }
    if (target === 'standard') {
      this.stdAnalyzing = true;
    } else {
      this.myAnalyzing = true;
    }
    try {
      const text: string = await AiService.recognizeImage(img, this.fracsOf(target));
      if (!this.alive) {
        return;
      }
      const cleaned: string = text.trim();
      if (cleaned.length === 0) {
        Toast.show('未识别到文字，请手动输入');
      } else if (target === 'standard') {
        this.standardAnswer = this.standardAnswer.length > 0 ? this.standardAnswer + ' ' + cleaned : cleaned;
      } else {
        this.studentAnswer = this.studentAnswer.length > 0 ? this.studentAnswer + ' ' + cleaned : cleaned;
      }
    } catch (e) {
      if (this.alive) {
        Toast.show(e instanceof Error ? e.message : 'AI 分析失败，请检查网络');
      }
    }
    if (this.alive) {
      if (target === 'standard') {
        this.stdAnalyzing = false;
      } else {
        this.myAnalyzing = false;
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
      let msg: string = '🔍 AI 分析结果：\n' + analysis.analysis;
      if (analysis.tags.length > 0) {
        msg += '\n知识点：' + analysis.tags.join('、');
      }
      this.compareResult = msg;
      this.answerType = analysis.answerType;
      this.selectedSubject = analysis.subject;
      await this.loadTags();
      this.selectTagsByName(analysis.tags);
      if (analysis.tags.length > 0) {
        this.knowledgeSummary = analysis.tags[0];
      }
    } catch (e) {
      if (!this.alive) {
        return;
      }
      this.compareResult = diffAnswers(s, m);
      Toast.show('AI 分析失败，已使用本地对比');
    }
    if (this.alive) {
      this.compareBusy = false;
    }
  }

  private anyAiBusy(): boolean {
    return this.knowledgeBusy || this.stdAnalyzing || this.myAnalyzing || this.compareBusy;
  }

  build() {
    Scroll() {
      Column() {
        Text(AppStrings.CONFIRM_OCR)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .padding({ left: 16, right: 16, bottom: 12 })

        Column() {
          Row() {
            Text('知识点总结')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .layoutWeight(1)
            if (this.knowledgeBusy) {
              Text('AI 总结中...')
                .fontSize(11)
                .fontColor(AppColors.TEXT_PLACEHOLDER)
            }
          }
          .width('100%')
          .margin({ bottom: 4 })
          TextInput({ text: this.knowledgeSummary, placeholder: '识别后由AI自动总结（不超过10字，可修改）' })
            .fontSize(16)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .backgroundColor(AppColors.BG_PAGE)
            .onChange((v: string) => {
              this.knowledgeSummary = v;
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Row() {
            Text('识别学科（自动）')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .layoutWeight(1)
            Text('识别有误可点击修改')
              .fontSize(11)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
          }
          .width('100%')
          .margin({ bottom: 8 })
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
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        this.OcrFieldCard()

        this.AnswerFieldCard('标准答案', 'standard')
        this.AnswerFieldCard('我的答案', 'mine')

        Button(this.compareBusy ? '🔍 AI 分析中...' : '🔍 智能对比分析')
          .width('90%')
          .height(42)
          .backgroundColor(this.anyAiBusy() ? AppColors.DISABLED : AppColors.SECONDARY)
          .fontColor(Color.White)
          .borderRadius(21)
          .margin({ top: 12 })
          .enabled(!this.anyAiBusy())
          .onClick(() => {
            this.runCompare();
          })

        if (this.compareResult.length > 0) {
          Text(this.compareResult)
            .fontSize(13)
            .fontColor(AppColors.TEXT_REGULAR)
            .lineHeight(20)
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .border({ width: 1, color: AppColors.DIVIDER })
            .margin({ left: 16, right: 16, top: 8 })
        }

        Column() {
          Text('题目类型')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row({ space: 6 }) {
            ForEach(this.answerTypeOptions, (item: AnswerTypeOption) => {
              FilterChip({
                text: item.label, selected: this.answerType === item.type,
                onTap: (): void => {
                  this.answerType = item.type;
                }
              })
            }, (item: AnswerTypeOption) => item.type as string)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('错误类型（可选）')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row({ space: 6 }) {
            ForEach(this.errorTypeOptions, (item: ErrorTypeOption) => {
              FilterChip({
                text: item.label, selected: this.selectedErrorType === item.type,
                onTap: (): void => {
                  this.selectedErrorType = item.type;
                }
              })
            }, (item: ErrorTypeOption) => item.type as string)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('知识点标签')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          if (this.knowledgeTags.length === 0) {
            Text('暂无匹配标签，可跳过')
              .fontSize(13)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
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
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Button(this.anyAiBusy() ? 'AI 识别中，请稍候...' : AppStrings.CONFIRM_COMPLETE)
          .width('90%')
          .height(44)
          .backgroundColor((this.questionText.length > 0 && !this.anyAiBusy()) ? AppColors.PRIMARY : AppColors.DISABLED)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 24 })
          .enabled(this.questionText.length > 0 && !this.anyAiBusy())
          .onClick(() => {
            this.onSaveClick();
          })
      }
      .width('100%')
    }
    .scrollBar(BarState.Auto)
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
    payload.ocrConfidence = this.ocrConfidence;
    this.onSave(payload);
  }

  @Builder
  OcrFieldCard() {
    Column() {
      Row() {
        Text('题目内容')
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if (this.questionText.length > 0) {
          Text(`置信度 ${Math.round(this.ocrConfidence * 100)}%`)
            .fontSize(12)
            .fontColor(this.ocrConfidence < CaptureOrchestrator.getConfidenceThreshold() && this.questionText.length > 0
              ? AppColors.WARNING : AppColors.TEXT_PLACEHOLDER)
        }
      }
      .width('100%')
      .margin({ bottom: 4 })

      TextArea({ text: this.questionText, placeholder: '请核对题目内容' })
        .fontSize(16)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_PAGE)
        .border({
          width: this.ocrConfidence < CaptureOrchestrator.getConfidenceThreshold() && this.questionText.length > 0 ? 1.5 : 0,
          color: AppColors.WARNING
        })
        .onChange((v: string) => {
          this.questionText = v;
        })

      Button('🔄 重新选择题目图片')
        .height(32)
        .fontSize(12)
        .backgroundColor(AppColors.CHIP_BG)
        .fontColor(AppColors.TEXT_REGULAR)
        .borderRadius(16)
        .margin({ top: 8 })
        .onClick(() => {
          this.onRepickQuestion();
        })

      if (CaptureOrchestrator.isLowConfidence(new OcrFieldResult(this.questionText, this.ocrConfidence, ContentType.PRINTED_TEXT))) {
        Text('⚠️ 识别置信度较低，需人工核对')
          .fontSize(11)
          .fontColor(AppColors.WARNING)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 16, right: 16, top: 8 })
  }

  @Builder
  AnswerFieldCard(label: string, target: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if (this.answerAnalyzing(target)) {
          Text('AI 分析中...')
            .fontSize(11)
            .fontColor(AppColors.WARNING)
        }
      }
      .width('100%')
      .margin({ bottom: 4 })

      if (target === 'standard') {
        TextArea({ text: this.standardAnswer, placeholder: `输入${label}，或选图后智能分析` })
          .fontSize(16)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.standardAnswer = v;
          })
      } else {
        TextArea({ text: this.studentAnswer, placeholder: `输入${label}，或选图后智能分析` })
          .fontSize(16)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.studentAnswer = v;
          })
      }

      if (this.answerImageOf(target).length > 0) {
        Row() {
          Image(toFileUri(this.answerImageOf(target)))
            .width(72)
            .height(72)
            .borderRadius(AppSizes.CORNER_RADIUS_XS)
            .objectFit(ImageFit.Cover)
            .sourceSize({ width: 256, height: 256 })
            .margin({ right: 8 })

          Column({ space: 8 }) {
            Button('✂️ 框选区域')
              .height(32)
              .fontSize(12)
              .backgroundColor(AppColors.CHIP_BG)
              .fontColor(AppColors.TEXT_REGULAR)
              .borderRadius(16)
              .onClick(() => {
                this.onRegionSelect(target);
              })
            Button('🔍 智能分析')
              .height(32)
              .fontSize(12)
              .backgroundColor(AppColors.PRIMARY)
              .fontColor(Color.White)
              .borderRadius(16)
              .enabled(!this.answerAnalyzing(target))
              .onClick(() => {
                this.analyzeAnswer(target);
              })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      Row({ space: 8 }) {
        Button('📷 拍照')
          .height(32)
          .fontSize(12)
          .backgroundColor(AppColors.CHIP_BG)
          .fontColor(AppColors.TEXT_REGULAR)
          .borderRadius(16)
          .onClick(() => {
            this.pickAnswerImage(target, true);
          })
        Button('🖼️ 相册')
          .height(32)
          .fontSize(12)
          .backgroundColor(AppColors.CHIP_BG)
          .fontColor(AppColors.TEXT_REGULAR)
          .borderRadius(16)
          .onClick(() => {
            this.pickAnswerImage(target, false);
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 16, right: 16, top: 8 })
  }
}

/** 第四步：保存结果。 */
@Component
export struct ResultStep {
  onContinue: () => void = (): void => {
  };
  onExit: () => void = (): void => {
  };

  build() {
    Column() {
      Text('✅')
        .fontSize(64)
        .margin({ top: 80 })
      Text('录入成功！')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 16 })
      Text('系统将根据遗忘曲线自动安排复习')
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 8 })
      Button('继续录入')
        .backgroundColor(AppColors.PRIMARY)
        .fontColor(Color.White)
        .borderRadius(22)
        .height(44)
        .width('60%')
        .margin({ top: 32 })
        .onClick(() => {
          this.onContinue();
        })
      Button('返回首页')
        .backgroundColor(AppColors.BG_CARD)
        .fontColor(AppColors.PRIMARY)
        .borderRadius(22)
        .height(44)
        .width('60%')
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
