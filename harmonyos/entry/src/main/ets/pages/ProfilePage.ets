import { Student } from '../models/Student';
import { Grade, TextbookVersion } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';
import { TabController } from '../common/TabController';
import { GradientHeader } from '../components/GradientHeader';
import { PointsSummary } from '../models/PointsLog';
import { InterestInsight, VoiceAskRecord } from '../models/VoiceAsk';

class MenuEntry {
  icon: string = '';
  label: string = '';
  url: string = '';
  bubble: Resource = AppColors.SOLID_PRIMARY;
}

@Component
export struct ProfilePage {
  controller: TabController = new TabController();
  @State student: Student = new Student();
  @State pointsSummary: PointsSummary = new PointsSummary();
  @State voiceAskCount: number = 0;
  @State latestInsight: InterestInsight | undefined = undefined;
  @State isLoaded: boolean = false;

  aboutToAppear(): void {
    this.controller.reload = (): void => { this.loadData(); };
    this.loadData();
  }

  async loadData(): Promise<void> {
    const s = await dbHelper.queryStudent('stu_default');
    if (s !== undefined) {
      this.student = s;
    } else {
      this.student.id = 'stu_default';
      this.student.nickname = '同学';
      this.student.grade = Grade.G3;
      this.student.textbookVersion = TextbookVersion.PEP;
      this.student.createdAt = Date.now();
      await dbHelper.insertStudent(this.student);
    }
    this.pointsSummary = await dbHelper.queryPointsSummary(this.student.id);
    const voiceRecords: VoiceAskRecord[] = await dbHelper.queryVoiceAskRecords(this.student.id);
    this.voiceAskCount = voiceRecords.length;
    const insights: InterestInsight[] = await dbHelper.queryInterestInsights(this.student.id, 1);
    this.latestInsight = insights.length > 0 ? insights[0] : undefined;
    this.isLoaded = true;
  }

  private menuItems(): MenuEntry[] {
    const m1 = new MenuEntry();
    m1.icon = '📚';
    m1.label = AppStrings.LEARNING_PROFILE;
    m1.url = 'pages/ProfileSettingPage';
    m1.bubble = AppColors.SOLID_INFO;

    const m2 = new MenuEntry();
    m2.icon = '⏰';
    m2.label = '复习提醒设置';
    m2.url = 'pages/ReminderSettingPage';
    m2.bubble = AppColors.SOLID_WARNING;

    const m3 = new MenuEntry();
    m3.icon = '🎁';
    m3.label = AppStrings.POINTS_CENTER;
    m3.url = 'pages/PointsCenterPage';
    m3.bubble = AppColors.SOLID_SECONDARY;

    const askEntry = new MenuEntry();
    askEntry.icon = '🎤';
    askEntry.label = '我的问一问';
    askEntry.url = 'pages/VoiceAskListPage';
    askEntry.bubble = AppColors.SOLID_INFO;

    const m4 = new MenuEntry();
    m4.icon = '🔄';
    m4.label = '导出与导入';
    m4.url = 'pages/DataManagementPage';
    m4.bubble = AppColors.SOLID_DANGER;

    const m5 = new MenuEntry();
    m5.icon = '👨‍👩‍👧';
    m5.label = AppStrings.PARENT_CENTER;
    m5.url = 'pages/OpsOverviewPage';
    m5.bubble = AppColors.SOLID_INFO;

    const m6 = new MenuEntry();
    m6.icon = 'ℹ️';
    m6.label = AppStrings.ABOUT;
    m6.url = 'pages/AboutPage';
    m6.bubble = AppColors.SOLID_PRIMARY;

    return [m1, m2, m3, askEntry, m4, m5, m6];
  }

  build() {
    Scroll() {
      Column() {
        GradientHeader({
          title: this.student.nickname,
          subtitle: `${this.student.grade}年级 · ${this.student.textbookVersion === TextbookVersion.PEP ? '人教版' : '其他教材'}`,
          badgeText: `⭐ ${this.pointsSummary.totalPoints}`
        }) {
          Row({ space: 10 }) {
            this.HeroStat('积分', `${this.pointsSummary.totalPoints}`)
            this.HeroStat('今日', `${this.pointsSummary.todayPoints}`)
            this.HeroStat('连击', `${this.pointsSummary.streakDays}`)
          }
          .width('100%')
          .margin({ top: 18 })
        }

        Column() {
          this.CuriosityCard()

          ForEach(this.menuItems(), (item: MenuEntry, index: number) => {
            if (index > 0) {
              Divider()
                .color(AppColors.DIVIDER)
                .strokeWidth(1)
                .margin({ left: 56 })
            }
            this.MenuItem(item)
          }, (item: MenuEntry) => item.url)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS_LG)
        .margin({ left: 16, right: 16, top: 16 })
        .shadow({ radius: 10, color: AppColors.SHADOW_SOFT, offsetY: 3 })
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  CuriosityCard() {
    Column() {
      Row() {
        Text('🪐')
          .fontSize(34)
          .width(64)
          .height(64)
          .textAlign(TextAlign.Center)
          .backgroundColor('#26FFFFFF')
          .borderRadius(22)
        Column() {
          Text('好奇星球')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.voiceAskCount > 0
            ? `已经收集 ${this.voiceAskCount} 个问题，点亮看看孩子最爱问什么`
            : '孩子每问一次，星球就会多一颗小星星')
            .fontSize(12)
            .fontColor('#E6FFFFFF')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Button(this.latestInsight === undefined ? '点亮好奇星球' : '查看我的好奇报告')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.HERO_BTN_TEXT)
        .backgroundColor(Color.White)
        .borderRadius(21)
        .padding({ left: 22, right: 22 })
        .margin({ top: 16 })
        .alignSelf(ItemAlign.Start)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/CuriosityPlanetPage' });
        })
        .accessibilityText('点亮好奇星球')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .linearGradient({
      angle: 140,
      colors: [[AppColors.PRIMARY_LIGHT, 0], [AppColors.SOLID_PRIMARY, 0.5], [AppColors.SOLID_SECONDARY, 1]]
    })
    .borderRadius(AppSizes.CORNER_RADIUS_LG)
    .shadow({ radius: 14, color: AppColors.SHADOW_PRIMARY, offsetY: 4 })
  }

  @Builder
  HeroStat(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .accessibilityText(`${label} ${value}`)
      Text(label)
        .fontSize(11)
        .fontColor(AppColors.HERO_TEXT_DIM)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(AppColors.BADGE_BG)
    .borderRadius(14)
  }

  @Builder
  MenuItem(item: MenuEntry) {
    Row() {
      Text(item.icon)
        .fontSize(16)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(item.bubble)
        .borderRadius(12)
      Text(item.label)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
        .margin({ left: 12 })
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.TEXT_PLACEHOLDER)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .accessibilityText(item.label)
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: item.url });
    })
  }
}
