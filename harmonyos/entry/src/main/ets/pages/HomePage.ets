import { Mistake } from '../models/Mistake';
import { dbHelper } from '../repository/DatabaseHelper';
import { Subject } from '../models/Enums';
import { MistakeStats } from '../models/AnalyticsEvent';
import { ReminderSettings } from '../models/ReminderSettings';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { TabController } from '../common/TabController';
import { GradientHeader } from '../components/GradientHeader';
import { MistakeCard } from '../components/MistakeCard';
import { PrimaryButton, EmptyBlock } from '../components/BasicWidgets';

function enabledSubjectsOf(settings: ReminderSettings): Subject[] {
  const list: Subject[] = [];
  if (settings.mathEnabled) {
    list.push(Subject.MATH);
  }
  if (settings.chineseEnabled) {
    list.push(Subject.CHINESE);
  }
  if (settings.englishEnabled) {
    list.push(Subject.ENGLISH);
  }
  if (settings.scienceEnabled) {
    list.push(Subject.SCIENCE);
  }
  return list;
}

function greetingText(): string {
  const hour: number = new Date().getHours();
  if (hour < 6) {
    return '夜深了';
  }
  if (hour < 12) {
    return '早上好';
  }
  if (hour < 14) {
    return '中午好';
  }
  if (hour < 18) {
    return '下午好';
  }
  return '晚上好';
}

@Component
export struct HomePage {
  controller: TabController = new TabController();
  @State todayReviewCount: number = 0;
  @State totalMistakes: number = 0;
  @State masteredCount: number = 0;
  @State reviewingCount: number = 0;
  @State recentMistakes: Mistake[] = [];
  @State studentPoints: number = 0;
  private studentId: string = 'stu_default';

  aboutToAppear(): void {
    this.controller.reload = (): void => {
      this.loadData();
    };
    this.loadData();
  }

  async loadData(): Promise<void> {
    const settings: ReminderSettings = await dbHelper.queryReminderSettings(this.studentId);
    const todayList = await dbHelper.queryTodayReviewMistakes(this.studentId, settings.dailyLimit,
      enabledSubjectsOf(settings));
    this.todayReviewCount = todayList.length;
    // 统计改 SQL 聚合（T036/FR-019），recent 限条数
    const stats: MistakeStats = await dbHelper.queryMistakeStats(this.studentId);
    this.totalMistakes = stats.total;
    this.masteredCount = stats.mastered;
    this.reviewingCount = stats.reviewing + stats.unmastered;
    this.recentMistakes = await dbHelper.queryMistakesByStudent(this.studentId, 0, 5);
    const summary = await dbHelper.queryPointsSummary(this.studentId);
    this.studentPoints = summary.totalPoints;
  }

  private todayDateText(): string {
    const d = new Date();
    return `${d.getMonth() + 1}月${d.getDate()}日 · 星期${'日一二三四五六'.charAt(d.getDay())}`;
  }

  build() {
    Scroll() {
      Column() {
        GradientHeader({
          title: greetingText() + '，同学',
          subtitle: this.todayDateText(),
          badgeText: `⭐ ${this.studentPoints}`
        }) {
          Row() {
            Column() {
              Text(`${this.todayReviewCount}`)
                .fontSize(46)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .accessibilityText(`今日待复习 ${this.todayReviewCount} 题`)
              Text(this.todayReviewCount > 0 ? '题待复习' : '今日复习已完成')
                .fontSize(13)
                .fontColor(AppColors.HERO_TEXT_DIM)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('🦉')
              .fontSize(26)
              .width(52)
              .height(52)
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.BADGE_BG)
              .borderRadius(18)
              .margin({ right: 10 })
              .accessibilityText('吉祥物醒醒')

            Button(this.todayReviewCount > 0 ? '开始复习' : '休息一下')
              .height(AppSizes.TOUCH_TARGET + 2)
              .backgroundColor(Color.White)
              .fontColor(AppColors.HERO_BTN_TEXT)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(23)
              .padding({ left: 24, right: 24 })
              .shadow({ radius: 10, color: AppColors.SHADOW_CARD, offsetY: 4 })
              .enabled(this.todayReviewCount > 0)
              .accessibilityText('开始复习今日错题')
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReviewPage' });
              })
          }
          .width('100%')
          .margin({ top: 22 })
        }

        Row() {
          this.GradientStatCard('📒', `${this.totalMistakes}`, '总错题',
            AppColors.PRIMARY_LIGHT, AppColors.GRADIENT_END)
          this.GradientStatCard('✅', `${this.masteredCount}`, '已掌握',
            AppColors.MINT_START, AppColors.MINT_END)
          this.GradientStatCard('🔁', `${this.reviewingCount}`, '复习中',
            AppColors.SUNSET_START, AppColors.SUNSET_END)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .justifyContent(FlexAlign.SpaceBetween)

        Column() {
          PrimaryButton({
            text: '🤖  AI 录入错题',
            isEnabled: true,
            onTap: (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CapturePage' });
            }
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })

        Row() {
          Text('最近错题')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 26, bottom: 10 })

        if (this.recentMistakes.length === 0) {
          EmptyBlock({ message: '还没有错题，点击上方按钮录入吧' })
        } else {
          ForEach(this.recentMistakes, (item: Mistake) => {
            MistakeCard({
              mistake: item,
              onItemClick: (m: Mistake): void => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeDetailPage', params: { mistakeId: m.id } });
              }
            })
          }, (item: Mistake) => item.id)
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  GradientStatCard(icon: string, value: string, label: string, gradStart: Resource, gradEnd: Resource) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(15)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2EFFFFFF')
          .borderRadius(10)
        Column() {
        }
        .layoutWeight(1)
      }
      .width('100%')

      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 8 })
        .accessibilityText(`${label} ${value}`)
      Text(label)
        .fontSize(11)
        .fontColor('#E6FFFFFF')
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .linearGradient({ angle: 140, colors: [[gradStart, 0], [gradEnd, 1]] })
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .margin({ left: 4, right: 4 })
    .shadow({ radius: 10, color: AppColors.SHADOW_CARD, offsetY: 4 })
  }
}
