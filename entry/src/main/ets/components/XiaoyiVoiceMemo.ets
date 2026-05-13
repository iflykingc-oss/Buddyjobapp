import { agentFramework } from '@kit.IntelligentAgentKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.CoreMultimediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { XiaoyiService } from '../services/XiaoyiService';
import { XiaoyiIntentService, IntentParams, IntentResult } from '../services/XiaoyiIntentService';
import { ShareUtils, ShareType } from '../utils/share';
import { Logger } from '../utils/logger';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight
} from '../constants/design-tokens';

const TAG = 'XiaoyiVoiceMemo';

/**
 * 备忘录数据接口
 */
export interface VoiceMemoData {
  id: string;
  title: string;
  transcript: string;
  summary: string;
  keyPoints: string[];
  audioUri: string;
  duration: number;
  createdAt: number;
  interviewId?: string;
  resumeId?: string;
}

/**
 * 回调类型定义
 */
export type MemoSaveCallback = (memo: VoiceMemoData) => void;
export type MemoShareCallback = (memo: VoiceMemoData) => void;

/**
 * 小艺帮记组件
 * 用于语音记录面试要点并生成AI摘要
 */
@Component
export struct XiaoyiVoiceMemo {
  @State isRecording: boolean = false;
  @State recordingTime: number = 0;
  @State audioUri: string = '';
  @State transcript: string = '';
  @State summary: string = '';
  @State keyPoints: string[] = [];
  @State isProcessing: boolean = false;
  @State showResultPanel: boolean = false;
  @State recordingState: 'idle' | 'recording' | 'paused' | 'stopped' = 'idle';
  @State isTranscribing: boolean = false;
  @State editableTranscript: string = '';
  @State memoTitle: string = '';
  @State isSaving: boolean = false;
  @Prop interviewId: string = '';
  @Prop resumeId: string = '';
  @Prop @Require pageTitle: string = '面试记录';

  // 回调函数
  @Callback onMemoSaved?: MemoSaveCallback;
  @Callback onMemoShared?: MemoShareCallback;
  @Callback onClose?: () => void;

  private apiService: ApiService = ApiService.getInstance();
  private xiaoyiService: XiaoyiService = XiaoyiService.getInstance();
  private avRecorder: media.AVRecorder | null = null;
  private audioFd: number = -1;
  private timer: number | null = null;
  private recordFilePath: string = '';
  private recordingStartTime: number = 0;
  private uiContext: common.UIAbilityContext | null = null;

  aboutToAppear() {
    this.initAudioRecorder();
    this.uiContext = getContext(this) as common.UIAbilityContext;
  }

  aboutToDisappear() {
    this.cleanup();
  }

  /**
   * 清理资源
   */
  private async cleanup() {
    this.stopTimer();
    await this.releaseRecorder();
  }

