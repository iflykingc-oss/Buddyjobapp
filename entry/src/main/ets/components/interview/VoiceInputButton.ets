/**
 * 语音输入按钮组件
 *
 * 支持长按录音、实时语音识别、录音波形动画、语音识别结果展示
 * 集成 SpeechRecognitionService 实现实时语音转文字
 * 遵循鸿蒙设计规范
 */
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
  Duration
} from '../../constants/design-tokens';
import {
  SpeechRecognitionService,
  SpeechRecognitionState,
  RecognitionResult
} from '../../services/SpeechRecognitionService';

// 波形数据
interface WaveBar {
  height: number;
  delay: number;
}

// 语言选项
interface LanguageOption {
  code: string;
  label: string;
}

@Component
export struct VoiceInputButton {
  // 状态
  @Prop isRecording: boolean = false;
  @Prop isProcessing: boolean = false;
  @Prop recognizedText: string = '';
  @Prop recordingDuration: number = 0;

  // 回调
  onStartRecording: () => void = () => {};
  onStopRecording: () => void = () => {};
  onTextChanged: (text: string) => void = () => {};
  onRecognitionResult: (text: string, confidence: number) => void = () => {};

  // 内部状态
  @State private waveBars: WaveBar[] = [];
  @State private animationProgress: number = 0;
  @State private isPressed: boolean = false;
  @State private inputMode: 'voice' | 'text' = 'voice';
  @State private textInput: string = '';

  // 语音识别相关状态
  @State private isListening: boolean = false;
  @State private isRecognizing: boolean = false;
  @State private recognitionState: SpeechRecognitionState = SpeechRecognitionState.IDLE;
  @State private interimText: string = '';
  @State private confidence: number = 0;
  @State private speechAvailable: boolean = true;
  @State private showSettings: boolean = false;

  // 语言设置
  @State private currentLanguage: string = 'zh-CN';
  private languageOptions: LanguageOption[] = [
    { code: 'zh-CN', label: '中文' },
    { code: 'en-US', label: 'English' }
  ];

  // 语音服务
  private speechService: SpeechRecognitionService = SpeechRecognitionService.getInstance();

  // 波形动画定时器
  private waveAnimationTimer: number = -1;
  private durationTimer: number = -1;
  private speechTimer: number = -1;

  aboutToAppear() {
    this.initWaveBars();
    this.checkSpeechAvailability();
  }

  aboutToDisappear() {
    this.stopWaveAnimation();
    if (this.durationTimer !== -1) {
      clearInterval(this.durationTimer);
    }
    if (this.speechTimer !== -1) {
      clearTimeout(this.speechTimer);
    }
    // 释放语音服务
    this.speechService.release();
  }

  /**
   * 检查语音识别可用性
   */
  private async checkSpeechAvailability(): Promise<void> {
    this.speechAvailable = await this.speechService.isAvailable();
  }

  /**
   * 初始化波形条
   */
  private initWaveBars(): void {
    const bars: WaveBar[] = [];
    for (let i = 0; i < 12; i++) {
      bars.push({
        height: 4 + Math.random() * 4,
        delay: i * 30
      });
    }
    this.waveBars = bars;
  }

  /**
   * 开始波形动画
   */
  private startWaveAnimation(): void {
    this.stopWaveAnimation();
    this.animationProgress = 0;

    this.waveAnimationTimer = setInterval(() => {
      this.animationProgress += 0.1;
      if (this.animationProgress > 1) {
        this.animationProgress = 0;
      }

      // 更新波形高度
      const newBars: WaveBar[] = [];
      for (let i = 0; i < 12; i++) {
        const baseHeight = 4;
        const maxHeight = this.isListening ? 28 : 24;
        const phase = this.animationProgress * Math.PI * 2 + i * 0.5;
        const height = baseHeight + (maxHeight - baseHeight) * (0.5 + 0.5 * Math.sin(phase));
        newBars.push({
          height: height,
          delay: i * 30
        });
      }
      this.waveBars = newBars;
    }, 50);
  }

