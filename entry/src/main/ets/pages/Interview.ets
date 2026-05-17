import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { InterviewService, InterviewSession } from '../services/InterviewService';
import { MemberService } from '../services/MemberService';

@Entry
@Component
struct Interview {
  private interviewService: InterviewService = InterviewService.getInstance();
  private memberService: MemberService = MemberService.getInstance();
  @State currentSession: InterviewSession | null = null;
  @State isLoading: boolean = false;
  @State answer: string = '';

  async startInterview(jobTitle: string, level: string) {
    if (!this.memberService.isActiveMember()) {
      const usage = this.memberService.getDailyFreeUsage('interview');
      if (usage.used >= usage.limit) {
        promptAction.showToast({
          message: `每日免费面试已用完（${usage.limit}次），升级 VIP 解锁无限面试`,
          duration: 3000
        });
        router.pushUrl({ url: 'pages/Profile' });
        return;
      }
      this.memberService.incrementDailyUsage('interview');
    }

    this.isLoading = true;
    try {
      this.currentSession = await this.interviewService.startSession(jobTitle, level);
    } catch (error) {
      promptAction.showToast({ message: '无法启动面试，请稍后重试', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  async submitAnswer() {
    if (!this.answer.trim() || !this.currentSession || this.isLoading) return;
    this.isLoading = true;
    try {
      const answer = this.answer.trim();
      this.answer = '';
      await this.interviewService.submitAnswer(this.currentSession.sessionId, answer);
      this.currentSession = await this.interviewService.getSession(this.currentSession.sessionId);
    } catch (error) {
      promptAction.showToast({ message: '提交失败，请稍后重试', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (!this.currentSession) {
        Column() {
          Text('AI 模拟面试').fontSize(24).fontWeight(FontWeight.Bold)
          Button('开始面试（前端工程师 · 初级）')
            .onClick(() => { this.startInterview('前端工程师', '初级'); })
            .margin(20)
          if (this.isLoading) {
            LoadingProgress().width(40).height(40)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text(`问题：${this.currentSession.currentQuestion}`)
            .fontSize(16)
            .padding(16)
          TextArea({ text: this.answer, placeholder: '输入你的回答...' })
            .onChange((val: string) => { this.answer = val; })
            .height(150)
            .margin(16)
          Button(this.isLoading ? '评估中...' : '提交回答')
            .onClick(() => { this.submitAnswer(); })
            .enabled(!this.isLoading)
            .margin(16)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
