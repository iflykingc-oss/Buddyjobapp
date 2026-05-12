/**
 * 求职看板页面
 * 横向滚动看板视图，支持新增/编辑/删除/移动卡片
 */
import router from '@ohos.router';
import { KanbanStorageService } from '../services/KanbanStorageService';
import { KanbanColumnItem } from '../components/kanban/KanbanColumnItem';
import { CardEditSheet } from '../components/kanban/CardEditSheet';
import {
  KanbanData, JobCard, KanbanColumnStatus,
  CardPriority, DEFAULT_COLUMNS
} from '../models/Kanban';
import { Colors } from '../constants/colors';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { WindowUtil } from '../utils/WindowUtil';

@Entry
@Component
struct KanbanPage {
  @State kanbanData: KanbanData = { columns: DEFAULT_COLUMNS, cards: [] };
  @State isLoading: boolean = true;
  @State showAddSheet: boolean = false;
  @State showEditSheet: boolean = false;
  @State editingCard: JobCard | null = null;
  @State addColumn: KanbanColumnStatus = KanbanColumnStatus.WISH;
  @State showSearch: boolean = false;
  @State searchKeyword: string = '';
  @State filteredCards: JobCard[] = [];
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;

  async aboutToAppear() {
    this.kanbanData = await KanbanStorageService.initialize();
    this.isLoading = false;
  }

