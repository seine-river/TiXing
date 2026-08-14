import { Mistake, OcrFieldResult, OcrRecognitionResult, CropFracs } from '../models/Mistake';
import { Subject, AnswerType, ErrorType, ContentType, Grade, ImageQualityIssue, PointsActionType } from '../models/Enums';
import { KnowledgeTag } from '../models/KnowledgeTag';
import { dbHelper } from '../repository/DatabaseHelper';
import { CaptureOrchestrator } from '../usecases/CaptureOrchestrator';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AnalyticsTracker } from '../usecases/AnalyticsTracker';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { MediaService } from '../services/MediaService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AiService } from '../services/AiService';
import { AppColors, AppSizes, AppStrings, subjectLabel, generateId, toFileUri } from '../common/Constants';
import { Toast } from '../common/Toast';
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
  @State studentAnswer: string = '';
  @State knowledgeSummary: string = '';
  @State answerType: AnswerType = AnswerType.TEXT;
  @State isConfirmed: boolean = false;
  @State capturing: boolean = false;

  @State compareResult: string = '';
  @State knowledgeBusy: boolean = false;
  @State compareBusy: boolean = false;

  @State stdImage: string = '';
  @State myImage: string = '';
  @State regionTarget: string = 'question';
  @State regionImagePath: string = '';
  @State stdAnalyzing: boolean = false;
  @State myAnalyzing: boolean = false;
  private stdFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
  private myFracs: CropFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);

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
  @State cropLeftFrac: number = 0.08;
  @State cropTopFrac: number = 0.08;
  @State cropRightFrac: number = 0.92;
  @State cropBottomFrac: number = 0.92;

  @State dragStartLeft: number = 0;
  @State dragStartTop: number = 0;
  @State dragStartRight: number = 0;
  @State dragStartBottom: number = 0;

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
    .shadow({ radius: 8, color: '#14223640', offsetY: 2 })
    .onClick(() => {
      this.startCapture(fromCamera);
    })
  }

  @Builder
  StepRegionSelect() {
    Column() {
      Text(this.regionTarget === 'question' ? '拖动四角调整题目识别区域' : '拖动四角框选答案区域')
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 16, top: 12, bottom: 8 })

      Stack() {
        Image(toFileUri(this.regionImagePath))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)

        Column() {
        }
        .width((this.cropRightFrac - this.cropLeftFrac) * this.dispW)
        .height((this.cropBottomFrac - this.cropTopFrac) * this.dispH)
        .position({ x: this.cropLeftFrac * this.dispW, y: this.cropTopFrac * this.dispH })
        .border({ width: 2, color: AppColors.PRIMARY })
        .backgroundColor('#333A7BD5')
        .hitTestBehavior(HitTestMode.Transparent)

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
        .position({ x: this.cropLeftFrac * this.dispW - 22, y: this.cropTopFrac * this.dispH - 22 })
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.dragStartLeft = this.cropLeftFrac;
              this.dragStartTop = this.cropTopFrac;
            })
            .onActionUpdate((e) => {
              const dx: number = e.offsetX / (this.dispW > 0 ? this.dispW : 1);
              const dy: number = e.offsetY / (this.dispH > 0 ? this.dispH : 1);
              this.cropLeftFrac = clamp(this.dragStartLeft + dx, 0, this.cropRightFrac - 0.05);
              this.cropTopFrac = clamp(this.dragStartTop + dy, 0, this.cropBottomFrac - 0.05);
            })
        )

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
        .position({ x: this.cropRightFrac * this.dispW - 22, y: this.cropBottomFrac * this.dispH - 22 })
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.dragStartRight = this.cropRightFrac;
              this.dragStartBottom = this.cropBottomFrac;
            })
            .onActionUpdate((e) => {
              const dx: number = e.offsetX / (this.dispW > 0 ? this.dispW : 1);
              const dy: number = e.offsetY / (this.dispH > 0 ? this.dispH : 1);
              this.cropRightFrac = clamp(this.dragStartRight + dx, this.cropLeftFrac + 0.05, 1);
              this.cropBottomFrac = clamp(this.dragStartBottom + dy, this.cropTopFrac + 0.05, 1);
            })
        )
      }
      .width('100%')
      .aspectRatio(this.imageAspectRatio())
      .margin({ left: 16, right: 16 })
      .backgroundColor('#000000')
      .borderRadius(AppSizes.CORNER_RADIUS_SM)
      .clip(true)
      .onAreaChange((_o: Area, n: Area) => {
        this.dispW = toPixels(n.width);
        this.dispH = toPixels(n.height);
      })

      Row() {
        Button(this.regionTarget === 'question' ? '识别全图' : '使用全图')
          .height(40)
          .backgroundColor(AppColors.BG_CARD)
          .fontColor(AppColors.PRIMARY)
          .borderRadius(20)
          .margin({ right: 12 })
          .enabled(this.regionTarget !== 'question' || !this.ocrBusy)
          .onClick(() => {
            this.onRegionConfirm(undefined);
          })
        Button(this.regionTarget === 'question' ? '识别此区域' : '确认区域')
          .height(40)
          .backgroundColor(this.ocrBusy ? '#C0C4CC' : AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(20)
          .enabled(this.regionTarget !== 'question' || !this.ocrBusy)
          .onClick(() => {
            this.onRegionConfirm(this.currentFracs());
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

  private async onRegionConfirm(fracs: CropFracs | undefined): Promise<void> {
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

  private async enterRegion(target: string): Promise<void> {
    this.regionTarget = target;
    if (target === 'question') {
      this.regionImagePath = this.imagePath;
      this.cropLeftFrac = 0.08;
      this.cropTopFrac = 0.08;
      this.cropRightFrac = 0.92;
      this.cropBottomFrac = 0.92;
    } else if (target === 'standard') {
      this.regionImagePath = this.stdImage;
      this.cropLeftFrac = this.stdFracs.leftFrac;
      this.cropTopFrac = this.stdFracs.topFrac;
      this.cropRightFrac = this.stdFracs.rightFrac;
      this.cropBottomFrac = this.stdFracs.bottomFrac;
    } else {
      this.regionImagePath = this.myImage;
      this.cropLeftFrac = this.myFracs.leftFrac;
      this.cropTopFrac = this.myFracs.topFrac;
      this.cropRightFrac = this.myFracs.rightFrac;
      this.cropBottomFrac = this.myFracs.bottomFrac;
    }
    await this.loadRegionImageSize();
    this.currentStep = 1;
  }

  private async loadRegionImageSize(): Promise<void> {
    const pm = await MediaService.loadScaledPixelMap(this.regionImagePath, 1280);
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

  private imageAspectRatio(): number {
    if (this.imgNatW > 0 && this.imgNatH > 0) {
      return this.imgNatW / this.imgNatH;
    }
    return 0.75;
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

        this.AnswerFieldCard('标准答案', this.standardAnswer, 'standard')
        this.AnswerFieldCard('我的答案', this.studentAnswer, 'mine')

        Button(this.compareBusy ? '🔍 AI 分析中...' : '🔍 智能对比分析')
          .width('90%')
          .height(42)
          .backgroundColor(this.compareBusy ? '#C0C4CC' : AppColors.SECONDARY)
          .fontColor(Color.White)
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
  AnswerFieldCard(label: string, value: string, target: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if ((target === 'standard' && this.stdAnalyzing) || (target === 'mine' && this.myAnalyzing)) {
          Text('AI 分析中...')
            .fontSize(11)
            .fontColor(AppColors.WARNING)
        }
      }
      .width('100%')
      .margin({ bottom: 4 })

      TextArea({ text: value, placeholder: `输入${label}，或选图后智能分析` })
        .fontSize(16)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_PAGE)
        .onChange((v: string) => {
          if (target === 'standard') {
            this.standardAnswer = v;
          } else {
            this.studentAnswer = v;
          }
        })

      if (this.answerImageOf(target).length > 0) {
        Row() {
          Image(toFileUri(this.answerImageOf(target)))
            .width(72)
            .height(72)
            .borderRadius(AppSizes.CORNER_RADIUS_XS)
            .objectFit(ImageFit.Cover)
            .margin({ right: 8 })

          Column({ space: 8 }) {
            Button('✂️ 框选区域')
              .height(32)
              .fontSize(12)
              .backgroundColor('#E8EAED')
              .fontColor(AppColors.TEXT_REGULAR)
              .borderRadius(16)
              .onClick(() => {
                this.enterRegion(target);
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
          .backgroundColor('#E8EAED')
          .fontColor(AppColors.TEXT_REGULAR)
          .borderRadius(16)
          .onClick(() => {
            this.pickAnswerImage(target, true);
          })
        Button('🖼️ 相册')
          .height(32)
          .fontSize(12)
          .backgroundColor('#E8EAED')
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

  private answerImageOf(target: string): string {
    if (target === 'standard') {
      return this.stdImage;
    }
    return this.myImage;
  }

  private answerAnalyzing(target: string): boolean {
    if (target === 'standard') {
      return this.stdAnalyzing;
    }
    return this.myAnalyzing;
  }

  private async pickAnswerImage(target: string, fromCamera: boolean): Promise<void> {
    const path = fromCamera ? await MediaService.capturePhoto() : await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未获取到图片，请重试');
      return;
    }
    if (target === 'standard') {
      this.stdImage = path;
      this.stdFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
    } else {
      this.myImage = path;
      this.myFracs = new CropFracs(0.05, 0.05, 0.95, 0.95);
    }
    await this.enterRegion(target);
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
      const fracs: CropFracs = target === 'standard' ? this.stdFracs : this.myFracs;
      const text: string = await AiService.recognizeImage(img, fracs);
      const cleaned: string = text.trim();
      if (cleaned.length === 0) {
        Toast.show('未识别到文字，请手动输入');
      } else if (target === 'standard') {
        this.standardAnswer = this.standardAnswer.length > 0 ? this.standardAnswer + ' ' + cleaned : cleaned;
      } else {
        this.studentAnswer = this.studentAnswer.length > 0 ? this.studentAnswer + ' ' + cleaned : cleaned;
      }
    } catch (e) {
      Toast.show('AI 分析失败，请检查网络');
    }
    if (target === 'standard') {
      this.stdAnalyzing = false;
    } else {
      this.myAnalyzing = false;
    }
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

      TextArea({ text: value, placeholder: `请核对${label}` })
        .fontSize(16)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_PAGE)
        .border({ width: CaptureOrchestrator.isLowConfidence(field) ? 1.5 : 0, color: AppColors.WARNING })
        .onChange((v: string) => {
          onChange(v);
        })

      if (label === '题目内容') {
        Button('🔄 重新选择题目图片')
          .height(32)
          .fontSize(12)
          .backgroundColor('#E8EAED')
          .fontColor(AppColors.TEXT_REGULAR)
          .borderRadius(16)
          .margin({ top: 8 })
          .onClick(() => {
            this.repickQuestion();
          })
      }

      if (CaptureOrchestrator.isLowConfidence(field)) {
        Text('⚠️ 该项识别置信度较低，请重点核对')
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

  private repickQuestion(): void {
    this.currentStep = 0;
  }

  private async startCapture(fromCamera: boolean): Promise<void> {
    this.capturing = true;
    const path = fromCamera ? await MediaService.capturePhoto() : await MediaService.pickFromAlbum();
    this.capturing = false;
    if (path === undefined || path.length === 0) {
      Toast.show(fromCamera ? '相机不可用或未拍照，请改用相册选取' : '未选取图片，请重试');
      this.qualityIssue = '';
      return;
    }
    this.imagePath = path;
    const quality = await CaptureOrchestrator.checkImageQuality(path);
    if (!quality.passed) {
      this.qualityIssue = quality.issue;
    } else {
      this.qualityIssue = '';
    }
    await this.enterRegion('question');
  }

  private async loadTags(): Promise<void> {
    const tags = await dbHelper.queryKnowledgeTags(this.selectedSubject);
    this.knowledgeTags = tags;
  }

  private currentFracs(): CropFracs {
    return new CropFracs(this.cropLeftFrac, this.cropTopFrac, this.cropRightFrac, this.cropBottomFrac);
  }

  private async runOcr(fracs: CropFracs | undefined): Promise<void> {
    this.ocrBusy = true;
    const localResult = await CaptureOrchestrator.performOcr(this.imagePath, fracs);
    const localText: string = localResult.questionText.text;
    this.ocrResult = localResult;
    this.questionText = localText;
    this.ocrBusy = false;
    this.currentStep = 2;
    if (localText.length === 0) {
      Toast.show('本地识别未提取到文字，正在用AI识别图片...');
    }
    this.recognizeByAi(fracs, localText);
  }

  private async recognizeByAi(fracs: CropFracs | undefined, localText: string): Promise<void> {
    this.knowledgeBusy = true;
    try {
      const ai = await AiService.recognizeQuestion(this.imagePath, fracs, localText);
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
      if (this.knowledgeSummary.length === 0) {
        this.knowledgeSummary = subjectLabel(this.selectedSubject) + '错题';
      }
      Toast.show('AI识别失败，请检查网络，可手动修改');
    }
    this.knowledgeBusy = false;
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
      this.compareResult = diffAnswers(s, m);
      Toast.show('AI 分析失败，已使用本地对比');
    }
    this.compareBusy = false;
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

  private qualityHint(issue: string): string {
    if (issue === ImageQualityIssue.BLUR) return '⚠️ 图片可能模糊，建议重新拍摄以获得更清晰的识别';
    if (issue === ImageQualityIssue.TILT) return '⚠️ 图片倾斜，建议重新拍摄';
    if (issue === ImageQualityIssue.GLARE) return '⚠️ 图片有反光，建议调整角度重拍';
    if (issue === ImageQualityIssue.LOW_LIGHT) return '⚠️ 光线较暗，建议在明亮处重拍';
    return '';
  }

  private async saveMistake(): Promise<void> {
    try {
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
      mistake.studentAnswer = this.studentAnswer;
      mistake.knowledgeSummary = this.knowledgeSummary;
      await dbHelper.insertMistake(mistake);

      const pointsLog = PointsCalculator.createPointsLog(generateId(), mistake.studentId, PointsActionType.CAPTURE);
      await dbHelper.insertPointsLog(pointsLog);

      await KnowledgeProfileAggregator.recomputeForStudent(mistake.studentId);
      AnalyticsTracker.trackCapture(mistake.studentId);
      AnalyticsTracker.trackOcrConfirm(mistake.studentId, mistake.ocrConfidence,
        CaptureOrchestrator.isLowConfidence(this.ocrResult.questionText));
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
    this.standardAnswer = '';
    this.studentAnswer = '';
    this.knowledgeSummary = '';
    this.compareResult = '';
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
    this.stdAnalyzing = false;
    this.myAnalyzing = false;
    this.qualityIssue = '';
    this.ocrResult = new OcrRecognitionResult();
    this.imgNatW = 0;
    this.imgNatH = 0;
    this.dispW = 0;
    this.dispH = 0;
    this.cropLeftFrac = 0.08;
    this.cropTopFrac = 0.08;
    this.cropRightFrac = 0.92;
    this.cropBottomFrac = 0.92;
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
