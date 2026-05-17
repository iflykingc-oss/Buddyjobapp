import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { ChatService, ChatMessage, MessageRole } from '../services/ChatService';
import { MemberService } from '../services/MemberService';

@Entry
@Component
struct Chat {
  private chatService: ChatService = ChatService.getInstance();
  private memberService: MemberService = MemberService.getInstance();
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State currentSessionId: string = '';
  @State showSessionList: boolean = false;

  aboutToAppear() {
    this.chatService.loadPersistedSessions();
    const session = this.chatService.getCurrentSession();
    if (session) {
      this.currentSessionId = session.sessionId;
      this.messages = this.chatService.getMessages();
    } else {
      this.currentSessionId = this.chatService.createSession();
      this.messages = [];
    }
  }

  async sendMessage() {
    if (!this.inputText.trim() || this.isLoading) return;

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

    const text = this.inputText.trim();
    this.inputText = '';
    this.isLoading = true;

    try {
      await this.chatService.sendMessage(text, (chunk: string) => {
        this.messages = [...this.chatService.getMessages()];
      });
      this.messages = [...this.chatService.getMessages()];
    } catch (error) {
      promptAction.showToast({ message: '发送失败，请稍后重试', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('AI 职业顾问')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .flexGrow(1)
        Button('新对话')
          .onClick(() => {
            this.currentSessionId = this.chatService.createSession();
            this.messages = [];
          })
      }
      .padding(16)
      .width('100%')

      List() {
        ForEach(this.messages.filter(m => m.role !== MessageRole.SYSTEM), (msg: ChatMessage) => {
          ListItem() {
            Row() {
              if (msg.role === MessageRole.USER) {
                Blank()
                Text(msg.content)
                  .backgroundColor('#007AFF')
                  .fontColor(Color.White)
                  .padding(12)
                  .borderRadius(12)
                  .maxWidth('75%')
              } else {
                Text(msg.isStreaming ? msg.content + '▌' : msg.content)
                  .backgroundColor('#F0F0F0')
                  .padding(12)
                  .borderRadius(12)
                  .maxWidth('75%')
                Blank()
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
          }
        })
      }
      .layoutWeight(1)

      Row() {
        TextInput({ text: this.inputText, placeholder: '输入消息...' })
          .onChange((val: string) => { this.inputText = val; })
          .layoutWeight(1)
        Button(this.isLoading ? '...' : '发送')
          .onClick(() => { this.sendMessage(); })
          .enabled(!this.isLoading)
      }
      .padding(12)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}
