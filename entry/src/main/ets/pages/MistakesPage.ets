import { Mistake } from '../models/Mistake';
import { MistakeStatus, Subject, ErrorType } from '../models/Enums';
import { dbHelper } from '../repository/DatabaseHelper';
import { AppColors, AppSizes, subjectLabel, statusLabel, formatDate, toFileUri, truncateText } from '../common/Constants';
import { TabController } from '../common/TabController';
import { Toast } from '../common/Toast';
import { MediaService } from '../services/MediaService';
import { StatusTag, SubjectTag } from '../components/CommonComponents';
import { EmptyBlock, FilterChip } from '../components/BasicWidgets';

const PAGE_SIZE: number = 20;

/**
 * 懒加载数据源（T037/D8）：键值为 mistake.id，数据变更经 notifyDataReload/onDataAdd 通知。
 */
class MistakeDataSource implements IDataSource {
  private items: Mistake[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Mistake {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  reload(items: Mistake[]): void {
    this.items = items;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  append(items: Mistake[]): void {
    const start: number = this.items.length;
    this.items = this.items.concat(items);
    for (let i: number = 0; i < items.length; i++) {
      for (const listener of this.listeners) {
        listener.onDataAdd(start + i);
      }
    }
  }
}

@Component
export struct MistakesPage {
  controller: TabController = new TabController();
  private dataSource: MistakeDataSource = new MistakeDataSource();
  @State filterSubject: string = '';
  @State filterStatus: string = '';
  @State filterErrorType: string = '';
  @State searchKeyword: string = '';
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State loadFailed: boolean = false;
  @State hasMore: boolean = false;
  private queryOffset: number = 0;

  aboutToAppear(): void {
    this.controller.reload = (): void => { this.applyFilters(); };
    this.applyFilters();
  }

  private currentSubject(): Subject | undefined {
    return this.filterSubject.length > 0 ? this.filterSubject as Subject : undefined;
  }

  private currentStatus(): MistakeStatus | undefined {
    return this.filterStatus.length > 0 ? this.filterStatus as MistakeStatus : undefined;
  }

  private currentErrorType(): ErrorType | undefined {
    return this.filterErrorType.length > 0 ? this.filterErrorType as ErrorType : undefined;
  }

  private currentKeyword(): string | undefined {
    return this.searchKeyword.length > 0 ? this.searchKeyword : undefined;
  }

  /**
   * 首屏/筛选变更加载（T037）：分页参数 offset=0，触底后按页追加；
   * 数据库未就绪/初始化失败时展示失败态（读失败细节以日志为准）。
   */
  private async applyFilters(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    this.queryOffset = 0;
    const page: Mistake[] = await dbHelper.queryMistakes(this.currentSubject(), this.currentStatus(),
      this.currentKeyword(), this.currentErrorType(), 0, PAGE_SIZE);
    this.loading = false;
    if (!dbHelper.isReady()) {
      this.loadFailed = true;
      return;
    }
    this.hasMore = page.length === PAGE_SIZE;
    this.dataSource.reload(page);
  }

  private async loadMore(): Promise<void> {
    if (!this.hasMore || this.loadingMore || this.loading) {
      return;
    }
    this.loadingMore = true;
    this.queryOffset += PAGE_SIZE;
    const page: Mistake[] = await dbHelper.queryMistakes(this.currentSubject(), this.currentStatus(),
      this.currentKeyword(), this.currentErrorType(), this.queryOffset, PAGE_SIZE);
    this.loadingMore = false;
    this.hasMore = page.length === PAGE_SIZE;
    if (page.length > 0) {
      this.dataSource.append(page);
    }
  }

  build() {
    Column() {
      Scroll() {
        Row({ space: 8 }) {
          FilterChip({
            text: '全部',
            selected: this.filterSubject.length === 0 && this.filterStatus.length === 0,
            onTap: (): void => {
              this.filterSubject = '';
              this.filterStatus = '';
              this.applyFilters();
            }
          })
          FilterChip({
            text: '数学',
            selected: this.filterSubject === Subject.MATH,
            onTap: (): void => {
              this.filterSubject = Subject.MATH;
              this.filterStatus = '';
              this.applyFilters();
            }
          })
          FilterChip({
            text: '语文',
            selected: this.filterSubject === Subject.CHINESE,
            onTap: (): void => {
              this.filterSubject = Subject.CHINESE;
              this.filterStatus = '';
              this.applyFilters();
            }
          })
          FilterChip({
            text: '未掌握',
            selected: this.filterStatus === MistakeStatus.UNMASTERED,
            onTap: (): void => {
              this.filterStatus = MistakeStatus.UNMASTERED;
              this.filterSubject = '';
              this.applyFilters();
            }
          })
          FilterChip({
            text: '复习中',
            selected: this.filterStatus === MistakeStatus.REVIEWING,
            onTap: (): void => {
              this.filterStatus = MistakeStatus.REVIEWING;
              this.filterSubject = '';
              this.applyFilters();
            }
          })
          FilterChip({
            text: '已掌握',
            selected: this.filterStatus === MistakeStatus.MASTERED,
            onTap: (): void => {
              this.filterStatus = MistakeStatus.MASTERED;
              this.filterSubject = '';
              this.applyFilters();
            }
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 4 })

      Row() {
        TextInput({ text: this.searchKeyword, placeholder: '🔍 搜索错题内容' })
          .fontSize(15)
          .layoutWeight(1)
          .backgroundColor(AppColors.BG_CARD)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .onChange((value: string) => {
            this.searchKeyword = value;
          })
        Button('搜索')
          .height(40)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(AppSizes.CORNER_RADIUS_SM)
          .margin({ left: 8 })
          .onClick(() => {
            this.applyFilters();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Scroll() {
        Row({ space: 8 }) {
          FilterChip({
            text: '概念不清',
            selected: this.filterErrorType === ErrorType.CONCEPT,
            onTap: (): void => {
              this.filterErrorType = this.filterErrorType === ErrorType.CONCEPT ? '' : ErrorType.CONCEPT;
              this.applyFilters();
            }
          })
          FilterChip({
            text: '粗心',
            selected: this.filterErrorType === ErrorType.CARELESS,
            onTap: (): void => {
              this.filterErrorType = this.filterErrorType === ErrorType.CARELESS ? '' : ErrorType.CARELESS;
              this.applyFilters();
            }
          })
          FilterChip({
            text: '审题错误',
            selected: this.filterErrorType === ErrorType.MISREAD,
            onTap: (): void => {
              this.filterErrorType = this.filterErrorType === ErrorType.MISREAD ? '' : ErrorType.MISREAD;
              this.applyFilters();
            }
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 4 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(AppColors.PRIMARY)
          Text('加载中...')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadFailed) {
        Column() {
          Text('加载失败，请检查数据后重试')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
          Button('重新加载')
            .height(40)
            .backgroundColor(AppColors.PRIMARY)
            .fontColor(Color.White)
            .borderRadius(20)
            .padding({ left: 24, right: 24 })
            .margin({ top: 12 })
            .onClick(() => {
              this.applyFilters();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.dataSource.totalCount() === 0) {
        Column() {
          EmptyBlock({ message: '还没有错题，快去录入吧' })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          LazyForEach(this.dataSource, (item: Mistake) => {
            ListItem() {
              Row() {
                Column() {
                  Text(this.displayTitle(item))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  if (item.ocrText.length > 0) {
                    Text(truncateText(item.ocrText, 40))
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 4 })
                  }

                  Row({ space: 4 }) {
                    SubjectTag({ subjectText: subjectLabel(item.subject), subjectKey: item.subject })
                    StatusTag({ statusText: statusLabel(item.status), statusKey: item.status })
                    Text(formatDate(item.createdAt))
                      .fontSize(11)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                  .margin({ top: 6 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.imageUrl.length > 0) {
                  Image(toFileUri(item.imageUrl))
                    .width(64).height(64).borderRadius(AppSizes.CORNER_RADIUS_XS)
                    .objectFit(ImageFit.Cover)
                    .sourceSize({ width: 200, height: 200 })
                    .margin({ left: 10 })
                } else {
                  Column() {
                    Text('📷')
                      .fontSize(28)
                  }
                  .width(64)
                  .height(64)
                  .borderRadius(AppSizes.CORNER_RADIUS_XS)
                  .backgroundColor(AppColors.BG_CHIP)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .margin({ left: 10 })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppColors.BG_CARD)
              .borderRadius(AppSizes.CORNER_RADIUS_SM)
              .shadow({ radius: 6, color: AppColors.SHADOW_SOFT, offsetY: 2 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/MistakeDetailPage', params: { mistakeId: item.id } });
              })
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.DeleteAction(item);
                }
              }
            })
          }, (item: Mistake) => item.id)

          ListItem() {
            Column() {
              if (this.loadingMore) {
                Text('加载更多...')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_SECONDARY)
              } else if (!this.hasMore) {
                Text('已加载全部错题')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_PLACEHOLDER)
              }
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
        .scrollBar(BarState.Auto)
        .onReachEnd(() => {
          this.loadMore();
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PAGE)
  }

  @Builder
  DeleteAction(item: Mistake) {
    Button('删除')
      .height('100%')
      .backgroundColor(AppColors.DANGER)
      .fontColor(Color.White)
      .fontSize(15)
      .borderRadius(0)
      .padding({ left: 20, right: 20 })
      .onClick(() => {
        this.confirmDelete(item);
      })
  }

  private displayTitle(item: Mistake): string {
    if (item.knowledgeSummary.length > 0) {
      return item.knowledgeSummary;
    }
    if (item.ocrText.length > 0) {
      return truncateText(item.ocrText, 30);
    }
    return '未命名错题';
  }

  /**
   * 删除二次确认（T029/FR-008）：确认后调用事务化 deleteMistake 并联动删除本机图片。
   */
  private confirmDelete(item: Mistake): void {
    this.getUIContext().showAlertDialog({
      title: '删除错题',
      message: '删除后该错题及其全部复习记录将一并删除，且无法恢复。确定删除吗？',
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppColors.DANGER,
        action: (): void => {
          this.executeDelete(item);
        }
      }
    });
  }

  private async executeDelete(item: Mistake): Promise<void> {
    const result = await dbHelper.deleteMistake(item.id);
    if (!result.success) {
      Toast.show('删除失败，请重试');
      return;
    }
    await MediaService.deleteImageIfOwned(item.imageUrl);
    Toast.show('已删除该错题');
    // 删除后按当前列表规模整页刷新
    const size: number = Math.max(this.dataSource.totalCount(), PAGE_SIZE);
    const refreshed: Mistake[] = await dbHelper.queryMistakes(this.currentSubject(), this.currentStatus(),
      this.currentKeyword(), this.currentErrorType(), 0, size);
    this.hasMore = refreshed.length === size;
    this.dataSource.reload(refreshed);
  }
}