  /**
   * 停止波形动画
   */
  private stopWaveAnimation(): void {
    if (this.waveAnimationTimer !== -1) {
      clearInterval(this.waveAnimationTimer);
      this.waveAnimationTimer = -1;
    }
  }

  /**
   * 格式化录音时长
   */
  private formatDuration(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 已识别的文字展示
      if (this.recognizedText || this.textInput || this.interimText) {
        this.RecognizedTextDisplay()
      }

      // 输入模式切换和输入区域
      Row() {
        // 模式切换按钮
        this.ModeSwitchButton()

        // 根据模式显示不同的输入方式
        if (this.inputMode === 'voice') {
          // 语音输入按钮
          this.VoiceButton()
        } else {
          // 文字输入框
          this.TextInputArea()
        }

        // 设置按钮（仅语音模式显示）
        if (this.inputMode === 'voice' && this.speechAvailable) {
          this.SettingsButton()
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral0)

      // 设置面板
      if (this.showSettings) {
        this.SettingsPanel()
      }
    }
    .width('100%')
  }

  /**
   * 已识别文字展示
   */
  @Builder
  RecognizedTextDisplay() {
    Column() {
      Row() {
        Text(this.inputMode === 'voice' ? '语音识别结果：' : '您的回答：')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)

        Blank()

        // 置信度显示
        if (this.confidence > 0 && this.inputMode === 'voice') {
          Text(`置信度: ${(this.confidence * 100).toFixed(0)}%`)
            .fontSize(FontSize.Xs)
            .fontColor(
              this.confidence >= 0.8 ? SemanticColors.Success :
              this.confidence >= 0.5 ? SemanticColors.Warning :
              SemanticColors.Error
            )
        }

        // 清除按钮
        Text('清除')
          .fontSize(FontSize.Xs)
          .fontColor(BrandColors.Brand500)
          .margin({ left: Spacing.Space3 })
          .onClick(() => {
            this.textInput = '';
            this.interimText = '';
            this.recognizedText = '';
            this.confidence = 0;
            this.onTextChanged('');
          })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space2 })

