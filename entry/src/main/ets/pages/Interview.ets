/**
 * 模拟面试页面
 *
 * 全屏沉浸式面试界面，隐藏状态栏
 * 支持语音/文字输入切换
 * 遵循鸿蒙设计规范
 */
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Router } from '../utils/Router';
import {
  InterviewService,
  InterviewSession,
  InterviewQuestion,
  InterviewAnswer,
  InterviewFeedback,
  InterviewConfig
} from '../services/InterviewService';
import { VoiceInputButton } from '../components/interview/VoiceInputButton';
import { FeedbackSheet } from '../components/interview/FeedbackSheet';
import { StarGuide } from '../components/interview/StarGuide';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration,
  Shadows
} from '../constants/design-tokens';

// 页面状态
type PageState = 'config' | 'preparing' | 'interviewing' | 'feedback' | 'completed';

@Component
export struct InterviewPage {
  // 页面状态
  @State private pageState: PageState = 'config';
  @State private isLoading: boolean = false;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  // 面试配置
  @State private jobPosition: string = '';
  @State private questionCount: number = 5;
  @State private selectedCategories: string[] = ['self_intro', 'behavioral', 'technical', 'situational', 'salary'];

  // 面试会话
  @State private session: InterviewSession | null = null;
  @State private currentQuestion: InterviewQuestion | null = null;
  @State private currentAnswer: string = '';
  @State private currentFeedback: InterviewFeedback | null = null;

  // 录音状态
  @State private isRecording: boolean = false;
  @State private isProcessing: boolean = false;
  @State private recordingDuration: number = 0;

  // UI状态
  @State private showFeedbackSheet: boolean = false;
  @State private showExitConfirm: boolean = false;
  @State private showStarGuide: boolean = true;

  // 服务
  private interviewService: InterviewService = InterviewService.getInstance();

  // 录音时长计时器
  private durationTimer: number = -1;

  aboutToAppear() {
    // 检查是否有传入的配置
    const params = router.getParams() as Record<string, string>;
    if (params && params.jobPosition) {
      this.jobPosition = params.jobPosition;
    }
  }

  aboutToDisappear() {
    this.clearTimers();
  }

  /**
   * 系统返回拦截：面试进行中时弹出确认
   */
  onBackPress(): boolean {
    if (this.session && this.session.status === 'in_progress') {
      this.showExitConfirm = true;
      return true;
    }
    return false;
  }

  private clearTimers(): void {
    if (this.durationTimer !== -1) {
      clearInterval(this.durationTimer);
      this.durationTimer = -1;
    }
  }

