/**
 * 语音面试助手页面
 * 全程语音交互的面试练习体验
 */
import {
  VoiceInterviewService,
  RecognitionState,
  InterviewQuestion,
  AnswerEvaluation,
  VoiceInterviewSession
} from '../services/VoiceInterviewService';
import router from '@ohos.router';
import { colors } from '../constants/colors';
import { SemanticRadius } from '../constants/design-tokens';

@Entry
@Component
struct VoiceInterviewPage {
  @State company: string = '';
  @State position: string = '';
  @State difficulty: string = 'medium';
  @State isInitialized: boolean = false;
  @State session: VoiceInterviewSession | null = null;
  @State state: RecognitionState = RecognitionState.IDLE;
  @State currentQuestion: InterviewQuestion | null = null;
  @State recognitionText: string = '';
  @State lastEvaluation: AnswerEvaluation | null = null;
  @State showSetupSheet: boolean = true;
  @State showResultSheet: boolean = false;

  async aboutToAppear() {
    this.isInitialized = await VoiceInterviewService.initialize();
  }

  aboutToDisappear() {
    VoiceInterviewService.destroy();
  }

  build() {
    Column() {
      // 顶部状态栏
      this.StatusBar()

      // 主内容区域
      if (this.session) {
        this.InterviewContent()
      } else {
        this.SetupContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.background)
    .bindSheet($$this.showSetupSheet, this.SetupSheet(), {
      height: '70%',
      dragBar: true,
      backgroundColor: Colors.surface
    })
    .bindSheet($$this.showResultSheet, this.ResultSheet(), {
      height: '80%',
      dragBar: true,
      backgroundColor: Colors.surface
    })
  }

  @Builder
  StatusBar() {
    Row() {
      // 返回按钮
      Image($r('app.media.ic_back'))
        .width(24)
        .height(24)
        .onClick(async () => {
          if (this.session) {
            await VoiceInterviewService.endSession();
          }
          router.back();
        })

      Text('语音面试助手')
        .fontSize(18)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })

      Blank()

      // 状态指示
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getStateColor())

        Text(this.getStateLabel())
          .fontSize(12)
          .fontColor(Colors.textSecondary)
          .margin({ left: 6 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Colors.surface)
  }

