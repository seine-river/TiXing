import { DbResult } from '../common/DbResult';
import { DataPortabilityService, BundlePreview, BundlePreviewItem } from '../services/DataPortabilityService';
import { AppColors, AppSizes, AppStrings, subjectLabel, formatDate } from '../common/Constants';
import { Toast } from '../common/Toast';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct DataManagementPage {
  @State busy: boolean = false;
  @State busyMsg: string = '';
  @State statusMsg: string = '';
  @State statusOk: boolean = false;
  @State preview: BundlePreview = new BundlePreview();

  build() {
    Column() {
      PageHeader({ title: AppStrings.PAGE_DATA })
      Scroll() {
        Column() {
          Column() {
            Text('导出数据')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 8 })
            Text('将错题、复习记录与错题图片打包为 zip 备份文件，可用于换机备份或分享。')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ bottom: 12 })
            Button(this.busy && this.busyMsg.length > 0 ? this.busyMsg : '导出备份（zip）')
              .width('100%')
              .height(44)
              .backgroundColor(this.busy ? AppColors.DISABLED : AppColors.SOLID_PRIMARY)
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
            Text('选择本应用导出的 zip 备份文件，导入前会先解析预览，需逐条核对确认。')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ bottom: 12 })
            Button(this.busy && this.busyMsg.length > 0 ? this.busyMsg : '选择文件并预览')
              .width('100%')
              .height(44)
              .backgroundColor(this.busy ? AppColors.DISABLED : AppColors.BG_PAGE)
              .fontColor(AppColors.PRIMARY)
              .borderRadius(22)
              .enabled(!this.busy)
              .onClick(() => {
                this.doPickImport();
              })

            if (this.preview.mistakeCount > 0) {
              Text(`预览：${this.preview.mistakeCount} 道错题，${this.preview.logCount} 条复习记录，${this.preview.imageCount} 张图片`)
                .fontSize(13)
                .fontColor(AppColors.TEXT_REGULAR)
                .margin({ top: 12, bottom: 8 })

              ForEach(this.preview.previewItems, (item: BundlePreviewItem) => {
                Row() {
                  Column() {
                    Text(item.ocrText.length > 0 ? item.ocrText : '（无题目文本）')
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
              }, (item: BundlePreviewItem) => item.id)

              Button('确认导入（已核对）')
                .width('100%')
                .height(44)
                .backgroundColor(AppColors.SOLID_SECONDARY)
                .fontColor(Color.White)
                .borderRadius(22)
                .margin({ top: 12 })
                .enabled(!this.busy)
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
              .fontColor(this.statusOk ? AppColors.SECONDARY : AppColors.DANGER)
              .padding({ left: 16, right: 16, top: 16 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  private setBusy(msg: string): void {
    this.busy = true;
    this.busyMsg = msg;
  }

  private clearBusy(): void {
    this.busy = false;
    this.busyMsg = '';
  }

  private async doExport(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.setBusy('导出中...');
    try {
      const path: string = await DataPortabilityService.exportBundle('stu_default');
      this.statusOk = true;
      this.statusMsg = `✅ 已导出到：${path}`;
      Toast.show('导出成功');
    } catch (e) {
      const reason: string = e instanceof Error ? e.message : '未知错误';
      this.statusOk = false;
      this.statusMsg = '❌ 导出失败：' + reason;
      Toast.show('导出失败，请重试');
    }
    this.clearBusy();
  }

  private async doPickImport(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.setBusy('选择文件...');
    const path: string | undefined = await DataPortabilityService.pickBundleFile();
    if (path === undefined) {
      this.clearBusy();
      this.statusOk = false;
      this.statusMsg = '未选择文件';
      return;
    }
    this.setBusy('解析中...');
    try {
      this.preview = await DataPortabilityService.parseBundlePreview(path);
      this.statusOk = true;
      this.statusMsg = `已解析 ${this.preview.mistakeCount} 道错题，请核对后确认导入`;
    } catch (e) {
      const reason: string = e instanceof Error ? e.message : '文件解析失败';
      this.preview = new BundlePreview();
      this.statusOk = false;
      this.statusMsg = '❌ ' + reason;
      Toast.show(reason);
    }
    this.clearBusy();
  }

  private async doImport(): Promise<void> {
    if (this.busy || this.preview.mistakeCount === 0) {
      return;
    }
    this.setBusy('导入中...');
    const result: DbResult = await DataPortabilityService.importBundle(this.preview);
    if (result.success) {
      DataPortabilityService.cleanupImportCache(this.preview);
      this.statusOk = true;
      this.statusMsg = `✅ 导入完成：${this.preview.mistakeCount} 道错题（重复项已自动跳过）`;
      Toast.show('导入成功');
      this.preview = new BundlePreview();
    } else {
      this.statusOk = false;
      this.statusMsg = '❌ 导入失败：' + result.reason;
      Toast.show('导入失败，请重试');
    }
    this.clearBusy();
  }
}
