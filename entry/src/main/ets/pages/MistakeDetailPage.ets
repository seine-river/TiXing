import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { MistakeStatus, Subject, AnswerType, GradingMethod, InputMethod } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { ReviewScheduler } from '../usecases/ReviewScheduler';
import { MasteryEvaluator } from '../usecases/MasteryEvaluator';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { MediaService } from '../services/MediaService';
import { AiService } from '../services/AiService';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, statusColor, formatDate, generateId, toFileUri } from '../common/Constants';
import { Toast } from '../common/Toast';
import { StatusTag, SubjectTag, PageTitle, EmptyPlaceholder, PageHeader } from '../components/CommonComponents';
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
  @State isLoaded: boolean = false;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as MistakeDetailParams;
    const id: string = params?.mistakeId ?? '';
    if (id.length > 0) {
      this.loadMistake(id);
    }
  }

  async loadMistake(id: string): Promise<void> {
    const m = await dbHelper.queryMistakeById(id);
    if (m !== undefined) {
      this.mistake = m;
      this.notesText = m.notes;
      this.editQuestion = m.ocrText;
      this.editStdAnswer = m.standardAnswer;
      this.editMyAnswer = m.studentAnswer;
      this.editKnowledge = m.knowledgeSummary;
    }
    const logs = await dbHelper.queryReviewLogs(id);
    this.reviewLogs = logs;
    this.isLoaded = true;
  }

  @Builder
  EditableCard(label: string, value: string, color: string, onChange: (v: string) => void, target: string) {
    Column() {
      Row() {
        Text(label)
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

      TextArea({ text: value, placeholder: `输入或修改${label}` })
        .fontSize(16)
        .fontColor(color)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .backgroundColor(AppColors.BG_PAGE)
        .onChange((v: string) => {
          onChange(v);
        })

      Button('📷 拍照重新识别')
        .height(32)
        .fontSize(12)
        .backgroundColor('#E8EAED')
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

  private async reRecognizeField(target: string): Promise<void> {
    const path = await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未选取图片');
      return;
    }
    this.fieldBusy = target;
    try {
      const text: string = await AiService.recognizeImage(path, undefined);
      const cleaned: string = text.trim();
      if (cleaned.length === 0) {
        Toast.show('未识别到文字');
      } else if (target === 'question') {
        this.editQuestion = cleaned;
        this.mistake.imageUrl = path;
      } else if (target === 'standard') {
        this.editStdAnswer = cleaned;
      } else {
        this.editMyAnswer = cleaned;
      }
    } catch (e) {
      Toast.show('识别失败，请检查网络');
    }
    this.fieldBusy = '';
  }

  build() {
    Column() {
      PageHeader({ title: '错题详情' })
      Scroll() {
        Column() {
          Row({ space: 6 }) {
            SubjectTag({ subjectText: subjectLabel(this.mistake.subject), subjectColor: AppColors.PRIMARY })
            StatusTag({ statusText: statusLabel(this.mistake.status), statusColor: statusColor(this.mistake.status) })
            Text(formatDate(this.mistake.createdAt))
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .padding({ left: 16, right: 16, top: 4 })

        Column() {
          Text('知识点总结')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 6 })
          TextInput({ text: this.editKnowledge, placeholder: '知识点总结' })
            .fontSize(16)
            .borderRadius(AppSizes.CORNER_RADIUS_SM)
            .backgroundColor(AppColors.BG_PAGE)
            .onChange((v: string) => { this.editKnowledge = v; })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        this.EditableCard('题目内容', this.editQuestion, AppColors.TEXT_PRIMARY, (v: string) => {
          this.editQuestion = v;
        }, 'question')

        this.EditableCard('标准答案', this.editStdAnswer, AppColors.SECONDARY, (v: string) => {
          this.editStdAnswer = v;
        }, 'standard')

        this.EditableCard('我的答案', this.editMyAnswer, AppColors.DANGER, (v: string) => {
          this.editMyAnswer = v;
        }, 'mine')

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
            Button('📷 拍照笔记')
              .height(32)
              .fontSize(12)
              .backgroundColor('#E8EAED')
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
          .backgroundColor(AppColors.PRIMARY)
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
    try {
      await dbHelper.updateMistake(this.mistake);
      Toast.show('已保存修改');
    } catch (e) {
      Toast.show('保存失败，请重试');
    }
  }

  private async attachNotePhoto(): Promise<void> {
    const path = await MediaService.pickFromAlbum();
    if (path === undefined || path.length === 0) {
      Toast.show('未选取图片');
      return;
    }
    this.mistake.notesAttachmentUrl = path;
    try {
      await dbHelper.updateMistake(this.mistake);
      Toast.show('已添加拍照笔记');
    } catch (e) {
      Toast.show('附件保存失败，请重试');
    }
  }
}
