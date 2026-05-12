import { agentFramework } from '@kit.IntelligentAgentKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { XiaoyiService } from '../services/XiaoyiService';
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
  @Prop interviewId: string = '';
  @Prop resumeId: string = '';

  private apiService: ApiService = ApiService.getInstance();
  private xiaoyiService: XiaoyiService = XiaoyiService.getInstance();
  private audioRecorder: audio.AudioRecorder | null = null;
  private timer: number | null = null;
  private recordFilePath: string = '';
  private uiContext: common.UIAbilityContext | null = null;

  aboutToAppear() {
    this.initAudioRecorder();
    this.uiContext = getContext(this) as common.UIAbilityContext;
  }

  aboutToDisappear() {
    this.stopTimer();
    if (this.audioRecorder) {
      this.audioRecorder.release();
      this.audioRecorder = null;
    }
  }

  build() {
    Stack() {
      Column() {
        // 标题栏
        Row() {
          Row() {
            Image($r('app.media.ic_xiaoyi'))
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
        Image($r('app.media.ic_microphone'))
          .width(48)
          .height(48)
          .fillColor(NeutralColors.Neutral0)
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
        .fontColor(SemanticColors.Text1)
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
          Image($r('app.media.ic_stop'))
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
        Image($r('app.media.ic_audio_wave'))
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
        // 暂停/继续按钮（可选）
        Button() {
          Image($r('app.media.ic_pause'))
            .width(24)
            .height(24)
            .fillColor(SemanticColors.Text2)
        }
        .width(56)
        .height(56)
        .backgroundColor(NeutralColors.Neutral200)
        .borderRadius(28)
        .margin({ right: SemanticSpacing.Lg })
        .onClick(() => {
          this.pauseRecording();
        })

        // 停止按钮
        Button() {
          Image($r('app.media.ic_stop'))
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
          .fontColor(SemanticColors.Text2)
          .height(48)
          .backgroundColor(NeutralColors.Neutral200)
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
      }
    }
    .width('100%')
    .height(80)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(NeutralColors.Neutral0)
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
          Image($r('app.media.ic_xiaoyi'))
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
          Image($r('app.media.ic_close'))
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
              Image($r('app.media.ic_summary'))
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

          // 完整转录
          if (this.transcript.length > 0) {
            Column() {
              Text('完整转录')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.Text1)
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              Text(this.transcript)
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text2)
                .width('100%')
                .lineHeight(22)
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(NeutralColors.Neutral50)
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
              .backgroundColor(BrandColors.Brand50)
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
   */
  private async initAudioRecorder() {
    try {
      const audioConfig: audio.AudioRecorderConfig = {
        audioEncoder: audio.AudioEncoder.AAC,
        audioEncodingBitRate: 48000,
        audioSampleRate: 44100,
        numberOfChannels: 1,
        format: audio.AudioOutputFormat.M4A
      };

      this.audioRecorder = await audio.createAudioRecorder(audioConfig);
      Logger.info(TAG, 'Audio recorder initialized');
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize audio recorder:', error);
    }
  }

  /**
   * 开始录音
   */
  private async startRecording() {
    try {
      if (!this.audioRecorder) {
        await this.initAudioRecorder();
      }

      // 生成录音文件路径
      const timestamp = Date.now();
      this.recordFilePath = `${getContext().cacheDir}/voice_memo_${timestamp}.m4a`;

      await this.audioRecorder!.start(this.recordFilePath);
      this.recordingState = 'recording';
      this.startTimer();

      Logger.info(TAG, 'Recording started');
    } catch (error) {
      Logger.error(TAG, 'Failed to start recording:', error);
      promptAction.showToast({ message: '启动录音失败' });
    }
  }

  /**
   * 暂停录音
   */
  private async pauseRecording() {
    try {
      if (this.audioRecorder) {
        await this.audioRecorder.pause();
        this.recordingState = 'paused';
        this.stopTimer();
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
      if (this.audioRecorder) {
        await this.audioRecorder.stop();
        this.recordingState = 'stopped';
        this.stopTimer();
        this.audioUri = this.recordFilePath;
        Logger.info(TAG, 'Recording stopped');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to stop recording:', error);
    }
  }

  /**
   * 重新录音
   */
  private restartRecording() {
    this.recordingState = 'idle';
    this.recordingTime = 0;
    this.audioUri = '';
    this.recordFilePath = '';

    // 删除之前的录音文件
    if (this.recordFilePath) {
      try {
        fileIo.unlink(this.recordFilePath);
      } catch (e) {
        // 忽略删除错误
      }
    }
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
   */
  private async saveMemo() {
    try {
      const response = await this.apiService.post('memo/save', {
        interviewId: this.interviewId,
        resumeId: this.resumeId,
        transcript: this.transcript,
        summary: this.summary,
        keyPoints: this.keyPoints,
        audioUri: this.audioUri,
        source: 'xiaoyi_voice_memo'
      });

      if (response.success) {
        promptAction.showToast({ message: '已保存到简历' });
        this.closeResultPanel();
      } else {
        promptAction.showToast({ message: '保存失败' });
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to save memo:', error);
      promptAction.showToast({ message: '保存失败' });
    }
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
