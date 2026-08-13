import { Mistake, OcrFieldResult, OcrRecognitionResult, ImageRegion } from '../models/Mistake';
import { Subject, AnswerType, ErrorType, ContentType, Grade, ImageQualityIssue, PointsActionType } from '../models/Enums';
import { KnowledgeTag } from '../models/KnowledgeTag';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { SubjectDetector } from '../usecases/SubjectDetector';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { MediaService } from '../services/MediaService';
import { AppColors, AppSizes, AppStrings, subjectLabel, generateId } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';

class AnswerTypeOption {
  type: AnswerType = AnswerType.TEXT;
  label: string = '';
}

class ErrorTypeOption {
  type: ErrorType = ErrorType.OTHER;
  label: string = '';
}

@Entry
@Component
struct CapturePage {
  @State currentStep: number = 0;
  @State selectedSubject: Subject = Subject.MATH;
  @State ocrResult: OcrRecognitionResult = new OcrRecognitionResult();
  @State questionText: string = '';
  @State standardAnswer: string = '';
  @State answerType: AnswerType = AnswerType.TEXT;
  @State isConfirmed: boolean = false;
  @State capturing: boolean = false;

  @State answerTypeOptions: AnswerTypeOption[] = [];
  @State errorTypeOptions: ErrorTypeOption[] = [];
  @State selectedErrorType: ErrorType = ErrorType.OTHER;
  @State knowledgeTags: KnowledgeTag[] = [];
  @State selectedTagIds: string[] = [];

  @State imagePath: string = '';
  @State imgNatW: number = 0;
  @State imgNatH: number = 0;
  @State dispW: number = 0;
  @State dispH: number = 0;
  @State cropLeftFrac: number = 0.05;
  @State cropTopFrac: number = 0.05;
  @State cropRightFrac: number = 0.95;
  @State cropBottomFrac: number = 0.95;

  @State qualityIssue: string = '';
  @State ocrBusy: boolean = false;
  @State hintMsg: string = '';

  aboutToAppear(): void {
    const o1 = new AnswerTypeOption(); o1.type = AnswerType.CHOICE; o1.label = '选择题';
    const o2 = new AnswerTypeOption(); o2.type = AnswerType.NUMERIC; o2.label = '填空/计算';
    const o3 = new AnswerTypeOption(); o3.type = AnswerType.TEXT; o3.label = '文字题';
    const o4 = new AnswerTypeOption(); o4.type = AnswerType.SUBJECTIVE; o4.label = '主观题';
    this.answerTypeOptions = [o1, o2, o3, o4];

    const e1 = new ErrorTypeOption(); e1.type = ErrorType.CONCEPT; e1.label = '概念不清';
    const e2 = new ErrorTypeOption(); e2.type = ErrorType.CARELESS; e2.label = '粗心';
    const e3 = new ErrorTypeOption(); e3.type = ErrorType.MISREAD; e3.label = '审题错误';
    const e4 = new ErrorTypeOption(); e4.type = ErrorType.OTHER; e4.label = '其他';
    this.errorTypeOptions = [e1, e2, e3, e4];
  }

