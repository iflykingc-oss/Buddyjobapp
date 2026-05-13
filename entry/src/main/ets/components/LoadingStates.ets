/**
 * LoadingStates - 通用加载状态组件集合
 *
 * 提供 4 种常用加载状态组件：
 *   1. SkeletonList - 骨架屏列表（数据加载中的占位效果）
 *   2. EmptyState - 空数据占位（列表无数据时的友好提示）
 *   3. ErrorState - 错误展示（加载失败时的降级 UI，含重试按钮）
 *   4. LoadingMore - 加载更多指示器（列表底部的加载状态）
 *
 * 设计规范：
 *   - 使用 design-tokens 中的语义化颜色
 *   - 支持深色模式（通过 AppStorage 'isDarkMode' 自动适配）
 *   - 骨架屏动画使用 shimmer 效果
 *
 * @since 1.0.0
 */
import {
  SemanticColors,
  DarkSemanticColors,
  BrandColors,
  NeutralColors,
  Spacing,
  BorderRadius,
  FontSize,
  FontWeight,
  SemanticRadius,
  Duration,
  Easing,
} from '../constants/design-tokens';

// ============================================
// SkeletonList - 骨架屏列表
// ============================================

/**
 * 骨架屏列表项配置
 */
interface SkeletonItemConfig {
  /** 是否显示头像 */
  showAvatar: boolean;
  /** 标题行数 */
  titleLines: number;
  /** 是否显示副标题 */
  showSubtitle: boolean;
  /** 是否显示尾部标签 */
  showTag: boolean;
}

