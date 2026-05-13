import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { KnowledgeService, ArticleDetail } from '../services/KnowledgeService';
import { FavoriteService, FavoriteType } from '../services/FavoriteService';
import { ShareService } from '../services/ShareService';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { Router } from '../utils/Router';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes,
  WarningColors
} from '../constants/design-tokens';

@Entry
@Component
struct KnowledgeDetail {
  @State article: ArticleDetail | null = null;
  @State isFavorited: boolean = false;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showError: boolean = false;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  private knowledgeService: KnowledgeService = KnowledgeService.getInstance();
  private favoriteService: FavoriteService = FavoriteService.getInstance();
  private articleId: string = '';

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['id']) {
      this.articleId = params['id'];
      await this.loadArticleDetail(this.articleId);
      await this.checkFavoriteStatus();
    } else {
      this.showError = true;
      this.errorMessage = '文章ID无效';
    }
  }

  /**
   * 加载文章详情
   */
  async loadArticleDetail(id: string): Promise<void> {
    this.isLoading = true;
    this.showError = false;
    this.errorMessage = '';

    try {
      const response = await this.knowledgeService.getArticleById(id);

      if (response.success && response.data) {
        this.article = response.data;
      } else {
        // API失败时使用默认数据
        this.article = this.knowledgeService.getDefaultArticleById(id);
        this.showError = true;
        this.errorMessage = response.error || '获取文章详情失败，显示默认内容';
      }
    } catch (error) {
      console.error('[KnowledgeDetail] Load article failed:', error);
      this.article = this.knowledgeService.getDefaultArticleById(id);
      this.showError = true;
      this.errorMessage = '网络错误，显示默认内容';
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 检查收藏状态
   */
  async checkFavoriteStatus(): Promise<void> {
    if (!this.articleId) {
      return;
    }

    try {
      const isFav = await this.favoriteService.isFavorited(this.articleId, FavoriteType.ARTICLE);
      this.isFavorited = isFav;
    } catch (error) {
      console.error('[KnowledgeDetail] Check favorite status failed:', error);
    }
  }

  /**
   * 切换收藏状态
   */
  async toggleFavorite(): Promise<void> {
    if (!this.article) {
      return;
    }

    try {
      const favoriteItem = {
        type: FavoriteType.ARTICLE,
        title: this.article.title,
        subtitle: this.article.category,
        sourceId: this.article.id,
        extraData: JSON.stringify({
          author: this.article.author,
          readCount: this.article.readCount,
          publishTime: this.article.publishTime
        })
      };

      const result = await this.favoriteService.toggleFavorite(favoriteItem);
      this.isFavorited = result;

      promptAction.showToast({
        message: result ? '已收藏' : '已取消收藏'
      });
    } catch (error) {
      console.error('[KnowledgeDetail] Toggle favorite failed:', error);
      promptAction.showToast({
        message: '操作失败，请重试'
      });
    }
  }

  /**
   * 重试加载
   */
  async retryLoad(): Promise<void> {
    if (this.articleId) {
      await this.loadArticleDetail(this.articleId);
      await this.checkFavoriteStatus();
    }
  }

  formatReadCount(count: number): string {
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + 'w';
    }
    return count.toString();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.media_ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('文章详情')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .shadow({
        radius: 8,
        color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 错误提示
      if (this.showError && this.errorMessage) {
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

      if (this.article) {
        // 文章内容
        Scroll() {
          Column() {
            // 文章标题
            Text(this.article.title)
              .fontSize(FontSize.Xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
              .width('100%')
              .margin({ top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })

            // 标签信息
            Row() {
              Text(this.article.category)
                .fontSize(FontSize.Xs)
                .fontColor(BrandColors.Brand500)
                .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                .borderRadius(SemanticRadius.Pill)

              Text(this.article.author)
                .fontSize(FontSize.Xs)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                .margin({ left: Spacing.Space4 })

              Blank()

              Text('阅读 ' + this.formatReadCount(this.article.readCount))
                .fontSize(FontSize.Xs)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .margin({ bottom: Spacing.Space4 })

            // 发布时间
            Text(this.article.publishTime)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            Divider()

            // 文章正文
            Text(this.article.content)
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text1)
              .lineHeight(28)
              .width('100%')
              .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })

            // 相关推荐操作
            Column() {
              Text('相关推荐操作')
                .fontSize(FontSize.Base)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .width('100%')
                .margin({ bottom: SemanticSpacing.Lg })

              // 第一行
              Row({ space: Spacing.Space3 }) {
                Column() {
                  Column() {
                    Image($r('app.media.media_ic_resume'))
                      .width(24)
                      .height(24)
                      .fillColor(BrandColors.Brand500)
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .justifyContent(FlexAlign.Center)

                  Text('优化我的简历')
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                    .margin({ top: Spacing.Space2 })
                }
                .layoutWeight(1)
                .height(88)
                .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
                .borderRadius(SemanticRadius.Component)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  AppStorage.setOrCreate('currentTab', 1);
                  router.back();
                })

                Column() {
                  Column() {
                    Image($r('app.media.media_ic_assessment'))
                      .width(24)
                      .height(24)
                      .fillColor(BrandColors.Brand500)
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .justifyContent(FlexAlign.Center)

                  Text('测试我的能力')
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                    .margin({ top: Spacing.Space2 })
                }
                .layoutWeight(1)
                .height(88)
                .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
                .borderRadius(SemanticRadius.Component)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  AppStorage.setOrCreate('currentTab', 2);
                  router.back();
                })
              }
              .width('100%')

              // 第二行
              Row({ space: Spacing.Space3 }) {
                Column() {
                  Column() {
                    Image($r('app.media.media_ic_chat'))
                      .width(24)
                      .height(24)
                      .fillColor(BrandColors.Brand500)
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .justifyContent(FlexAlign.Center)

                  Text('开始模拟面试')
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                    .margin({ top: Spacing.Space2 })
                }
                .layoutWeight(1)
                .height(88)
                .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
                .borderRadius(SemanticRadius.Component)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  Router.push('pages/Interview');
                })

                Column() {
                  Column() {
                    Image($r('app.media.media_ic_order'))
                      .width(24)
                      .height(24)
                      .fillColor(BrandColors.Brand500)
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .justifyContent(FlexAlign.Center)

                  Text('分析我的Offer')
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                    .margin({ top: Spacing.Space2 })
                }
                .layoutWeight(1)
                .height(88)
                .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
                .borderRadius(SemanticRadius.Component)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  Router.push('pages/OfferAnalysis');
                })
              }
              .width('100%')
              .margin({ top: Spacing.Space3 })
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Component)
            .margin({ top: SemanticSpacing.Lg })
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        }
        .layoutWeight(1)
        .backgroundColor(NeutralColors.Neutral50)

        // 底部操作栏
        Row() {
          // 收藏按钮
          Row() {
            Column() {
              Image($r('app.media.media_ic_favorite'))
                .width(ComponentSizes.Icon.Lg)
                .height(ComponentSizes.Icon.Lg)
                .fillColor(this.isFavorited ? WarningColors.Warning500 : SemanticColors.Text3)
            }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)

            Text(this.isFavorited ? '已收藏' : '收藏')
              .fontSize(FontSize.Xs)
              .fontColor(this.isFavorited ? WarningColors.Warning500 : SemanticColors.Text3)
          }
          .layoutWeight(1)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.toggleFavorite();
          })

          Divider()
            .vertical(true)
            .height(24)
            .color(NeutralColors.Neutral200)

          // 分享按钮
          Row() {
            Column() {
              Image($r('app.media.media_ic_share'))
                .width(ComponentSizes.Icon.Lg)
                .height(ComponentSizes.Icon.Lg)
                .fillColor(SemanticColors.Text3)
            }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)

            Text('分享')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
          }
          .layoutWeight(1)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            ShareService.getInstance().shareArticle(this.article!.title, this.article!.url || '');
          })
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .backgroundColor(NeutralColors.Neutral0)
        .border({ width: { top: 1 }, color: NeutralColors.Neutral200 })
      }

      // 加载中提示
      if (this.isLoading) {
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
        .backgroundColor('rgba(255, 255, 255, 0.9)')
        .justifyContent(FlexAlign.Center)
      }

      // 加载失败且无数据
      if (!this.article && !this.isLoading && this.showError) {
        Column() {
          Image($r('app.media.media_ic_error'))
            .width(80)
            .height(80)
            .fillColor(SemanticColors.Text4)

          Text('加载失败')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space4 })

          Text(this.errorMessage)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text4)
            .margin({ top: Spacing.Space2 })
            .textAlign(TextAlign.Center)

          Button('重新加载')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
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
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }
}