      // 中间识别结果（实时显示）
      if (this.interimText && this.isListening) {
        Text(this.interimText)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text3)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .opacity(0.7)
          .margin({ bottom: Spacing.Space2 })
      }

      // 最终识别结果
      Text(this.textInput || this.recognizedText)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 模式切换按钮
   */
  @Builder
  ModeSwitchButton() {
    Column() {
      if (this.inputMode === 'voice') {
        Image($r('app.media.ic_keyboard'))
          .width(24)
          .height(24)
          .fillColor(SemanticColors.Text2)
      } else {
        Image($r('app.media.ic_microphone'))
          .width(24)
          .height(24)
          .fillColor(this.speechAvailable ? SemanticColors.Text2 : SemanticColors.Text4)
      }
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor(NeutralColors.Neutral100)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.inputMode === 'voice') {
        this.inputMode = 'text';
      } else if (this.speechAvailable) {
        this.inputMode = 'voice';
      }
    })
  }

  /**
   * 设置按钮
   */
  @Builder
  SettingsButton() {
    Column() {
      Image($r('app.media.ic_settings'))
        .width(20)
        .height(20)
        .fillColor(SemanticColors.Text2)
    }
    .width(36)
    .height(36)
    .borderRadius(18)
    .backgroundColor(NeutralColors.Neutral100)
    .justifyContent(FlexAlign.Center)
    .margin({ left: Spacing.Space2 })
    .onClick(() => {
      this.showSettings = !this.showSettings;
    })
  }

  /**
   * 设置面板
   */
  @Builder
  SettingsPanel() {
    Column() {
      // 语言选择
      Row() {
        Text('识别语言')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)

        Blank()

        // 语言选项
        Row() {
          ForEach(this.languageOptions, (option: LanguageOption) => {
            Text(option.label)
              .fontSize(FontSize.Sm)
              .fontColor(this.currentLanguage === option.code ? BrandColors.Brand500 : SemanticColors.Text3)
              .backgroundColor(this.currentLanguage === option.code ? BrandColors.Brand50 : Color.Transparent)
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space1, bottom: Spacing.Space1 })
              .borderRadius(SemanticRadius.Sm)
              .onClick(() => {
                this.currentLanguage = option.code;
                this.speechService.setLanguage(option.code);
              })
          })
        }
      }
      .width('100%')
      .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })

      // 可用性提示
      if (!this.speechAvailable) {
        Row() {
          Image($r('app.media.ic_warning'))
            .width(16)
            .height(16)
            .fillColor(ErrorColors.Error500)

          Text('语音识别不可用，请检查权限设置')
            .fontSize(FontSize.Xs)
            .fontColor(ErrorColors.Error500)
            .margin({ left: Spacing.Space2 })
        }
        .width('100%')
        .padding({ top: Spacing.Space2 })
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Md)
    .backgroundColor(NeutralColors.Neutral100)
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space2 })
  }

  /**
   * 语音输入按钮
   */
  @Builder
  VoiceButton() {
    Row() {
      if (this.isListening) {
        // 聆听中状态
        Row() {
          // 波形动画
          Row() {
            ForEach(this.waveBars, (bar: WaveBar, index: number) => {
              Row()
                .width(3)
                .height(bar.height)
                .backgroundColor(BrandColors.Brand400)
                .borderRadius(1.5)
                .margin({ left: index === 0 ? 0 : 2 })
            })
          }
          .height(32)
          .justifyContent(FlexAlign.Center)

          // 聆听状态文字
          Text('聆听中...')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ left: Spacing.Space4 })
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(BrandColors.Brand100)
        .borderRadius(SemanticRadius.Pill)
        .border({
          width: 2,
          color: BrandColors.Brand500
        })
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })

        // 停止按钮
        Column() {
          Image($r('app.media.ic_stop'))
            .width(20)
            .height(20)
            .fillColor(ErrorColors.Error500)
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor(NeutralColors.Neutral0)
        .border({
          width: 2,
          color: ErrorColors.Error500
        })
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })
        .onClick(() => {
          this.stopSpeechRecognition();
        })

      } else if (this.isProcessing || this.isRecognizing) {
        // 处理中状态
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(BrandColors.Brand500)

          Text('识别中...')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .margin({ left: Spacing.Space3 })
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(SemanticRadius.Pill)
        .border({
          width: 2,
          color: BrandColors.Brand300
        })
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })

      } else if (this.isRecording) {
        // 录音中状态（传统录音模式）
        Row() {
          // 波形动画
          Row() {
            ForEach(this.waveBars, (bar: WaveBar, index: number) => {
              Row()
                .width(3)
                .height(bar.height)
                .backgroundColor(NeutralColors.Neutral0)
                .borderRadius(1.5)
                .margin({ left: index === 0 ? 0 : 2 })
            })
          }
          .height(32)
          .justifyContent(FlexAlign.Center)

          // 录音时长
          Text(this.formatDuration(this.recordingDuration))
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .margin({ left: Spacing.Space4 })
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(ErrorColors.Error500)
        .borderRadius(SemanticRadius.Pill)
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })

        // 停止按钮
        Column() {
          Image($r('app.media.ic_stop'))
            .width(20)
            .height(20)
            .fillColor(NeutralColors.Neutral0)
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor(ErrorColors.Error500)
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })
        .onClick(() => {
          this.stopWaveAnimation();
          this.onStopRecording();
        })

      } else {
        // 待聆听状态 - 点击开始语音识别
        Column() {
          Row() {
            Image($r('app.media.ic_microphone'))
              .width(20)
              .height(20)
              .fillColor(this.speechAvailable ? NeutralColors.Neutral0 : SemanticColors.Text3)

            Text(this.speechAvailable ? '点击说话' : '语音不可用')
              .fontSize(FontSize.Sm)
              .fontColor(this.speechAvailable ? NeutralColors.Neutral0 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3 })
          }
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(this.isPressed ? BrandColors.Brand600 : BrandColors.Brand500)
        .borderRadius(SemanticRadius.Pill)
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })
        .opacity(this.speechAvailable ? 1 : 0.6)
        .onClick(() => {
          if (this.speechAvailable) {
            this.startSpeechRecognition();
          }
        })
      }
    }
    .layoutWeight(1)
  }

  /**
   * 文字输入区域
   */
  @Builder
  TextInputArea() {
    Row() {
      TextInput({ placeholder: '输入您的回答...', text: this.textInput })
        .layoutWeight(1)
        .height(48)
        .backgroundColor(NeutralColors.Neutral50)
        .borderRadius(SemanticRadius.Pill)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .placeholderColor(SemanticColors.Text4)
        .placeholderFont({ size: FontSize.Sm })
        .fontColor(SemanticColors.Text1)
        .fontSize(FontSize.Sm)
        .onChange((value: string) => {
          this.textInput = value;
          this.onTextChanged(value);
        })
        .border({
          width: 1,
          color: NeutralColors.Neutral200
        })
        .margin({ left: Spacing.Space3 })
    }
    .layoutWeight(1)
  }

  /**
   * 开始语音识别
   */
  private async startSpeechRecognition(): Promise<void> {
    // 如果已经在聆听，先停止
    if (this.isListening) {
      await this.stopSpeechRecognition();
      return;
    }

    // 初始化服务
    if (!this.speechService.isInitialized) {
      const initSuccess = await this.speechService.initialize({
        language: this.currentLanguage,
        enablePunctuation: true,
        enableInterimResults: true
      });

      if (!initSuccess) {
        return;
      }
    }

    // 设置回调
    this.speechService.onResult = (result: RecognitionResult) => {
      if (result.isFinal) {
        // 最终结果
        this.recognizedText = result.text;
        this.textInput = result.text;
        this.confidence = result.confidence;
        this.interimText = '';
        this.isRecognizing = false;

        // 回调
        this.onRecognitionResult(result.text, result.confidence);
        this.onTextChanged(result.text);

      } else {
        // 中间结果
        this.interimText = result.text;
      }
    };

    this.speechService.onError = (error: RecognitionResult) => {
      this.isListening = false;
      this.isRecognizing = false;
      this.recognitionState = SpeechRecognitionState.ERROR;
      this.stopWaveAnimation();
    };

    this.speechService.onStateChange = (state: SpeechRecognitionState) => {
      this.recognitionState = state;
      this.isListening = state === SpeechRecognitionState.LISTENING;
      this.isRecognizing = state === SpeechRecognitionState.PROCESSING;
    };

    // 开始聆听
    const success = await this.speechService.startListening();

    if (success) {
      this.isListening = true;
      this.recognitionState = SpeechRecognitionState.LISTENING;
      this.startWaveAnimation();
    }
  }

  /**
   * 停止语音识别
   */
  private async stopSpeechRecognition(): Promise<void> {
    await this.speechService.stopListening();
    this.isListening = false;
    this.isRecognizing = true;
    this.recognitionState = SpeechRecognitionState.PROCESSING;
    this.stopWaveAnimation();

    // 获取最终结果
    const result = this.speechService.lastResult;
    if (result) {
      this.recognizedText = result.text;
      this.textInput = result.text;
      this.confidence = result.confidence;
      this.onRecognitionResult(result.text, result.confidence);
      this.onTextChanged(result.text);
    }

    // 延迟重置处理状态
    if (this.speechTimer !== -1) {
      clearTimeout(this.speechTimer);
    }
    this.speechTimer = setTimeout(() => {
      this.isRecognizing = false;
      this.recognitionState = SpeechRecognitionState.IDLE;
    }, 1000);
  }
}
