import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { dbHelper } from '../repository/DatabaseHelper';
import { MediaService } from '../services/MediaService';
import { AiService } from '../services/AiService';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, formatDate, toFileUri } from '../common/Constants';
import { Toast } from '../common/Toast';
import { StatusTag, SubjectTag, PageHeader } from '../components/CommonComponents';
import { EmptyBlock } from '../components/BasicWidgets';
import { MistakeDetailParams } from '../common/RouteParams';

@Entry
@Component
struct MistakeDetailPage {
  @State mistake: Mistake = new Mistake();
  @State reviewLogs: ReviewLog[] = [];
  @State notesText: string = '';
  @State editQuestion: string = '';
  @State editStdAnswer: string = '';
  @State editMyAnswer: string = '';
  @State editKnowledge: string = '';
  @State fieldBusy: string = '';
  @State notFound: boolean = false;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as MistakeDetailParams;
    const id: string = params?.mistakeId ?? '';
    if (id.length > 0) {
      this.loadMistake(id);
    } else {
      this.notFound = true;
    }
  }

  async loadMistake(id: string): Promise<void> {
    const m: Mistake | undefined = await dbHelper.queryMistakeById(id);
    if (m !== undefined) {
      this.mistake = m;
      this.notesText = m.notes;
      this.editQuestion = m.ocrText;
      this.editStdAnswer = m.standardAnswer;
      this.editMyAnswer = m.studentAnswer;
      this.editKnowledge = m.knowledgeSummary;
    } else {
      this.notFound = true;
      return;
    }
    this.reviewLogs = await dbHelper.queryReviewLogs(id);
  }

  @Builder
  EditableCard(target: string) {
    Column() {
      Row() {
        Text(this.fieldLabel(target))
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        if (this.fieldBusy === target) {
          Text('识别中...')
            .fontSize(11)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
        }
      }
      .width('100%')
      .margin({ bottom: 6 })

      if (target === 'question') {
        TextArea({ text: this.editQuestion, placeholder: '输入或修改题目内容' })
          .fontSize(16)
          .fontColor(AppColors.TEXT_PRIMARY)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.editQuestion = v;
          })
      } else if (target === 'standard') {
        TextArea({ text: this.editStdAnswer, placeholder: '输入或修改标准答案' })
          .fontSize(16)
          .fontColor(AppColors.SECONDARY)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.editStdAnswer = v;
          })
      } else {
        TextArea({ text: this.editMyAnswer, placeholder: '输入或修改我的答案' })
          .fontSize(16)
          .fontColor(AppColors.DANGER)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .backgroundColor(AppColors.BG_PAGE)
          .onChange((v: string) => {
            this.editMyAnswer = v;
          })
      }

      Button('🖼️ 相册选图识别')
        .height(32)
        .fontSize(12)
        .backgroundColor(AppColors.CHIP_BG)
        .fontColor(AppColors.TEXT_REGULAR)
        .borderRadius(16)
        .margin({ top: 8 })
        .enabled(this.fieldBusy.length === 0)
        .onClick(() => {
          this.reRecognizeField(target);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 16, right: 16, top: 8 })
  }

  private fieldLabel(target: string): string {
    if (target === 'standard') {
      return '标准答案';
    } else if (target === 'mine') {
      return '我的答案';
    }
    return '题目内容';
  }

  /**
   * 相册选图重新识别（T030/FR-027）：题图更换后 imageUrl 立即落库（updateMistake 含 imageUrl）。
   */
  private async reRecognizeField(target: string): Promise<void> {
    const path = await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未选取图片');
      return;
    }
    this.fieldBusy = target;
    try {
      const text: string = await AiService.recognizeImage(path);
      const cleaned: string = text.trim();
      if (cleaned.length === 0) {
        Toast.show('未识别到文字');
      } else if (target === 'question') {
        this.editQuestion = cleaned;
        this.mistake.imageUrl = path;
        const saveRes = await dbHelper.updateMistake(this.mistake);
        if (!saveRes.success) {
          Toast.show('图片路径保存失败，请点击保存修改重试');
        } else {
          Toast.show('题图已更新');
        }
      } else if (target === 'standard') {
        this.editStdAnswer = cleaned;
      } else {
        this.editMyAnswer = cleaned;
      }
    } catch (e) {
      Toast.show('识别失败，请检查网络或 AI 配置');
    }
    this.fieldBusy = '';
  }

  build() {
    Column() {
      PageHeader({ title: AppStrings.PAGE_DETAIL })
      if (this.notFound) {
        Column() {
          EmptyBlock({ message: '错题不存在或已被删除' })
          Button('返回')
            .height(44)
            .backgroundColor(AppColors.SOLID_PRIMARY)
            .fontColor(Color.White)
            .borderRadius(22)
            .padding({ left: 32, right: 32 })
            .margin({ top: 16 })
            .onClick(() => {
              this.getUIContext().getRouter().back();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Row({ space: 6 }) {
              SubjectTag({ subjectText: subjectLabel(this.mistake.subject), subjectKey: this.mistake.subject })
              StatusTag({ statusText: statusLabel(this.mistake.status), statusKey: this.mistake.status })
              Text(formatDate(this.mistake.createdAt))
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .padding({ left: 16, right: 16, top: 4 })

            // 原始照片（录入时拍摄的错题原图）
            if (this.mistake.imageUrl.length > 0) {
              Column() {
                Text('📷 原始照片')
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .width('100%')
                  .margin({ bottom: 8 })
                Image(toFileUri(this.mistake.imageUrl))
                  .width('100%')
                  .height(220)
                  .objectFit(ImageFit.Contain)
                  .sourceSize({ width: 1080, height: 1080 })
                  .backgroundColor(AppColors.IMAGE_VIEWER_BG)
                  .borderRadius(AppSizes.CORNER_RADIUS_SM)
                  .draggable(false)
                  .alt($r('app.media.startIcon'))
                  .accessibilityText('错题原始照片')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppColors.BG_CARD)
              .borderRadius(AppSizes.CORNER_RADIUS_SM)
              .margin({ left: 16, right: 16, top: 8 })
            }

            Column() {
              Text('知识点总结')
                .fontSize(14)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ bottom: 6 })
              TextInput({ text: this.editKnowledge, placeholder: '知识点总结' })
                .fontSize(16)
                .borderRadius(AppSizes.CORNER_RADIUS_SM)
                .backgroundColor(AppColors.BG_PAGE)
                .onChange((v: string) => {
                  this.editKnowledge = v;
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .margin({ left: 16, right: 16, top: 8 })

            this.EditableCard('question')

            this.EditableCard('standard')

            this.EditableCard('mine')

            Column() {
              Text('掌握度信息')
                .fontSize(14)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ bottom: 8 })
              Row() {
                Text('间隔级别:')
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_REGULAR)
                Text(`${this.mistake.intervalIndex + 1}/5`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.PRIMARY)
                  .margin({ left: 4 })
                Text('  下次复习:')
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_REGULAR)
                  .margin({ left: 12 })
                Text(formatDate(this.mistake.nextReviewDate))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.WARNING)
                  .margin({ left: 4 })
              }
              Progress({ value: this.mistake.intervalIndex + 1, total: 5, type: ProgressType.Linear })
                .width('100%')
                .color(AppColors.PRIMARY)
                .margin({ top: 8 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .margin({ left: 16, right: 16, top: 8 })

            Column() {
              Row() {
                Text(AppStrings.ADD_NOTES)
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .layoutWeight(1)
                Button('🖼️ 相册选图笔记')
                  .height(32)
                  .fontSize(12)
                  .backgroundColor(AppColors.CHIP_BG)
                  .fontColor(AppColors.TEXT_REGULAR)
                  .borderRadius(16)
                  .onClick(() => {
                    this.attachNotePhoto();
                  })
              }
              .width('100%')
              .margin({ bottom: 6 })
              TextInput({ text: this.notesText, placeholder: '添加讲解笔记（可使用输入法语音/手写）...' })
                .fontSize(16)
                .onChange((value: string) => {
                  this.notesText = value;
                })
                .borderRadius(AppSizes.CORNER_RADIUS_SM)
                .backgroundColor(AppColors.BG_PAGE)
              if (this.mistake.notesAttachmentUrl.length > 0) {
                Image(toFileUri(this.mistake.notesAttachmentUrl))
                  .width('100%')
                  .height(160)
                  .objectFit(ImageFit.Contain)
                  .sourceSize({ width: 1080, height: 800 })
                  .borderRadius(AppSizes.CORNER_RADIUS_SM)
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .margin({ left: 16, right: 16, top: 8 })

            Column() {
              Text('复习历史')
                .fontSize(14)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ bottom: 8 })

              if (this.reviewLogs.length === 0) {
                Text('暂无复习记录')
                  .fontSize(14)
                  .fontColor(AppColors.TEXT_PLACEHOLDER)
              } else {
                ForEach(this.reviewLogs, (log: ReviewLog) => {
                  Row() {
                    Text(formatDate(log.reviewTime))
                      .fontSize(13)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .layoutWeight(1)
                    Text(log.correct ? '✓ 正确' : '✗ 错误')
                      .fontSize(13)
                      .fontColor(log.correct ? AppColors.SECONDARY : AppColors.DANGER)
                    Text(`${log.durationSeconds}秒`)
                      .fontSize(13)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                }, (log: ReviewLog) => log.id)
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .margin({ left: 16, right: 16, top: 8 })

            Button('保存修改')
              .width('90%')
              .height(44)
              .backgroundColor(AppColors.SOLID_PRIMARY)
              .fontColor(Color.White)
              .borderRadius(22)
              .margin({ top: 24, bottom: 32 })
              .onClick(() => {
                this.saveAll();
              })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .backgroundColor(AppColors.BG_PAGE)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  private async saveAll(): Promise<void> {
    this.mistake.notes = this.notesText;
    this.mistake.ocrText = this.editQuestion;
    this.mistake.standardAnswer = this.editStdAnswer;
    this.mistake.studentAnswer = this.editMyAnswer;
    this.mistake.knowledgeSummary = this.editKnowledge;
    const result = await dbHelper.updateMistake(this.mistake);
    if (result.success) {
      Toast.show('已保存修改');
    } else {
      Toast.show('保存失败：' + (result.reason.length > 0 ? result.reason : '请重试'));
    }
  }

  private async attachNotePhoto(): Promise<void> {
    const path = await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未选取图片');
      return;
    }
    this.mistake.notesAttachmentUrl = path;
    const result = await dbHelper.updateMistake(this.mistake);
    if (result.success) {
      Toast.show('已添加图片笔记');
    } else {
      Toast.show('附件保存失败，请重试');
    }
  }
}
