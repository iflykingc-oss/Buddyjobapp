/**
 * TypewriterText - 打字机效果文本组件
 * 
 * 鸿蒙规范设计：
 * - 逐字显示配合光标闪烁
 * - 每个字符间隔 30-50ms
 * - 光标使用动画闪烁（opacity 0↔1）
 * - 支持暂停/继续
 */

import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  FontSize,
  FontWeight,
  Spacing,
  SemanticSpacing,
  Duration
} from '../../constants/design-tokens';

/**
 * 打字机效果文本组件
 */
@Component
export struct TypewriterText {
  /** 完整文本内容 */
  @Prop fullText: string = '';
  /** 是否正在流式输出 */
  @Prop isStreaming: boolean = false;
  /** 字符显示间隔（毫秒） */
  @Prop charInterval: number = 40;
  /** 字体大小 */
  @Prop fontSize: number = FontSize.Sm;
  /** 字体颜色 */
  @Prop fontColor: string = SemanticColors.Text1;
  /** 行高 */
  @Prop lineHeight: number = 22;
  /** 最大宽度 */
  @Prop maxWidth: string | number = '100%';
  
  /** 当前显示的文本 */
  @State displayText: string = '';
  /** 光标是否可见 */
  @State cursorVisible: boolean = true;
  /** 是否暂停 */
  @State isPaused: boolean = false;
  /** 当前字符索引 */
  private currentIndex: number = 0;
  /** 打字机定时器 */
  private typewriterTimer: number = -1;
  /** 光标闪烁定时器 */
  private cursorTimer: number = -1;

  aboutToAppear() {
    this.startTypewriter();
    this.startCursorBlink();
  }

  aboutToUpdate() {
    // 当 fullText 变化时，更新显示文本
    if (this.isStreaming && this.fullText.length > this.displayText.length) {
      // 流式模式下，新内容追加显示
      this.displayText = this.fullText;
    } else if (!this.isStreaming && this.fullText !== this.displayText) {
      // 非流式模式，重新开始打字机效果
      this.resetAndStart();
    }
  }

  aboutToDisappear() {
    this.clearTimers();
  }

  /**
   * 重置并开始打字机效果
   */
  private resetAndStart() {
    this.clearTimers();
    this.currentIndex = 0;
    this.displayText = '';
    this.startTypewriter();
    this.startCursorBlink();
  }

  /**
   * 开始打字机效果
   */
  private startTypewriter() {
    if (this.isStreaming) {
      // 流式模式：直接显示全部内容
      this.displayText = this.fullText;
      return;
    }

    // 非流式模式：逐字显示
    if (this.currentIndex < this.fullText.length) {
      this.typewriterTimer = setInterval(() => {
        if (this.isPaused) {
          return;
        }

        if (this.currentIndex < this.fullText.length) {
          this.displayText += this.fullText[this.currentIndex];
          this.currentIndex++;
        } else {
          // 打字完成
          clearInterval(this.typewriterTimer);
          this.typewriterTimer = -1;
        }
      }, this.charInterval);
    }
  }

  /**
   * 开始光标闪烁动画
   */
  private startCursorBlink() {
    this.cursorTimer = setInterval(() => {
      this.cursorVisible = !this.cursorVisible;
    }, 530); // 530ms 闪烁周期，接近鸿蒙规范
  }

  /**
   * 清除所有定时器
   */
  private clearTimers() {
    if (this.typewriterTimer !== -1) {
      clearInterval(this.typewriterTimer);
      this.typewriterTimer = -1;
    }
    if (this.cursorTimer !== -1) {
      clearInterval(this.cursorTimer);
      this.cursorTimer = -1;
    }
  }

  /**
   * 暂停打字机效果
   */
  pause() {
    this.isPaused = true;
  }

  /**
   * 继续打字机效果
   */
  resume() {
    this.isPaused = false;
  }

  /**
   * 立即显示全部内容
   */
  showAll() {
    this.clearTimers();
    this.displayText = this.fullText;
    this.currentIndex = this.fullText.length;
  }

  build() {
    Row() {
      // 文本内容
      Text(this.displayText)
        .fontSize(this.fontSize)
        .fontColor(this.fontColor)
        .fontWeight(FontWeight.Normal)
        .lineHeight(this.lineHeight)
        .layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Clip })

      // 光标（仅在流式输出或打字过程中显示）
      if (this.isStreaming || this.currentIndex < this.fullText.length) {
        Text('|')
          .fontSize(this.fontSize)
          .fontColor(this.cursorVisible ? BrandColors.Brand500 : 'transparent')
          .fontWeight(FontWeight.Normal)
          .lineHeight(this.lineHeight)
          .opacity(this.cursorVisible ? 1 : 0)
          .animation({
            duration: 200,
            curve: Curve.EaseInOut
          })
          .margin({ left: 1 })
      }
    }
    .width(this.maxWidth)
    .alignItems(VerticalAlign.Top)
  }
}

/**
 * 打字机效果控制器
 * 用于外部控制打字机效果的状态
 */
export class TypewriterController {
  private component: TypewriterText | null = null;

  bind(component: TypewriterText) {
    this.component = component;
  }

  unbind() {
    this.component = null;
  }

  pause() {
    this.component?.pause();
  }

  resume() {
    this.component?.resume();
  }

  showAll() {
    this.component?.showAll();
  }
}

/**
 * 简化的打字机文本组件
 * 用于简单场景，不需要控制器
 */
@Component
export struct SimpleTypewriterText {
  @Prop text: string = '';
  @Prop isStreaming: boolean = false;
  @Prop fontSize: number = FontSize.Sm;
  @Prop fontColor: string = SemanticColors.Text1;
  @State cursorVisible: boolean = true;
  private cursorTimer: number = -1;

  aboutToAppear() {
    this.cursorTimer = setInterval(() => {
      this.cursorVisible = !this.cursorVisible;
    }, 530);
  }

  aboutToDisappear() {
    if (this.cursorTimer !== -1) {
      clearInterval(this.cursorTimer);
    }
  }

  build() {
    Row() {
      Text(this.text)
        .fontSize(this.fontSize)
        .fontColor(this.fontColor)
        .lineHeight(22)
        .layoutWeight(1)

      if (this.isStreaming) {
        Text('|')
          .fontSize(this.fontSize)
          .fontColor(this.cursorVisible ? BrandColors.Brand500 : 'transparent')
          .lineHeight(22)
          .opacity(this.cursorVisible ? 1 : 0)
          .animation({
            duration: 200,
            curve: Curve.EaseInOut
          })
          .margin({ left: 1 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