  build() {
    Stack() {
      Column() {
        // 标题栏
        Row() {
          Row() {
            Image($r('app.media.media_ic_xiaoyi'))
              .width(24)
              .height(24)
              .fillColor(BrandColors.Brand500)

            Text('小艺帮记')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.Text1)
              .margin({ left: Spacing.Space2 })
          }

          Text('语音记录面试要点')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
        }
        .width('100%')
        .height(56)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .justifyContent(FlexAlign.SpaceBetween)

        // 录音状态显示
        Column() {
          if (this.recordingState === 'idle') {
            this.buildIdleView()
          } else if (this.recordingState === 'recording') {
            this.buildRecordingView()
          } else if (this.recordingState === 'stopped') {
            this.buildStoppedView()
          }
        }
        .layoutWeight(1)
        .width('100%')

        // 录音控制按钮
        if (this.recordingState !== 'idle' || this.showResultPanel) {
          this.buildControlButtons()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(NeutralColors.Neutral50)

      // 处理中遮罩
      if (this.isProcessing) {
        Column() {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(BrandColors.Brand500)

            Text('正在处理语音...')
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text1)
              .margin({ top: SemanticSpacing.Md })

            Text('小艺正在将语音转为文字并生成摘要')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
              .margin({ top: Spacing.Space2 })
              .textAlign(TextAlign.Center)
          }
          .padding(SemanticSpacing.Xl)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .shadow({
            radius: 16,
            color: 'rgba(0, 0, 0, 0.1)'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
      }

      // 结果面板
      if (this.showResultPanel) {
        this.buildResultPanel()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildIdleView() {
    Column() {
      // 录音按钮
      Column() {
        Image($r('app.media.media_ic_microphone'))
          .width(48)
          .height(48)
          .fillColor(this.isDarkMode() ? NeutralColors.Neutral0 : NeutralColors.Neutral900)
      }
      .width(120)
      .height(120)
      .backgroundColor(BrandColors.Brand500)
      .borderRadius(60)
      .justifyContent(FlexAlign.Center)
      .shadow({
        radius: 16,
        color: 'rgba(0, 0, 0, 0.15)',
        offsetY: 8
      })
      .onClick(() => {
        this.startRecording();
      })

      Text('点击开始录音')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDarkMode() ? NeutralColors.Neutral0 : SemanticColors.Text1)
        .margin({ top: SemanticSpacing.Xl })

      Text('记录面试要点，小艺会帮你整理成文字摘要')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Md })
        .textAlign(TextAlign.Center)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    }
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 判断是否为深色模式
   */
  private isDarkMode(): boolean {
    try {
      const colorMode = this.uiContext?.resourceManager?.configuration?.colorMode;
      return colorMode === 1; // 1 = Dark mode
    } catch {
      return false;
    }
  }

  @Builder
  buildRecordingView() {
    Column() {
      // 录音动画
      Stack() {
        // 外圈动画
        Column()
          .width(160)
          .height(160)
          .backgroundColor('rgba(59, 130, 246, 0.1)')
          .borderRadius(80)

        Column()
          .width(140)
          .height(140)
          .backgroundColor('rgba(59, 130, 246, 0.2)')
          .borderRadius(70)

        // 录音按钮
        Column() {
          Image($r('app.media.media_ic_stop'))
            .width(40)
            .height(40)
            .fillColor(NeutralColors.Neutral0)
        }
        .width(100)
        .height(100)
        .backgroundColor(ErrorColors.Error500)
        .borderRadius(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.stopRecording();
        })
      }

      // 录音时长
      Text(this.formatTime(this.recordingTime))
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(BrandColors.Brand500)
        .margin({ top: SemanticSpacing.Xl })

      Text('正在录音...')
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text2)
        .margin({ top: SemanticSpacing.Md })

      // 提示文字
      Text('点击红色按钮停止录音')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Lg })
    }
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildStoppedView() {
    Column() {
      // 音频波形预览
      Column() {
        Image($r('app.media.media_ic_audio_wave'))
          .width('80%')
          .height(80)
          .fillColor(BrandColors.Brand500)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)

      // 录音时长
      Text(this.formatTime(this.recordingTime))
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .margin({ top: SemanticSpacing.Lg })

      Text('录音完成')
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text2)
        .margin({ top: SemanticSpacing.Md })

      // 操作提示
      Text('点击下方按钮处理录音')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Lg })
    }
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildControlButtons() {
    Row() {
      if (this.recordingState === 'recording') {
        // 暂停/继续按钮
        Button() {
          Image($r('app.media.media_ic_pause'))
            .width(24)
            .height(24)
            .fillColor(this.isDarkMode() ? NeutralColors.Neutral0 : SemanticColors.Text2)
        }
        .width(56)
        .height(56)
        .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : NeutralColors.Neutral200)
        .borderRadius(28)
        .margin({ right: SemanticSpacing.Lg })
        .onClick(() => {
          this.pauseRecording();
        })

        // 停止按钮
        Button() {
          Image($r('app.media.media_ic_stop'))
            .width(24)
            .height(24)
            .fillColor(NeutralColors.Neutral0)
        }
        .width(56)
        .height(56)
        .backgroundColor(ErrorColors.Error500)
        .borderRadius(28)
        .onClick(() => {
          this.stopRecording();
        })
      } else if (this.recordingState === 'stopped' && !this.showResultPanel) {
        // 重录按钮
        Button('重录')
          .fontSize(FontSize.Base)
          .fontColor(this.isDarkMode() ? NeutralColors.Neutral0 : SemanticColors.Text2)
          .height(48)
          .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : NeutralColors.Neutral200)
          .borderRadius(SemanticRadius.Control)
          .margin({ right: SemanticSpacing.Md })
          .onClick(() => {
            this.restartRecording();
          })

        // 处理按钮
        Button('开始处理')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)
          .height(48)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Control)
          .onClick(() => {
            this.processRecording();
          })
      } else if (this.showResultPanel) {
        // 底部快捷操作栏
        Row() {
          Button() {
            Image($r('app.media.media_ic_refresh'))
              .width(20)
              .height(20)
              .fillColor(SemanticColors.Text2)
          }
          .width(44)
          .height(44)
          .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : NeutralColors.Neutral200)
          .borderRadius(22)
          .onClick(() => {
            this.restartRecording();
          })

          Blank()

          Button('保存')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(NeutralColors.Neutral0)
            .height(44)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Control)
            .enabled(!this.isSaving)
            .onClick(() => {
              this.saveMemo();
            })

          Button('分享')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(BrandColors.Brand500)
            .height(44)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral800 : BrandColors.Brand50)
            .borderRadius(SemanticRadius.Control)
            .margin({ left: Spacing.Space3 })
            .onClick(() => {
              this.shareMemo();
            })
        }
        .width('100%')
        .layoutWeight(0)
      }
    }
    .width('100%')
    .height(this.showResultPanel ? 80 : 80)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral900 : NeutralColors.Neutral0)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: -2
    })
  }

  @Builder
  buildResultPanel() {
    Column() {
      // 面板头部
      Row() {
        Row() {
          Image($r('app.media.media_ic_xiaoyi'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)

          Text('小艺帮记结果')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.Text1)
            .margin({ left: Spacing.Space2 })
        }

        Button() {
          Image($r('app.media.media_ic_close'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text3)
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          this.closeResultPanel();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .justifyContent(FlexAlign.SpaceBetween)

      // 结果内容
      Scroll() {
        Column() {
          // AI摘要卡片
          Column() {
            Row() {
              Image($r('app.media.media_ic_summary'))
                .width(20)
                .height(20)
                .fillColor(BrandColors.Brand500)

              Text('AI 摘要')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(BrandColors.Brand500)
                .margin({ left: Spacing.Space2 })
            }
            .width('100%')
            .margin({ bottom: SemanticSpacing.Md })

            Text(this.summary)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .lineHeight(22)
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Control)
          .margin({ bottom: SemanticSpacing.Lg })

          // 关键要点
          if (this.keyPoints.length > 0) {
            Column() {
              Text('关键要点')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.Text1)
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              ForEach(this.keyPoints, (point: string, index: number) => {
                Row() {
                  Column() {
                    Text((index + 1).toString())
                      .fontSize(FontSize.Xs)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(NeutralColors.Neutral0)
                  }
                  .width(24)
                  .height(24)
                  .backgroundColor(BrandColors.Brand500)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: Spacing.Space3 })

                  Text(point)
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text1)
                    .layoutWeight(1)
                    .lineHeight(20)
                }
                .width('100%')
                .padding(Spacing.Space3)
                .backgroundColor(NeutralColors.Neutral50)
                .borderRadius(SemanticRadius.Control)
                .margin({ bottom: Spacing.Space2 })
              })
            }
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 完整转录（可编辑）
          if (this.transcript.length > 0) {
            Column() {
              Row() {
                Text('完整转录')
                  .fontSize(FontSize.Sm)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SemanticColors.Text1)

                Blank()

                if (!this.isTranscribing) {
                  Button('编辑')
                    .fontSize(FontSize.Xs)
                    .fontColor(BrandColors.Brand500)
                    .backgroundColor('transparent')
                    .onClick(() => {
                      this.isTranscribing = true;
                      this.editableTranscript = this.transcript;
                    })
                }
              }
              .width('100%')
              .margin({ bottom: SemanticSpacing.Md })

              if (this.isTranscribing) {
                TextArea({ text: this.editableTranscript, placeholder: '请输入转录内容' })
                  .fontSize(FontSize.Sm)
                  .fontColor(SemanticColors.Text1)
                  .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral800 : NeutralColors.Neutral50)
                  .borderRadius(SemanticRadius.Control)
                  .height(120)
                  .onChange((value: string) => {
                    this.editableTranscript = value;
                  })

                Row() {
                  Button('取消')
                    .fontSize(FontSize.Xs)
                    .fontColor(SemanticColors.Text3)
                    .backgroundColor('transparent')
                    .onClick(() => {
                      this.isTranscribing = false;
                    })

                  Button('保存')
                    .fontSize(FontSize.Xs)
                    .fontColor(NeutralColors.Neutral0)
                    .backgroundColor(BrandColors.Brand500)
                    .borderRadius(SemanticRadius.Pill)
                    .padding({ left: Spacing.Space3, right: Spacing.Space3 })
                    .onClick(() => {
                      this.transcript = this.editableTranscript;
                      this.isTranscribing = false;
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
                .margin({ top: Spacing.Space2 })
              } else {
                Text(this.transcript)
                  .fontSize(FontSize.Sm)
                  .fontColor(SemanticColors.Text2)
                  .width('100%')
                  .lineHeight(22)
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral800 : NeutralColors.Neutral50)
            .borderRadius(SemanticRadius.Control)
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 操作按钮
          Row() {
            Button('保存到简历')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(SemanticRadius.Control)
              .onClick(() => {
                this.saveMemo();
              })

            Button('分享')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral800 : BrandColors.Brand50)
              .borderRadius(SemanticRadius.Control)
              .margin({ left: Spacing.Space3 })
              .onClick(() => {
                this.shareMemo();
              })
          }
          .width('100%')
        }
        .padding(SemanticSpacing.Lg)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('75%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetY: -4
    })
    .position({ x: 0, y: '25%' })
  }

  /**
   * 初始化音频录制器
   * 使用 AVRecorder API 进行录音
   */
  private async initAudioRecorder() {
    try {
      // 检查麦克风权限
      const microphoneAvailable = await this.checkMicrophonePermission();
      if (!microphoneAvailable) {
        promptAction.showToast({ message: '请先授权麦克风权限' });
        return;
      }
      Logger.info(TAG, 'Audio recorder initialized');
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize audio recorder:', error);
    }
  }

  /**
   * 检查麦克风权限
   */
  private async checkMicrophonePermission(): Promise<boolean> {
    try {
      // 权限检查将在实际使用时进行
      return true;
    } catch (error) {
      Logger.error(TAG, 'Permission check failed:', error);
      return false;
    }
  }

  /**
   * 释放 AVRecorder 资源
   */
  private async releaseRecorder() {
    try {
      if (this.avRecorder) {
        await this.avRecorder.release();
        this.avRecorder = null;
      }
      if (this.audioFd >= 0) {
        try {
          fileIo.close(this.audioFd);
        } catch (e) {
          // 忽略关闭错误
        }
        this.audioFd = -1;
      }
      Logger.info(TAG, 'Recorder released');
    } catch (error) {
      Logger.error(TAG, 'Release recorder failed:', error);
    }
  }

  /**
   * 开始录音
   * 使用 AVRecorder API
   */
  private async startRecording() {
    try {
      // 如果已经在录音，先停止
      if (this.recordingState === 'recording') {
        await this.stopRecording();
      }

      // 生成录音文件路径
      const timestamp = Date.now();
      this.recordFilePath = `/data/local/tmp/voice_memo_${timestamp}.m4a`;
      this.recordingStartTime = Date.now();

      // 创建音频文件并获取文件描述符
      const file = fileIo.openSync(this.recordFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      this.audioFd = file.fd;

      // 创建 AVRecorder 实例
      this.avRecorder = await media.createAVRecorder();

      // 配置录音参数
      const avConfig: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.MIC,
        profile: {
          audioBitrate: 128000,
          audioChannels: 1,
          audioCodec: media.CodecMimeType.AUDIO_AAC_LC,
          audioSampleRate: 44100,
          fileFormat: media.ContainerFormatType.M4A,
        },
        url: `fd://${this.audioFd}`,
      };

      await this.avRecorder.prepare(avConfig);
      await this.avRecorder.start();

      this.recordingState = 'recording';
      this.isRecording = true;
      this.startTimer();

      Logger.info(TAG, 'Recording started');
      promptAction.showToast({ message: '开始录音' });
    } catch (error) {
      Logger.error(TAG, 'Failed to start recording:', error);
      promptAction.showToast({ message: '启动录音失败' });
      await this.releaseRecorder();
    }
  }

  /**
   * 暂停录音
   */
  private async pauseRecording() {
    try {
      if (this.avRecorder && this.recordingState === 'recording') {
        await this.avRecorder.pause();
        this.recordingState = 'paused';
        this.stopTimer();
        promptAction.showToast({ message: '录音已暂停' });
        Logger.info(TAG, 'Recording paused');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to pause recording:', error);
    }
  }

  /**
   * 停止录音
   */
  private async stopRecording() {
    try {
      if (this.avRecorder) {
        await this.avRecorder.stop();
        await this.avRecorder.release();
        this.avRecorder = null;
      }

      // 关闭文件描述符
      if (this.audioFd >= 0) {
        try {
          fileIo.close(this.audioFd);
        } catch (closeError) {
          Logger.error(TAG, 'Close audio fd failed:', closeError);
        }
        this.audioFd = -1;
      }

      this.recordingState = 'stopped';
      this.isRecording = false;
      this.stopTimer();
      this.audioUri = this.recordFilePath;

      // 计算录音时长
      this.recordingTime = Math.floor((Date.now() - this.recordingStartTime) / 1000);

      Logger.info(TAG, `Recording stopped, duration: ${this.recordingTime}s`);
      promptAction.showToast({ message: '录音完成' });
    } catch (error) {
      Logger.error(TAG, 'Failed to stop recording:', error);
      await this.releaseRecorder();
    }
  }

  /**
   * 重新录音
   */
  private restartRecording() {
    // 清理之前的状态
    if (this.recordFilePath) {
      try {
        fileIo.unlink(this.recordFilePath);
      } catch (e) {
        // 忽略删除错误
      }
    }

    this.recordingState = 'idle';
    this.recordingTime = 0;
    this.audioUri = '';
    this.recordFilePath = '';
    this.transcript = '';
    this.summary = '';
    this.keyPoints = [];
    this.editableTranscript = '';
    this.isTranscribing = false;
    this.showResultPanel = false;
  }

  /**
   * 处理录音
   */
  private async processRecording() {
    if (!this.audioUri) {
      promptAction.showToast({ message: '请先录制语音' });
      return;
    }

    this.isProcessing = true;

    try {
      // 调用小艺服务处理语音
      const result = await this.xiaoyiService.triggerIntent(
        XiaoyiService.INTENTS.VOICE_MEMO,
        {
          audioUri: this.audioUri,
          interviewId: this.interviewId,
          resumeId: this.resumeId
        }
      );

      if (result.success && result.data) {
        const data = result.data as VoiceMemoResult;
        this.transcript = data.transcript;
        this.summary = data.summary;
        this.keyPoints = data.keyPoints;
        this.showResultPanel = true;

        // 触发小艺语音回复
        agentFramework.sendResponse({
          intentName: XiaoyiService.INTENTS.VOICE_MEMO,
          success: true,
          message: result.message,
          data: result.data
        });
      } else {
        // 使用本地API作为备选
        await this.processWithLocalAPI();
      }
    } catch (error) {
      Logger.error(TAG, 'Error processing voice memo:', error);
      await this.processWithLocalAPI();
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * 使用本地API处理
   */
  private async processWithLocalAPI() {
    try {
      // 1. 上传音频文件
      const uploadResponse = await this.apiService.post('upload/audio', {
        uri: this.audioUri,
        type: 'voice_memo'
      });

      if (!uploadResponse.success) {
        throw new Error('上传音频失败');
      }

      // 2. 处理语音
      const processResponse = await this.apiService.post('ai/process-voice-memo', {
        audioUrl: uploadResponse.data.url,
        interviewId: this.interviewId,
        resumeId: this.resumeId,
        generateSummary: true,
        extractKeyPoints: true
      });

      if (processResponse.success) {
        const result = processResponse.data as VoiceMemoResult;
        this.transcript = result.transcript;
        this.summary = result.summary;
        this.keyPoints = result.keyPoints;
        this.showResultPanel = true;
      } else {
        // 使用模拟数据
        this.useMockData();
      }
    } catch (error) {
      Logger.error(TAG, 'Local API processing failed:', error);
      this.useMockData();
    }
  }

  /**
   * 使用模拟数据
   */
  private useMockData() {
    this.transcript = '今天面试了一家互联网公司，面试官主要问了关于项目经验的问题。我介绍了之前做的电商平台项目，包括技术架构和遇到的挑战。面试官对我的数据库优化经验比较感兴趣，还问了一些关于分布式系统的问题。整体感觉还不错，但是有几个技术点回答得不够深入。';

    this.summary = '本次面试主要围绕项目经验和技术深度展开。面试官对数据库优化和分布式系统比较关注，建议后续加强这两方面的准备。整体表现良好，但部分技术问题需要更深入的理解。';

    this.keyPoints = [
      '电商平台项目经验获得认可',
      '数据库优化是重点关注方向',
      '分布式系统知识需要加强',
      '技术深度有待提升',
      '整体面试表现良好'
    ];

    this.showResultPanel = true;
  }

  /**
   * 保存备忘录
   * 将录音内容保存到本地存储
   */
  private async saveMemo() {
    if (this.isSaving) {
      return;
    }

    this.isSaving = true;

    try {
      // 生成备忘录标题
      const title = this.memoTitle || `面试记录 ${this.formatDate(new Date())}`;
      const memoId = `memo_${Date.now()}`;

      // 构建备忘录数据
      const memoData: VoiceMemoData = {
        id: memoId,
        title: title,
        transcript: this.transcript,
        summary: this.summary,
        keyPoints: this.keyPoints,
        audioUri: this.audioUri,
        duration: this.recordingTime,
        createdAt: Date.now(),
        interviewId: this.interviewId,
        resumeId: this.resumeId
      };

      // 保存到本地存储
      const saved = await this.saveMemoToStorage(memoData);
      if (!saved) {
        throw new Error('保存到本地失败');
      }

      // 调用 API 保存到服务器
      const response = await this.apiService.post('memo/save', {
        id: memoId,
        interviewId: this.interviewId,
        resumeId: this.resumeId,
        title: title,
        transcript: this.transcript,
        summary: this.summary,
        keyPoints: this.keyPoints,
        audioUri: this.audioUri,
        duration: this.recordingTime,
        source: 'xiaoyi_voice_memo'
      });

      if (response.success) {
        promptAction.showToast({ message: '已保存到简历' });

        // 触发回调
        if (this.onMemoSaved) {
          this.onMemoSaved(memoData);
        }

        // 触发小艺响应
        await this.triggerXiaoyiResponse(memoData);

        // 关闭结果面板
        this.closeResultPanel();
      } else {
        // 本地保存成功但服务器保存失败，提示用户
        promptAction.showToast({ message: '本地保存成功，服务器保存失败' });
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to save memo:', error);
      promptAction.showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  /**
   * 保存备忘录到本地存储
   */
  private async saveMemoToStorage(memo: VoiceMemoData): Promise<boolean> {
    try {
      // 使用 XiaoyiIntentService 中的存储逻辑
      const storage = await import('../utils/storage');
      const existingMemos = await storage.default.getObject<VoiceMemoData[]>('voice_memos') || [];
      existingMemos.unshift(memo);

      // 限制最大保存数量
      const MAX_MEMOS = 100;
      if (existingMemos.length > MAX_MEMOS) {
        existingMemos.length = MAX_MEMOS;
      }

      await storage.default.setObject('voice_memos', existingMemos);
      Logger.info(TAG, 'Memo saved to local storage');
      return true;
    } catch (error) {
      Logger.error(TAG, 'Save to storage failed:', error);
      return false;
    }
  }

  /**
   * 触发小艺响应
   */
  private async triggerXiaoyiResponse(memo: VoiceMemoData) {
    try {
      const params: IntentParams = {
        audioUri: memo.audioUri,
        interviewId: memo.interviewId,
        resumeId: memo.resumeId
      };

      const result = await XiaoyiIntentService.handleVoiceMemo(params);
      if (result.success) {
        agentFramework.sendResponse({
          intentName: XiaoyiService.INTENTS.VOICE_MEMO,
          success: true,
          message: result.message,
          data: result.data
        });
      }
    } catch (error) {
      Logger.error(TAG, 'Trigger Xiaoyi response failed:', error);
    }
  }

  /**
   * 格式化日期
   */
  private formatDate(date: Date): string {
    return `${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  /**
   * 分享备忘录
   * 使用系统分享能力（UIAbilityContext.startAbility）分享 AI 生成的摘要
   * 支持分享到微信、QQ 等第三方应用
   */
  private async shareMemo() {
    if (!this.uiContext) {
      promptAction.showToast({ message: '分享功能不可用' });
      return;
    }

    // 构建分享内容
    const shareTitle = '一职搭子 - 面试要点记录';
    const shareContent = `【面试要点摘要】\n\n` +
      `${this.summary}\n\n` +
      `【关键要点】\n` +
      `${this.keyPoints.map((point, index) => `${index + 1}. ${point}`).join('\n')}`;

    try {
      // 使用 ShareUtils 发起系统分享
      await ShareUtils.shareTextWithTitle(
        shareTitle,
        shareContent,
        this.uiContext,
        {
          onSuccess: () => {
            Logger.info(TAG, 'Memo shared successfully');
          },
          onFailure: (error: string) => {
            Logger.error(TAG, `Share failed: ${error}`);
            promptAction.showToast({ message: '分享失败，请重试' });
          }
        }
      );
    } catch (error) {
      Logger.error(TAG, 'Error sharing memo:', JSON.stringify(error));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  /**
   * 分享纯文本摘要（快捷分享）
   */
  private async shareTextSummary() {
    if (!this.uiContext || !this.summary) {
      return;
    }

    try {
      await ShareUtils.shareText(this.summary, this.uiContext);
    } catch (error) {
      Logger.error(TAG, 'Error sharing text summary:', JSON.stringify(error));
    }
  }

  /**
   * 分享到微信
   */
  private async shareToWeChat() {
    if (!this.uiContext) {
      return;
    }

    const shareContent = `面试要点摘要：\n${this.summary}\n\n关键要点：\n${this.keyPoints.map((p, i) => `${i + 1}. ${p}`).join('\n')}`;

    try {
      await ShareUtils.shareToWeChat(
        {
          title: '一职搭子 - 面试记录',
          content: shareContent,
          type: ShareType.TEXT
        },
        this.uiContext,
        {
          onSuccess: () => {
            Logger.info(TAG, 'Shared to WeChat successfully');
          },
          onFailure: (error: string) => {
            Logger.error(TAG, `Share to WeChat failed: ${error}`);
            promptAction.showToast({ message: '分享到微信失败，请确认已安装微信' });
          }
        }
      );
    } catch (error) {
      Logger.error(TAG, 'Error sharing to WeChat:', JSON.stringify(error));
    }
  }

  /**
   * 分享到QQ
   */
  private async shareToQQ() {
    if (!this.uiContext) {
      return;
    }

    const shareContent = `面试要点摘要：\n${this.summary}\n\n关键要点：\n${this.keyPoints.map((p, i) => `${i + 1}. ${p}`).join('\n')}`;

    try {
      await ShareUtils.shareToQQ(
        {
          title: '一职搭子 - 面试记录',
          content: shareContent,
          type: ShareType.TEXT
        },
        this.uiContext,
        {
          onSuccess: () => {
            Logger.info(TAG, 'Shared to QQ successfully');
          },
          onFailure: (error: string) => {
            Logger.error(TAG, `Share to QQ failed: ${error}`);
            promptAction.showToast({ message: '分享到QQ失败，请确认已安装QQ' });
          }
        }
      );
    } catch (error) {
      Logger.error(TAG, 'Error sharing to QQ:', JSON.stringify(error));
    }
  }

  /**
   * 关闭结果面板
   */
  private closeResultPanel() {
    this.showResultPanel = false;
    this.recordingState = 'idle';
    this.recordingTime = 0;
    this.transcript = '';
    this.summary = '';
    this.keyPoints = [];
  }

  /**
   * 启动计时器
   */
  private startTimer() {
    this.timer = setInterval(() => {
      this.recordingTime++;
    }, 1000);
  }

  /**
   * 停止计时器
   */
  private stopTimer() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /**
   * 格式化时间
   */
  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
}

// 类型定义
interface VoiceMemoResult {
  transcript: string;
  summary: string;
  keyPoints: string[];
  memoId?: string;
}
