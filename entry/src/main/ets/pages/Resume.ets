import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { ResumeOptimizationService, ResumeAnalysisResult } from '../services/ResumeOptimizationService';
import { MemberService } from '../services/MemberService';

@Entry
@Component
struct Resume {
  private resumeService: ResumeOptimizationService = ResumeOptimizationService.getInstance();
  private memberService: MemberService = MemberService.getInstance();
  @State isLoading: boolean = false;
  @State result: ResumeAnalysisResult | null = null;
  @State errorMsg: string = '';

  async selectAndUploadResume() {
    if (!this.memberService.isActiveMember()) {
      const usage = this.memberService.getDailyFreeUsage('resume');
      if (usage.used >= usage.limit) {
        promptAction.showToast({
          message: `每日免费简历优化已用完（${usage.limit}次），升级 VIP 解锁无限次`,
          duration: 3000
        });
        router.pushUrl({ url: 'pages/Profile' });
        return;
      }
      this.memberService.incrementDailyUsage('resume');
    }

    this.isLoading = true;
    this.errorMsg = '';
    try {
      const fileUri = await this.resumeService.selectResumeFile();
      const analysisResult = await this.resumeService.analyzeResume(fileUri);
      this.result = analysisResult;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.errorMsg = errMsg;
      promptAction.showToast({ message: errMsg, duration: 3000 });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Text('简历优化').fontSize(24).fontWeight(FontWeight.Bold).padding(20)

      if (this.result) {
        Column() {
          Text(`综合评分: ${this.result.overallScore}`).fontSize(18)
          Text(`ATS 兼容性: ${this.result.atsScore}`).fontSize(16).margin({ top: 8 })
          Text(`关键词匹配: ${this.result.keywordMatch}%`).fontSize(16).margin({ top: 8 })
          ForEach(this.result.suggestions, (s: string) => {
            Text(`• ${s}`).fontSize(14).margin({ top: 6 })
          })
        }
        .padding(16)
      } else if (this.errorMsg) {
        Text(this.errorMsg).fontColor(Color.Red).padding(16)
      }

      Button(this.isLoading ? '分析中...' : '选择简历文件')
        .onClick(() => { this.selectAndUploadResume(); })
        .enabled(!this.isLoading)
        .margin(20)

      if (this.isLoading) {
        LoadingProgress().width(40).height(40)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
