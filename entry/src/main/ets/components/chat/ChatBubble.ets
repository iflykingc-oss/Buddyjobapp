/**
 * ChatBubble - 聊天气泡组件
 *
 * 鸿蒙规范设计：
 * - 根据内容长度自适应宽度
 * - 短消息：紧凑气泡
 * - 长消息：最大宽度 80%，超出换行
 * - 圆角遵循鸿蒙规范（12px 大圆角，4px 小圆角）
 * - 用户/AI 不同样式
 * - 时间戳显示
 * - 已读状态显示
 */

import { Message } from '../../models/Message';
import { ChatMarkdownRenderer } from '../MarkdownRenderer';
import { SimpleTypewriterText } from './TypewriterText';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  ErrorColors,
  DarkSemanticColors,
  FontSize,
  FontWeight,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  BorderRadius
} from '../../constants/design-tokens';

/**
 * 消息状态枚举
 */
export enum MessageStatus {
  SENDING = 'sending',
  SENT = 'sent',
  READ = 'read',
  ERROR = 'error'
}

/**
 * 聊天气泡组件
 */
@Component
export struct ChatBubble {
  /** 消息对象 */
  @Prop message: Message;
  /** 是否正在流式输出 */
  @Prop isStreaming: boolean = false;
  /** 是否显示时间戳 */
  @Prop showTimestamp: boolean = true;
  /** 是否显示头像 */
  @Prop showAvatar: boolean = true;
  /** 是否显示已读状态（仅用户消息） */
  @Prop showStatus: boolean = false;
  /** 最大宽度百分比 */
  @Prop maxWidthPercent: number = 80;
  /** 外部传入的时间戳字符串（可选） */
  @Prop timestamp: string = '';

  /** 存储键 */
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  /** 时间戳格式化缓存 */
  @State formattedTime: string = '';

  aboutToAppear() {
    // 如果外部没有传入时间戳，则格式化内部时间戳
    if (this.timestamp) {
      this.formattedTime = this.timestamp;
    } else {
      this.formattedTime = this.formatTime(this.message.timestamp);
    }
  }

  /**
   * 格式化时间戳
   */
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  /**
   * 计算气泡宽度
   * 根据内容长度自适应
   */
  private getBubbleWidth(): string | number {
    const contentLength = this.message.content.length;
    // 短消息（< 15字符）：紧凑气泡
    if (contentLength < 15) {
      return 'auto';
    }
    // 长消息：最大宽度百分比
    return `${this.maxWidthPercent}%`;
  }

  /**
   * 判断是否为短消息
   */
  private isShortMessage(): boolean {
    return this.message.content.length < 15 && !this.message.content.includes('\n');
  }

  /**
   * 获取消息状态文本
   */
  private getStatusText(): string {
    const status = this.message.status || 'sent';
    switch (status) {
      case MessageStatus.SENDING:
        return '发送中...';
      case MessageStatus.SENT:
        return '已发送';
      case MessageStatus.READ:
        return '已读';
      case MessageStatus.ERROR:
        return '发送失败';
      default:
        return '';
    }
  }

  /**
   * 获取消息状态图标颜色
   */
  private getStatusColor(): string {
    const status = this.message.status || 'sent';
    switch (status) {
      case MessageStatus.SENDING:
        return this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4;
      case MessageStatus.SENT:
        return this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4;
      case MessageStatus.READ:
        return BrandColors.Brand500;
      case MessageStatus.ERROR:
        return ErrorColors.Error500;
      default:
        return this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4;
    }
  }

  build() {
    if (this.message.role === 'user') {
      this.UserBubble();
    } else if (this.message.role === 'assistant') {
      this.AssistantBubble();
    } else {
      // 系统消息
      this.SystemBubble();
    }
  }

