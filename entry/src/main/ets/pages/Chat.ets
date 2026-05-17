/**
 * Chat - 聊天页面
 *
 * 鸿蒙规范设计：
 * - SSE 流式消息接收
 * - 打字机效果展示
 * - 新消息提示
 * - 自适应消息气泡
 * - 场景模式选择
 * - 消息操作（长按）
 * - 快速建议
 */

import { Message, ChatSession } from '../models/Message';
import { ChatService, StreamCallbacks, SSEConnectionState, ChatScene, SCENE_CONFIGS, SceneConfig } from '../services/ChatService';
import { HistoryService } from '../services/HistoryService';
import { ChatMarkdownRenderer } from '../components/MarkdownRenderer';
import { ChatBubble, StreamingChatBubble } from '../components/chat/ChatBubble';
import { SimpleNewMessageToast, ScrollToBottomButton } from '../components/chat/NewMessageToast';
import { WindowUtil } from '../utils/WindowUtil';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes,
  Duration,
  DarkSemanticColors
} from '../constants/design-tokens';
import { promptAction, messageManager } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';

const WARNING_STORAGE_KEY = 'chat_warning_dismissed';
const WARNING_MESSAGE = '当前对话记录仅保存在本地，关闭页面后自动清除';

/**
 * 消息操作类型
 */
enum MessageActionType {
  COPY = 'copy',
  RESEND = 'resend',
  DELETE = 'delete'
}

/**
 * 消息列表数据源 - 用于LazyForEach
 */
class MessageDataSource implements IDataSource {
  private messages: Message[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.messages.length;
  }

