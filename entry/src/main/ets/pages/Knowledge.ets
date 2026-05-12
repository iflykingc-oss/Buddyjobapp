import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { KnowledgeService, KnowledgeArticle, ArticleListResponse } from '../services/KnowledgeService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';

interface KnowledgeItem {
  id: string;
  title: string;
  category: string;
  summary: string;
  readCount: number;
  updateTime: string;
}

@Component
export struct KnowledgePage {
  @State knowledgeList: KnowledgeItem[] = [];
  @State selectedCategory: string = '全部';
  @State searchText: string = '';
  @State isSearchMode: boolean = false;
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State errorMessage: string = '';
  @State showError: boolean = false;

  private categories: string[] = ['全部', '简历技巧', '面试攻略', '职场法则', '行业动态'];
  private knowledgeService: KnowledgeService = KnowledgeService.getInstance();
  private currentPage: number = 1;
  private readonly pageSize: number = 20;
  private searchTimeout: number = -1;

  aboutToAppear() {
    this.loadKnowledge();
  }

  aboutToDisappear() {
    // 清除搜索定时器
    if (this.searchTimeout !== -1) {
      clearTimeout(this.searchTimeout);
    }
  }

  /**
   * 加载文章列表
   */
  async loadKnowledge(isRefresh: boolean = false): Promise<void> {
    if (isRefresh) {
      this.currentPage = 1;
      this.isRefreshing = true;
    } else {
      this.isLoading = true;
    }

    this.showError = false;
    this.errorMessage = '';

    try {
      const response = await this.knowledgeService.getArticles(
        this.selectedCategory,
        this.currentPage,
        this.pageSize
      );

      if (response.success && response.data) {
        const data = response.data;
        if (isRefresh || this.currentPage === 1) {
          this.knowledgeList = data.list;
        } else {
          this.knowledgeList = [...this.knowledgeList, ...data.list];
        }
        this.hasMore = data.hasMore;
      } else {
        // API失败时使用默认数据
        if (isRefresh || this.currentPage === 1) {
          this.knowledgeList = this.knowledgeService.getDefaultArticles();
          this.showError = true;
          this.errorMessage = response.error || '获取数据失败，显示默认内容';
        }
        this.hasMore = false;
      }
    } catch (error) {
      console.error('[KnowledgePage] Load knowledge failed:', error);
      if (isRefresh || this.currentPage === 1) {
        this.knowledgeList = this.knowledgeService.getDefaultArticles();
        this.showError = true;
        this.errorMessage = '网络错误，显示默认内容';
      }
      this.hasMore = false;
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  /**
   * 搜索文章
   */
  async searchKnowledge(): Promise<void> {
    if (!this.searchText.trim()) {
      // 搜索为空时重新加载列表
      this.loadKnowledge(true);
      return;
    }

    this.isLoading = true;
    this.showError = false;

    try {
      const response = await this.knowledgeService.searchArticles(
        this.searchText.trim(),
        1,
        this.pageSize
      );

      if (response.success && response.data) {
        this.knowledgeList = response.data.list;
        this.hasMore = response.data.hasMore;
        this.currentPage = 1;
      } else {
        // 搜索失败时本地过滤
        this.localSearch();
        this.showError = true;
        this.errorMessage = response.error || '搜索失败，显示本地结果';
      }
    } catch (error) {
      console.error('[KnowledgePage] Search knowledge failed:', error);
      this.localSearch();
      this.showError = true;
      this.errorMessage = '搜索失败，显示本地结果';
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 本地搜索（API失败时使用）
   */
  localSearch(): void {
    const defaultList = this.knowledgeService.getDefaultArticles();
    const keyword = this.searchText.toLowerCase();
    this.knowledgeList = defaultList.filter(item =>
      item.title.toLowerCase().includes(keyword) ||
      item.summary.toLowerCase().includes(keyword)
    );
    this.hasMore = false;
  }

  /**
   * 加载更多
   */
  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore || this.searchText) {
      return;
    }

    this.isLoadingMore = true;
    this.currentPage++;

    try {
      const response = await this.knowledgeService.getArticles(
        this.selectedCategory,
        this.currentPage,
        this.pageSize
      );

      if (response.success && response.data) {
        const data = response.data;
        this.knowledgeList = [...this.knowledgeList, ...data.list];
        this.hasMore = data.hasMore;
      } else {
        this.hasMore = false;
        promptAction.showToast({ message: '没有更多内容了' });
      }
    } catch (error) {
      console.error('[KnowledgePage] Load more failed:', error);
      this.hasMore = false;
    } finally {
      this.isLoadingMore = false;
    }
  }

  /**
   * 处理搜索输入变化
   */
  onSearchChange(value: string): void {
    this.searchText = value;

    // 防抖处理
    if (this.searchTimeout !== -1) {
      clearTimeout(this.searchTimeout);
    }

    this.searchTimeout = setTimeout(() => {
      this.searchKnowledge();
    }, 500);
  }

  /**
   * 处理分类切换
   */
  onCategoryChange(category: string): void {
    this.selectedCategory = category;
    this.searchText = '';
    this.loadKnowledge(true);
  }

  /**
   * 重试加载
   */
  async retryLoad(): Promise<void> {
    this.loadKnowledge(true);
  }

  getFilteredList(): KnowledgeItem[] {
    // 如果有搜索文本且不是通过API搜索，进行本地过滤
    if (this.searchText && !this.isLoading) {
      return this.knowledgeList;
    }
    return this.knowledgeList;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('知识库')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 搜索栏
      Row() {
        Column() {
          Image($r('app.media.ic_search'))
            .width(18)
            .height(18)
            .fillColor(SemanticColors.Text4)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)

        TextInput({ placeholder: '搜索知识库', text: this.searchText })
          .layoutWeight(1)
          .height(36)
          .backgroundColor('transparent')
          .placeholderColor(SemanticColors.Text4)
          .placeholderFont({ size: FontSize.Sm })
          .fontColor(SemanticColors.Text1)
          .fontSize(FontSize.Sm)
          .onChange((value: string) => {
            this.onSearchChange(value);
          })

        if (this.searchText.length > 0) {
          Column() {
            Image($r('app.media.ic_close'))
              .width(16)
              .height(16)
              .fillColor(SemanticColors.Text4)
          }
          .width(32)
          .height(32)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.searchText = '';
            this.loadKnowledge(true);
          })
        }
      }
      .width('100%')
      .padding({ left: Spacing.Space4, right: Spacing.Space4 })
      .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral100)
      .borderRadius(SemanticRadius.Pill)

