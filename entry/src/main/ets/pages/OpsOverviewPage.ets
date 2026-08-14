import { dbHelper } from '../repository/DatabaseHelper';
import { Mistake } from '../models/Mistake';
import { MistakeStatus } from '../models/Enums';
import { MetricSummary, ReviewStats } from '../models/AnalyticsEvent';
import { AppColors, AppSizes } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';

@Entry
@Component
struct OpsOverviewPage {
  @State totalMistakes: number = 0;
  @State masteredCount: number = 0;
  @State masteryRate: number = 0;
  @State reviewTotal: number = 0;
  @State reviewAccuracy: number = 0;
  @State ocrConfirmCount: number = 0;
  @State avgOcrConfidence: number = 0;

  aboutToAppear(): void {
    this.loadMetrics();
  }

  async loadMetrics(): Promise<void> {
    const all: Mistake[] = await dbHelper.queryMistakes();
    this.totalMistakes = all.length;
    this.masteredCount = all.filter((m: Mistake) => m.status === MistakeStatus.MASTERED).length;
    this.masteryRate = this.totalMistakes > 0 ? this.masteredCount / this.totalMistakes : 0;

    const reviewStats: ReviewStats = await dbHelper.queryReviewStats();
    this.reviewTotal = reviewStats.total;
    this.reviewAccuracy = reviewStats.total > 0 ? reviewStats.correct / reviewStats.total : 0;

    const summary: MetricSummary = await dbHelper.queryMetricSummary();
    this.ocrConfirmCount = summary.ocrConfirmCount;
    this.avgOcrConfidence = summary.avgOcrConfidence;
  }

  build() {
    Column() {
      PageHeader({ title: '家长中心' })
      Scroll() {
        Column() {
          Text('本地聚合统计（脱敏），对应 FR-OPS 基础运营看板')
            .fontSize(12)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
            .width('100%')
            .padding({ left: 16, bottom: 8 })

          Column() {
            Text('错题与掌握')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 12 })
            this.MetricRow('累计录入错题数', `${this.totalMistakes}`)
            this.MetricRow('已掌握数', `${this.masteredCount}`)
            this.MetricRow('掌握判定通过率', `${Math.round(this.masteryRate * 100)}%`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 8 })

          Column() {
            Text('复习情况')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 12 })
            this.MetricRow('累计复习次数', `${this.reviewTotal}`)
            this.MetricRow('复习正确率', `${Math.round(this.reviewAccuracy * 100)}%`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS)
          .margin({ left: 16, right: 16, top: 12 })

          Column() {
            Text('识别质量')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: 12 })
            this.MetricRow('识别确认次数', `${this.ocrConfirmCount}`)
            this.MetricRow('平均识别置信度', `${Math.round(this.avgOcrConfidence * 100)}%`)
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
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
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
