import router from '@ohos.router';
import { HistoryService, HistoryItem, HistoryType } from '../../services/HistoryService';
import { promptAction } from '@kit.ArkUI';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

@Component
export struct HistoryPage {
  @State historyList: HistoryItem[] = [];
  @State currentTab: HistoryType = 'all';
  @State isLoading: boolean = false;
  @State showClearDialog: boolean = false;
  @State selectedItemId: string = '';
  @State showDeleteDialog: boolean = false;

  private historyService: HistoryService = HistoryService.getInstance();
  private tabs: HistoryType[] = ['all', 'resume', 'assessment', 'chat', 'interview'];

  aboutToAppear() {
    this.loadHistory();
  }

  async loadHistory() {
    this.isLoading = true;
    try {
      this.historyList = await this.historyService.getHistory(this.currentTab);
    } catch (error) {
      console.error('[HistoryPage] Load history failed:', error);
    } finally {
      this.isLoading = false;
    }
  }

  onTabChange(tab: HistoryType) {
    this.currentTab = tab;
    this.loadHistory();
  }

  async deleteItem(id: string) {
    await this.historyService.removeHistory(id);
    this.loadHistory();
    promptAction.showToast({ message: '已删除', duration: 1500 });
  }

  async clearAll() {
    await this.historyService.clearHistory(this.currentTab === 'all' ? undefined : this.currentTab);
    this.loadHistory();
    this.showClearDialog = false;
    promptAction.showToast({ message: '已清空', duration: 1500 });
  }