      // 分类标签
      Scroll() {
        Row() {
          ForEach(this.categories, (category: string) => {
            Text(category)
              .fontSize(FontSize.Sm)
              .fontWeight(this.selectedCategory === category ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.selectedCategory === category ? NeutralColors.Neutral0 : SemanticColors.Text2)
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
              .backgroundColor(this.selectedCategory === category ? BrandColors.Brand500 : NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Pill)
              .margin({ right: Spacing.Space3 })
              .onClick(() => {
                this.onCategoryChange(category);
              })
          })
        }
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .backgroundColor(NeutralColors.Neutral0)
      .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })

      // 错误提示
      if (this.showError) {
        Row() {
          Text(this.errorMessage)
            .fontSize(FontSize.Sm)
            .fontColor(ErrorColors.Error500)
            .layoutWeight(1)

          Button('重试')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .backgroundColor('transparent')
            .onClick(() => {
              this.retryLoad();
            })
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
        .backgroundColor(ErrorColors.Error50)
      }

      // 内容列表
      Refresh({ refreshing: this.isRefreshing }) {
        List() {
          ForEach(this.getFilteredList(), (item: KnowledgeItem) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(item.title)
                      .fontSize(FontSize.Sm)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(SemanticColors.Text1)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(item.summary)
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text2)
                      .margin({ top: Spacing.Space3 })
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .lineHeight(18)

                    Row() {
                      Text(item.category)
                        .fontSize(FontSize.Xs)
                        .fontColor(BrandColors.Brand500)
                        .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                        .backgroundColor(BrandColors.Brand50)
                        .borderRadius(SemanticRadius.Pill)

                      Blank()

                      Text('阅读 ' + this.formatReadCount(item.readCount))
                        .fontSize(FontSize.Xs)
                        .fontColor(SemanticColors.Text4)

                      Text(' | ')
                        .fontSize(FontSize.Xs)
                        .fontColor(SemanticColors.Text4)

                      Text(item.updateTime)
                        .fontSize(FontSize.Xs)
                        .fontColor(SemanticColors.Text4)
                    }
                    .margin({ top: Spacing.Space4 })
                  }
                  .layoutWeight(1)
                }
              }
              .width('100%')
              .padding(SemanticSpacing.Lg)
              .backgroundColor(NeutralColors.Neutral0)
              .borderRadius(SemanticRadius.Component)
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
              .shadow({
                radius: 4,
                color: 'rgba(0, 0, 0, 0.02)',
                offsetY: 1
              })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/KnowledgeDetail',
                  params: { id: item.id }
                });
              })
            }
          })

          // 加载更多提示
          if (this.isLoadingMore) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(BrandColors.Brand500)

                Text('加载中...')
                  .fontSize(FontSize.Sm)
                  .fontColor(SemanticColors.Text3)
                  .margin({ left: Spacing.Space3 })
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
          }

          // 没有更多数据提示
          if (!this.hasMore && this.knowledgeList.length > 0 && !this.searchText) {
            ListItem() {
              Text('没有更多内容了')
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text4)
                .width('100%')
                .height(50)
                .textAlign(TextAlign.Center)
            }
          }
        }
        .layoutWeight(1)
        .padding({ top: Spacing.Space4 })
        .backgroundColor(NeutralColors.Neutral50)
        .onReachEnd(() => {
          this.loadMore();
        })
      }
      .onRefreshing(() => {
        this.loadKnowledge(true);
      })

      // 加载中提示
      if (this.isLoading && !this.isRefreshing) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(BrandColors.Brand500)

          Text('加载中...')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space3 })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .backgroundColor('rgba(255, 255, 255, 0.8)')
        .justifyContent(FlexAlign.Center)
      }

      // 空数据提示
      if (this.knowledgeList.length === 0 && !this.isLoading) {
        Column() {
          Image($r('app.media.ic_empty'))
            .width(80)
            .height(80)
            .fillColor(SemanticColors.Text4)

          Text('暂无内容')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space4 })

          Button('刷新试试')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .backgroundColor(BrandColors.Brand50)
            .margin({ top: Spacing.Space4 })
            .onClick(() => {
              this.retryLoad();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  formatReadCount(count: number): string {
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + 'w';
    }
    return count.toString();
  }
}

// 错误颜色（从design-tokens导入）
import { ErrorColors } from '../constants/design-tokens';
