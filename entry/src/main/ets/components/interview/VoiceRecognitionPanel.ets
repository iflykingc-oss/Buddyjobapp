/**
 * 语音识别面板组件
 *
 * 提供实时语音识别交互界面
 * 支持聆听动画、实时转文字、文字编辑和提交
 */
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration
} from '../../constants/design-tokens';
import {
  SpeechRecognitionService,
  SpeechRecognitionState,
  RecognitionResult
} from '../services/SpeechRecognitionService';

interface WavePoint {
  x: number;
  y: number;
  phase: number;
  amplitude: number;
}

@Component
export struct VoiceRecognitionPanel {
  // 回调函数
  onSubmit: (text: string) => void = () => {};
  onCancel: () => void = () => {};

  // 状态
  @State private isListening: boolean = false;
  @State private recognizedText: string = '';
  @State private interimText: string = '';
  @State private isProcessing: boolean = false;
  @State private currentState: SpeechRecognitionState = SpeechRecognitionState.IDLE;
  @State private confidence: number = 0;
  @State private errorMessage: string = '';
  @State private isAvailable: boolean = true;

  // 语言
  @State private currentLanguage: string = 'zh-CN';
  @State private showLanguageSelector: boolean = false;

  // 波形动画相关
  @State private wavePoints: WavePoint[] = [];
  @State private waveAnimationAngle: number = 0;
  @State private pulseScale: number = 1;

  // 动画定时器
  private waveTimer: number = -1;
  private pulseTimer: number = -1;

  // 语音服务
  private speechService: SpeechRecognitionService = SpeechRecognitionService.getInstance();

  aboutToAppear() {
    this.initWavePoints();
    this.checkAvailability();
  }

  aboutToDisappear() {
    this.stopAnimations();
    // 离开时取消识别
    if (this.isListening) {
      this.speechService.cancel();
    }
  }

  /**
   * 初始化波形点
   */
  private initWavePoints(): void {
    const points: WavePoint[] = [];
    for (let i = 0; i < 32; i++) {
      points.push({
        x: i * 10,
        y: 50,
        phase: (i / 32) * Math.PI * 2,
        amplitude: 5 + Math.random() * 10
      });
    }
    this.wavePoints = points;
  }

  /**
   * 检查语音识别可用性
   */
  private async checkAvailability(): Promise<void> {
    this.isAvailable = await this.speechService.isAvailable();
    if (!this.isAvailable) {
      this.errorMessage = '语音识别不可用，请检查权限设置';
    }
  }

  build() {
    Column() {
      // 顶部区域 - 语言切换
      this.LanguageHeader()

      // 中央区域 - 波形和文字
      Column() {
        // 波形可视化区域
        this.WaveVisualization()

        // 识别状态文字
        this.StatusText()

        // 置信度显示
        if (this.isListening || this.isProcessing) {
          this.ConfidenceDisplay()
        }
      }
      .layoutWeight(1)

      // 底部区域 - 输入文字和按钮
      this.BottomArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral0)
  }

