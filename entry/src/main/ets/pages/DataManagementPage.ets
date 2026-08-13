import { Mistake } from '../models/Mistake';
import { MistakeStatus, Subject } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { DataPortabilityService, ImportPreview } from '../services/DataPortabilityService';
import { KnowledgeProfileAggregator } from '../usecases/KnowledgeProfileAggregator';
import { AppColors, AppSizes, subjectLabel, formatDate } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct DataManagementPage {
  @State statusMsg: string = '';
  @State importPath: string = '';
  @State importPreview: ImportPreview = new ImportPreview();
  @State busy: boolean = false;

  build() {
    Column() {
      PageHeader({ title: '导出与导入' })
      Scroll() {
        Column() {
          Column() {
            Text('导出数据')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 8 })
          Text('将错题与复习记录导出为 JSON 结构化文件，可用于换机备份或分享。')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 12 })
          Button('导出 JSON')
            .width('100%')
            .height(44)
            .backgroundColor(this.busy ? '#C0C4CC' : AppColors.PRIMARY)
            .fontColor(Color.White)
            .borderRadius(22)
            .enabled(!this.busy)
            .onClick(() => {
              this.doExport();
            })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('导入数据')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 8 })
          Text('导入本应用备份文件，导入前需逐条核对确认。')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 12 })
          Button('选择文件并预览')
            .width('100%')
            .height(44)
            .backgroundColor(this.busy ? '#C0C4CC' : AppColors.BG_PAGE)
            .fontColor(AppColors.PRIMARY)
            .borderRadius(22)
            .enabled(!this.busy)
            .onClick(() => {
              this.doPickImport();
            })

          if (this.importPreview.mistakes.length > 0) {
            Text(`预览：${this.importPreview.mistakes.length} 道错题，${this.importPreview.logCount} 条复习记录`)
              .fontSize(13)
              .fontColor(AppColors.TEXT_REGULAR)
              .margin({ top: 12, bottom: 8 })

            ForEach(this.importPreview.mistakes.slice(0, 10), (item: Mistake) => {
              Row() {
                Column() {
                  Text(item.ocrText.length > 30 ? item.ocrText.substring(0, 30) + '...' : item.ocrText)
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text(`${subjectLabel(item.subject)} · ${formatDate(item.createdAt)}`)
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
            }, (item: Mistake) => item.id)

            Button('确认导入（已核对）')
              .width('100%')
              .height(44)
              .backgroundColor(AppColors.SECONDARY)
              .fontColor(Color.White)
              .borderRadius(22)
              .margin({ top: 12 })
              .onClick(() => {
                this.doImport();
              })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        if (this.statusMsg.length > 0) {
          Text(this.statusMsg)
            .fontSize(14)
            .fontColor(AppColors.SECONDARY)
            .padding({ left: 16, right: 16, top: 16 })
        }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  private async doExport(): Promise<void> {
    this.busy = true;
    try {
      const path = await DataPortabilityService.exportToJson('stu_default');
      this.statusMsg = `✅ 已导出到：${path}`;
    } catch (e) {
      this.statusMsg = '❌ 导出失败';
    }
    this.busy = false;
  }

  private async doPickImport(): Promise<void> {
    this.busy = true;
    const path = await DataPortabilityService.pickImportFile();
    this.busy = false;
    if (path === undefined) {
      this.statusMsg = '未选择文件';
      return;
    }
    this.importPath = path;
    this.importPreview = DataPortabilityService.parsePreview(path);
    this.statusMsg = `已解析 ${this.importPreview.mistakes.length} 道错题，请核对后确认导入`;
  }

  private async doImport(): Promise<void> {
    this.busy = true;
    const count = await DataPortabilityService.applyImport(this.importPreview);
    await KnowledgeProfileAggregator.recomputeForStudent('stu_default');
    this.statusMsg = `✅ 成功导入 ${count} 道错题`;
    this.importPreview = new ImportPreview();
    this.busy = false;
  }
}
