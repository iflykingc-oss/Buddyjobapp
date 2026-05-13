/**
 * NewMessageToast - 新消息提示组件
 * 
 * 鸿蒙规范设计：
 * - 底部 Toast 提示
 * - 新消息到达时显示"新消息"提示
 * - 点击滚动到底部
 * - 自动消失（3秒）
 */

import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  FontSize,
  FontWeight,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  Duration,
  ZIndex
} from '../../constants/design-tokens';

/**
 * 新消息提示组件
 */
@Component
export struct NewMessageToast {
  /** 是否显示提示 */
  @Link isVisible: boolean;
  /** 新消息数量 */
  @Prop messageCount: number = 1;
  /** 点击回调 */
  private onScrollToBottom?: () => void;
  /** 自动消失定时器 */
  private autoHideTimer: number = -1;
  /** 动画状态 */
  @State opacity: number = 0;
  @State translateY: number = 20;

  aboutToAppear() {
    this.setupAutoHide();
  }

  aboutToUpdate() {
    if (this.isVisible) {
      this.showAnimation();
      this.setupAutoHide();
    } else {
      this.hideAnimation();
    }
  }

  aboutToDisappear() {
    this.clearTimer();
  }

  /**
   * 设置自动隐藏
   */
  private setupAutoHide() {
    this.clearTimer();
    if (this.isVisible) {
      this.autoHideTimer = setTimeout(() => {
        this.isVisible = false;
      }, 3000); // 3秒后自动消失
    }
  }

  /**
   * 清除定时器
   */
  private clearTimer() {
    if (this.autoHideTimer !== -1) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = -1;
    }
  }

  /**
   * 显示动画
   */
  private showAnimation() {
    this.opacity = 1;
    this.translateY = 0;
  }

  /**
   * 隐藏动画
   */
  private hideAnimation() {
    this.opacity = 0;
    this.translateY = 20;
  }

  /**
   * 处理点击事件
   */
  private handleClick() {
    this.isVisible = false;
    this.clearTimer();
    if (this.onScrollToBottom) {
      this.onScrollToBottom();
    }
  }

  /**
   * 设置滚动到底部回调
   */
  setOnScrollToBottom(callback: () => void) {
    this.onScrollToBottom = callback;
  }

  build() {
    if (this.isVisible) {
      Row() {
        // 新消息图标
        Image($r('app.media.media_ic_chat'))
          .width(16)
          .height(16)
          .fillColor(BrandColors.Brand500)

        // 新消息文本
        Text(this.getMessageText())
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand600)
          .fontWeight(FontWeight.Medium)
          .margin({ left: Spacing.Space2 })

        // 向下箭头
        Text('↓')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .margin({ left: Spacing.Space2 })
      }
      .padding({
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        top: Spacing.Space3,
        bottom: Spacing.Space3
      })
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(SemanticRadius.Control)
      .border({
        width: 1,
        color: BrandColors.Brand200
      })
      .shadow({
        radius: 12,
        color: 'rgba(139, 92, 246, 0.15)',
        offsetY: 2
      })
      .opacity(this.opacity)
      .translate({ y: this.translateY })
      .animation({
        duration: Duration.Normal,
        curve: Curve.EaseOut
      })
      .onClick(() => this.handleClick())
    }
  }

  /**
   * 获取消息文本
   */
  private getMessageText(): string {
    if (this.messageCount === 1) {
      return '新消息';
    } else {
      return `${this.messageCount} 条新消息`;
    }
  }
}

/**
 * 新消息提示控制器
 * 用于外部控制提示的显示和隐藏
 */
export class NewMessageToastController {
  private visible: boolean = false;
  private count: number = 0;
  private onVisibleChange?: (visible: boolean) => void;
  private onScrollToBottom?: () => void;

  /**
   * 显示新消息提示
   */
  show(count: number = 1) {
    this.count = count;
    this.visible = true;
    if (this.onVisibleChange) {
      this.onVisibleChange(true);
    }
  }

  /**
   * 隐藏提示
   */
  hide() {
    this.visible = false;
    if (this.onVisibleChange) {
      this.onVisibleChange(false);
    }
  }

  /**
   * 获取可见状态
   */
  isVisible(): boolean {
    return this.visible;
  }

  /**
   * 获取消息数量
   */
  getCount(): number {
    return this.count;
  }

