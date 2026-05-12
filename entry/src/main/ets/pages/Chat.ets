/**
 * Chat - 聊天页面
 * 
 * 鸿蒙规范设计：
 * - SSE 流式消息接收
 * - 打字机效果展示
 * - 新消息提示
 * - 自适应消息气泡
 */

import { Message, ChatSession } from '../models/Message';
import { ChatService, StreamCallbacks, SSEConnectionState } from '../services/ChatService';
import { HistoryService } from '../services/HistoryService';
import { ChatMarkdownRenderer } from '../components/MarkdownRenderer';
import { ChatBubble, StreamingChatBubble } from '../components/chat/ChatBubble';
import { SimpleNewMessageToast, ScrollToBottomButton } from '../components/chat/NewMessageToast';
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
  ComponentSizes,
  Duration
} from '../constants/design-tokens';
import { promptAction } from '@kit.ArkUI';

const WARNING_STORAGE_KEY = 'chat_warning_dismissed';
const WARNING_MESSAGE = '当前对话记录仅保存在本地，关闭页面后自动清除';

@Component
export struct ChatPage {
  @State messageList: Message[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State currentSessionId: string = '';
  @State showWarningBanner: boolean = false;
  
  // 流式消息相关
  @State streamingContent: string = '';
  @State isStreaming: boolean = false;
  @State streamingMessageId: string = '';
  
  // 新消息提示相关
  @State showNewMessageToast: boolean = false;
  @State newMessageCount: number = 0;
  @State isAtBottom: boolean = true;
  @State unreadCount: number = 0;
  
  // 滚动相关
  private scroller: Scroller = new Scroller();
  private chatService: ChatService = ChatService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private cancelStream: (() => void) | null = null;
  private scrollCheckTimer: number = -1;

  aboutToAppear() {
    this.loadHistory();
    this.checkAndShowWarning();
    this.startScrollCheck();
  }

  aboutToDisappear() {
    this.stopScrollCheck();
    if (this.cancelStream) {
      this.cancelStream();
    }
  }

  onPageHide() {
    if (this.messageList.length > 0) {
      promptAction.showToast({
        message: '对话记录将在关闭后自动清除',
        duration: 2000
      });
    }
  }

  /**
   * 开始滚动位置检测
   */
  private startScrollCheck() {
    this.scrollCheckTimer = setInterval(() => {
      // 检测是否在底部
      // 注意：实际项目中需要使用 onScroll 回调来更新 isAtBottom
    }, 500);
  }

  /**
   * 停止滚动位置检测
   */
  private stopScrollCheck() {
    if (this.scrollCheckTimer !== -1) {
      clearInterval(this.scrollCheckTimer);
      this.scrollCheckTimer = -1;
    }
  }

  checkAndShowWarning() {
    const dismissed = AppStorage.get<string>(WARNING_STORAGE_KEY);
    if (dismissed !== 'true') {
      this.showWarningDialog();
    }
  }

  showWarningDialog() {
    promptAction.showDialog({
      title: '提示',
      message: WARNING_MESSAGE,
      buttons: [
        {
          text: '不再提示',
          color: BrandColors.Brand500
        },
        {
          text: '我知道了',
          color: SemanticColors.Text2
        }
      ]
    }).then((result) => {
      if (result.index === 0) {
        AppStorage.setOrCreate(WARNING_STORAGE_KEY, 'true');
      }
    }).catch((err) => {
      console.error('Show warning dialog failed:', err);
    });
  }

  async loadHistory() {
    const historyStr = AppStorage.get<string>('chatHistory');
    if (historyStr) {
      try {
        this.messageList = JSON.parse(historyStr);
        if (this.messageList.length > 0) {
          this.currentSessionId = this.messageList[0].id;
        }
      } catch (e) {
        console.error('Parse chat history failed:', e);
      }
    }
  }

  /**
   * 发送消息（流式）
   */
  async sendMessage() {
    if (!this.inputText.trim() || this.isLoading || this.isStreaming) {
      return;
    }

    const userMessage: Message = {
      id: Date.now().toString() + '_' + Math.random().toString(36).substring(2, 9),
      role: 'user',
      content: this.inputText.trim(),
      timestamp: Date.now(),
      status: 'sent'
    };

    this.messageList.push(userMessage);
    const originalText = this.inputText;
    this.inputText = '';
    this.isLoading = true;

    // 滚动到底部
    this.scrollToBottom();

    try {
      // 准备流式消息占位
      this.streamingMessageId = Date.now().toString() + '_' + Math.random().toString(36).substring(2, 9);
      this.streamingContent = '';
      this.isStreaming = true;

      // 定义流式回调
      const callbacks: StreamCallbacks = {
        onMessage: (content: string, done: boolean) => {
          this.streamingContent = content;
          if (done) {
            this.finalizeStreamingMessage(content);
          } else {
            // 流式输出过程中滚动到底部
            this.scrollToBottom();
          }
        },
        onError: (error: string) => {
          console.error('[Chat] Stream error:', error);
          this.finalizeStreamingMessage('抱歉，服务暂时不可用，请稍后重试。', 'error');
          promptAction.showToast({
            message: error,
            duration: 2000
          });
        },
        onComplete: (fullContent: string) => {
          this.finalizeStreamingMessage(fullContent);
        },
        onConnectionStateChange: (state: SSEConnectionState) => {
          console.log('[Chat] Connection state:', state);
          if (state === 'error') {
            promptAction.showToast({
              message: '连接出现问题，正在重试...',
              duration: 2000
            });
          }
        }
      };

      // 尝试使用真实 SSE 流式接口
      // 如果后端不支持，则使用模拟流式输出
      try {
        this.cancelStream = await this.chatService.sendMessageStream(originalText, callbacks);
      } catch (e) {
        // SSE 不可用，使用模拟流式输出
        console.log('[Chat] SSE not available, using simulated stream');
        await this.chatService.simulateStreamOutput(originalText, callbacks, 40);
      }

    } catch (error) {
      console.error('[Chat] Send message failed:', error);
      this.finalizeStreamingMessage('抱歉，发送失败，请稍后重试。', 'error');
    }
  }

  /**
   * 完成流式消息
   */
  private finalizeStreamingMessage(content: string, status: 'sent' | 'error' = 'sent') {
    const assistantMessage: Message = {
      id: this.streamingMessageId || Date.now().toString(),
      role: 'assistant',
      content: content,
      timestamp: Date.now(),
      status: status
    };

    this.messageList.push(assistantMessage);
    this.saveHistory();

    // 保存对话到历史记录
    const userMessage = this.messageList[this.messageList.length - 2];
    if (userMessage && userMessage.role === 'user') {
      this.saveToHistory(userMessage.content, content);
    }

    // 重置流式状态
    this.isStreaming = false;
    this.streamingContent = '';
    this.streamingMessageId = '';
    this.isLoading = false;
    this.cancelStream = null;

    // 滚动到底部
    this.scrollToBottom();
  }

  /**
   * 滚动到底部
   */
  private scrollToBottom() {
    setTimeout(() => {
      if (this.messageList.length > 0) {
        this.scroller.scrollToIndex(this.messageList.length - 1);
      }
    }, 50);
  }

  /**
   * 处理新消息到达（用户不在底部时）
   */
  private onNewMessageArrived() {
    if (!this.isAtBottom) {
      this.newMessageCount++;
      this.unreadCount++;
      this.showNewMessageToast = true;
    }
  }

  /**
   * 点击新消息提示，滚动到底部
   */
  private onNewMessageToastClick() {
    this.scrollToBottom();
    this.showNewMessageToast = false;
    this.newMessageCount = 0;
    this.unreadCount = 0;
    this.isAtBottom = true;
  }

  /**
   * 保存对话到历史记录
   */
  private async saveToHistory(userContent: string, assistantContent: string): Promise<void> {
    if (this.messageList.length <= 2) {
      await this.historyService.addHistory({
        type: 'chat',
        title: `AI对话 - ${userContent.substring(0, 20)}${userContent.length > 20 ? '...' : ''}`,
        content: assistantContent.substring(0, 50) + (assistantContent.length > 50 ? '...' : ''),
        metadata: {
          userQuestion: userContent,
          messageCount: this.messageList.length
        }
      });
    }
  }

  saveHistory() {
    AppStorage.setOrCreate('chatHistory', JSON.stringify(this.messageList));
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 标题栏
        this.TitleBar()

        // 消息列表
        if (this.messageList.length === 0 && !this.isStreaming) {
          this.EmptyState()
        } else {
          this.MessageList()
        }

        // 加载指示器（非流式时显示）
        if (this.isLoading && !this.isStreaming) {
          this.LoadingIndicator()
        }

        // 输入区域
        this.InputArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(NeutralColors.Neutral50)

      // 新消息提示 Toast
      if (this.showNewMessageToast) {
        Column() {
          Blank()
            .layoutWeight(1)

          SimpleNewMessageToast({
            isVisible: this.showNewMessageToast,
            messageCount: this.newMessageCount,
            onScrollToBottom: () => this.onNewMessageToastClick()
          })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 120 })
      }

      // 滚动到底部按钮
      if (!this.isAtBottom && !this.showNewMessageToast) {
        Column() {
          Blank()
            .layoutWeight(1)

          Row() {
            Blank()
              .layoutWeight(1)

            ScrollToBottomButton({
              isVisible: !this.isAtBottom,
              unreadCount: this.unreadCount,
              onClick: () => this.onNewMessageToastClick()
            })
          }
          .width('100%')
          .padding({ right: SemanticSpacing.Lg, bottom: 120 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 标题栏
   */
  @Builder
  TitleBar() {
    Row() {
      Text('一职搭子')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
    }
    .width('100%')
    .height(56)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(NeutralColors.Neutral0)
    .justifyContent(FlexAlign.Center)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 空状态
   */
  @Builder
  EmptyState() {
    Column() {
      // 空状态图标
      Column() {
        Image($r('app.media.ic_chat'))
          .width(64)
          .height(64)
          .fillColor(BrandColors.Brand300)
      }
      .width(100)
      .height(100)
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(50)
      .justifyContent(FlexAlign.Center)

      Text('向我提问，获取求职建议')
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Lg })

      // 快捷问题建议
      Column({ space: Spacing.Space3 }) {
        ForEach([
          '如何优化我的简历？',
          '面试时如何自我介绍？',
          '如何谈薪资？'
        ], (question: string) => {
          Text(question)
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .padding({
              left: SemanticSpacing.Lg,
              right: SemanticSpacing.Lg,
              top: Spacing.Space3,
              bottom: Spacing.Space3
            })
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(SemanticRadius.Pill)
            .onClick(() => {
              this.inputText = question;
            })
        })
      }
      .margin({ top: SemanticSpacing.Xl })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 消息列表
   */
  @Builder
  MessageList() {
    List({ scroller: this.scroller }) {
      ForEach(this.messageList, (msg: Message, index: number) => {
        ListItem() {
          ChatBubble({
            message: msg,
            isStreaming: false,
            showTimestamp: true,
            showAvatar: msg.role === 'assistant',
            maxWidthPercent: 80
          })
        }
      })

      // 流式消息占位
      if (this.isStreaming && this.streamingContent) {
        ListItem() {
          StreamingChatBubble({
            content: this.streamingContent,
            isStreaming: true,
            timestamp: Date.now()
          })
        }
      }
    }
    .layoutWeight(1)
    .padding({
      left: SemanticSpacing.Lg,
      right: SemanticSpacing.Lg,
      top: SemanticSpacing.Md,
      bottom: SemanticSpacing.Md
    })
    .backgroundColor(NeutralColors.Neutral50)
    .edgeEffect(EdgeEffect.Spring)
    .onScroll(() => {
      // 滚动时更新位置状态
    })
    .onScrollEdge((edge: Edge) => {
      if (edge === Edge.Bottom) {
        this.isAtBottom = true;
        this.unreadCount = 0;
        this.showNewMessageToast = false;
      }
    })
  }

  /**
   * 加载指示器
   */
  @Builder
  LoadingIndicator() {
    Row() {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(BrandColors.Brand500)

      Text('AI 正在思考...')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .margin({ left: Spacing.Space3 })
    }
    .padding(SemanticSpacing.Md)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 输入区域
   */
  @Builder
  InputArea() {
    Row() {
      TextInput({ placeholder: '输入你的问题...', text: this.inputText })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(NeutralColors.Neutral0)
        .borderRadius(SemanticRadius.Pill)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .placeholderColor(SemanticColors.Text4)
        .placeholderFont({ size: FontSize.Sm })
        .fontColor(SemanticColors.Text1)
        .fontSize(FontSize.Sm)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .border({
          width: 1,
          color: NeutralColors.Neutral200
        })
        .enabled(!this.isStreaming)

      // 发送按钮
      Column() {
        if (this.isStreaming) {
          // 流式输出时显示停止按钮
          Image($r('app.media.ic_send'))
            .width(20)
            .height(20)
            .fillColor(NeutralColors.Neutral0)
        } else {
          Image($r('app.media.ic_send'))
            .width(20)
            .height(20)
            .fillColor(NeutralColors.Neutral0)
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(
        this.isStreaming
          ? ErrorColors.Error500
          : (this.inputText.trim() ? BrandColors.Brand500 : NeutralColors.Neutral300)
      )
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .margin({ left: Spacing.Space3 })
      .onClick(() => {
        if (this.isStreaming) {
          // 停止流式输出
          if (this.cancelStream) {
            this.cancelStream();
            this.finalizeStreamingMessage(this.streamingContent || '（已停止）');
          }
        } else {
          this.sendMessage();
        }
      })
      .enabled(this.isStreaming || (!this.isLoading && this.inputText.trim().length > 0))
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
    .backgroundColor(NeutralColors.Neutral0)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: -2
    })
  }
}

// 错误颜色（从 design-tokens 导入）
const ErrorColors = {
  Error500: '#E84026'
};
