import { PointsLog, PointsSummary } from '../models/PointsLog';
import { RedeemableItem, RedeemableCategory } from '../models/RedeemableItem';
import { dbHelper } from '../repository/DatabaseHelper';
import { PreferenceService } from '../services/PreferenceService';
import { AppColors, AppSizes, AppStrings } from '../common/Constants';

@Entry
@Component
struct PointsCenterPage {
  @State earnedTotal: number = 0;
  @State spentTotal: number = 0;
  @State todayPoints: number = 0;
  @State pointsLogs: PointsLog[] = [];
  @State redeemItems: RedeemableItem[] = [];
  @State ownedIds: string[] = [];
  @State leaderboardEnabled: boolean = true;
  @State statusMsg: string = '';
  private studentId: string = 'stu_default';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    const summary = await dbHelper.queryPointsSummary(this.studentId);
    this.earnedTotal = summary.totalPoints;
    this.todayPoints = summary.todayPoints;
    this.spentTotal = await dbHelper.queryTotalSpent(this.studentId);
    this.pointsLogs = await dbHelper.queryPointsLogs(this.studentId);
    this.ownedIds = await dbHelper.queryRedeemedItemIds(this.studentId);
    this.redeemItems = this.buildRedeemItems();
    this.leaderboardEnabled = await PreferenceService.getLeaderboardEnabled();
  }

  private availablePoints(): number {
    return this.earnedTotal - this.spentTotal;
  }

  build() {
    Scroll() {
      Column() {
        Text(AppStrings.POINTS_CENTER)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 16, top: 12, bottom: 8 })

        Column() {
          Text(`${this.availablePoints()}`)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.WARNING)
          Text('可用积分')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 4 })
          Row() {
            Column() {
              Text(`+${this.todayPoints}`)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.SECONDARY)
              Text('今日获得')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            Column() {
              Text(`-${this.spentTotal}`)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.DANGER)
              Text('已兑换')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
          }
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 8 })
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text('积分兑换')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 8 })
          ForEach(this.redeemItems, (item: RedeemableItem) => {
            Row() {
              Text(item.icon)
                .fontSize(28)
                .width(40)
              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Text(this.categoryLabel(item.category))
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 8 })
              if (this.ownedIds.indexOf(item.id) >= 0) {
                Text('已拥有')
                  .fontSize(13)
                  .fontColor(AppColors.SECONDARY)
              } else {
                Button(`${item.cost}积分`)
                  .height(32)
                  .fontSize(13)
                  .backgroundColor(this.availablePoints() >= item.cost ? AppColors.PRIMARY : '#C0C4CC')
                  .fontColor(Color.White)
                  .borderRadius(16)
                  .enabled(this.availablePoints() >= item.cost)
                  .onClick(() => {
                    this.redeem(item);
                  })
              }
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
          }, (item: RedeemableItem) => item.id)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        Column() {
          Row() {
            Text('排行榜展示')
              .fontSize(15)
              .fontColor(AppColors.TEXT_PRIMARY)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.leaderboardEnabled })
              .onChange((isOn: boolean) => {
                this.leaderboardEnabled = isOn;
                PreferenceService.setLeaderboardEnabled(isOn);
              })
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          Text('关闭后将隐藏社区/排行榜排名展示，仅展示正向 Top 名单')
            .fontSize(12)
            .fontColor(AppColors.TEXT_PLACEHOLDER)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        Column() {
          Text('积分明细')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 8 })

          if (this.pointsLogs.length === 0) {
            Text('暂无积分记录')
              .fontSize(14)
              .fontColor(AppColors.TEXT_PLACEHOLDER)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 24, bottom: 24 })
          } else {
            ForEach(this.pointsLogs, (log: PointsLog) => {
              Row() {
                Column() {
                  Text(this.actionLabel(log.actionType))
                    .fontSize(15)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text(this.formatDate(log.createdAt))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(`+${log.points}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.WARNING)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (log: PointsLog) => log.id)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColors.BG_CARD)
        .borderRadius(AppSizes.CORNER_RADIUS)
        .margin({ left: 16, right: 16, top: 12 })

        if (this.statusMsg.length > 0) {
          Text(this.statusMsg)
            .fontSize(13)
            .fontColor(AppColors.SECONDARY)
            .margin({ top: 8 })
        }

        Text('积分仅可兑换应用内虚拟内容，不可充值购买')
          .fontSize(12)
          .fontColor(AppColors.TEXT_PLACEHOLDER)
          .margin({ top: 12, bottom: 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
    .scrollBar(BarState.Auto)
  }

  private buildRedeemItems(): RedeemableItem[] {
    const items: RedeemableItem[] = [];
    items.push(this.makeItem('avatar_cat', '猫咪头像', RedeemableCategory.AVATAR, 30, '🐱'));
    items.push(this.makeItem('avatar_rocket', '火箭头像', RedeemableCategory.AVATAR, 50, '🚀'));
    items.push(this.makeItem('cover_blue', '蓝色封面', RedeemableCategory.COVER, 40, '🟦'));
    items.push(this.makeItem('title_master', '错题大师 称号', RedeemableCategory.TITLE, 80, '🏆'));
    items.push(this.makeItem('tree_oak', '橡树成长树', RedeemableCategory.TREE, 60, '🌳'));
    return items;
  }

  private makeItem(id: string, name: string, category: RedeemableCategory, cost: number, icon: string): RedeemableItem {
    const item = new RedeemableItem();
    item.id = id;
    item.name = name;
    item.category = category;
    item.cost = cost;
    item.icon = icon;
    return item;
  }

  private async redeem(item: RedeemableItem): Promise<void> {
    if (this.availablePoints() < item.cost) {
      return;
    }
    await dbHelper.insertRedemption(this.studentId, item.id, item.cost);
    this.spentTotal = await dbHelper.queryTotalSpent(this.studentId);
    this.ownedIds = await dbHelper.queryRedeemedItemIds(this.studentId);
    this.statusMsg = `✅ 兑换成功：${item.name}`;
  }

  private categoryLabel(category: RedeemableCategory): string {
    if (category === RedeemableCategory.AVATAR) return '头像';
    if (category === RedeemableCategory.COVER) return '封面';
    if (category === RedeemableCategory.TITLE) return '称号';
    return '成长树';
  }

  private actionLabel(actionType: string): string {
    if (actionType === 'capture') return '录入错题';
    if (actionType === 'on_time_review') return '按时复习';
    if (actionType === 'mastery_achieved') return '掌握判定通过';
    if (actionType === 'streak') return '连续打卡';
    if (actionType === 'community_contribution') return '社区贡献';
    return actionType;
  }

  private formatDate(timestamp: number): string {
    const d = new Date(timestamp);
    return `${d.getMonth() + 1}月${d.getDate()}日 ${d.getHours()}:${d.getMinutes() < 10 ? '0' : ''}${d.getMinutes()}`;
  }
}