  build() {
    Column() {
      // 顶部导航栏
      this.TopBar()

      // 搜索栏
      if (this.showSearch) {
        Row() {
          Image($r('app.media.ic_search'))
            .width(18)
            .height(18)
            .fillColor(this.isDarkMode ? '#99A0A6' : Colors.textSecondary)

          TextInput({ placeholder: '搜索公司或职位...', text: $$this.searchKeyword })
            .placeholderColor(this.isDarkMode ? '#99A0A6' : Colors.textSecondary)
            .fontColor(this.isDarkMode ? '#E3E5E8' : Colors.textPrimary)
            .fontSize(14)
            .layoutWeight(1)
            .margin({ left: 8 })
            .backgroundColor('transparent')
            .onChange((value: string) => {
              this.searchKeyword = value;
              this.filterCards();
            })

          if (this.searchKeyword.length > 0) {
            Image($r('app.media.ic_close'))
              .width(18)
              .height(18)
              .fillColor(this.isDarkMode ? '#99A0A6' : Colors.textSecondary)
              .onClick(() => {
                this.searchKeyword = '';
                this.filterCards();
              })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.isDarkMode ? '#252A34' : Colors.background)
        .borderRadius(8)
        .margin({ left: 16, right: 16, top: 12 })
      }

      // 统计概览
      this.StatisticsBar()

      if (this.isLoading) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(Colors.primary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.showSearch && this.searchKeyword) {
        // 搜索结果
        this.SearchResults()
      } else {
        // 看板主视图
        this.KanbanView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#141820' : Colors.background)
    .bindSheet($$this.showAddSheet, this.AddSheetContent(), {
      height: '85%',
      dragBar: true,
      backgroundColor: this.isDarkMode ? '#1C2028' : Colors.white,
      onDisappear: () => {
        this.refreshData();
      }
    })
    .bindSheet($$this.showEditSheet, this.EditSheetContent(), {
      height: '85%',
      dragBar: true,
      backgroundColor: this.isDarkMode ? '#1C2028' : Colors.white,
      onDisappear: () => {
        this.refreshData();
      }
    })
  }

  @Builder
  TopBar() {
    Row() {
        Column() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor(this.isDarkMode ? '#E3E5E8' : Colors.textPrimary)
            .onClick(() => {
              router.back();
            })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)

        Text('求职看板')
          .fontSize(18)
          .fontColor(this.isDarkMode ? '#E3E5E8' : Colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })

        Blank()

        // 搜索按钮
        Column() {
          Image($r('app.media.ic_search'))
            .width(22)
            .height(22)
            .fillColor(this.showSearch ? Colors.primary : (this.isDarkMode ? '#99A0A6' : Colors.textSecondary))
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 16 })
        .onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) {
            this.searchKeyword = '';
          }
        })

        // 新增按钮
        Row() {
          Image($r('app.media.ic_add'))
            .width(18)
            .height(18)
            .fillColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor(Colors.primary)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.addColumn = KanbanColumnStatus.WISH;
          this.showAddSheet = true;
        })
      }
      .width('100%')
      .height(56)
      .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: 16, right: 16 })
      .backgroundColor(this.isDarkMode ? '#1C2028' : Colors.white)
  }

  @Builder
  StatisticsBar() {
    Row() {
      ForEach(this.kanbanData.columns, (col) => {
        Row() {
          Circle()
            .width(6)
            .height(6)
            .fill(col.color)

          Text(col.title)
            .fontSize(11)
            .fontColor(Colors.textSecondary)
            .margin({ left: 3 })

          Text(`${this.getColumnCardCount(col.status)}`)
            .fontSize(11)
            .fontColor(Colors.textPrimary)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 2 })
        }
        .margin({ right: 16 })
        .onClick(() => {
          // 快速新增到此列
          this.addColumn = col.status;
          this.showAddSheet = true;
        })
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  KanbanView() {
    Scroll() {
      Row() {
        ForEach(this.kanbanData.columns, (col) => {
          KanbanColumnItem({
            column: col,
            cards: this.getColumnCards(col.status),
            onCardEdit: (card) => {
              this.editingCard = card;
              this.showEditSheet = true;
            },
            onCardDelete: async (cardId: string) => {
              await KanbanStorageService.deleteCard(cardId);
              this.refreshData();
            },
            onCardMove: (cardId: string) => {
              // 显示移动选择弹窗（简化：循环移动到下一列）
              this.moveCardToNextColumn(cardId);
            }
          })
          .constraintSize({ minWidth: this.windowUtil?.isWideScreen() ? 280 : 240 })
          .margin({ left: 8, right: 8 })
        }, (col) => col.status)
      }
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  SearchResults() {
    if (this.filteredCards.length === 0) {
      Column() {
        Text('未找到匹配结果')
          .fontSize(14)
          .fontColor(Colors.textMuted)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.filteredCards, (card: JobCard) => {
          ListItem() {
            Row() {
              // 公司首字
              Text(card.company.charAt(0))
                .fontSize(16)
                .fontColor('#FFFFFF')
                .width(36)
                .height(36)
                .backgroundColor(this.getColumnColor(card.columnStatus))
                .borderRadius(8)
                .textAlign(TextAlign.Center)

              Column() {
                Text(card.company)
                  .fontSize(15)
                  .fontColor(Colors.textPrimary)
                  .fontWeight(FontWeight.Medium)

                Text(card.position)
                  .fontSize(12)
                  .fontColor(Colors.textSecondary)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 10 })

              // 状态标签
              Text(this.getColumnTitle(card.columnStatus))
                .fontSize(11)
                .fontColor(this.getColumnColor(card.columnStatus))
                .backgroundColor(this.getColumnColor(card.columnStatus) + '15')
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Colors.white)
            .borderRadius(10)
            .onClick(() => {
              this.editingCard = card;
              this.showEditSheet = true;
            })
          }
          .margin({ left: 16, right: 16, bottom: 8 })
        }, (card: JobCard) => card.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 8 })
    }
  }

  @Builder
  AddSheetContent() {
    CardEditSheet({
      isEdit: false,
      defaultColumn: this.addColumn,
      isDarkMode: this.isDarkMode,
      onSave: async (data) => {
        await KanbanStorageService.addCard({
          company: data.company,
          position: data.position,
          location: data.location,
          salary: data.salary,
          priority: data.priority,
          source: data.source,
          note: data.note,
          columnStatus: data.columnStatus,
          tags: data.tags
        });
        this.showAddSheet = false;
        this.refreshData();
      }
    })
  }

  @Builder
  EditSheetContent() {
    CardEditSheet({
      isEdit: true,
      editCard: this.editingCard,
      isDarkMode: this.isDarkMode,
      onSave: async (data) => {
        if (this.editingCard) {
          await KanbanStorageService.updateCard(this.editingCard.id, {
            company: data.company,
            position: data.position,
            location: data.location,
            salary: data.salary,
            priority: data.priority,
            source: data.source,
            note: data.note,
            columnStatus: data.columnStatus,
            tags: data.tags
          });
          this.showEditSheet = false;
          this.refreshData();
        }
      },
      onDelete: async () => {
        if (this.editingCard) {
          await KanbanStorageService.deleteCard(this.editingCard.id);
          this.showEditSheet = false;
          this.editingCard = null;
          this.refreshData();
        }
      }
    })
  }

  // ==================== 辅助方法 ====================

  private getColumnCards(status: KanbanColumnStatus): JobCard[] {
    return this.kanbanData.cards
      .filter(c => c.columnStatus === status)
      .sort((a, b) => a.sortWeight - b.sortWeight);
  }

  private getColumnCardCount(status: KanbanColumnStatus): number {
    return this.kanbanData.cards.filter(c => c.columnStatus === status).length;
  }

  private getColumnColor(status: KanbanColumnStatus): string {
    const col = this.kanbanData.columns.find(c => c.status === status);
    return col?.color || Colors.primary;
  }

  private getColumnTitle(status: KanbanColumnStatus): string {
    const col = this.kanbanData.columns.find(c => c.status === status);
    return col?.title || '';
  }

  private async moveCardToNextColumn(cardId: string): Promise<void> {
    const card = this.kanbanData.cards.find(c => c.id === cardId);
    if (!card) return;

    const currentIndex = this.kanbanData.columns.findIndex(c => c.status === card.columnStatus);
    const nextIndex = (currentIndex + 1) % this.kanbanData.columns.length;
    const nextStatus = this.kanbanData.columns[nextIndex].status;

    await KanbanStorageService.moveCard(cardId, nextStatus);
    this.refreshData();
  }

  private async doSearch(): Promise<void> {
    if (!this.searchKeyword.trim()) {
      this.filteredCards = [];
      return;
    }
    this.filteredCards = await KanbanStorageService.searchCards(this.searchKeyword);
  }

  private async refreshData(): Promise<void> {
    const data = await KanbanStorageService.load();
    if (data) {
      this.kanbanData = data;
    }
  }
}