  /**
   * 设置可见状态变化回调
   */
  setOnVisibleChange(callback: (visible: boolean) => void) {
    this.onVisibleChange = callback;
  }

  /**
   * 设置滚动到底部回调
   */
  setOnScrollToBottom(callback: () => void) {
    this.onScrollToBottom = callback;
  }

  /**
   * 触发滚动到底部
   */
  scrollToBottom() {
    if (this.onScrollToBottom) {
      this.onScrollToBottom();
    }
    this.hide();
  }
}

/**
 * 简化的新消息提示组件
 * 自带状态管理
 */
@Component
export struct SimpleNewMessageToast {
  @Prop isVisible: boolean = false;
  @Prop messageCount: number = 1;
  @Prop onScrollToBottom: () => void = () => {};
  @State opacity: number = 0;
  @State translateY: number = 20;
  private autoHideTimer: number = -1;

  aboutToAppear() {
    if (this.isVisible) {
      this.showAnimation();
      this.setupAutoHide();
    }
  }

  aboutToUpdate() {
    if (this.isVisible) {
      this.showAnimation();
      this.setupAutoHide();
    } else {
      this.hideAnimation();
    }
  }

  aboutToDisappear() {
    this.clearTimer();
  }

  private setupAutoHide() {
    this.clearTimer();
    this.autoHideTimer = setTimeout(() => {
      this.hideAnimation();
    }, 3000);
  }

  private clearTimer() {
    if (this.autoHideTimer !== -1) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = -1;
    }
  }

  private showAnimation() {
    this.opacity = 1;
    this.translateY = 0;
  }

  private hideAnimation() {
    this.opacity = 0;
    this.translateY = 20;
  }

  build() {
    if (this.isVisible) {
      Row() {
        Image($r('app.media.media_ic_chat'))
          .width(16)
          .height(16)
          .fillColor(BrandColors.Brand500)

        Text(this.messageCount === 1 ? '新消息' : `${this.messageCount} 条新消息`)
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand600)
          .fontWeight(FontWeight.Medium)
          .margin({ left: Spacing.Space2 })

        Text('↓')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .margin({ left: Spacing.Space2 })
      }
      .padding({
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        top: Spacing.Space3,
        bottom: Spacing.Space3
      })
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(SemanticRadius.Control)
      .border({ width: 1, color: BrandColors.Brand200 })
      .shadow({ radius: 12, color: 'rgba(139, 92, 246, 0.15)', offsetY: 2 })
      .opacity(this.opacity)
      .translate({ y: this.translateY })
      .animation({ duration: Duration.Normal, curve: Curve.EaseOut })
      .onClick(() => {
        this.onScrollToBottom();
      })
    }
  }
}

/**
 * 滚动到底部按钮组件
 * 当有新消息且不在底部时显示
 */
@Component
export struct ScrollToBottomButton {
  @Prop isVisible: boolean = false;
  @Prop unreadCount: number = 0;
  @Prop onClick: () => void = () => {};
  @State opacity: number = 0;
  @State scale: number = 0.8;

  aboutToUpdate() {
    if (this.isVisible) {
      this.opacity = 1;
      this.scale = 1;
    } else {
      this.opacity = 0;
      this.scale = 0.8;
    }
  }

  build() {
    if (this.isVisible) {
      Column() {
        // 未读数量角标
        if (this.unreadCount > 0) {
          Text(this.unreadCount > 99 ? '99+' : this.unreadCount.toString())
            .fontSize(FontSize.Xs)
            .fontColor(NeutralColors.Neutral0)
            .fontWeight(FontWeight.Medium)
            .constraintSize({ minWidth: 18, minHeight: 18 })
            .padding({ left: 4, right: 4 })
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(9)
            .position({ x: -6, y: -6 })
            .zIndex(1)
        }

        // 向下箭头图标
        Column() {
          Text('↓')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text2)
        }
        .width(36)
        .height(36)
        .backgroundColor(NeutralColors.Neutral0)
        .borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetY: 2 })
        .border({ width: 1, color: NeutralColors.Neutral200 })
      }
      .width(36)
      .height(36)
      .opacity(this.opacity)
      .scale({ x: this.scale, y: this.scale })
      .animation({ duration: Duration.Fast, curve: Curve.EaseOut })
      .onClick(() => this.onClick())
    }
  }
}
