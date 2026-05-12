/**
 * 语音输入按钮组件
 *
 * 支持长按录音、录音波形动画、语音识别结果展示
 * 遵循鸿蒙设计规范
 */
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
  Duration
} from '../../constants/design-tokens';

// 波形数据
interface WaveBar {
  height: number;
  delay: number;
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

  // 内部状态
  @State private waveBars: WaveBar[] = [];
  @State private animationProgress: number = 0;
  @State private isPressed: boolean = false;
  @State private inputMode: 'voice' | 'text' = 'voice';
  @State private textInput: string = '';

  // 波形动画定时器
  private waveAnimationTimer: number = -1;
  private durationTimer: number = -1;

  aboutToAppear() {
    this.initWaveBars();
  }

  aboutToDisappear() {
    this.stopWaveAnimation();
    if (this.durationTimer !== -1) {
      clearInterval(this.durationTimer);
    }
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
        const maxHeight = 24;
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
      if (this.recognizedText || this.textInput) {
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
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral0)
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

        // 清除按钮
        Text('清除')
          .fontSize(FontSize.Xs)
          .fontColor(BrandColors.Brand500)
          .onClick(() => {
            this.textInput = '';
            this.onTextChanged('');
          })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space2 })

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
          .fillColor(SemanticColors.Text2)
      }
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor(NeutralColors.Neutral100)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.inputMode = this.inputMode === 'voice' ? 'text' : 'voice';
    })
  }

  /**
   * 语音输入按钮
   */
  @Builder
  VoiceButton() {
    Row() {
      if (this.isRecording) {
        // 录音中状态
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
      } else if (this.isProcessing) {
        // 处理中状态
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(NeutralColors.Neutral0)

          Text('识别中...')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .margin({ left: Spacing.Space3 })
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(BrandColors.Brand400)
        .borderRadius(SemanticRadius.Pill)
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })
      } else {
        // 待录音状态 - 长按录音按钮
        Column() {
          Row() {
            Image($r('app.media.ic_microphone'))
              .width(20)
              .height(20)
              .fillColor(NeutralColors.Neutral0)

            Text('按住说话')
              .fontSize(FontSize.Sm)
              .fontColor(NeutralColors.Neutral0)
              .margin({ left: Spacing.Space3 })
          }
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(this.isPressed ? BrandColors.Brand600 : BrandColors.Brand500)
        .borderRadius(SemanticRadius.Pill)
        .justifyContent(FlexAlign.Center)
        .margin({ left: Spacing.Space3 })
        .gesture(
          LongPressGesture({ repeat: false })
            .onAction(() => {
              this.isPressed = true;
              this.startWaveAnimation();
              this.onStartRecording();
            })
            .onActionEnd(() => {
              this.isPressed = false;
              this.stopWaveAnimation();
              this.onStopRecording();
            })
        )
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isPressed = false;
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
}

// 错误色（用于录音状态）
const ErrorColors = {
  Error500: '#E84026'
};