  /**
   * 用户消息气泡
   */
  @Builder
  UserBubble() {
    Row() {
      Blank()
        .layoutWeight(1)

      Column() {
        // 消息内容
        Text(this.message.content)
          .fontSize(FontSize.Sm)
          .fontColor(NeutralColors.Neutral0)
          .fontWeight(FontWeight.Normal)
          .lineHeight(22)
          .textOverflow({ overflow: TextOverflow.Clip })

        // 时间戳和状态行
        if (this.showTimestamp || this.showStatus) {
          Row() {
            // 时间戳
            if (this.showTimestamp) {
              Text(this.formattedTime)
                .fontSize(FontSize.Xs)
                .fontColor('rgba(255, 255, 255, 0.7)')
            }

            // 已读状态
            if (this.showStatus && this.message.status !== 'sending') {
              Row({ space: 2 }) {
                // 单勾/双勾图标表示状态
                Text(this.message.status === 'read' ? '✓✓' : '✓')
                  .fontSize(FontSize.Xs)
                  .fontColor('rgba(255, 255, 255, 0.7)')
              }
              .margin({ left: Spacing.Space2 })
            }

            // 发送中状态
            if (this.showStatus && this.message.status === 'sending') {
              Text('...')
                .fontSize(FontSize.Xs)
                .fontColor('rgba(255, 255, 255, 0.7)')
                .margin({ left: Spacing.Space2 })
            }
          }
          .margin({ top: Spacing.Space1 })
          .alignSelf(ItemAlign.End)
        }
      }
      .padding({
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        top: Spacing.Space4,
        bottom: Spacing.Space4
      })
      .backgroundColor(BrandColors.Brand500)
      .borderRadius({
        topLeft: SemanticRadius.Control,   // 8px
        topRight: BorderRadius.RadiusSm,  // 4px 小圆角
        bottomLeft: SemanticRadius.Control, // 8px
        bottomRight: SemanticRadius.Control // 8px
      })
      .constraintSize({ maxWidth: `${this.maxWidthPercent}%` })
      .alignItems(this.isShortMessage() ? HorizontalAlign.Center : HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
  }

  /**
   * AI 助手消息气泡
   */
  @Builder
  AssistantBubble() {
    Row() {
      Column() {
        // AI 头像和名称
        if (this.showAvatar) {
          Row() {
            Column() {
              Text('AI')
                .fontSize(FontSize.Xs)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
            }
            .width(28)
            .height(28)
            .backgroundColor(BrandColors.Brand400)
            .borderRadius(14)
            .justifyContent(FlexAlign.Center)

            Text('一职搭子')
              .fontSize(FontSize.Xs)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3 })
          }
          .margin({ bottom: Spacing.Space3 })
        }

        // 消息内容区域
        Column() {
          // 使用 Markdown 渲染器或打字机效果
          if (this.isStreaming) {
            // 流式输出时使用打字机效果
            ChatMarkdownRenderer({
              content: this.message.content,
              isStreaming: true
            })
          } else {
            // 正常显示使用 Markdown 渲染
            ChatMarkdownRenderer({
              content: this.message.content,
              isStreaming: false
            })
          }
        }
        .padding({
          left: SemanticSpacing.Lg,
          right: SemanticSpacing.Lg,
          top: Spacing.Space4,
          bottom: Spacing.Space4
        })
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : NeutralColors.Neutral0)
        .borderRadius({
          topLeft: BorderRadius.RadiusSm,    // 4px 小圆角
          topRight: SemanticRadius.Control,   // 8px
          bottomLeft: SemanticRadius.Control, // 8px
          bottomRight: SemanticRadius.Control // 8px
        })
        .constraintSize({ maxWidth: `${this.maxWidthPercent + 5}%` }) // AI 消息稍宽

        // 时间戳
        if (this.showTimestamp) {
          Text(this.formattedTime)
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            .margin({ top: Spacing.Space2 })
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
  }

  /**
   * 系统消息气泡
   */
  @Builder
  SystemBubble() {
    Row() {
      Blank()
        .layoutWeight(1)

      Column() {
        Text(this.message.content)
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .lineHeight(18)
      }
      .padding({
        left: Spacing.Space4,
        right: Spacing.Space4,
        top: Spacing.Space2,
        bottom: Spacing.Space2
      })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : NeutralColors.Neutral100)
      .borderRadius(SemanticRadius.Control)

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
  }
}

/**
 * 简化的聊天气泡组件
 * 用于不需要复杂功能的场景
 */
@Component
export struct SimpleChatBubble {
  @Prop message: Message;
  @Prop isStreaming: boolean = false;

  build() {
    ChatBubble({
      message: this.message,
      isStreaming: this.isStreaming,
      showTimestamp: true,
      showAvatar: true,
      maxWidthPercent: 80
    });
  }
}

/**
 * 流式消息气泡组件
 * 专为流式输出设计
 */
@Component
export struct StreamingChatBubble {
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @Prop timestamp: number = Date.now();

  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  @State formattedTime: string = '';

  aboutToAppear() {
    this.formattedTime = this.formatTime(this.timestamp);
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  build() {
    Row() {
      Column() {
        // AI 头像和名称
        Row() {
          Column() {
            Text('AI')
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
          }
          .width(28)
          .height(28)
          .backgroundColor(BrandColors.Brand400)
          .borderRadius(14)
          .justifyContent(FlexAlign.Center)

          Text('一职搭子')
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
            .margin({ left: Spacing.Space3 })

          // 正在输入指示器
          if (this.isStreaming) {
            Row({ space: 2 }) {
              ForEach([0, 1, 2], (index: number) => {
                Column()
                  .width(4)
                  .height(4)
                  .backgroundColor(BrandColors.Brand400)
                  .borderRadius(2)
              })
            }
            .margin({ left: Spacing.Space3 })
          }
        }
        .margin({ bottom: Spacing.Space3 })

        // 消息内容
        Column() {
          ChatMarkdownRenderer({
            content: this.content,
            isStreaming: this.isStreaming
          })
        }
        .padding({
          left: SemanticSpacing.Lg,
          right: SemanticSpacing.Lg,
          top: Spacing.Space4,
          bottom: Spacing.Space4
        })
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : NeutralColors.Neutral0)
        .borderRadius({
          topLeft: BorderRadius.RadiusSm,
          topRight: SemanticRadius.Control,
          bottomLeft: SemanticRadius.Control,
          bottomRight: SemanticRadius.Control
        })
        .constraintSize({ maxWidth: '85%' })

        // 时间戳
        Text(this.formattedTime)
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
          .margin({ top: Spacing.Space2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
  }
}