  /**
   * 开始面试
   */
  private async startInterview(): Promise<void> {
    if (!this.jobPosition.trim()) {
      promptAction.showToast({ message: '请输入目标岗位' });
      return;
    }

    this.isLoading = true;
    this.pageState = 'preparing';

    try {
      const config: InterviewConfig = {
        jobPosition: this.jobPosition,
        questionCount: this.questionCount,
        categories: this.selectedCategories,
        difficulty: 'mixed'
      };

      this.session = await this.interviewService.createInterviewSession(config);
      this.session.status = 'in_progress';
      this.session.startTime = Date.now();
      this.currentQuestion = this.session.questions[0];
      this.pageState = 'interviewing';
    } catch (error) {
      console.error('[InterviewPage] Start interview failed:', error);
      promptAction.showToast({ message: '创建面试失败，请重试' });
      this.pageState = 'config';
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 提交回答
   */
  private async submitAnswer(): Promise<void> {
    if (!this.currentAnswer.trim() || !this.session || !this.currentQuestion) {
      promptAction.showToast({ message: '请先回答问题' });
      return;
    }

    this.isProcessing = true;

    try {
      const answer: InterviewAnswer = {
        questionId: this.currentQuestion.id,
        content: this.currentAnswer,
        timestamp: Date.now()
      };

      // 获取AI点评
      const feedback = await this.interviewService.submitAnswer(this.session.id, answer);

      // 更新会话
      this.session.answers.push(answer);
      this.session.feedbacks.push(feedback);
      this.currentFeedback = feedback;

      // 显示点评面板
      this.pageState = 'feedback';
      this.showFeedbackSheet = true;
    } catch (error) {
      console.error('[InterviewPage] Submit answer failed:', error);
      promptAction.showToast({ message: '提交失败，请重试' });
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * 下一题
   */
  private nextQuestion(): void {
    if (!this.session) return;

    this.showFeedbackSheet = false;
    this.currentAnswer = '';
    this.currentFeedback = null;

    if (this.session.currentQuestionIndex < this.session.questions.length - 1) {
      this.session.currentQuestionIndex++;
      this.currentQuestion = this.session.questions[this.session.currentQuestionIndex];
      this.pageState = 'interviewing';
    } else {
      // 面试完成
      this.completeInterview();
    }
  }

  /**
   * 完成面试
   */
  private async completeInterview(): Promise<void> {
    if (!this.session) return;

    this.isLoading = true;

    try {
      this.session = await this.interviewService.completeInterview(this.session);
      this.pageState = 'completed';
    } catch (error) {
      console.error('[InterviewPage] Complete interview failed:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 开始录音
   */
  private async handleStartRecording(): Promise<void> {
    const success = await this.interviewService.startRecording();
    if (success) {
      this.isRecording = true;
      this.recordingDuration = 0;

      // 开始计时
      this.durationTimer = setInterval(() => {
        this.recordingDuration++;
      }, 1000);
    }
  }

  /**
   * 停止录音
   */
  private async handleStopRecording(): Promise<void> {
    this.clearTimers();
    this.isRecording = false;

    const result = await this.interviewService.stopRecording();
    if (result) {
      this.isProcessing = true;

      // 语音识别
      const text = await this.interviewService.recognizeSpeech(result.path);
      if (text) {
        this.currentAnswer = text;
      }

      this.isProcessing = false;
    }
  }

  /**
   * 退出面试
   */
  private exitInterview(): void {
    if (this.pageState === 'interviewing' || this.pageState === 'feedback') {
      this.showExitConfirm = true;
    } else {
      router.back();
    }
  }

  build() {
    Stack() {
      // 沉浸式背景
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [
            [BrandColors.Brand600, 0],
            [BrandColors.Brand800, 0.5],
            [BrandColors.Brand950, 1]
          ]
        })

      // 内容层
      Column() {
        if (this.pageState === 'config') {
          this.ConfigView()
        } else if (this.pageState === 'preparing') {
          this.PreparingView()
        } else if (this.pageState === 'interviewing') {
          this.InterviewView()
        } else if (this.pageState === 'feedback') {
          this.InterviewView()
        } else if (this.pageState === 'completed') {
          this.CompletedView()
        }
      }
      .width('100%')
      .height('100%')

      // AI点评底部弹出面板
      if (this.showFeedbackSheet && this.currentFeedback) {
        this.FeedbackSheetOverlay()
      }

      // 退出确认对话框
      if (this.showExitConfirm) {
        this.ExitConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 配置视图
   */
  @Builder
  ConfigView() {
    Column() {
      // 顶部导航
      this.TopBar('模拟面试')

      // 配置内容
      Scroll() {
        Column() {
          // 标题
          Column() {
            Text('准备开始模拟面试')
              .fontSize(FontSize.Xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(NeutralColors.Neutral0)

            Text('AI面试官将根据您的目标岗位提出问题')
              .fontSize(FontSize.Base)
              .fontColor('rgba(255, 255, 255, 0.7)')
              .margin({ top: Spacing.Space3 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: Spacing.Space9 })

          // 目标岗位输入
          Column() {
            Text('目标岗位')
              .fontSize(FontSize.Sm)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .width('100%')
              .margin({ bottom: Spacing.Space2 })

            TextInput({ placeholder: '例如：产品经理', text: this.jobPosition })
              .width('100%')
              .height(48)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .borderRadius(SemanticRadius.Control)
              .placeholderColor('rgba(255, 255, 255, 0.5)')
              .fontColor(NeutralColors.Neutral0)
              .fontSize(FontSize.Base)
              .onChange((value: string) => {
                this.jobPosition = value;
              })
              .border({
                width: 1,
                color: 'rgba(255, 255, 255, 0.3)'
              })
          }
          .width('100%')
          .margin({ bottom: Spacing.Space7 })

          // 问题数量选择
          Column() {
            Text('问题数量')
              .fontSize(FontSize.Sm)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            Row() {
              ForEach([3, 5, 8, 10], (count: number) => {
                Column() {
                  Text(count.toString())
                    .fontSize(FontSize.Base)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.questionCount === count ? BrandColors.Brand500 : NeutralColors.Neutral0)
                }
                .width(60)
                .height(44)
                .backgroundColor(this.questionCount === count ? NeutralColors.Neutral0 : 'rgba(255, 255, 255, 0.15)')
                .borderRadius(SemanticRadius.Control)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.questionCount = count;
                })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .margin({ bottom: Spacing.Space7 })

          // 问题类型选择
          Column() {
            Text('问题类型')
              .fontSize(FontSize.Sm)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            Column({ space: Spacing.Space3 }) {
              this.CategoryItem('self_intro', '自我介绍', '考察基本素质和表达能力')
              this.CategoryItem('behavioral', '行为面试', '考察过往经历和软技能')
              this.CategoryItem('technical', '技术面试', '考察专业知识和技能')
              this.CategoryItem('situational', '情景面试', '考察问题解决能力')
              this.CategoryItem('salary', '薪资谈判', '考察谈判技巧和职业认知')
            }
          }
          .width('100%')
          .margin({ bottom: Spacing.Space9 })

          // 开始按钮
          Button() {
            Row() {
              if (this.isLoading) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color(BrandColors.Brand500)
              } else {
                Text('开始面试')
                  .fontSize(FontSize.Base)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(BrandColors.Brand500)
              }
            }
          }
          .width('100%')
          .height(52)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Pill)
          .enabled(!this.isLoading && this.jobPosition.trim().length > 0 && this.selectedCategories.length > 0)
          .onClick(() => this.startInterview())
        }
        .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 分类项
   */
  @Builder
  CategoryItem(key: string, title: string, description: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)

        Text(description)
          .fontSize(FontSize.Xs)
          .fontColor('rgba(255, 255, 255, 0.6)')
          .margin({ top: Spacing.Space1 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 选中状态
      Column() {
        if (this.selectedCategories.includes(key)) {
          Image($r('app.media.ic_check'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)
        }
      }
      .width(24)
      .height(24)
      .backgroundColor(this.selectedCategories.includes(key) ? NeutralColors.Neutral0 : 'transparent')
      .borderRadius(12)
      .border({
        width: 1,
        color: this.selectedCategories.includes(key) ? NeutralColors.Neutral0 : 'rgba(255, 255, 255, 0.5)'
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor('rgba(255, 255, 255, 0.1)')
    .borderRadius(SemanticRadius.Component)
    .onClick(() => {
      if (this.selectedCategories.includes(key)) {
        this.selectedCategories = this.selectedCategories.filter(c => c !== key);
      } else {
        this.selectedCategories.push(key);
      }
    })
  }

  /**
   * 准备中视图
   */
  @Builder
  PreparingView() {
    Column() {
      this.TopBar('准备中')

      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color(NeutralColors.Neutral0)

        Text('正在生成面试问题...')
          .fontSize(FontSize.Base)
          .fontColor('rgba(255, 255, 255, 0.8)')
          .margin({ top: Spacing.Space7 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 面试视图
   */
  @Builder
  InterviewView() {
    Column() {
      // 顶部导航
      Row() {
        // 返回按钮
        Column() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor(NeutralColors.Neutral0)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(255, 255, 255, 0.2)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.exitInterview())

        Blank()

        // 进度指示
        if (this.session) {
          Text(`${this.session.currentQuestionIndex + 1}/${this.session.questions.length}`)
            .fontSize(FontSize.Sm)
            .fontColor('rgba(255, 255, 255, 0.8)')
        }

        Blank()

        // STAR引导开关
        Column() {
          Text('STAR')
            .fontSize(FontSize.Xs)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.showStarGuide ? BrandColors.Brand500 : 'rgba(255, 255, 255, 0.6)')
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.showStarGuide ? NeutralColors.Neutral0 : 'rgba(255, 255, 255, 0.2)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showStarGuide = !this.showStarGuide;
        })
      }
      .width('100%')
      .padding({
        top: (AppStorage.get<number>('topSafeArea') || 0) + Spacing.Space4,
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        bottom: Spacing.Space4
      })

      // 进度条
      if (this.session) {
        Stack() {
          Row()
            .width('100%')
            .height(3)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(1.5)

          Row()
            .width(`${((this.session.currentQuestionIndex + 1) / this.session.questions.length) * 100}%`)
            .height(3)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(1.5)
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }

      // 面试内容区域
      Stack() {
        // 主内容
        Column() {
          // AI面试官头像和问题
          Column() {
            // AI头像
            Column() {
              Image($r('app.media.ic_ai'))
                .width(48)
                .height(48)
                .fillColor(NeutralColors.Neutral0)
            }
            .width(80)
            .height(80)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(40)
            .justifyContent(FlexAlign.Center)

            // 问题卡片
            Column() {
              // 问题类型标签
              Row() {
                Text(this.getCategoryLabel(this.currentQuestion?.category || ''))
                  .fontSize(FontSize.Xs)
                  .fontColor(BrandColors.Brand500)
                  .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space1, bottom: Spacing.Space1 })
                  .backgroundColor(BrandColors.Brand50)
                  .borderRadius(SemanticRadius.Pill)

                Blank()

                Text(this.getDifficultyLabel(this.currentQuestion?.difficulty || 'medium'))
                  .fontSize(FontSize.Xs)
                  .fontColor(SemanticColors.Text3)
              }
              .width('100%')
              .margin({ bottom: Spacing.Space4 })

              // 问题内容
              Text(this.currentQuestion?.question || '')
                .fontSize(FontSize.Lg)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.Text1)
                .lineHeight(28)
                .width('100%')

              // 回答提示
              if (this.currentQuestion?.tips) {
                Row() {
                  Image($r('app.media.ic_lightbulb'))
                    .width(16)
                    .height(16)
                    .fillColor(WarningColors.Warning500)

                  Text(this.currentQuestion.tips)
                    .fontSize(FontSize.Xs)
                    .fontColor(SemanticColors.Text2)
                    .margin({ left: Spacing.Space2 })
                    .layoutWeight(1)
                }
                .width('100%')
                .margin({ top: Spacing.Space4 })
                .padding(Spacing.Space3)
                .backgroundColor(WarningColors.Warning50)
                .borderRadius(SemanticRadius.Control)
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Xl)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Component)
            .margin({ top: Spacing.Space7 })
            .shadow({
              radius: 24,
              color: 'rgba(0, 0, 0, 0.15)',
              offsetY: 8
            })
          }
          .width('100%')
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

          Blank()

          // 底部输入区域
          Column() {
            // 语音输入按钮
            VoiceInputButton({
              isRecording: this.isRecording,
              isProcessing: this.isProcessing,
              recognizedText: '',
              recordingDuration: this.recordingDuration,
              onStartRecording: () => this.handleStartRecording(),
              onStopRecording: () => this.handleStopRecording(),
              onTextChanged: (text: string) => {
                this.currentAnswer = text;
              }
            })

            // 提交按钮
            if (this.currentAnswer.trim().length > 0) {
              Button() {
                Row() {
                  Text('提交回答')
                    .fontSize(FontSize.Sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(BrandColors.Brand500)

                  Image($r('app.media.ic_send'))
                    .width(16)
                    .height(16)
                    .fillColor(BrandColors.Brand500)
                    .margin({ left: Spacing.Space2 })
                }
              }
              .width('100%')
              .height(48)
              .backgroundColor(NeutralColors.Neutral0)
              .borderRadius(SemanticRadius.Pill)
              .margin({ top: Spacing.Space3 })
              .onClick(() => this.submitAnswer())
            }
          }
          .width('100%')
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: (AppStorage.get<number>('bottomSafeArea') || 0) + Spacing.Space4 })
        }
        .width('100%')
        .height('100%')

        // STAR引导悬浮提示
        if (this.showStarGuide && this.currentQuestion?.starGuide) {
          Column() {
            StarGuide({
              starGuide: this.currentQuestion.starGuide,
              isAnswering: this.currentAnswer.length > 0
            })
          }
          .position({ x: '100%', y: 120 })
          .translate({ x: -180 })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 完成视图
   */
  @Builder
  CompletedView() {
    Column() {
      this.TopBar('面试完成')

      Scroll() {
        Column() {
          // 完成图标
          Column() {
            Image($r('app.media.ic_check'))
              .width(48)
              .height(48)
              .fillColor(SuccessColors.Success500)
          }
          .width(100)
          .height(100)
          .backgroundColor(SuccessColors.Success50)
          .borderRadius(50)
          .justifyContent(FlexAlign.Center)

          Text('面试已完成')
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(NeutralColors.Neutral0)
            .margin({ top: Spacing.Space7 })

          Text(`您完成了 ${this.session?.questions.length || 0} 道面试题`)
            .fontSize(FontSize.Base)
            .fontColor('rgba(255, 255, 255, 0.7)')
            .margin({ top: Spacing.Space3 })

          // 总分卡片
          Column() {
            Text('综合得分')
              .fontSize(FontSize.Sm)
              .fontColor('rgba(255, 255, 255, 0.8)')

            Text((this.session?.totalScore || 0).toString())
              .fontSize(48)
              .fontWeight(FontWeight.Bold)
              .fontColor(NeutralColors.Neutral0)
              .margin({ top: Spacing.Space2 })

            Text(this.getScoreLabel(this.session?.totalScore || 0))
              .fontSize(FontSize.Base)
              .fontColor(this.getScoreColor(this.session?.totalScore || 0))
          }
          .width('100%')
          .padding(SemanticSpacing.Xl)
          .backgroundColor('rgba(255, 255, 255, 0.15)')
          .borderRadius(SemanticRadius.Component)
          .margin({ top: Spacing.Space9 })

          // 各题得分
          if (this.session && this.session.feedbacks.length > 0) {
            Column() {
              Text('各题得分')
                .fontSize(FontSize.Base)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
                .width('100%')
                .margin({ bottom: Spacing.Space4 })

              ForEach(this.session.feedbacks, (feedback: InterviewFeedback, index: number) => {
                Row() {
                  Text(`第${index + 1}题`)
                    .fontSize(FontSize.Sm)
                    .fontColor('rgba(255, 255, 255, 0.8)')
                    .width(60)

                  Stack() {
                    Row()
                      .width('100%')
                      .height(6)
                      .backgroundColor('rgba(255, 255, 255, 0.2)')
                      .borderRadius(3)

                    Row()
                      .width(`${feedback.score}%`)
                      .height(6)
                      .backgroundColor(this.getScoreColor(feedback.score))
                      .borderRadius(3)
                  }
                  .layoutWeight(1)
                  .height(6)

                  Text(feedback.score.toString())
                    .fontSize(FontSize.Sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.getScoreColor(feedback.score))
                    .width(36)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .margin({ top: index === 0 ? 0 : Spacing.Space3 })
              })
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(SemanticRadius.Component)
            .margin({ top: Spacing.Space4 })
          }

          // 操作按钮
          Row() {
            Button() {
              Text('返回')
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)
            }
            .height(48)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(SemanticRadius.Pill)
            .layoutWeight(1)
            .onClick(() => router.back())

            Button() {
              Text('再来一次')
                .fontSize(FontSize.Sm)
                .fontColor(BrandColors.Brand500)
            }
            .height(48)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Pill)
            .layoutWeight(1)
            .margin({ left: Spacing.Space3 })
            .onClick(() => {
              this.pageState = 'config';
              this.session = null;
              this.currentQuestion = null;
              this.currentAnswer = '';
              this.currentFeedback = null;
            })
          }
          .width('100%')
          .margin({ top: Spacing.Space9 })

          // 面试后推荐操作
          Column() {
            Text('推荐下一步')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .width('100%')
              .margin({ bottom: Spacing.Space4 })

            // 查看面试技巧
            Row() {
              Column() {
                Image($r('app.media.ic_knowledge'))
                  .width(20)
                  .height(20)
                  .fillColor(NeutralColors.Neutral0)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .justifyContent(FlexAlign.Center)

              Text('查看面试技巧')
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space3 })
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('rgba(255, 255, 255, 0.5)')
            }
            .width('100%')
            .height(52)
            .padding({ left: Spacing.Space3, right: Spacing.Space3 })
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(SemanticRadius.Component)
            .onClick(() => {
              AppStorage.setOrCreate('currentTab', 3);
              router.back();
            })

            // 再做一次测评
            Row() {
              Column() {
                Image($r('app.media.ic_assessment'))
                  .width(20)
                  .height(20)
                  .fillColor(NeutralColors.Neutral0)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .justifyContent(FlexAlign.Center)

              Text('再做一次测评')
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space3 })
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('rgba(255, 255, 255, 0.5)')
            }
            .width('100%')
            .height(52)
            .padding({ left: Spacing.Space3, right: Spacing.Space3 })
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(SemanticRadius.Component)
            .margin({ top: Spacing.Space2 })
            .onClick(() => {
              AppStorage.setOrCreate('currentTab', 2);
              router.back();
            })

            // 分析Offer
            Row() {
              Column() {
                Image($r('app.media.ic_order'))
                  .width(20)
                  .height(20)
                  .fillColor(NeutralColors.Neutral0)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .justifyContent(FlexAlign.Center)

              Text('分析Offer')
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space3 })
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('rgba(255, 255, 255, 0.5)')
            }
            .width('100%')
            .height(52)
            .padding({ left: Spacing.Space3, right: Spacing.Space3 })
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(SemanticRadius.Component)
            .margin({ top: Spacing.Space2 })
            .onClick(() => {
              Router.push('pages/OfferAnalysis');
            })

            // 记录到看板
            Row() {
              Column() {
                Image($r('app.media.ic_history'))
                  .width(20)
                  .height(20)
                  .fillColor(NeutralColors.Neutral0)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor('rgba(255, 255, 255, 0.15)')
              .justifyContent(FlexAlign.Center)

              Text('记录到看板')
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space3 })
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('rgba(255, 255, 255, 0.5)')
            }
            .width('100%')
            .height(52)
            .padding({ left: Spacing.Space3, right: Spacing.Space3 })
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(SemanticRadius.Component)
            .margin({ top: Spacing.Space2 })
            .onClick(() => {
              Router.push('pages/Kanban');
            })
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor('rgba(255, 255, 255, 0.08)')
          .borderRadius(SemanticRadius.Component)
          .margin({ top: Spacing.Space7 })
        }
        .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 顶部导航栏
   */
  @Builder
  TopBar(title: string) {
    Row() {
      Column() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .fillColor(NeutralColors.Neutral0)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('rgba(255, 255, 255, 0.2)')
      .justifyContent(FlexAlign.Center)
      .onClick(() => this.exitInterview())

      Text(title)
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(NeutralColors.Neutral0)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位
      Row()
        .width(40)
    }
    .width('100%')
    .height(56)
    .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
  }

  /**
   * AI点评底部弹出面板遮罩层
   */
  @Builder
  FeedbackSheetOverlay() {
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          // 不允许点击遮罩关闭
        })

      // 点评面板
      FeedbackSheet({
        feedback: this.currentFeedback,
        isExpanded: true,
        onNextQuestion: () => this.nextQuestion(),
        onRetryQuestion: () => {
          this.showFeedbackSheet = false;
          this.currentAnswer = '';
          this.currentFeedback = null;
          this.pageState = 'interviewing';
        },
        onClose: () => {
          this.showFeedbackSheet = false;
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 退出确认对话框
   */
  @Builder
  ExitConfirmDialog() {
    Column() {
      Column() {
        Text('确认退出')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

        Text('面试尚未完成，退出后当前进度将不会保存')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ top: Spacing.Space4 })
          .textAlign(TextAlign.Center)

        Row() {
          Button('继续面试')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .backgroundColor('transparent')
            .layoutWeight(1)
            .onClick(() => {
              this.showExitConfirm = false;
            })

          Button('确认退出')
            .fontSize(FontSize.Sm)
            .fontColor(ErrorColors.Error500)
            .backgroundColor('transparent')
            .layoutWeight(1)
            .onClick(() => {
              this.showExitConfirm = false;
              router.back();
            })
        }
        .width('100%')
        .margin({ top: Spacing.Space7 })
      }
      .width('80%')
      .padding(SemanticSpacing.Xl)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius(SemanticRadius.Component)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center)
  }

  // 辅助方法
  private getCategoryLabel(category: string): string {
    const labels: Record<string, string> = {
      self_intro: '自我介绍',
      behavioral: '行为面试',
      technical: '技术面试',
      situational: '情景面试',
      salary: '薪资谈判'
    };
    return labels[category] || '面试题';
  }

  private getDifficultyLabel(difficulty: string): string {
    const labels: Record<string, string> = {
      easy: '简单',
      medium: '中等',
      hard: '困难'
    };
    return labels[difficulty] || '';
  }

  private getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  private getScoreLabel(score: number): string {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 70) return '中等';
    if (score >= 60) return '及格';
    return '需改进';
  }
}
