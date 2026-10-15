import { KnowledgeProfile } from '../models/KnowledgeTag';
import { MistakeStats, SubjectCount } from '../models/AnalyticsEvent';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings, subjectLabel, subjectColor } from '../common/Constants';
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
        GradientHeader({ title: AppStrings.PAGE_REPORT, subtitle: '看看你的进步与薄弱点' }) {
          if (this.totalMistakes > 0) {
            Column() {
              Row() {
                Text('总掌握率')
                  .fontSize(13)
                  .fontColor(AppColors.HERO_TEXT_DIM)
                  .layoutWeight(1)
                Text(`${Math.round(this.masteredCount / this.totalMistakes * 100)}%`)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .width('100%')
              Progress({ value: this.masteredCount, total: this.totalMistakes, type: ProgressType.Linear })
                .width('100%')
                .height(10)
                .margin({ top: 8 })
                .color(Color.White)
                .backgroundColor('#33FFFFFF')
                .borderRadius(5)
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .backgroundColor(AppColors.BADGE_BG)
            .borderRadius(16)
            .margin({ top: 16 })
          }
        }
        this.OverviewSection()
        this.SubjectSection()
        this.WeakPointsSection()
      }
      .padding({ bottom: 24 })
      .width('100%')
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
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        this.OverviewItem('📒', '总错题', `${this.totalMistakes}`, AppColors.SOLID_PRIMARY)
        this.OverviewItem('✅', '已掌握', `${this.masteredCount}`, AppColors.SOLID_SECONDARY)
      }
      .width('100%')
      .margin({ bottom: 10 })
      Row() {
        this.OverviewItem('🔁', '复习中', `${this.reviewingCount}`, AppColors.SOLID_INFO)
        this.OverviewItem('⚠️', '未掌握', `${this.unmasteredCount}`, AppColors.SOLID_DANGER)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .margin({ left: 16, right: 16, top: 16 })
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
  }

  @Builder
  OverviewItem(icon: string, label: string, value: string, bubble: Resource) {
    Row() {
      Text(icon)
        .fontSize(16)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(bubble)
        .borderRadius(12)
      Column() {
        Text(value)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(label)
          .fontSize(11)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor(AppColors.BG_PAGE)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin(4)
    .accessibilityText(`${label} ${value}`)
  }

  @Builder
  SubjectSection() {
    Column() {
      Text('学科分布')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
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
              .fontSize(13)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width(48)
            Stack({ alignContent: Alignment.Start }) {
              Column() {
              }
              .width('100%')
              .height(10)
              .backgroundColor(AppColors.BG_PAGE)
              .borderRadius(5)
              Progress({ value: item.count, total: this.totalMistakes > 0 ? this.totalMistakes : 1, type: ProgressType.Linear })
                .width('100%')
                .height(10)
                .color(subjectColor(item.subject))
                .backgroundColor(Color.Transparent)
                .borderRadius(5)
            }
            .layoutWeight(1)
            Text(`${item.count}题`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ left: 10 })
              .width(40)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .margin({ top: 8 })
        }, (item: SubjectDist) => item.subject)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .margin({ left: 16, right: 16, top: 12 })
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
  }

  @Builder
  WeakPointsSection() {
    Column() {
      Text('薄弱知识点 Top3')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 12 })

      if (this.weakPoints.length === 0) {
        Column() {
          Text('🌱')
            .fontSize(36)
          Text('继续录入错题，系统将为你分析薄弱点')
            .fontSize(13)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.weakPoints, (item: WeakPoint, idx: number) => {
          Row() {
            Text(`${idx + 1}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width(26)
              .height(26)
              .textAlign(TextAlign.Center)
              .backgroundColor(idx === 0 ? AppColors.SOLID_DANGER : AppColors.SOLID_WARNING)
              .borderRadius(13)
            Column() {
              Text(item.tagId)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
              Text(`错题${item.totalMistakes}题 · 掌握度${Math.round(item.score * 100)}%`)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 10 })
          }
          .width('100%')
          .padding({ top: 10, bottom: 10, left: 8, right: 8 })
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .margin({ top: 6 })
        }, (item: WeakPoint) => item.tagId)
      }

      Text('💡 深度分析报告需要家长订阅解锁')
        .fontSize(12)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
        .margin({ top: 14 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .margin({ left: 16, right: 16, top: 12, bottom: 24 })
    .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
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