@Component
export struct SkeletonList {
  /** 列表项数量 */
  @Prop count: number = 6;
  /** 是否显示头像 */
  @Prop showAvatar: boolean = true;
  /** 标题行数 */
  @Prop titleLines: number = 2;
  /** 是否显示副标题 */
  @Prop showSubtitle: boolean = true;
  /** 是否显示尾部标签 */
  @Prop showTag: boolean = false;

  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.isDark = AppStorage.get<boolean>('isDarkMode') || false;
  }

  /**
   * 骨架屏单行
   */
  @Builder
  SkeletonRow(widthPercent: string, marginTop: number) {
    Row()
      .width(`${widthPercent}%`)
      .height(14)
      .borderRadius(BorderRadius.RadiusSm)
      .backgroundColor(this.isDark ? NeutralColors.Neutral800 : NeutralColors.Neutral100)
      .opacity(0.6)
      .margin({ top: marginTop })
  }

  /**
   * 骨架屏列表项
   */
  @Builder
  SkeletonListItem() {
    Row() {
      // 头像占位
      if (this.showAvatar) {
        Column()
          .width(44)
          .height(44)
          .borderRadius(BorderRadius.RadiusFull)
          .backgroundColor(this.isDark ? NeutralColors.Neutral800 : NeutralColors.Neutral100)
          .opacity(0.6)
          .shimmer({
            duration: Duration.Slow,
            curve: Easing.Default,
          })
      }

      // 文字占位
      Column({ space: 0 }) {
        ForEach(Array.from({ length: this.titleLines }), (_: Object, index: number) => {
          Row()
            .width(index === this.titleLines - 1 ? '60%' : '100%')
            .height(14)
            .borderRadius(BorderRadius.RadiusSm)
            .backgroundColor(this.isDark ? NeutralColors.Neutral800 : NeutralColors.Neutral100)
            .opacity(0.6)
            .margin({ top: index === 0 ? 0 : 8 })
            .shimmer({
              duration: Duration.Slow,
              curve: Easing.Default,
            })
        })

        if (this.showSubtitle) {
          Row()
            .width('40%')
            .height(12)
            .borderRadius(BorderRadius.RadiusSm)
            .backgroundColor(this.isDark ? NeutralColors.Neutral800 : NeutralColors.Neutral100)
            .opacity(0.4)
            .margin({ top: 10 })
            .shimmer({
              duration: Duration.Slow,
              curve: Easing.Default,
            })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: this.showAvatar ? Spacing.Space4 : 0 })

      // 尾部标签占位
      if (this.showTag) {
        Column()
          .width(48)
          .height(24)
          .borderRadius(SemanticRadius.Pill)
          .backgroundColor(this.isDark ? NeutralColors.Neutral800 : NeutralColors.Neutral100)
          .opacity(0.5)
          .shimmer({
            duration: Duration.Slow,
            curve: Easing.Default,
          })
      }
    }
    .width('100%')
    .padding({
      left: Spacing.Space6,
      right: Spacing.Space6,
      top: Spacing.Space4,
      bottom: Spacing.Space4,
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    List({ space: 0 }) {
      ForEach(Array.from({ length: this.count }), (_: Object, _: number) => {
        ListItem() {
          this.SkeletonListItem()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDark ? DarkSemanticColors.Background : SemanticColors.Background)
  }
}

// ============================================
// EmptyState - 空数据占位
// ============================================

@Component
export struct EmptyStateView {
  /** 图标资源 */
  @Prop icon: Resource = $r('app.media.media_icon');
  /** 标题 */
  @Prop title: string = '暂无数据';
  /** 描述文字 */
  @Prop description: string = '';
  /** 按钮文字（为空则不显示按钮） */
  @Prop buttonText: string = '';
  /** 按钮点击回调 */
  onButtonClick: () => void = () => {};

  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.isDark = AppStorage.get<boolean>('isDarkMode') || false;
  }

  build() {
    Column() {
      // 图标
      Image(this.icon)
        .width(80)
        .height(80)
        .opacity(0.3)
        .objectFit(ImageFit.Contain)

      // 标题
      Text(this.title)
        .fontSize(FontSize.Base)
        .fontColor(this.isDark ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .margin({ top: Spacing.Space5 })

      // 描述
      if (this.description) {
        Text(this.description)
          .fontSize(FontSize.Sm)
          .fontColor(this.isDark ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ top: Spacing.Space2 })
          .textAlign(TextAlign.Center)
          .padding({ left: Spacing.Space8, right: Spacing.Space8 })
      }

      // 操作按钮
      if (this.buttonText) {
        Button(this.buttonText)
          .fontSize(FontSize.Sm)
          .fontColor(NeutralColors.Neutral0)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Control)
          .height(40)
          .padding({ left: Spacing.Space8, right: Spacing.Space8 })
          .margin({ top: Spacing.Space6 })
          .onClick(() => {
            this.onButtonClick();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: Spacing.Space8, right: Spacing.Space8 })
    .backgroundColor(this.isDark ? DarkSemanticColors.Background : SemanticColors.Background)
  }
}

// ============================================
// ErrorState - 错误展示（含重试）
// ============================================

@Component
export struct ErrorState {
  /** 错误标题 */
  @Prop title: string = '加载失败';
  /** 错误描述 */
  @Prop description: string = '请检查网络连接后重试';
  /** 重试按钮文字 */
  @Prop retryButtonText: string = '重试';
  /** 是否正在重试 */
  @Prop retrying: boolean = false;
  /** 重试回调 */
  onRetry: () => void = () => {};

  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.isDark = AppStorage.get<boolean>('isDarkMode') || false;
  }

  build() {
    Column() {
      // 错误图标
      Column() {
        Text('!')
          .fontSize(FontSize.Xxxl)
          .fontColor(this.isDark ? DarkSemanticColors.Error : SemanticColors.Error)
          .fontWeight(FontWeight.Bold)
      }
      .width(64)
      .height(64)
      .borderRadius(BorderRadius.RadiusFull)
      .backgroundColor(this.isDark ? 'rgba(232, 64, 38, 0.12)' : 'rgba(232, 64, 38, 0.08)')
      .justifyContent(FlexAlign.Center)

      // 错误标题
      Text(this.title)
        .fontSize(FontSize.Lg)
        .fontColor(this.isDark ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .fontWeight(FontWeight.Semibold)
        .margin({ top: Spacing.Space6 })

      // 错误描述
      Text(this.description)
        .fontSize(FontSize.Sm)
        .fontColor(this.isDark ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ top: Spacing.Space2 })
        .textAlign(TextAlign.Center)
        .padding({ left: Spacing.Space8, right: Spacing.Space8 })

      // 重试按钮
      Button(this.retrying ? '重试中...' : this.retryButtonText)
        .fontSize(FontSize.Sm)
        .fontColor(NeutralColors.Neutral0)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.retrying ?
          (this.isDark ? NeutralColors.Neutral700 : NeutralColors.Neutral300) :
          BrandColors.Brand500)
        .borderRadius(SemanticRadius.Control)
        .height(40)
        .padding({ left: Spacing.Space8, right: Spacing.Space8 })
        .margin({ top: Spacing.Space6 })
        .enabled(!this.retrying)
        .opacity(this.retrying ? 0.6 : 1.0)
        .onClick(() => {
          if (!this.retrying) {
            this.onRetry();
          }
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: Spacing.Space8, right: Spacing.Space8 })
    .backgroundColor(this.isDark ? DarkSemanticColors.Background : SemanticColors.Background)
  }
}

// ============================================
// LoadingMore - 加载更多指示器
// ============================================

/**
 * 加载更多状态枚举
 */
export enum LoadMoreStatus {
  /** 空闲 - 不显示 */
  IDLE = 'idle',
  /** 加载中 */
  LOADING = 'loading',
  /** 加载完成 - 没有更多数据 */
  NO_MORE = 'no_more',
  /** 加载失败 */
  ERROR = 'error',
}

@Component
export struct LoadingMore {
  /** 加载状态 */
  @Prop status: LoadMoreStatus = LoadMoreStatus.IDLE;
  /** 加载中文字 */
  @Prop loadingText: string = '加载中...';
  /** 没有更多数据文字 */
  @Prop noMoreText: string = '没有更多了';
  /** 错误文字 */
  @Prop errorText: string = '加载失败，点击重试';
  /** 重试回调 */
  onRetry: () => void = () => {};

  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.isDark = AppStorage.get<boolean>('isDarkMode') || false;
  }

  build() {
    if (this.status === LoadMoreStatus.IDLE) {
      // 空闲状态不渲染
      Column().height(0)
    } else {
      Column() {
        if (this.status === LoadMoreStatus.LOADING) {
          // 加载中
          Row({ space: Spacing.Space2 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(this.isDark ? DarkSemanticColors.Text3 : SemanticColors.Text3)

            Text(this.loadingText)
              .fontSize(FontSize.Sm)
              .fontColor(this.isDark ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          }
        } else if (this.status === LoadMoreStatus.NO_MORE) {
          // 没有更多
          Row() {
            // 左分割线
            Row()
              .width(40)
              .height(0.5)
              .backgroundColor(this.isDark ? DarkSemanticColors.Border : SemanticColors.Border)

            Text(this.noMoreText)
              .fontSize(FontSize.Xs)
              .fontColor(this.isDark ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space4, right: Spacing.Space4 })

            // 右分割线
            Row()
              .width(40)
              .height(0.5)
              .backgroundColor(this.isDark ? DarkSemanticColors.Border : SemanticColors.Border)
          }
        } else if (this.status === LoadMoreStatus.ERROR) {
          // 加载失败
          Text(this.errorText)
            .fontSize(FontSize.Sm)
            .fontColor(this.isDark ? DarkSemanticColors.Error : SemanticColors.Error)
            .padding({
              top: Spacing.Space3,
              bottom: Spacing.Space3,
              left: Spacing.Space6,
              right: Spacing.Space6,
            })
            .borderRadius(SemanticRadius.Control)
            .backgroundColor(this.isDark ? 'rgba(232, 64, 38, 0.08)' : 'rgba(232, 64, 38, 0.04)')
            .onClick(() => {
              this.onRetry();
            })
        }
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
    }
  }
}