  build() {
    Column() {
      PageHeader({ title: '录入错题' })

      if (this.currentStep === 0) {
        this.StepSourceSelect()
      } else if (this.currentStep === 1) {
        this.StepRegionSelect()
      } else if (this.currentStep === 2) {
        this.StepOcrConfirm()
      } else {
        this.StepSaveSuccess()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  StepSourceSelect() {
    Scroll() {
      Column() {
        Text('选择图片来源，系统将自动识别题目并判断学科')
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .padding({ left: 16, right: 16, top: 12 })

        Column() {
          Button({ type: ButtonType.Normal }) {
            Column() {
              Text('📷')
                .fontSize(48)
              Text(AppStrings.CAPTURE_PHOTO)
                .fontSize(18)
                .fontColor(AppColors.TEXT_PRIMARY)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .height(120)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 16 })
          .onClick(() => {
            this.startCapture(true);
          })

          Button({ type: ButtonType.Normal }) {
            Column() {
              Text('🖼️')
                .fontSize(48)
              Text(AppStrings.CAPTURE_ALBUM)
                .fontSize(18)
                .fontColor(AppColors.TEXT_PRIMARY)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .height(120)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12 })
          .onClick(() => {
            this.startCapture(false);
          })
        }
        .width('100%')

        if (this.qualityIssue.length > 0) {
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
  StepRegionSelect() {
    Column() {
      Text('框选题目区域（可拖动四角调整）')
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })

      Stack() {
        Image(this.imagePath)
          .width('100%')
          .objectFit(ImageFit.Contain)
          .onAreaChange((_o: Area, n: Area) => {
            this.dispW = toPixels(n.width);
            this.dispH = toPixels(n.height);
          })

        Column() {
          Stack() {
            Column() {
            }
            .width((this.cropRightFrac - this.cropLeftFrac) * this.dispW)
            .height((this.cropBottomFrac - this.cropTopFrac) * this.dispH)
            .border({ width: 2, color: AppColors.PRIMARY })
            .backgroundColor('#334A90D9')
            .position({ x: this.cropLeftFrac * this.dispW, y: this.cropTopFrac * this.dispH })

            this.CornerKnob(this.cropLeftFrac, this.cropTopFrac, true, true)
            this.CornerKnob(this.cropRightFrac, this.cropBottomFrac, false, false)
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row() {
        Button('识别全图')
          .height(40)
          .backgroundColor(AppColors.BG_CARD)
          .fontColor(AppColors.PRIMARY)
          .borderRadius(20)
          .margin({ right: 12 })
          .onClick(() => {
            this.runOcr(undefined);
          })
        Button('识别此区域')
          .height(40)
          .backgroundColor(this.ocrBusy ? '#C0C4CC' : AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(20)
          .enabled(!this.ocrBusy)
          .onClick(() => {
            this.runOcr(this.currentRegion());
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16 })

      if (this.ocrBusy) {
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
  CornerKnob(fracX: number, fracY: number, isLeft: boolean, isTop: boolean) {
    Column() {
    }
    .width(24)
    .height(24)
    .borderRadius(12)
    .backgroundColor(AppColors.PRIMARY)
    .border({ width: 2, color: Color.White })
    .position({ x: fracX * this.dispW - 12, y: fracY * this.dispH - 12 })
    .gesture(
      PanGesture()
        .onActionUpdate((e) => {
          const dx: number = e.offsetX / (this.dispW > 0 ? this.dispW : 1);
          const dy: number = e.offsetY / (this.dispH > 0 ? this.dispH : 1);
          if (isLeft) {
            this.cropLeftFrac = clamp(this.cropLeftFrac + dx, 0, this.cropRightFrac - 0.05);
          } else {
            this.cropRightFrac = clamp(this.cropRightFrac + dx, this.cropLeftFrac + 0.05, 1);
          }
          if (isTop) {
            this.cropTopFrac = clamp(this.cropTopFrac + dy, 0, this.cropBottomFrac - 0.05);
          } else {
            this.cropBottomFrac = clamp(this.cropBottomFrac + dy, this.cropTopFrac + 0.05, 1);
          }
        })
    )
  }

  @Builder
  StepOcrConfirm() {
    Scroll() {
      Column() {
        Text(AppStrings.CONFIRM_OCR)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .padding({ left: 16, right: 16, bottom: 12 })

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
          Row() {
            ForEach([Subject.MATH, Subject.CHINESE, Subject.ENGLISH], (sub: Subject) => {
              Button(subjectLabel(sub))
                .backgroundColor(this.selectedSubject === sub ? AppColors.PRIMARY : '#E8EAED')
                .fontColor(this.selectedSubject === sub ? Color.White : AppColors.TEXT_REGULAR)
                .borderRadius(16)
                .height(32)
                .fontSize(13)
                .margin({ left: 2, right: 2 })
                .layoutWeight(1)
                .onClick(() => {
                  this.selectedSubject = sub;
                  this.loadTags();
                })
            }, (sub: Subject) => sub)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        this.OcrFieldCard('题目内容', this.questionText, this.ocrResult.questionText, (v: string) => {
          this.questionText = v;
        })

        this.OcrFieldCard('标准答案', this.standardAnswer, this.ocrResult.standardAnswerCandidate, (v: string) => {
          this.standardAnswer = v;
        })

        Column() {
          Text('题目类型')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Row() {
            ForEach(this.answerTypeOptions, (item: AnswerTypeOption) => {
              Button(item.label)
                .backgroundColor(this.answerType === item.type ? AppColors.PRIMARY : '#E8EAED')
                .fontColor(this.answerType === item.type ? Color.White : AppColors.TEXT_REGULAR)
                .borderRadius(16)
                .height(32)
                .fontSize(13)
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.answerType = item.type;
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
          Row() {
            ForEach(this.errorTypeOptions, (item: ErrorTypeOption) => {
              Button(item.label)
                .backgroundColor(this.selectedErrorType === item.type ? AppColors.PRIMARY : '#E8EAED')
                .fontColor(this.selectedErrorType === item.type ? Color.White : AppColors.TEXT_REGULAR)
                .borderRadius(16)
                .height(32)
                .fontSize(13)
                .margin({ left: 2, right: 2 })
                .onClick(() => {
                  this.selectedErrorType = item.type;
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
                Button(tag.name)
                  .backgroundColor(this.selectedTagIds.indexOf(tag.id) >= 0 ? AppColors.PRIMARY : '#E8EAED')
                  .fontColor(this.selectedTagIds.indexOf(tag.id) >= 0 ? Color.White : AppColors.TEXT_REGULAR)
                  .borderRadius(16)
                  .height(32)
                  .fontSize(13)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    this.toggleTag(tag.id);
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

        Button(AppStrings.CONFIRM_COMPLETE)
          .width('90%')
          .height(44)
          .backgroundColor(this.questionText.length > 0 ? AppColors.PRIMARY : '#C0C4CC')
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 24 })
          .enabled(this.questionText.length > 0)
          .onClick(() => {
            this.saveMistake();
          })
      }
      .width('100%')
    }
    .scrollBar(BarState.Auto)
  }

  @Builder
  OcrFieldCard(label: string, value: string, field: OcrFieldResult, onChange: (v: string) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if (field.text.length > 0) {
          Text(`置信度 ${Math.round(field.confidence * 100)}%`)
            .fontSize(12)
            .fontColor(CaptureOrchestrator.isLowConfidence(field) ? AppColors.WARNING : AppColors.TEXT_PLACEHOLDER)
        }
      }
      .width('100%')
      .margin({ bottom: 4 })

      TextInput({ text: value, placeholder: `请核对${label}` })
        .fontSize(16)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_PAGE)
        .border({ width: CaptureOrchestrator.isLowConfidence(field) ? 1.5 : 0, color: AppColors.WARNING })
        .onChange((v: string) => {
          onChange(v);
        })

      if (CaptureOrchestrator.isLowConfidence(field)) {
        Text('⚠️ 该项识别置信度较低，请重点核对（可使用输入法的语音/手写）')
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
  StepSaveSuccess() {
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
          this.resetFlow();
        })
      Button('返回首页')
        .backgroundColor(AppColors.BG_CARD)
        .fontColor(AppColors.PRIMARY)
        .borderRadius(22)
        .height(44)
        .width('60%')
        .margin({ top: 12 })
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  private async startCapture(fromCamera: boolean): Promise<void> {
    this.capturing = true;
    const path = fromCamera ? await MediaService.capturePhoto() : await MediaService.pickFromAlbum();
    this.capturing = false;
    if (path === undefined || path.length === 0) {
      this.qualityIssue = '';
      return;
    }
    this.imagePath = path;
    const quality = await CaptureOrchestrator.checkImageQuality(path);
    if (!quality.passed) {
      this.qualityIssue = quality.issue;
      this.currentStep = 1;
    } else {
      this.qualityIssue = '';
      this.currentStep = 1;
    }
    await this.loadImageSize();
  }

  private async loadImageSize(): Promise<void> {
    const pm = await MediaService.loadScaledPixelMap(this.imagePath, 1280);
    if (pm !== undefined) {
      try {
        const info = await pm.getImageInfo();
        this.imgNatW = info.size.width;
        this.imgNatH = info.size.height;
        await pm.release();
      } catch (e) {
      }
    }
  }

  private async loadTags(): Promise<void> {
    const tags = await dbHelper.queryKnowledgeTags(this.selectedSubject);
    this.knowledgeTags = tags;
  }

  private currentRegion(): ImageRegion {
    return new ImageRegion(
      Math.round(this.cropLeftFrac * this.imgNatW),
      Math.round(this.cropTopFrac * this.imgNatH),
      Math.round((this.cropRightFrac - this.cropLeftFrac) * this.imgNatW),
      Math.round((this.cropBottomFrac - this.cropTopFrac) * this.imgNatH)
    );
  }

  private async runOcr(region: ImageRegion | undefined): Promise<void> {
    this.ocrBusy = true;
    const result = await CaptureOrchestrator.performOcr(this.imagePath, region);
    this.ocrResult = result;
    this.questionText = result.questionText.text;
    this.standardAnswer = result.standardAnswerCandidate.text;
    this.selectedSubject = SubjectDetector.detect(this.questionText);
    await this.loadTags();
    this.ocrBusy = false;
    this.currentStep = 2;
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

  private qualityHint(issue: string): string {
    if (issue === ImageQualityIssue.BLUR) return '⚠️ 图片可能模糊，建议重新拍摄以获得更清晰的识别';
    if (issue === ImageQualityIssue.TILT) return '⚠️ 图片倾斜，建议重新拍摄';
    if (issue === ImageQualityIssue.GLARE) return '⚠️ 图片有反光，建议调整角度重拍';
    if (issue === ImageQualityIssue.LOW_LIGHT) return '⚠️ 光线较暗，建议在明亮处重拍';
    return '';
  }

  private async saveMistake(): Promise<void> {
    const mistake = Mistake.create(
      generateId(),
      'stu_default',
      this.imagePath,
      this.questionText,
      this.selectedSubject,
      this.selectedTagIds.slice(),
      this.answerType,
      this.standardAnswer
    );
    mistake.isConfirmed = true;
    mistake.errorType = this.selectedErrorType;
    mistake.ocrConfidence = this.ocrResult.questionText.confidence;
    await dbHelper.insertMistake(mistake);

    const pointsLog = PointsCalculator.createPointsLog(generateId(), mistake.studentId, PointsActionType.CAPTURE);
    await dbHelper.insertPointsLog(pointsLog);

    await KnowledgeProfileAggregator.recomputeForStudent(mistake.studentId);
    AnalyticsTracker.trackCapture(mistake.studentId);
    AnalyticsTracker.trackOcrConfirm(mistake.studentId, mistake.ocrConfidence,
      CaptureOrchestrator.isLowConfidence(this.ocrResult.questionText));

    this.currentStep = 3;
  }

  private resetFlow(): void {
    this.currentStep = 0;
    this.questionText = '';
    this.standardAnswer = '';
    this.answerType = AnswerType.TEXT;
    this.selectedErrorType = ErrorType.OTHER;
    this.selectedTagIds = [];
    this.imagePath = '';
    this.qualityIssue = '';
    this.ocrResult = new OcrRecognitionResult();
  }
}

function clamp(v: number, min: number, max: number): number {
  if (v < min) return min;
  if (v > max) return max;
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