  @Builder
  SetupContent() {
    Column() {
      // 空状态
      Column() {
        Image($r('app.media.ic_voice_interview'))
          .width(120)
          .height(120)

        Text('语音面试助手')
          .fontSize(20)
          .fontColor(Colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 24 })

        Text('全程语音交互，真实模拟面试场景')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .margin({ top: 8 })

        Button('开始面试')
          .width(200)
          .height(48)
          .fontSize(16)
          .fontColor(Colors.surface)
          .backgroundColor(Colors.primary)
          .borderRadius(SemanticRadius.lg)
          .margin({ top: 32 })
          .onClick(() => {
            this.showSetupSheet = true;
          })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  InterviewContent() {
    Column() {
      // 进度指示
      Row() {
        Text(`问题 ${this.session?.currentQuestionIndex ?? 0 + 1}/${this.session?.questions.length ?? 0}`)
          .fontSize(14)
          .fontColor(Colors.textSecondary)

        Blank()

        Text(this.session?.company ?? '')
          .fontSize(14)
          .fontColor(Colors.textPrimary)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })

      // 进度条
      Progress({
        value: (this.session?.currentQuestionIndex ?? 0) + 1,
        total: this.session?.questions.length ?? 1,
        type: ProgressType.Linear
      })
        .width('100%')
        .color(Colors.primary)
        .padding({ left: 16, right: 16 })

      // 当前问题卡片
      if (this.currentQuestion) {
        this.QuestionCard()
      }

      // 语音波形区域
      this.VoiceWaveform()

      // 识别文本显示
      if (this.recognitionText) {
        Column() {
          Text(this.recognitionText)
            .fontSize(16)
            .fontColor(Colors.textPrimary)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('90%')
        .padding(16)
        .backgroundColor(Colors.surfaceSecondary)
        .borderRadius(SemanticRadius.md)
        .margin({ top: 16 })
      }

      Blank()

      // 底部控制按钮
      this.ControlButtons()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  QuestionCard() {
    Column() {
      Row() {
        Text(this.getQuestionTypeLabel(this.currentQuestion!.type))
          .fontSize(12)
          .fontColor(Colors.primary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Colors.primaryLight)
          .borderRadius(SemanticRadius.sm)

        Blank()

        if (this.currentQuestion!.tips && this.currentQuestion!.tips.length > 0) {
          Row() {
            Image($r('app.media.ic_tip'))
              .width(16)
              .height(16)
              .fontColor(Colors.textSecondary)

            Text('提示')
              .fontSize(12)
              .fontColor(Colors.textSecondary)
              .margin({ left: 4 })
          }
        }
      }
      .width('100%')

      Text(this.currentQuestion!.content)
        .fontSize(18)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 12 })

      // 提示信息
      if (this.currentQuestion!.tips && this.currentQuestion!.tips.length > 0) {
        Column() {
          ForEach(this.currentQuestion!.tips!, (tip: string) => {
            Row() {
              Text('•')
                .fontSize(14)
                .fontColor(Colors.textSecondary)

              Text(tip)
                .fontSize(14)
                .fontColor(Colors.textSecondary)
                .margin({ left: 8 })
            }
            .width('100%')
            .margin({ top: 4 })
          })
        }
        .width('100%')
        .margin({ top: 12 })
        .padding(12)
        .backgroundColor(Colors.surfaceSecondary)
        .borderRadius(SemanticRadius.sm)
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor(Colors.surface)
    .borderRadius(SemanticRadius.md)
    .margin({ top: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VoiceWaveform() {
    Column() {
      Stack() {
        // 波形动画
        if (this.state === RecognitionState.LISTENING) {
          Row() {
            ForEach([1, 2, 3, 4, 5], (i: number) => {
              Column()
                .width(4)
                .height(this.getWaveHeight(i))
                .backgroundColor(Colors.primary)
                .borderRadius(2)
                .margin({ left: 4, right: 4 })
                .animation({
                  duration: 300,
                  curve: Curve.EaseInOut,
                  iterations: -1
                })
            })
          }
          .justifyContent(FlexAlign.Center)
        } else {
          // 静态麦克风图标
          Image($r('app.media.ic_mic'))
            .width(48)
            .height(48)
            .fontColor(this.state === RecognitionState.SPEAKING ? Colors.primary : Colors.textSecondary)
        }
      }
      .width(120)
      .height(80)
      .justifyContent(FlexAlign.Center)

      Text(this.getStateDescription())
        .fontSize(14)
        .fontColor(Colors.textSecondary)
        .margin({ top: 8 })
    }
    .width('100%')
    .margin({ top: 24 })
  }

  @Builder
  ControlButtons() {
    Row() {
      // 跳过按钮
      Button('跳过')
        .width(100)
        .height(44)
        .fontSize(14)
        .fontColor(Colors.textSecondary)
        .backgroundColor(Colors.surfaceSecondary)
        .borderRadius(SemanticRadius.md)
        .onClick(async () => {
          await VoiceInterviewService.skipQuestion();
        })

      Blank()

      // 主控制按钮
      Button(this.getMainButtonLabel())
        .width(120)
        .height(56)
        .fontSize(16)
        .fontColor(Colors.surface)
        .backgroundColor(this.getMainButtonColor())
        .borderRadius(SemanticRadius.full)
        .enabled(this.state !== RecognitionState.PROCESSING && this.state !== RecognitionState.SPEAKING)
        .onClick(async () => {
          await this.handleMainButton();
        })

      Blank()

      // 结束按钮
      Button('结束')
        .width(100)
        .height(44)
        .fontSize(14)
        .fontColor(Colors.error)
        .backgroundColor(Colors.surfaceSecondary)
        .borderRadius(SemanticRadius.md)
        .onClick(async () => {
          this.session = await VoiceInterviewService.endSession();
          if (this.session) {
            this.showResultSheet = true;
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 24 })
  }

  @Builder
  SetupSheet() {
    Column() {
      Text('设置面试')
        .fontSize(20)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 16, bottom: 24 })

      // 公司输入
      Column() {
        Text('公司名称')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        TextInput({ placeholder: '请输入公司名称' })
          .width('100%')
          .height(44)
          .margin({ top: 8 })
          .onChange((value) => {
            this.company = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      // 职位输入
      Column() {
        Text('应聘职位')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        TextInput({ placeholder: '请输入应聘职位' })
          .width('100%')
          .height(44)
          .margin({ top: 8 })
          .onChange((value) => {
            this.position = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      // 难度选择
      Column() {
        Text('面试难度')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        Row() {
          ForEach(['easy', 'medium', 'hard'], (level: string) => {
            Button(this.getDifficultyLabel(level))
              .width(90)
              .height(36)
              .fontSize(14)
              .fontColor(this.difficulty === level ? Colors.surface : Colors.textPrimary)
              .backgroundColor(this.difficulty === level ? Colors.primary : Colors.surfaceSecondary)
              .borderRadius(SemanticRadius.md)
              .onClick(() => {
                this.difficulty = level;
              })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })

      Blank()

      // 开始按钮
      Button('开始语音面试')
        .width('90%')
        .height(52)
        .fontSize(16)
        .fontColor(Colors.surface)
        .backgroundColor(Colors.primary)
        .borderRadius(SemanticRadius.lg)
        .enabled(this.company.length > 0 && this.position.length > 0)
        .onClick(async () => {
          this.showSetupSheet = false;
          this.session = await VoiceInterviewService.startSession(
            this.company,
            this.position,
            this.difficulty as 'easy' | 'medium' | 'hard'
          );

          // 设置回调
          VoiceInterviewService.startListening({
            onRecognitionResult: (text, isFinal) => {
              this.recognitionText = text;
            },
            onQuestionChange: (question) => {
              this.currentQuestion = question;
              this.recognitionText = '';
            },
            onEvaluationReady: (evaluation) => {
              this.lastEvaluation = evaluation;
            }
          });
        })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 24 })
  }

  @Builder
  ResultSheet() {
    Column() {
      Text('面试结果')
        .fontSize(20)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 16, bottom: 24 })

      if (this.session) {
        // 总体评分
        Column() {
          Text('总体表现')
            .fontSize(14)
            .fontColor(Colors.textSecondary)

          Row() {
            Text(this.calculateAverageScore().toString())
              .fontSize(48)
              .fontColor(Colors.primary)
              .fontWeight(FontWeight.Bold)

            Text('分')
              .fontSize(20)
              .fontColor(Colors.textSecondary)
              .margin({ left: 4 })
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor(Colors.surfaceSecondary)
        .borderRadius(SemanticRadius.md)

        // 各问题评分
        List() {
          ForEach(this.session.answers, (answer, index) => {
            ListItem() {
              Row() {
                Text(`问题 ${index + 1}`)
                  .fontSize(14)
                  .fontColor(Colors.textPrimary)

                Blank()

                Text(`${answer.evaluation.score}分`)
                  .fontSize(14)
                  .fontColor(this.getScoreColor(answer.evaluation.score))
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16 })

        // 完成按钮
        Button('完成')
          .width('90%')
          .height(48)
          .fontSize(16)
          .fontColor(Colors.surface)
          .backgroundColor(Colors.primary)
          .borderRadius(SemanticRadius.lg)
          .onClick(() => {
            this.showResultSheet = false;
            this.session = null;
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 24 })
  }

  private async handleMainButton(): Promise<void> {
    switch (this.state) {
      case RecognitionState.IDLE:
        // 开始监听
        VoiceInterviewService.startListening({
          onRecognitionResult: (text) => {
            this.recognitionText = text;
          }
        });
        break;
      case RecognitionState.LISTENING:
        // 停止监听
        VoiceInterviewService.stopListening();
        break;
    }
  }

  private getStateColor(): ResourceColor {
    switch (this.state) {
      case RecognitionState.LISTENING:
        return Colors.success;
      case RecognitionState.SPEAKING:
        return Colors.info;
      case RecognitionState.PROCESSING:
        return Colors.warning;
      default:
        return Colors.textTertiary;
    }
  }

  private getStateLabel(): string {
    switch (this.state) {
      case RecognitionState.LISTENING:
        return '正在聆听';
      case RecognitionState.SPEAKING:
        return '正在播报';
      case RecognitionState.PROCESSING:
        return '处理中';
      default:
        return '待机';
    }
  }

  private getStateDescription(): string {
    switch (this.state) {
      case RecognitionState.LISTENING:
        return '请开始回答...';
      case RecognitionState.SPEAKING:
        return 'AI正在反馈...';
      case RecognitionState.PROCESSING:
        return '正在分析您的回答...';
      default:
        return '点击麦克风开始回答';
    }
  }

  private getMainButtonLabel(): string {
    switch (this.state) {
      case RecognitionState.LISTENING:
        return '完成回答';
      default:
        return '开始回答';
    }
  }

  private getMainButtonColor(): ResourceColor {
    switch (this.state) {
      case RecognitionState.LISTENING:
        return Colors.success;
      default:
        return Colors.primary;
    }
  }

  private getQuestionTypeLabel(type: string): string {
    switch (type) {
      case 'introduction':
        return '自我介绍';
      case 'technical':
        return '技术问题';
      case 'behavioral':
        return '行为面试';
      case 'project':
        return '项目经验';
      case 'situation':
        return '情景问题';
      default:
        return '面试问题';
    }
  }

  private getDifficultyLabel(level: string): string {
    switch (level) {
      case 'easy':
        return '简单';
      case 'medium':
        return '中等';
      case 'hard':
        return '困难';
      default:
        return '中等';
    }
  }

  private getWaveHeight(index: number): number {
    const baseHeight = 20;
    const variation = Math.sin(Date.now() / 200 + index) * 15;
    return Math.max(8, baseHeight + variation);
  }

  private calculateAverageScore(): number {
    if (!this.session || this.session.answers.length === 0) {
      return 0;
    }

    const total = this.session.answers.reduce((sum, answer) => sum + answer.evaluation.score, 0);
    return Math.round(total / this.session.answers.length);
  }

  private getScoreColor(score: number): ResourceColor {
    if (score >= 80) return Colors.success;
    if (score >= 60) return Colors.warning;
    return Colors.error;
  }
}
