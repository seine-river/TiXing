import { Mistake } from '../models/Mistake';
import { ReviewLog } from '../models/ReviewLog';
import { MistakeStatus, Subject, AnswerType, GradingMethod, InputMethod } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { ReviewScheduler } from '../usecases/ReviewScheduler';
import { MasteryEvaluator } from '../usecases/MasteryEvaluator';
import { PointsCalculator } from '../usecases/PointsCalculator';
import { MediaService } from '../services/MediaService';
import { AppColors, AppSizes, AppStrings, subjectLabel, statusLabel, statusColor, formatDate, generateId } from '../common/Constants';
import { StatusTag, SubjectTag, PageTitle, EmptyPlaceholder, PageHeader } from '../components/CommonComponents';
import { MistakeDetailParams } from '../common/RouteParams';

@Entry
@Component
struct MistakeDetailPage {
  @State mistake: Mistake = new Mistake();
  @State reviewLogs: ReviewLog[] = [];
  @State notesText: string = '';
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
    }
    const logs = await dbHelper.queryReviewLogs(id);
    this.reviewLogs = logs;
    this.isLoaded = true;
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
          Text('题目内容')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 6 })
          Text(this.mistake.ocrText)
            .fontSize(16)
            .fontColor(AppColors.TEXT_PRIMARY)
            .lineHeight(24)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('标准答案')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 6 })
          Text(this.mistake.standardAnswer)
            .fontSize(16)
            .fontColor(AppColors.SECONDARY)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_SM)
        .margin({ left: 16, right: 16, top: 8 })

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
            Image(this.mistake.notesAttachmentUrl)
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

        Button('保存笔记')
          .width('90%')
          .height(44)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(22)
          .margin({ top: 24, bottom: 32 })
          .onClick(() => {
            this.saveNotes();
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

  private async saveNotes(): Promise<void> {
    this.mistake.notes = this.notesText;
    await dbHelper.updateMistake(this.mistake);
  }

  private async attachNotePhoto(): Promise<void> {
    const path = await MediaService.pickFromAlbum();
    if (path !== undefined && path.length > 0) {
      this.mistake.notesAttachmentUrl = path;
      await dbHelper.updateMistake(this.mistake);
    }
  }
}