  build() {
    Column() {
      // 标题栏
      this.buildHeader()

      // 分类标签
      this.buildTabs()

      // 历史列表
      this.buildHistoryList()

      // 清空全部按钮
      if (this.historyList.length > 0) {
        Button('清空全部')
          .fontSize(FontSize.Sm)
          .fontColor(ErrorColors.Error500)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Pill)
          .border({ width: 1, color: ErrorColors.Error500 })
          .width('calc(100% - 32px)')
          .height(44)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space9 })
          .onClick(() => {
            this.showClearDialog = true;
          })
      }

      // 清空确认弹窗
      if (this.showClearDialog) {
        this.buildClearDialog()
      }

      // 删除确认弹窗
      if (this.showDeleteDialog) {
        this.buildDeleteDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  @Builder
  buildHeader() {
    Row() {
      // 返回按钮
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(24)
          .height(24)
          .fillColor(SemanticColors.Text1)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        router.back();
      })

      Text('历史记录')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位，保持标题居中
      Blank()
        .width(40)
    }
    .width('100%')
    .height(56)
    .padding({ left: Spacing.Space4, right: Spacing.Space4 })
    .backgroundColor(NeutralColors.Neutral0)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildTabs() {
    Scroll() {
      Row({ space: Spacing.Space3 }) {
        ForEach(this.tabs, (tab: HistoryType) => {
          Column() {
            Text(HistoryService.getTypeLabel(tab))
              .fontSize(FontSize.Sm)
              .fontWeight(this.currentTab === tab ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.currentTab === tab ? BrandColors.Brand500 : SemanticColors.Text2)
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
          .backgroundColor(this.currentTab === tab ? BrandColors.Brand50 : NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Pill)
          .border({
            width: 1,
            color: this.currentTab === tab ? BrandColors.Brand500 : NeutralColors.Neutral200
          })
          .onClick(() => {
            this.onTabChange(tab);
          })
        })
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Md, bottom: SemanticSpacing.Md })
    }
    .scrollBar(BarState.Off)
    .scrollDirection(ScrollDirection.Horizontal)
  }

  @Builder
  buildHistoryList() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(BrandColors.Brand500)

        Text('加载中...')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .margin({ top: SemanticSpacing.Md })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.historyList.length === 0) {
      Column() {
        // 空状态图标
        Column() {
          Image($r('app.media.ic_history'))
            .width(64)
            .height(64)
            .fillColor(BrandColors.Brand300)
        }
        .width(100)
        .height(100)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(50)
        .justifyContent(FlexAlign.Center)

        Text('暂无历史记录')
          .fontSize(FontSize.Base)
          .fontColor(SemanticColors.Text3)
          .margin({ top: SemanticSpacing.Lg })

        Text('使用功能后会自动保存记录')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text4)
          .margin({ top: Spacing.Space3 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.historyList, (item: HistoryItem) => {
          ListItem() {
            this.buildHistoryItem(item)
          }
          .swipeAction({
            end: {
              builder: () => {
                this.buildDeleteButton(item.id)
              }
            }
          })
        })
      }
      .layoutWeight(1)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral50)
      .divider({ strokeWidth: 1, color: NeutralColors.Neutral100 })
    }
  }

  @Builder
  buildHistoryItem(item: HistoryItem) {
    Row() {
      // 类型图标
      Column() {
        Image(this.getTypeIcon(item.type))
          .width(24)
          .height(24)
          .fillColor(BrandColors.Brand500)
      }
      .width(44)
      .height(44)
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .margin({ right: SemanticSpacing.Md })

      // 内容区域
      Column() {
        Row() {
          Text(item.title)
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(HistoryService.formatTimestamp(item.timestamp))
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text4)
        }
        .width('100%')

        Text(item.content)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text2)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: Spacing.Space2 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: SemanticSpacing.Md, bottom: SemanticSpacing.Md })
    .backgroundColor(NeutralColors.Neutral0)
    .onClick(() => {
      this.navigateToDetail(item);
    })
  }

  @Builder
  buildDeleteButton(id: string) {
    Column() {
      Text('删除')
        .fontSize(FontSize.Sm)
        .fontColor(NeutralColors.Neutral0)
    }
    .width(80)
    .height('100%')
    .backgroundColor(ErrorColors.Error500)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectedItemId = id;
      this.showDeleteDialog = true;
    })
  }

  @Builder
  buildClearDialog() {
    Column() {
      Column() {
        Text('确认清空')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 12 })

        Text(this.currentTab === 'all' ? '确定要清空所有历史记录吗？此操作不可恢复。' : `确定要清空所有${HistoryService.getTypeLabel(this.currentTab)}记录吗？`)
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ bottom: 24 })
          .textAlign(TextAlign.Center)

        Row() {
          Button('取消')
            .backgroundColor('#F1F5F9')
            .fontColor('#64748B')
            .onClick(() => {
              this.showClearDialog = false;
            })

          Button('确定')
            .backgroundColor(ErrorColors.Error500)
            .fontColor(Color.White)
            .margin({ left: 12 })
            .onClick(() => {
              this.clearAll();
            })
        }
      }
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(24)
      .width('80%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showClearDialog = false;
    })
  }

  @Builder
  buildDeleteDialog() {
    Column() {
      Column() {
        Text('确认删除')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 12 })

        Text('确定要删除这条记录吗？')
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ bottom: 24 })

        Row() {
          Button('取消')
            .backgroundColor('#F1F5F9')
            .fontColor('#64748B')
            .onClick(() => {
              this.showDeleteDialog = false;
              this.selectedItemId = '';
            })

          Button('删除')
            .backgroundColor(ErrorColors.Error500)
            .fontColor(Color.White)
            .margin({ left: 12 })
            .onClick(() => {
              if (this.selectedItemId) {
                this.deleteItem(this.selectedItemId);
              }
              this.showDeleteDialog = false;
              this.selectedItemId = '';
            })
        }
      }
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(24)
      .width('80%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showDeleteDialog = false;
      this.selectedItemId = '';
    })
  }

  getTypeIcon(type: Exclude<HistoryType, 'all'>): Resource {
    return HistoryService.getTypeIcon(type);
  }

  navigateToDetail(item: HistoryItem) {
    // 根据类型跳转到对应页面
    switch (item.type) {
      case 'resume':
        router.pushUrl({ url: 'pages/Resume' });
        break;
      case 'assessment':
        router.pushUrl({ url: 'pages/Assessment' });
        break;
      case 'chat':
        router.pushUrl({ url: 'pages/Chat' });
        break;
      case 'interview':
        // 面试页面暂未实现
        promptAction.showToast({ message: '面试功能开发中', duration: 1500 });
        break;
    }
  }
}
