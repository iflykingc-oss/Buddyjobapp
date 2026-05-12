import { Message, ChatSession } from '../models/Message';
import { ChatService } from '../services/ChatService';
import { ChatBubble } from '../components/ChatBubble';
import { ChatInput } from '../components/ChatInput';
import { ChatMarkdownRenderer } from '../components/MarkdownRenderer';
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
  private scroller: Scroller = new Scroller();
  private chatService: ChatService = ChatService.getInstance();

  aboutToAppear() {
    this.loadHistory();
    this.checkAndShowWarning();
  }

  onPageHide() {
    // 页面隐藏时提示用户
    if (this.messageList.length > 0) {
      promptAction.showToast({
        message: '对话记录将在关闭后自动清除',
        duration: 2000
      });
    }
  }

  checkAndShowWarning() {
    // 检查用户是否已选择"不再提示"
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
        // 用户选择"不再提示"
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

  async sendMessage() {
    if (!this.inputText.trim() || this.isLoading) {
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
    setTimeout(() => {
      if (this.messageList.length > 0) {
        this.scroller.scrollToIndex(this.messageList.length - 1);
      }
    }, 100);

    try {
      const response = await this.chatService.sendMessage(userMessage.content);

      const assistantMessage: Message = {
        id: Date.now().toString() + '_' + Math.random().toString(36).substring(2, 9),
        role: 'assistant',
        content: response.content,
        timestamp: Date.now(),
        status: 'sent'
      };

      this.messageList.push(assistantMessage);
      this.saveHistory();
    } catch (error) {
      const errorMessage: Message = {
        id: Date.now().toString() + '_' + Math.random().toString(36).substring(2, 9),
        role: 'assistant',
        content: '抱歉，服务暂时不可用，请稍后重试。',
        timestamp: Date.now(),
        status: 'error'
      };
      this.messageList.push(errorMessage);
      this.saveHistory();
    } finally {
      this.isLoading = false;
    }
  }

  saveHistory() {
    AppStorage.setOrCreate('chatHistory', JSON.stringify(this.messageList));
  }

  build() {
    Column() {
      // 标题栏
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

      // 消息列表
      if (this.messageList.length === 0) {
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
                .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
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
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.messageList, (msg: Message) => {
            ListItem() {
              this.MessageBubble(msg)
            }
            .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
          })
        }
        .layoutWeight(1)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Md, bottom: SemanticSpacing.Md })
        .backgroundColor(NeutralColors.Neutral50)
        .edgeEffect(EdgeEffect.Spring)
      }

      // 加载指示器
      if (this.isLoading) {
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

      // 输入区域
      this.InputArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  /**
   * 消息气泡组件
   */
  @Builder
  MessageBubble(msg: Message) {
    Row() {
      if (msg.role === 'user') {
        // 用户消息靠右
        Blank()

        Column() {
          Text(msg.content)
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .lineHeight(22)
        }
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
        .backgroundColor(BrandColors.Brand500)
        .borderRadius({
          topLeft: SemanticRadius.Control,
          topRight: SemanticRadius.Element,
          bottomLeft: SemanticRadius.Control,
          bottomRight: SemanticRadius.Control
        })
        .constraintSize({ maxWidth: '75%' })
      } else {
        // AI 消息靠左
        Column() {
          // AI 头像
          Row() {
            Column() {
              Text('AI')
                .fontSize(FontSize.Xs)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
            }
            .width(24)
            .height(24)
            .backgroundColor(BrandColors.Brand400)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)

            Text('一职搭子')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .margin({ left: Spacing.Space3 })
          }
          .margin({ bottom: Spacing.Space3 })

          // AI 消息内容 - 使用 MarkdownRenderer 渲染
          Column() {
            ChatMarkdownRenderer({
              content: msg.content,
              isStreaming: msg.status === 'sending'
            })
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius({
            topLeft: SemanticRadius.Element,
            topRight: SemanticRadius.Control,
            bottomLeft: SemanticRadius.Control,
            bottomRight: SemanticRadius.Control
          })
          .constraintSize({ maxWidth: '85%' })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
    }
    .width('100%')
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

      // 发送按钮
      Column() {
        Image($r('app.media.ic_send'))
          .width(20)
          .height(20)
          .fillColor(NeutralColors.Neutral0)
      }
      .width(44)
      .height(44)
      .backgroundColor(this.inputText.trim() ? BrandColors.Brand500 : NeutralColors.Neutral300)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .margin({ left: Spacing.Space3 })
      .onClick(() => {
        this.sendMessage();
      })
      .enabled(!this.isLoading && this.inputText.trim().length > 0)
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
