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

  // ===== [临时-故障注入] 仅用于 jscrash 定位演练，分析完成后删除 =====
  // 模拟"后端返回数据不足"场景：越界索引在编译期类型是 number，运行期是 undefined
  private triggerInjectedCrash(): void {
    const badgeList: number[] = [1, 2, 3];
    const badge: number = badgeList[7]; // 越界 → 运行时为 undefined，编译期不报错
    this.renderBadgeText(badge);
  }

  private renderBadgeText(badge: number): void {
    // undefined.toFixed() → TypeError: Cannot read property 'toFixed' of undefined（jscrash 崩溃点）
    const text: string = badge.toFixed(0);
    console.info('[FaultInject] badge=' + text);
  }
  // ===== [临时-故障注入] 结束 =====

  build() {
    Scroll() {
      Column() {
        GradientHeader({
          title: AppStrings.APP_NAME,
          subtitle: '今日学习概览，加油进步每一天',
          badgeText: `⭐ ${this.studentPoints}`
        }) {
          Row() {
            Column() {
              Text(`${this.todayReviewCount}`)
                .fontSize(44)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .accessibilityText(`今日待复习 ${this.todayReviewCount} 题`)
              Text('今日待复习')
                .fontSize(13)
                .fontColor(AppColors.HERO_TEXT_DIM)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button(this.todayReviewCount > 0 ? '开始复习' : '暂无待复习')
              .height(AppSizes.TOUCH_TARGET)
              .backgroundColor(Color.White)
              .fontColor(AppColors.PRIMARY)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(22)
              .padding({ left: 24, right: 24 })
              .enabled(this.todayReviewCount > 0)
              .accessibilityText('开始复习今日错题')
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ReviewPage' });
              })
          }
          .width('100%')
          .margin({ top: 20 })
        }

        Row() {
          this.StatCard('总错题', `${this.totalMistakes}`, AppColors.PRIMARY, '📒')
          this.StatCard('已掌握', `${this.masteredCount}`, AppColors.MASTERY_MASTERED, '✓')
          this.StatCard('复习中', `${this.reviewingCount}`, AppColors.WARNING, '🔁')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .justifyContent(FlexAlign.SpaceBetween)

        Column() {
          PrimaryButton({
            text: '📷  录入错题',
            isEnabled: true,
            onTap: (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CapturePage' });
            }
          })
            .shadow({ radius: 12, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })

          // [临时-故障注入] 点击触发 jscrash，演练完成后删除
          Text('🧪 故障注入测试')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 8 })
            .padding(8)
            .onClick(() => {
              this.triggerInjectedCrash();
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
        .padding({ left: 16, right: 16, top: 24, bottom: 8 })

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
      .height('100%')
      .padding({ bottom: 24 })
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  StatCard(label: string, value: string, color: Resource, icon: string) {
    Column() {
      Text(icon)
        .fontSize(22)
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 6 })
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppSizes.CORNER_RADIUS_SM)
    .margin({ left: 4, right: 4 })
    .shadow({ radius: 8, color: AppColors.SHADOW_CARD, offsetY: 2 })
  }
}
