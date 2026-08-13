import { dbHelper } from '../repository/DatabaseHelper';
import { Mistake } from '../models/Mistake';
import { MistakeStatus } from '../models/Enums';
import { MetricSummary } from '../models/AnalyticsEvent';
import { AppColors, AppSizes, subjectLabel } from '../common/Constants';

@Entry
@Component
struct OpsOverviewPage {
  @State summary: MetricSummary = new MetricSummary();
  @State totalMistakes: number = 0;
  @State masteredCount: number = 0;
  @State masteryRate: number = 0;
  @State isLoaded: boolean = false;

  aboutToAppear(): void {
    this.loadMetrics();
  }

  async loadMetrics(): Promise<void> {
    this.summary = await dbHelper.queryMetricSummary();
    const all: Mistake[] = await dbHelper.queryMistakes();
    this.totalMistakes = all.length;
    this.masteredCount = all.filter((m: Mistake) => m.status === MistakeStatus.MASTERED).length;
    this.masteryRate = this.totalMistakes > 0 ? this.masteredCount / this.totalMistakes : 0;
    this.isLoaded = true;
  }

  build() {
    Scroll() {
      Column() {
        Text('运营指标概览')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 4 })
        Text('本地聚合统计（脱敏），对应 FR-OPS 基础运营看板')
          .fontSize(12)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
          .width('100%')
          .padding({ left: 16, bottom: 8 })

        Column() {
          Text('功能使用')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 12 })
          this.MetricRow('拍照录入频次', `${this.summary.captureCount}`)
          this.MetricRow('识别确认次数', `${this.summary.ocrConfirmCount}`)
          this.MetricRow('平均识别置信度', `${Math.round(this.summary.avgOcrConfidence * 100)}%`)
          this.MetricRow('复习提交次数', `${this.summary.reviewSubmitCount}`)
          this.MetricRow('复习正确率', `${Math.round(this.summary.reviewAccuracy * 100)}%`)
          this.MetricRow('掌握判定通过', `${this.summary.masteryAchievedCount}`)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 8 })

        Column() {
          Text('内容与掌握')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 12 })
          this.MetricRow('总错题数', `${this.totalMistakes}`)
          this.MetricRow('已掌握数', `${this.masteredCount}`)
          this.MetricRow('掌握判定通过率', `${Math.round(this.masteryRate * 100)}%`)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        Text('注：完整运营 BI 后台为独立 Web 产品（FR-OPS-01），此处为端侧本地聚合的脱敏指标预览。')
          .fontSize(12)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
          .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
  }

  @Builder
  MetricRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_REGULAR)
        .layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.PRIMARY)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