  getData(index: number): Message {
    return this.messages[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  setData(messages: Message[]): void {
    this.messages = messages;
    this.notifyDataReload();
  }

  addMessage(message: Message): void {
    this.messages.push(message);
    this.notifyDataAdd(this.messages.length - 1);
  }

  deleteMessage(index: number): void {
    if (index >= 0 && index < this.messages.length) {
      this.messages.splice(index, 1);
      this.notifyDataDelete(index);
    }
  }

  getMessage(index: number): Message | undefined {
    return this.messages[index];
  }

  getMessages(): Message[] {
    return this.messages;
  }
}

@Component
export struct ChatPage {
  @State messageList: Message[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State currentSessionId: string = '';
  @State showWarningBanner: boolean = false;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;

  // 流式消息相关
  @State streamingContent: string = '';
  @State isStreaming: boolean = false;
  @State streamingMessageId: string = '';

  // 新消息提示相关
  @State showNewMessageToast: boolean = false;
  @State newMessageCount: number = 0;
  @State isAtBottom: boolean = true;
  @State unreadCount: number = 0;

  // 场景模式相关
  @State currentScene: ChatScene = ChatScene.GENERAL;
  @State showSceneSelector: boolean = false;

  // 快速建议相关
  @State showQuickSuggestions: boolean = true;

  // 打字指示器
  @State showTypingIndicator: boolean = false;

  // 滚动相关
  private scroller: Scroller = new Scroller();
  private chatService: ChatService = ChatService.getInstance();
  private memberService: MemberService = MemberService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private cancelStream: (() => void) | null = null;
  private messageDataSource: MessageDataSource = new MessageDataSource();

  // 所有场景配置
  private sceneConfigs: SceneConfig[] = [];

  aboutToAppear() {
    this.loadHistory();
    this.checkAndShowWarning();
    // 初始化场景
    this.currentScene = this.chatService.getScene();
    // 初始化场景配置列表（避免Object.values）
    this.sceneConfigs = this.chatService.getAllSceneConfigs();
  }

  aboutToDisappear() {
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
        this.messageDataSource.setData(this.messageList);
        if (this.messageList.length > 0) {
          this.currentSessionId = this.messageList[0].id;
        }
        // 如果有历史消息，隐藏快速建议
        if (this.messageList.length > 0) {
          this.showQuickSuggestions = false;
        }
      } catch (e) {
        console.error('Parse chat history failed:', e);
      }
    }
  }

  /**
   * 切换场景
   */
  onSceneChange(scene: ChatScene) {
    if (this.currentScene === scene) {
      return;
    }
    this.currentScene = scene;
    this.chatService.setScene(scene);
    // 切换场景时显示新的快速建议
    this.showQuickSuggestions = true;
    // 清空当前对话
    this.messageList = [];
    this.messageDataSource.setData([]);
    this.saveHistory();
    promptAction.showToast({
      message: `已切换到${SCENE_CONFIGS[scene].nameCn}模式`,
      duration: 1500
    });
  }

  /**
   * 处理快速建议点击
   */
  onQuickSuggestionClick(suggestion: string) {
    this.inputText = suggestion;
    this.showQuickSuggestions = false;
    this.sendMessage();
  }

  /**
   * 获取当前场景的快速建议
   */
  getQuickSuggestions(): string[] {
    return SCENE_CONFIGS[this.currentScene].quickSuggestions;
  }

  /**
   * 发送消息（流式）
   */
  async sendMessage() {
    if (!this.inputText.trim() || this.isLoading || this.isStreaming) {
      return;
    }

    if (!this.memberService.isActiveMember()) {
      const usage = this.memberService.getDailyFreeUsage('chat');
      if (usage.used >= usage.limit) {
        promptAction.showToast({
          message: `每日免费对话已用完（${usage.limit}条），升级 VIP 解锁无限对话`,
          duration: 3000
        });
        router.pushUrl({ url: 'pages/Profile' });
        return;
      }
      this.memberService.incrementDailyUsage('chat');
    }

    // 隐藏快速建议
    this.showQuickSuggestions = false;

    const userMessage: Message = {
      id: Date.now().toString() + '_' + Math.random().toString(36).substring(2, 9),
      role: 'user',
      content: this.inputText.trim(),
      timestamp: Date.now(),
      status: 'sent'
    };

    this.messageList.push(userMessage);
    this.messageDataSource.setData([...this.messageList]);
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
          if (state === 'connecting') {
            this.showTypingIndicator = true;
          } else if (state === 'connected' || state === 'disconnected') {
            this.showTypingIndicator = false;
          }
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
    this.messageDataSource.setData([...this.messageList]);
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
    this.showTypingIndicator = false;
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

  /**
   * 长按消息处理
   */
  async onMessageLongPress(message: Message, index: number) {
    const isUserMessage = message.role === 'user';

    const buttons: Array<{
      text: string;
      color: string;
    }> = [
      {
        text: '复制',
        color: BrandColors.Brand500
      }
    ];

    if (isUserMessage) {
      buttons.push({
        text: '重新发送',
        color: SemanticColors.Text2
      });
    }

    buttons.push({
      text: '删除',
      color: ErrorColors.Error500
    });

    promptAction.showDialog({
      title: '消息操作',
      message: message.content.length > 50 ? message.content.substring(0, 50) + '...' : message.content,
      buttons: buttons
    }).then((result) => {
      const action = buttons[result.index].text;
      switch (action) {
        case '复制':
          this.copyMessage(message.content);
          break;
        case '重新发送':
          this.resendMessage(message, index);
          break;
        case '删除':
          this.deleteMessage(message.id, index);
          break;
      }
    }).catch((err) => {
      console.error('Message action dialog failed:', err);
    });
  }

  /**
   * 复制消息
   */
  private async copyMessage(content: string): Promise<void> {
    try {
      const pasteboardData = pasteboard.getSystemPasteboard();
      pasteboardData.setData(pasteboard.createPlainTextData(content));
      promptAction.showToast({
        message: '已复制到剪贴板',
        duration: 1500
      });
    } catch (e) {
      console.error('Copy failed:', e);
    }
  }

  /**
   * 重新发送消息
   */
  private async resendMessage(message: Message, index: number) {
    // 删除当前消息
    this.messageList = this.messageList.filter((_, i) => i !== index);
    this.messageDataSource.setData([...this.messageList]);
    this.saveHistory();

    // 设置输入文本并发送
    this.inputText = message.content;
    await this.sendMessage();
  }

  /**
   * 删除消息
   */
  private async deleteMessage(messageId: string, index: number) {
    // 从本地删除
    this.messageList = this.messageList.filter((_, i) => i !== index);
    this.messageDataSource.setData([...this.messageList]);
    this.saveHistory();

    // 从服务器撤回
    await this.chatService.recallMessage(messageId);

    promptAction.showToast({
      message: '消息已删除',
      duration: 1500
    });
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 标题栏
        this.TitleBar()

        // 场景选择器
        this.SceneSelector()

        // 消息列表和输入区域（宽屏最大宽度限制）
        Column() {
          // 消息列表
          if (this.messageList.length === 0 && !this.isStreaming) {
            this.EmptyState()
          } else {
            this.MessageList()
          }

          // 打字指示器
          if (this.showTypingIndicator) {
            this.TypingIndicator()
          }

          // 加载指示器（非流式时显示）
          if (this.isLoading && !this.isStreaming) {
            this.LoadingIndicator()
          }

          // 输入区域
          this.InputArea()
        }
        .layoutWeight(1)
        .constraintSize({ maxWidth: 800 })
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)

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
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

      Blank()
        .layoutWeight(1)

      // 场景指示器
      Text(SCENE_CONFIGS[this.currentScene].nameCn)
        .fontSize(FontSize.Xs)
        .fontColor(BrandColors.Brand500)
        .padding({
          left: Spacing.Space2,
          right: Spacing.Space2,
          top: Spacing.Space1,
          bottom: Spacing.Space1
        })
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(SemanticRadius.Pill)
    }
    .width('100%')
    .height(56)
    .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .justifyContent(FlexAlign.Center)
    .shadow({
      radius: 8,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 场景选择器
   */
  @Builder
  SceneSelector() {
    Scroll() {
      Row({ space: Spacing.Space2 }) {
        ForEach(this.sceneConfigs, (config) => {
          // 场景芯片
          Column() {
            Text(config.nameCn)
              .fontSize(FontSize.Sm)
              .fontWeight(this.currentScene === config.id ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.currentScene === config.id ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
          }
          .padding({
            left: SemanticSpacing.Md,
            right: SemanticSpacing.Md,
            top: Spacing.Space2,
            bottom: Spacing.Space2
          })
          .backgroundColor(this.currentScene === config.id ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1))
          .borderRadius(SemanticRadius.Pill)
          .border({
            width: 1,
            color: this.currentScene === config.id ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
          })
          .onClick(() => {
            this.onSceneChange(config.id);
          })
        })
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height(48)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 打字指示器
   */
  @Builder
  TypingIndicator() {
    Row() {
      // 三个跳动的点
      Row({ space: 4 }) {
        ForEach([0, 1, 2], (index: number) => {
          Column()
            .width(8)
            .height(8)
            .backgroundColor(BrandColors.Brand400)
            .borderRadius(4)
        })
      }
      .margin({ left: Spacing.Space2 })

      Text('AI正在输入...')
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ left: Spacing.Space2 })
    }
    .padding(SemanticSpacing.Md)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
  }

  /**
   * 空状态
   */
  @Builder
  EmptyState() {
    Column() {
      // 空状态图标
      Column() {
        Image($r('app.media.media_ic_chat'))
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
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Lg })

      // 快速建议
      if (this.showQuickSuggestions) {
        this.QuickSuggestions()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 快速建议
   */
  @Builder
  QuickSuggestions() {
    Column({ space: Spacing.Space3 }) {
      ForEach(this.getQuickSuggestions(), (suggestion: string) => {
        Text(suggestion)
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
          .constraintSize({ minHeight: 40 })
          .onClick(() => {
            this.onQuickSuggestionClick(suggestion);
          })
      })
    }
    .margin({ top: SemanticSpacing.Xl })
  }

  /**
   * 消息列表
   */
  @Builder
  MessageList() {
    List({ scroller: this.scroller }) {
      LazyForEach(this.messageDataSource, (msg: Message, index: number) => {
        ListItem() {
          ChatBubble({
            message: msg,
            isStreaming: false,
            showTimestamp: true,
            showAvatar: msg.role === 'assistant',
            showStatus: msg.role === 'user',
            timestamp: this.formatTime(msg.timestamp),
            maxWidthPercent: 80
          })
          .onLongPress(() => {
            this.onMessageLongPress(msg, index);
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
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
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
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ left: Spacing.Space3 })
    }
    .padding(SemanticSpacing.Md)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
    .shadow({
      radius: 8,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
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
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Pill)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .placeholderColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
        .placeholderFont({ size: FontSize.Sm })
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .fontSize(FontSize.Sm)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .border({
          width: 1,
          color: this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200
        })
        .enabled(!this.isStreaming)

      // 发送按钮
      Column() {
        if (this.isStreaming) {
          // 流式输出时显示停止按钮
          Image($r('app.media.media_ic_stop'))
            .width(20)
            .height(20)
            .fillColor(NeutralColors.Neutral0)
        } else {
          Image($r('app.media.media_ic_send'))
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
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: (AppStorage.get<number>('bottomSafeArea') || 0) + Spacing.Space4 })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .shadow({
      radius: 16,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.20)' : 'rgba(0, 0, 0, 0.04)',
      offsetY: -2
    })
  }
}