  /**
   * 语言选择头部
   */
  @Builder
  LanguageHeader() {
    Row() {
      Text(this.currentLanguage === 'zh-CN' ? '中文' : 'English')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .onClick(() => {
          this.showLanguageSelector = !this.showLanguageSelector;
        })

      if (this.showLanguageSelector) {
        Text(' | ')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text4)

        Text('切换')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .onClick(() => {
            this.currentLanguage = this.currentLanguage === 'zh-CN' ? 'en-US' : 'zh-CN';
            this.speechService.setLanguage(this.currentLanguage);
            this.showLanguageSelector = false;
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .padding({ right: SemanticSpacing.Lg, top: SemanticSpacing.Md })
  }

  /**
   * 波形可视化区域
   */
  @Builder
  WaveVisualization() {
    Column() {
      // 麦克风按钮 + 脉冲动画
      Stack() {
        // 脉冲圆环
        if (this.isListening) {
          ForEach([1, 2, 3], (index: number) => {
            Circle()
              .width(120 + index * 30)
              .height(120 + index * 30)
              .fill(Color.Transparent)
              .stroke(BrandColors.Brand300)
              .strokeOpacity((1 - index * 0.25) * (0.3 + this.pulseScale * 0.2))
              .position({ x: '50%', y: '50%' })
              .translate({ x: -60 - index * 15, y: -60 - index * 15 })
          })
        }

        // 主麦克风按钮
        Column() {
          if (this.isProcessing) {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(BrandColors.Brand500)
          } else if (this.isListening) {
            Image($r('app.media.ic_microphone'))
              .width(40)
              .height(40)
              .fillColor(BrandColors.Brand500)
          } else {
            Image($r('app.media.ic_microphone'))
              .width(40)
              .height(40)
              .fillColor(NeutralColors.Neutral500)
          }
        }
        .width(100)
        .height(100)
        .borderRadius(50)
        .backgroundColor(
          this.isListening ? BrandColors.Brand100 :
          this.isProcessing ? BrandColors.Brand50 :
          NeutralColors.Neutral100
        )
        .scale({ x: this.pulseScale, y: this.pulseScale })
        .onClick(() => {
          if (!this.isAvailable) {
            return;
          }
          if (this.isListening) {
            this.stopListening();
          } else if (!this.isProcessing) {
            this.startListening();
          }
        })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)

      // 波形条
      if (this.isListening) {
        Row() {
          ForEach(this.wavePoints, (point: WavePoint, index: number) => {
            Rect()
              .width(4)
              .height(point.amplitude * (0.5 + this.pulseScale * 0.5))
              .fill(BrandColors.Brand400)
              .borderRadius(2)
              .margin({ left: index === 0 ? 0 : 2 })
          })
        }
        .height(60)
        .justifyContent(FlexAlign.Center)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }
    }
    .width('100%')
  }

  /**
   * 状态文字显示
   */
  @Builder
  StatusText() {
    Column() {
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(FontSize.Sm)
          .fontColor(ErrorColors.Error500)
          .textAlign(TextAlign.Center)
      } else if (this.currentState === SpeechRecognitionState.IDLE) {
        Text('点击麦克风开始说话')
          .fontSize(FontSize.Lg)
          .fontColor(SemanticColors.Text2)
          .textAlign(TextAlign.Center)
      } else if (this.isListening) {
        Text(this.interimText || '正在聆听...')
          .fontSize(FontSize.Lg)
          .fontColor(SemanticColors.Text1)
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.isProcessing) {
        Text('正在识别...')
          .fontSize(FontSize.Lg)
          .fontColor(SemanticColors.Text2)
          .textAlign(TextAlign.Center)
      } else if (this.currentState === SpeechRecognitionState.COMPLETED) {
        Text(this.recognizedText || '识别完成')
          .fontSize(FontSize.Lg)
          .fontColor(SemanticColors.Text1)
          .textAlign(TextAlign.Center)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, top: SemanticSpacing.Lg })
  }

  /**
   * 置信度显示
   */
  @Builder
  ConfidenceDisplay() {
    Row() {
      Text('置信度:')
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text3)

      Text(`${(this.confidence * 100).toFixed(0)}%`)
        .fontSize(FontSize.Xs)
        .fontColor(
          this.confidence >= 0.8 ? SemanticColors.Success :
          this.confidence >= 0.5 ? SemanticColors.Warning :
          SemanticColors.Error
        )
        .margin({ left: Spacing.Space2 })
    }
    .padding({ top: SemanticSpacing.Sm })
  }

  /**
   * 底部区域 - 文字编辑和按钮
   */
  @Builder
  BottomArea() {
    Column() {
      // 文字输入/编辑区域
      TextArea({ text: this.recognizedText, placeholder: '识别的文字将显示在这里...' })
        .width('100%')
        .height(120)
        .backgroundColor(NeutralColors.Neutral50)
        .borderRadius(SemanticRadius.Control)
        .border({
          width: 1,
          color: NeutralColors.Neutral200
        })
        .padding(SemanticSpacing.Md)
        .placeholderColor(SemanticColors.Text4)
        .placeholderFont({ size: FontSize.Sm })
        .fontColor(SemanticColors.Text1)
        .fontSize(FontSize.Sm)
        .onChange((value: string) => {
          this.recognizedText = value;
        })

      // 操作按钮
      Row() {
        // 取消按钮
        Button('取消')
          .fontSize(FontSize.Md)
          .fontColor(SemanticColors.Text2)
          .backgroundColor(NeutralColors.Neutral100)
          .borderRadius(SemanticRadius.Pill)
          .height(44)
          .layoutWeight(1)
          .margin({ right: Spacing.Space3 })
          .onClick(() => {
            this.handleCancel();
          })

        // 发送按钮
        Button('发送')
          .fontSize(FontSize.Md)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(
            this.recognizedText.trim() ? BrandColors.Brand500 : NeutralColors.Neutral300
          )
          .borderRadius(SemanticRadius.Pill)
          .height(44)
          .layoutWeight(1)
          .enabled(this.recognizedText.trim().length > 0)
          .onClick(() => {
            this.handleSubmit();
          })
      }
      .width('100%')
      .padding({ top: SemanticSpacing.Lg })
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(NeutralColors.Neutral50)
  }

  /**
   * 开始聆听
   */
  private async startListening(): Promise<void> {
    // 初始化服务
    if (!this.speechService.isInitialized) {
      const initSuccess = await this.speechService.initialize({
        language: this.currentLanguage,
        enablePunctuation: true,
        enableInterimResults: true
      });

      if (!initSuccess) {
        this.errorMessage = '语音服务初始化失败';
        return;
      }
    }

    // 设置回调
    this.speechService.onResult = (result: RecognitionResult) => {
      if (result.isFinal) {
        this.recognizedText = result.text;
        this.confidence = result.confidence;
      } else {
        this.interimText = result.text;
      }
    };

    this.speechService.onError = (error: RecognitionResult) => {
      this.errorMessage = error.errorMessage || '识别错误';
      this.isListening = false;
      this.stopAnimations();
    };

    this.speechService.onStateChange = (state: SpeechRecognitionState) => {
      this.currentState = state;
      this.isListening = state === SpeechRecognitionState.LISTENING;
      this.isProcessing = state === SpeechRecognitionState.PROCESSING;
    };

    // 开始聆听
    const success = await this.speechService.startListening();

    if (success) {
      this.isListening = true;
      this.errorMessage = '';
      this.recognizedText = '';
      this.interimText = '';
      this.startAnimations();
    } else {
      this.errorMessage = '启动聆听失败';
    }
  }

  /**
   * 停止聆听
   */
  private async stopListening(): Promise<void> {
    await this.speechService.stopListening();
    this.isListening = false;
    this.isProcessing = true;
    this.stopAnimations();

    // 获取最终结果
    const result = this.speechService.lastResult;
    if (result) {
      this.recognizedText = result.text;
      this.confidence = result.confidence;
    }
  }

  /**
   * 处理取消
   */
  private handleCancel(): void {
    if (this.isListening) {
      this.speechService.cancel();
    }
    this.stopAnimations();
    this.onCancel();
  }

  /**
   * 处理提交
   */
  private handleSubmit(): void {
    const text = this.recognizedText.trim();
    if (text) {
      this.onSubmit(text);
      // 重置状态
      this.recognizedText = '';
      this.interimText = '';
      this.confidence = 0;
      this.currentState = SpeechRecognitionState.IDLE;
    }
  }

  /**
   * 开始动画
   */
  private startAnimations(): void {
    // 脉冲动画
    this.pulseTimer = setInterval(() => {
      this.pulseScale = 1 + 0.05 * Math.sin(Date.now() / 200);
    }, 33);

    // 波形动画
    this.waveTimer = setInterval(() => {
      this.waveAnimationAngle += 0.1;
      const newPoints: WavePoint[] = [];
      for (let i = 0; i < this.wavePoints.length; i++) {
        const baseAmplitude = 5 + Math.random() * 15;
        const phase = this.waveAnimationAngle + (i / this.wavePoints.length) * Math.PI * 2;
        const amplitude = this.isListening ?
          baseAmplitude + 10 * Math.abs(Math.sin(phase)) :
          baseAmplitude * 0.5;

        newPoints.push({
          ...this.wavePoints[i],
          amplitude: amplitude
        });
      }
      this.wavePoints = newPoints;
    }, 50);
  }

  /**
   * 停止动画
   */
  private stopAnimations(): void {
    if (this.pulseTimer !== -1) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
    }
    if (this.waveTimer !== -1) {
      clearInterval(this.waveTimer);
      this.waveTimer = -1;
    }
    this.pulseScale = 1;
  }
}
