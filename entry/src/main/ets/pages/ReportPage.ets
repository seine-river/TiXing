import { KnowledgeProfile } from '../models/KnowledgeTag';
import { MistakeStats, SubjectCount } from '../models/AnalyticsEvent';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings, subjectLabel } from '../common/Constants';
import { TabController } from '../common/TabController';
import { GradientHeader } from '../components/GradientHeader';

@Component
export struct ReportPage {
  controller: TabController = new TabController();
  @State totalMistakes: number = 0;
  @State masteredCount: number = 0;
  @State reviewingCount: number = 0;
  @State unmasteredCount: number = 0;
  @State knowledgeProfiles: KnowledgeProfile[] = [];
  @State weakPoints: WeakPoint[] = [];
  @State subjectDistribution: SubjectDist[] = [];

  aboutToAppear(): void {
    this.controller.reload = (): void => { this.loadReport(); };
    this.loadReport();
  }

  async loadReport(): Promise<void> {
    // 统计改 SQL 聚合（T036/FR-019）
    const stats: MistakeStats = await dbHelper.queryMistakeStats('stu_default');
    this.totalMistakes = stats.total;
    this.masteredCount = stats.mastered;
    this.reviewingCount = stats.reviewing;
    this.unmasteredCount = stats.unmastered;

    const profiles = await dbHelper.queryKnowledgeProfiles('stu_default');
    this.knowledgeProfiles = profiles;

    const distList: SubjectCount[] = await dbHelper.querySubjectDistribution('stu_default');
    this.subjectDistribution = distList.map((d: SubjectCount): SubjectDist => {
      const s = new SubjectDist();
      s.subject = d.subject;
      s.count = d.count;
      return s;
    });

    const weakList: WeakPoint[] = [];
    for (const p of profiles) {
      if (p.currentMasteryScore < 0.6) {
        const w = new WeakPoint();
        w.tagId = p.knowledgeTagId;
        w.score = p.currentMasteryScore;
        w.totalMistakes = p.totalMistakes;
        weakList.push(w);
      }
    }
    weakList.sort((a: WeakPoint, b: WeakPoint) => a.score - b.score);
    this.weakPoints = weakList.slice(0, 3);
  }

  build() {
    Scroll() {
      Column() {
        GradientHeader({ title: AppStrings.PAGE_REPORT, subtitle: '错题掌握与薄弱知识点分析' }) {
        }
        this.OverviewSection()
        this.SubjectSection()
        this.WeakPointsSection()
      }
      .padding({ bottom: 24 })
      .width('100%')
      .height('100%')
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  OverviewSection() {
    Column() {
      Text('错题概览')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        this.OverviewItem('总错题', `${this.totalMistakes}`, AppColors.PRIMARY)
        this.OverviewItem('已掌握', `${this.masteredCount}`, AppColors.SECONDARY)
        this.OverviewItem('复习中', `${this.reviewingCount}`, AppColors.MASTERY_REVIEWING)
        this.OverviewItem('未掌握', `${this.unmasteredCount}`, AppColors.DANGER)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.totalMistakes > 0) {
        Row() {
          Text('掌握率')
            .fontSize(14)
            .fontColor(AppColors.TEXT_REGULAR)
          Progress({ value: this.masteredCount, total: this.totalMistakes, type: ProgressType.Linear })
            .layoutWeight(1)
            .margin({ left: 8 })
            .color(AppColors.SECONDARY)
          Text(`${Math.round(this.masteredCount / this.totalMistakes * 100)}%`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.SECONDARY)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 8 })
    .shadow({ radius: 8, color: AppColors.SHADOW_SOFT, offsetY: 2 })
  }

  @Builder
  OverviewItem(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }

  @Builder
  SubjectSection() {
    Column() {
      Text('学科分布')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 12 })

      if (this.subjectDistribution.length === 0) {
        Text('暂无数据')
          .fontSize(14)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
      } else {
        ForEach(this.subjectDistribution, (item: SubjectDist) => {
          Row() {
            Text(subjectLabel(item.subject))
              .fontSize(14)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width(60)
            Progress({ value: item.count, total: this.totalMistakes > 0 ? this.totalMistakes : 1, type: ProgressType.Linear })
              .layoutWeight(1)
              .color(AppColors.PRIMARY)
            Text(`${item.count}题`)
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ left: 8 })
              .width(40)
          }
          .width('100%')
          .margin({ top: 6 })
        }, (item: SubjectDist) => item.subject)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12 })
    .shadow({ radius: 8, color: AppColors.SHADOW_SOFT, offsetY: 2 })
  }

  @Builder
  WeakPointsSection() {
    Column() {
      Text('薄弱知识点 Top3')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 12 })

      if (this.weakPoints.length === 0) {
        Text('继续录入错题，系统将为您分析薄弱点')
          .fontSize(14)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
      } else {
        ForEach(this.weakPoints, (item: WeakPoint, idx: number) => {
          Row() {
            Text(`${idx + 1}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.DANGER)
              .width(24)
            Column() {
              Text(item.tagId)
                .fontSize(14)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text(`错题${item.totalMistakes}题 · 掌握度${Math.round(item.score * 100)}%`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 8 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }, (item: WeakPoint) => item.tagId)
      }

      Text('深度分析报告需要家长订阅解锁')
        .fontSize(13)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS)
    .margin({ left: 16, right: 16, top: 12, bottom: 24 })
    .shadow({ radius: 8, color: AppColors.SHADOW_SOFT, offsetY: 2 })
  }
}

class WeakPoint {
  tagId: string = '';
  score: number = 0;
  totalMistakes: number = 0;
}

class SubjectDist {
  subject: string = '';
  count: number = 0;
}
