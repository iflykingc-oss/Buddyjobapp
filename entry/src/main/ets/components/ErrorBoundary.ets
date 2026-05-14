/**
 * ErrorBoundary - 错误边界组件
 *
 * 包装子组件，捕获渲染过程中的错误并展示降级 UI。
 * 防止单个组件的错误导致整个页面白屏或崩溃。
 *
 * 使用方式：
 * ```
 * ErrorBoundary({
 *   onError: (msg) => hilog.error(...),
 *   children: () => {
 *     MyComponent()
 *   }
 * })
 * ```
 *
 * 设计规范：
 *   - 使用 design-tokens 中的语义化颜色
 *   - 支持深色模式
 *   - 提供重试按钮，允许用户恢复
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
} from '../constants/design-tokens';

const TAG = 'ErrorBoundary';

@Component
export struct ErrorBoundary {
  /** 子组件构建函数 */
  children: () => void;
  /** 错误回调 */
  onError?: (errorMessage: string) => void;
  /** 自定义错误标题 */
  errorTitle?: string;
  /** 自定义错误描述 */
  errorDescription?: string;
  /** 自定义重试按钮文字 */
  retryButtonText?: string;

  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isDark: boolean = false;

  aboutToAppear(): void {
    this.isDark = AppStorage.get<boolean>('isDarkMode') || false;
  }

  /**
   * 标记错误状态
   * 子组件在 catch 中调用此方法通知 ErrorBoundary
   */
  setError(msg: string): void {
    this.hasError = true;
    this.errorMessage = msg;
    console.error(`[${TAG}] Component error: ${msg}`);
    this.onError?.(msg);
  }

  /**
   * 重试 - 清除错误状态，重新渲染子组件
   */
  retry(): void {
    this.hasError = false;
    this.errorMessage = '';
    console.info(`[${TAG}] Retry triggered`);
  }

  build() {
    if (this.hasError) {
      // 错误降级 UI
      Column() {
        // 错误图标区域
        Column() {
          Text('!')
            .fontSize(FontSize.Xxxl)
            .fontColor(this.isDark ? DarkSemanticColors.Error : SemanticColors.Error)
            .fontWeight(FontWeight.Bold)
            .width(64)
            .height(64)
            .borderRadius(BorderRadius.RadiusFull)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.isDark ? 'rgba(232, 64, 38, 0.12)' : 'rgba(232, 64, 38, 0.08)')
        }
        .margin({ bottom: Spacing.Space6 })

        // 错误标题
        Text(this.errorTitle || '加载失败')
          .fontSize(FontSize.Lg)
          .fontColor(this.isDark ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .fontWeight(FontWeight.Semibold)

        // 错误描述
        Text(this.errorDescription || '页面加载遇到了问题，请稍后重试')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDark ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ top: Spacing.Space2 })
          .textAlign(TextAlign.Center)
          .padding({ left: Spacing.Space8, right: Spacing.Space8 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 开发模式下显示错误详情
        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(FontSize.Xs)
            .fontColor(this.isDark ? DarkSemanticColors.Text3 : SemanticColors.Text3)
            .margin({ top: Spacing.Space3 })
            .padding({
              left: Spacing.Space4,
              right: Spacing.Space4,
              top: Spacing.Space2,
              bottom: Spacing.Space2,
            })
            .backgroundColor(this.isDark ? DarkSemanticColors.Surface2 : SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Control)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: Spacing.Space4, right: Spacing.Space4 })
        }

        // 重试按钮
        Button(this.retryButtonText || '重试')
          .fontSize(FontSize.Sm)
          .fontColor(NeutralColors.Neutral0)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Control)
          .height(40)
          .padding({ left: Spacing.Space8, right: Spacing.Space8 })
          .margin({ top: Spacing.Space6 })
          .onClick(() => {
            this.retry();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: Spacing.Space8, right: Spacing.Space8 })
      .backgroundColor(this.isDark ? DarkSemanticColors.Background : SemanticColors.Background)
    } else {
      // 正常渲染子组件
      this.children();
    }
  }
}
