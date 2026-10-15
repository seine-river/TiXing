import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, formatDate } from '../common/Constants';
import { PageHeader } from '../components/CommonComponents';
import { EmptyBlock, PrimaryButton } from '../components/BasicWidgets';
import { Toast } from '../common/Toast';
import { AiService } from '../services/AiService';
import { CuriosityAggregator } from '../usecases/CuriosityAggregator';
import { Student } from '../models/Student';
import {
  InterestInsight, VoiceAskRecord, VoiceAskStats,
  voiceAskSubjectLabel, VoiceAskSubjectSummary, VoiceAskTopicSummary, VoiceAskTagSummary
} from '../models/VoiceAsk';

@Entry
@Component
struct CuriosityPlanetPage {
  @State records: VoiceAskRecord[] = [];
  @State stats: VoiceAskStats = new VoiceAskStats();
  @State insights: InterestInsight[] = [];
  @State busy: boolean = false;
  @State stage: string = '点亮好奇星球';
  @State errorText: string = '';
  private grade: string = '3';

  aboutToAppear(): void {
    this.loadData();
  }

  build() {
    Column() {
      PageHeader({ title: '好奇星球' })
      Scroll() {
        Column() {
          Column() {
            Text('🪐')
              .fontSize(58)
              .width(116)
              .height(116)
              .textAlign(TextAlign.Center)
              .backgroundColor('#26FFFFFF')
              .borderRadius(42)
              .scale({ x: this.busy ? 1.06 : 1, y: this.busy ? 1.06 : 1 })
              .animation({ duration: 700, curve: Curve.EaseInOut })
            Text(this.busy ? this.stage : '点亮好奇星球')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 14 })
            Text(this.records.length > 0
              ? `已经收集 ${this.records.length} 个问题 · 本周 +${this.stats.weekCount}`
              : '先去中间麦克风问一个问题，星球就会亮起来')
              .fontSize(13)
              .fontColor('#E6FFFFFF')
              .margin({ top: 6 })

            Column() {
              PrimaryButton({
                text: this.busy ? this.stage : '点亮好奇星球',
                isEnabled: !this.busy && this.records.length > 0,
                onTap: (): void => {
                  this.generateReport();
                }
              })
            }
            .width('100%')
            .margin({ top: 18 })
          }
          .width('100%')
          .padding({ top: 28, bottom: 24, left: 18, right: 18 })
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 145,
            colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.45],
              [AppColors.SOLID_SECONDARY, 1]]
          })
          .borderRadius(AppSizes.CORNER_RADIUS_XL)
          .shadow({ radius: 16, color: AppColors.SHADOW_PRIMARY, offsetY: 5 })

          if (this.errorText.length > 0) {
            Column() {
              Text('报告没有点亮')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.DANGER)
                .width('100%')
                .margin({ bottom: 5 })
              Text(this.errorText)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .maxLines(8)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.SOFT_DANGER)
            .borderRadius(AppSizes.CORNER_RADIUS)
            .margin({ top: 12 })
          }

          if (this.insights.length > 0) {
            this.InsightCard(this.insights[0])
          } else {
            EmptyBlock({ message: '点亮后，醒醒会把孩子的问题变成一份有趣的成长观察' })
          }

          if (this.stats.subjects.length > 0 || this.stats.topics.length > 0 || this.stats.tags.length > 0) {
            Column() {
              Text('星球信号')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 10 })
              this.StatRow('最爱领域', this.subjectTexts())
              this.StatRow('高频主题', this.topicTexts())
              this.StatRow('兴趣星标', this.tagTexts())
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_LG)
            .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
            .margin({ top: 12 })
          }

          if (this.insights.length > 1) {
            Column() {
              Text('历史报告')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 8 })
              ForEach(this.insights, (item: InterestInsight, index: number) => {
                if (index > 0) {
                  Row() {
                    Text(formatDate(item.generatedAt))
                      .fontSize(13)
                      .fontColor(AppColors.TEXT_PRIMARY)
                    Text(`${item.questionCount} 个问题`)
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .margin({ left: 10 })
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                }
              }, (item: InterestInsight) => item.id)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(16)
            .backgroundColor(AppColors.BG_CARD)
            .borderRadius(AppSizes.CORNER_RADIUS_LG)
            .margin({ top: 12 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  InsightCard(item: InterestInsight) {
    Column() {
      Text('孩子看到的星球')
        .fontSize(13)
        .fontColor(AppColors.PRIMARY)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 5 })
      Text(item.childSummary)
        .fontSize(16)
        .lineHeight(27)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')

      Divider()
        .color(AppColors.DIVIDER)
        .margin({ top: 14, bottom: 14 })

      Text('家长看到的观察')
        .fontSize(13)
        .fontColor(AppColors.TEXT_SECONDARY)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 5 })
      Text(item.parentSummary)
        .fontSize(14)
        .lineHeight(24)
        .fontColor(AppColors.TEXT_REGULAR)
        .width('100%')

      if (item.recommendedActivities.length > 0) {
        Text('可以一起做')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .margin({ top: 14, bottom: 6 })
        ForEach(item.recommendedActivities, (activity: string) => {
          Text('· ' + activity)
            .fontSize(13)
            .fontColor(AppColors.TEXT_REGULAR)
            .width('100%')
            .margin({ top: 3 })
        }, (activity: string) => activity)
      }

      Text(`生成于 ${formatDate(item.generatedAt)} · 覆盖 ${item.questionCount} 个问题`)
        .fontSize(11)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
        .margin({ top: 14 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 12, color: AppColors.SHADOW_SOFT, offsetY: 3 })
    .margin({ top: 16 })
  }

  @Builder
  StatRow(label: string, values: string) {
    if (values.length > 0) {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width(70)
        Text(values)
          .fontSize(13)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 6, bottom: 6 })
    }
  }

  private async loadData(): Promise<void> {
    const student: Student | undefined = await dbHelper.queryStudent('stu_default');
    if (student !== undefined) {
      this.grade = student.grade;
    }
    this.records = await dbHelper.queryVoiceAskRecords('stu_default');
    this.stats = CuriosityAggregator.aggregate(this.records);
    this.insights = await dbHelper.queryInterestInsights('stu_default', 20);
  }

  private async generateReport(): Promise<void> {
    if (this.busy || this.records.length === 0) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    this.stage = '正在收集星球信号…';
    try {
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 180);
      });
      this.stage = '醒醒正在阅读问题…';
      const report = await AiService.generateCuriosityReport(this.records, this.grade);
      this.stage = '正在生成星球报告…';
      const end: number = Date.now();
      const start: number = end - 30 * 24 * 60 * 60 * 1000;
      const insight: InterestInsight =
        CuriosityAggregator.buildInsight(this.records, report, start, end, 'stu_default');
      const result = await dbHelper.insertInterestInsight(insight);
      if (!result.success) {
        throw new Error(result.reason);
      }
      this.insights = await dbHelper.queryInterestInsights('stu_default', 20);
      this.stage = '报告已点亮';
      Toast.show('好奇星球已点亮');
    } catch (e) {
      this.errorText = AiService.userMessage(e, '报告生成失败，请稍后重试');
      this.stage = '再试一次点亮';
      Toast.show(this.errorText);
    }
    this.busy = false;
  }

  private subjectTexts(): string {
    return this.stats.subjects.slice(0, 5)
      .map((item: VoiceAskSubjectSummary): string => `${voiceAskSubjectLabel(item.subject)} ${item.count}`)
      .join(' · ');
  }

  private topicTexts(): string {
    return this.stats.topics.slice(0, 8)
      .map((item: VoiceAskTopicSummary): string => `${item.topic} ${item.count}`)
      .join(' · ');
  }

  private tagTexts(): string {
    return this.stats.tags.slice(0, 10)
      .map((item: VoiceAskTagSummary): string => `#${item.tag} ${item.count}`)
      .join(' · ');
  }
}
