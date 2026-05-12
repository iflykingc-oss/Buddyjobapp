import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import {
  FavoriteService,
  FavoriteItem,
  FavoriteType
} from '../../services/FavoriteService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

@Entry
@Component
struct FavoritesPage {
  @State favoriteList: FavoriteItem[] = [];
  @State isLoading: boolean = false;
  @State selectedType: FavoriteType | 'all' = 'all';

  private favoriteService: FavoriteService = FavoriteService.getInstance();

  aboutToAppear() {
    this.loadFavorites();
  }

  /**
   * 加载收藏列表
   */
  async loadFavorites() {
    this.isLoading = true;
    try {
      const type = this.selectedType === 'all' ? undefined : this.selectedType;
      this.favoriteList = await this.favoriteService.getFavorites(type);
    } catch (error) {
      console.error('[FavoritesPage] Load favorites failed:', error);
      promptAction.showToast({ message: '加载收藏失败' });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 取消收藏
   */
  async removeFavorite(item: FavoriteItem, index: number) {
    try {
      const success = await this.favoriteService.removeFavorite(item.id);
      if (success) {
        this.favoriteList.splice(index, 1);
        promptAction.showToast({ message: '已取消收藏' });
      } else {
        promptAction.showToast({ message: '操作失败，请重试' });
      }
    } catch (error) {
      console.error('[FavoritesPage] Remove favorite failed:', error);
      promptAction.showToast({ message: '操作失败' });
    }
  }

  /**
   * 获取类型标签文本
   */
  getTypeLabel(type: FavoriteType): string {
    const labels: Record<FavoriteType, string> = {
      [FavoriteType.ARTICLE]: '文章',
      [FavoriteType.ASSESSMENT]: '测评',
      [FavoriteType.RESUME_TEMPLATE]: '简历',
      [FavoriteType.JOB]: '职位',
      [FavoriteType.COURSE]: '课程'
    };
    return labels[type] || '其他';
  }

  /**
   * 获取类型标签颜色
   */
  getTypeColor(type: FavoriteType): string {
    const colors: Record<FavoriteType, string> = {
      [FavoriteType.ARTICLE]: BrandColors.Brand500,
      [FavoriteType.ASSESSMENT]: SuccessColors.Success500,
      [FavoriteType.RESUME_TEMPLATE]: WarningColors.Warning500,
      [FavoriteType.JOB]: '#8B5CF6',
      [FavoriteType.COURSE]: '#EC4899'
    };
    return colors[type] || SemanticColors.Text3;
  }

  /**
   * 格式化时间
   */
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('我的收藏')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 类型筛选标签
      Row() {
        ForEach([
          { key: 'all', label: '全部' },
          { key: FavoriteType.ARTICLE, label: '文章' },
          { key: FavoriteType.ASSESSMENT, label: '测评' },
          { key: FavoriteType.RESUME_TEMPLATE, label: '简历' }
        ], (item: { key: string; label: string }) => {
          Column() {
            Text(item.label)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedType === item.key ? NeutralColors.Neutral0 : SemanticColors.Text2)
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
          .backgroundColor(this.selectedType === item.key ? BrandColors.Brand500 : NeutralColors.Neutral100)
          .borderRadius(SemanticRadius.Pill)
          .margin({ right: Spacing.Space3 })
          .onClick(() => {
            this.selectedType = item.key as FavoriteType | 'all';
            this.loadFavorites();
          })
        })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral50)

      // 收藏列表或空状态
      if (this.favoriteList.length === 0 && !this.isLoading) {
        // 空状态
        Column() {
          Image($r('app.media.ic_favorite'))
            .width(80)
            .height(80)
            .fillColor(SemanticColors.Text4)
            .opacity(0.5)

          Text('暂无收藏内容')
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text3)
            .margin({ top: SemanticSpacing.Lg })

          Text('收藏感兴趣的文章、测评和简历模板')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text4)
            .margin({ top: Spacing.Space3 })

          Button('去浏览')
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Medium)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Control)
            .height(40)
            .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
            .margin({ top: SemanticSpacing.Xl })
            .onClick(() => {
              router.back();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(NeutralColors.Neutral50)
      } else {
        // 收藏列表
        List() {
          ForEach(this.favoriteList, (item: FavoriteItem, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  // 左侧图片或图标
                  if (item.imageUrl) {
                    Image(item.imageUrl)
                      .width(80)
                      .height(80)
                      .borderRadius(SemanticRadius.Control)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Column() {
                      Image($r('app.media.ic_favorite'))
                        .width(32)
                        .height(32)
                        .fillColor(BrandColors.Brand500)
                    }
                    .width(80)
                    .height(80)
                    .borderRadius(SemanticRadius.Control)
                    .backgroundColor(BrandColors.Brand50)
                    .justifyContent(FlexAlign.Center)
                  }

                  // 中间内容
                  Column() {
                    // 类型标签
                    Row() {
                      Text(this.getTypeLabel(item.type))
                        .fontSize(FontSize.Xs)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.getTypeColor(item.type))
                        .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
                        .backgroundColor(this.getTypeColor(item.type) + '20')
                        .borderRadius(4)
                    }

                    // 标题
                    Text(item.title)
                      .fontSize(FontSize.Base)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(SemanticColors.Text1)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: Spacing.Space2 })
                      .layoutWeight(1)

                    // 副标题（如果有）
                    if (item.subtitle) {
                      Text(item.subtitle)
                        .fontSize(FontSize.Xs)
                        .fontColor(SemanticColors.Text3)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: Spacing.Space1 })
                    }

                    // 收藏时间
                    Text('收藏于 ' + this.formatTime(item.createTime))
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text4)
                      .margin({ top: Spacing.Space2 })
                  }
                  .layoutWeight(1)
                  .height(80)
                  .margin({ left: SemanticSpacing.Lg })
                  .alignItems(HorizontalAlign.Start)

                  // 右侧取消收藏按钮
                  Column() {
                    Image($r('app.media.ic_close'))
                      .width(20)
                      .height(20)
                      .fillColor(SemanticColors.Text4)
                  }
                  .width(32)
                  .height(32)
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => {
                    this.removeFavorite(item, index as number);
                  })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .padding(SemanticSpacing.Lg)
              .backgroundColor(NeutralColors.Neutral0)
              .borderRadius(SemanticRadius.Component)
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space4 })
              .shadow({
                radius: 8,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 2
              })
            }
          })
        }
        .layoutWeight(1)
        .padding({ top: SemanticSpacing.Lg })
        .backgroundColor(NeutralColors.Neutral50)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }
}
