import file from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import { ResumeAnalysisResult, Dimension, Suggestion } from '../models/Resume';
import { ChatService } from '../services/ChatService';
import { HistoryService } from '../services/HistoryService';
import { PageStateSync, ResumePageState } from '../utils/distributed';
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
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';

// 错误类型枚举
enum AnalysisErrorType {
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT_ERROR = 'TIMEOUT_ERROR',
  FILE_FORMAT_ERROR = 'FILE_FORMAT_ERROR',
  FILE_SIZE_ERROR = 'FILE_SIZE_ERROR',
  SERVER_ERROR = 'SERVER_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR'
}

// 错误信息接口
interface AnalysisError {
  type: AnalysisErrorType;
  message: string;
  suggestion: string;
}

@Component
export struct ResumePage {
  @State hasResume: boolean = false;
  @State analysisResult: ResumeAnalysisResult | null = null;
  @State isLoading: boolean = false;
  @State isDragging: boolean = false;
  @State selectedFileName: string = '';
  @State resumeContent: string = '';
  @State isEditing: boolean = false;
  @State isContinueRestore: boolean = false;
  // 错误处理相关状态
  @State hasError: boolean = false;
  @State errorInfo: AnalysisError | null = null;
  @State isCancelling: boolean = false;
  @State analysisProgress: number = 0;
  @State progressText: string = '正在上传文件...';
  // 保存当前文件以便重试
  private currentFile: file.File | null = null;
  // 进度模拟定时器
  private progressTimer: number = -1;
  // 超时定时器
  private timeoutTimer: number = -1;
  // 超时时间（毫秒）
  private readonly ANALYSIS_TIMEOUT = 60000;

  private chatService: ChatService = ChatService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private pageStateSync: PageStateSync = new PageStateSync('pages/Resume');

  aboutToAppear() {
    // 注册当前页面
    AppStorage.setOrCreate('currentPage', 'pages/Resume');

    // 检查是否是跨设备流转恢复
    this.checkContinueRestore();

    // 开始自动同步页面状态
    this.pageStateSync.startAutoSync(() => this.getCurrentState());

    // 监听跨设备流转恢复事件
    const eventHub = getContext(this).eventHub;
    eventHub.on('onContinueRestore', (data) => {
      this.handleContinueRestore(data);
    });
  }

  aboutToDisappear() {
    // 停止自动同步
    this.pageStateSync.stopAutoSync();

    // 移除事件监听
    const eventHub = getContext(this).eventHub;
    eventHub.off('onContinueRestore');

    // 清理定时器
    this.clearTimers();
  }

  /**
   * 清理所有定时器
   */
  private clearTimers(): void {
    if (this.progressTimer !== -1) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
    if (this.timeoutTimer !== -1) {
      clearTimeout(this.timeoutTimer);
      this.timeoutTimer = -1;
    }
  }

  /**
   * 检查是否是跨设备流转恢复
   */
  private checkContinueRestore(): void {
    const isContinueRestore = AppStorage.get<boolean>('isContinueRestore') || false;
    const continueData = AppStorage.get<Record<string, any>>('continueData');

    if (isContinueRestore && continueData) {
      this.handleContinueRestore(continueData);
    }
  }

  /**
   * 处理跨设备流转恢复
   */
  private handleContinueRestore(data: Record<string, any>): void {
    console.log('[ResumePage] Handling continue restore:', JSON.stringify(data));

    if (data.pageUrl === 'pages/Resume' && data.pageState) {
      const state = data.pageState as ResumePageState;

      this.isContinueRestore = true;
      this.hasResume = state.hasResume || false;
      this.analysisResult = state.analysisResult || null;
      this.selectedFileName = state.selectedFileName || '';
      this.resumeContent = state.resumeContent || '';
      this.isEditing = state.isEditing || false;

      // 更新全局页面状态
      this.updateGlobalPageState();

      console.log('[ResumePage] State restored successfully');
    }
  }

  /**
   * 获取当前页面状态
   */
  private getCurrentState(): ResumePageState {
    return {
      hasResume: this.hasResume,
      analysisResult: this.analysisResult,
      selectedFileName: this.selectedFileName,
      resumeContent: this.resumeContent,
      isEditing: this.isEditing
    };
  }

  /**
   * 更新全局页面状态（用于跨设备流转）
   */
  private updateGlobalPageState(): void {
    const pageState = this.getCurrentState();
    AppStorage.setOrCreate('currentPageState', pageState);

    // 立即同步到分布式数据对象
    this.pageStateSync.syncState(pageState);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('简历分析')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)

        // 跨设备同步指示器
        if (this.isContinueRestore) {
          Row() {
            Image($r('app.media.ic_sync'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)

            Text('已同步')
              .fontSize(FontSize.Xs)
              .fontColor(BrandColors.Brand500)
              .margin({ left: Spacing.Space2 })
          }
          .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Pill)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })
      .justifyContent(FlexAlign.SpaceBetween)

      if (!this.hasResume) {
        // 上传区域
        this.buildUploadArea()
      } else if (this.isLoading) {
        // 加载状态
        this.buildLoadingView()
      } else if (this.hasError) {
        // 错误状态
        this.buildErrorView()
      } else if (this.analysisResult) {
        this.buildResultView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  @Builder
  buildUploadArea() {
    Column() {
      Column() {
        // 上传图标
        Column() {
          Image($r('app.media.ic_upload'))
            .width(48)
            .height(48)
            .fillColor(BrandColors.Brand400)
        }
        .width(80)
        .height(80)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(40)
        .justifyContent(FlexAlign.Center)

        Text('点击上传简历')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
          .margin({ top: SemanticSpacing.Lg })

        Text('支持 PDF、Word 格式，最大 10MB')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space3 })
      }
      .width(200)
      .height(200)
      .backgroundColor(this.isDragging ? BrandColors.Brand50 : NeutralColors.Neutral50)
      .borderRadius(SemanticRadius.Component)
      .border({
        width: 2,
        color: this.isDragging ? BrandColors.Brand500 : NeutralColors.Neutral200,
        style: BorderStyle.Dashed
      })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.pickFile();
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildLoadingView() {
    Column() {
      Column() {
        // 进度圆环
        Stack() {
          // 背景圆环
          Circle()
            .width(80)
            .height(80)
            .fill('transparent')
            .stroke(NeutralColors.Neutral200)
            .strokeWidth(6)

          // 进度圆环
          Circle()
            .width(80)
            .height(80)
            .fill('transparent')
            .stroke(BrandColors.Brand500)
            .strokeWidth(6)
            .strokeDashArray([this.analysisProgress / 100 * 251, 251]) // 251 是周长 (2 * PI * 40)
            .rotate({ angle: -90, centerX: '50%', centerY: '50%' })

          // 进度百分比
          Text(`${Math.floor(this.analysisProgress)}%`)
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(BrandColors.Brand500)
        }
        .width(80)
        .height(80)
      }
      .width(100)
      .height(100)
      .justifyContent(FlexAlign.Center)

      Text(this.progressText)
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text1)
        .margin({ top: SemanticSpacing.Lg })

      if (this.selectedFileName) {
        Text(this.selectedFileName)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('80%')
          .textAlign(TextAlign.Center)
      }

      // 取消按钮
      Button(this.isCancelling ? '取消中...' : '取消分析')
        .fontSize(FontSize.Sm)
        .fontColor(ErrorColors.Error500)
        .backgroundColor('transparent')
        .border({ width: 1, color: ErrorColors.Error500 })
        .borderRadius(SemanticRadius.Pill)
        .width(120)
        .height(40)
        .margin({ top: SemanticSpacing.Xl })
        .enabled(!this.isCancelling)
        .onClick(() => {
          this.cancelAnalysis();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildErrorView() {
    Column() {
      Column() {
        // 错误图标
        Column() {
          Image($r('app.media.ic_error'))
            .width(48)
            .height(48)
            .fillColor(ErrorColors.Error500)
        }
        .width(80)
        .height(80)
        .backgroundColor(ErrorColors.Error50)
        .borderRadius(40)
        .justifyContent(FlexAlign.Center)

        Text('分析失败')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .margin({ top: SemanticSpacing.Lg })

        // 错误详情
        if (this.errorInfo) {
          Text(this.errorInfo.message)
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text2)
            .margin({ top: Spacing.Space3 })
            .textAlign(TextAlign.Center)
            .width('80%')

          // 可能原因提示
          Column() {
            Text('可能的原因：')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            Text(this.getErrorCauses(this.errorInfo.type))
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .width('100%')
              .lineHeight(20)
          }
          .width('80%')
          .padding(Spacing.Space4)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .margin({ top: SemanticSpacing.Lg })

          // 解决建议
          Column() {
            Text('解决建议：')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            Text(this.errorInfo.suggestion)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .width('100%')
              .lineHeight(20)
          }
          .width('80%')
          .padding(Spacing.Space4)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Control)
          .margin({ top: Spacing.Space3 })
        }

        // 操作按钮组
        Row() {
          // 重试按钮
          Button('重新分析')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
            .width(120)
            .height(44)
            .onClick(() => {
              this.retryAnalysis();
            })

          // 重新上传按钮
          Button('重新上传')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .backgroundColor(NeutralColors.Neutral0)
            .border({ width: 1, color: BrandColors.Brand500 })
            .borderRadius(SemanticRadius.Pill)
            .width(120)
            .height(44)
            .margin({ left: Spacing.Space4 })
            .onClick(() => {
              this.resetResume();
            })
        }
        .margin({ top: SemanticSpacing.Xl })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildResultView() {
    Scroll() {
      Column() {
        // 流转提示卡片
        if (this.isContinueRestore) {
          Row() {
            Image($r('app.media.ic_info'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)

            Text('已从其他设备恢复简历数据')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .margin({ left: Spacing.Space3 })
              .layoutWeight(1)

            Button('知道了')
              .fontSize(FontSize.Xs)
              .fontColor(BrandColors.Brand500)
              .backgroundColor('transparent')
              .onClick(() => {
                this.isContinueRestore = false;
              })
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Component)
          .margin({ bottom: SemanticSpacing.Lg })
        }

        // ATS 评分卡片
        this.buildScoreCard()

        // 维度分析卡片
        this.buildDimensionCard()

        // 优化建议卡片
        this.buildSuggestionCard()

        // 关键词卡片
        this.buildKeywordCard()

        // 重新上传按钮
        Button('重新上传简历')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Pill)
          .border({ width: 1, color: BrandColors.Brand500 })
          .width('100%')
          .height(44)
          .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })
          .onClick(() => {
            this.resetResume();
          })
      }
      .padding(SemanticSpacing.Lg)
    }
    .layoutWeight(1)
  }

  @Builder
  buildScoreCard() {
    Column() {
      Text('ATS 评分')
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text2)
        .alignSelf(ItemAlign.Start)

      Text(this.analysisResult!.atsScore.toString())
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getScoreColor(this.analysisResult!.atsScore))
        .margin({ top: Spacing.Space3 })

      Text(this.getScoreLabel(this.analysisResult!.atsScore))
        .fontSize(FontSize.Base)
        .fontColor(this.getScoreColor(this.analysisResult!.atsScore))

      Text(this.analysisResult!.summary)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .margin({ top: SemanticSpacing.Lg })
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildDimensionCard() {
    Column() {
      Text('多维度分析')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      ForEach(this.analysisResult!.dimensions, (dim: Dimension, index: number) => {
        Column() {
          Row() {
            Text(dim.name)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .width(80)

            Stack() {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor(NeutralColors.Neutral200)
                .borderRadius(4)

              Row()
                .width(`${dim.score}%`)
                .height(8)
                .backgroundColor(this.getScoreColor(dim.score))
                .borderRadius(4)
            }
            .layoutWeight(1)
            .height(8)

            Text(dim.score.toString() + '分')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getScoreColor(dim.score))
              .width(40)
              .textAlign(TextAlign.End)
              .margin({ left: Spacing.Space4 })
          }
          .width('100%')

          Text(dim.description)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .width('100%')
            .margin({ top: Spacing.Space2 })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildSuggestionCard() {
    Column() {
      Text('优化建议')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      ForEach(this.analysisResult!.suggestions, (suggestion: Suggestion, index: number) => {
        Row() {
          Column() {
            Text(this.getSuggestionIcon(suggestion.type))
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Bold)
          }
          .width(32)
          .height(32)
          .backgroundColor(this.getSuggestionBgColor(suggestion.type))
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .margin({ right: Spacing.Space4 })

          Column() {
            Text(suggestion.title)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)

            Text(suggestion.description)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text2)
              .margin({ top: Spacing.Space2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(Spacing.Space4)
        .backgroundColor(NeutralColors.Neutral50)
        .borderRadius(SemanticRadius.Control)
        .margin({ bottom: Spacing.Space3 })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildKeywordCard() {
    Column() {
      Text('简历关键词')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.analysisResult!.keywords, (keyword: string) => {
          Text(keyword)
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space3, bottom: Spacing.Space3 })
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(SemanticRadius.Pill)
            .margin({ right: Spacing.Space3, bottom: Spacing.Space3 })
        })
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  getScoreLabel(score: number): string {
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    return '待优化';
  }

  getSuggestionIcon(type: string): string {
    switch (type) {
      case 'add': return '+';
      case 'modify': return '~';
      case 'delete': return '-';
      default: return '>';
    }
  }

  getSuggestionBgColor(type: string): string {
    switch (type) {
      case 'add': return SuccessColors.Success50;
      case 'modify': return WarningColors.Warning50;
      case 'delete': return ErrorColors.Error50;
      default: return NeutralColors.Neutral100;
    }
  }

  /**
   * 获取错误原因提示
   */
  private getErrorCauses(errorType: AnalysisErrorType): string {
    switch (errorType) {
      case AnalysisErrorType.NETWORK_ERROR:
        return '• 网络连接不稳定或已断开\n• 服务器暂时不可用\n• DNS 解析失败';
      case AnalysisErrorType.TIMEOUT_ERROR:
        return '• 网络速度较慢\n• 文件较大需要更长时间\n• 服务器响应延迟';
      case AnalysisErrorType.FILE_FORMAT_ERROR:
        return '• 文件格式不支持（仅支持 PDF、Word）\n• 文件已损坏\n• 文件内容无法解析';
      case AnalysisErrorType.FILE_SIZE_ERROR:
        return '• 文件超过 10MB 限制\n• 文件包含大量图片';
      case AnalysisErrorType.SERVER_ERROR:
        return '• 服务器内部错误\n• 服务暂时不可用\n• 系统维护中';
      default:
        return '• 未知错误，请稍后重试';
    }
  }

  /**
   * 解析错误类型
   */
  private parseError(error: any): AnalysisError {
    const errorMessage = error?.message || error?.toString() || '';
    const errorCode = error?.code || 0;

    // 网络错误检测
    if (errorMessage.includes('网络') ||
        errorMessage.includes('network') ||
        errorMessage.includes('connection') ||
        errorMessage.includes('ECONNREFUSED') ||
        errorMessage.includes('ENOTFOUND') ||
        errorCode === -1) {
      return {
        type: AnalysisErrorType.NETWORK_ERROR,
        message: '网络连接失败，无法连接到服务器',
        suggestion: '请检查您的网络连接是否正常，可以尝试切换 Wi-Fi 或移动数据网络，然后点击"重新分析"按钮重试。'
      };
    }

    // 超时错误检测
    if (errorMessage.includes('timeout') ||
        errorMessage.includes('超时') ||
        errorCode === 408) {
      return {
        type: AnalysisErrorType.TIMEOUT_ERROR,
        message: '分析请求超时，服务器响应时间过长',
        suggestion: '由于网络或文件较大导致超时，请检查网络后重试。如果文件较大，建议压缩后再上传。'
      };
    }

    // 文件格式错误
    if (errorMessage.includes('format') ||
        errorMessage.includes('格式') ||
        errorMessage.includes('unsupported') ||
        errorCode === 415) {
      return {
        type: AnalysisErrorType.FILE_FORMAT_ERROR,
        message: '文件格式不支持或文件已损坏',
        suggestion: '请确保上传的文件是 PDF 或 Word 格式（.pdf, .doc, .docx），且文件未损坏。'
      };
    }

    // 文件大小错误
    if (errorMessage.includes('size') ||
        errorMessage.includes('大小') ||
        errorMessage.includes('large') ||
        errorMessage.includes('too big') ||
        errorCode === 413) {
      return {
        type: AnalysisErrorType.FILE_SIZE_ERROR,
        message: '文件过大，超过系统限制',
        suggestion: '请确保文件大小不超过 10MB。如果文件较大，可以尝试压缩图片或删除不必要的内容后再上传。'
      };
    }

    // 服务器错误
    if (errorMessage.includes('server') ||
        errorMessage.includes('服务器') ||
        errorMessage.includes('500') ||
        errorMessage.includes('502') ||
        errorMessage.includes('503') ||
        errorCode >= 500) {
      return {
        type: AnalysisErrorType.SERVER_ERROR,
        message: '服务器暂时不可用，请稍后重试',
        suggestion: '服务器可能正在维护或暂时过载，请等待几分钟后点击"重新分析"按钮重试。'
      };
    }

    // 默认未知错误
    return {
      type: AnalysisErrorType.UNKNOWN_ERROR,
      message: '分析过程中发生错误：' + errorMessage,
      suggestion: '请检查网络连接和文件格式后重试。如果问题持续存在，请联系客服支持。'
    };
  }

  /**
   * 开始进度模拟
   */
  private startProgressSimulation(): void {
    this.analysisProgress = 0;
    this.progressText = '正在上传文件...';

    // 清理之前的定时器
    this.clearTimers();

    // 进度模拟定时器
    this.progressTimer = setInterval(() => {
      if (this.analysisProgress < 30) {
        this.analysisProgress += 2;
      } else if (this.analysisProgress < 60) {
        this.analysisProgress += 1;
        this.progressText = '正在解析简历内容...';
      } else if (this.analysisProgress < 85) {
        this.analysisProgress += 0.5;
        this.progressText = '正在进行 AI 分析...';
      } else if (this.analysisProgress < 95) {
        this.analysisProgress += 0.2;
        this.progressText = '正在生成分析报告...';
      }
    }, 200);

    // 设置超时检测
    this.timeoutTimer = setTimeout(() => {
      if (this.isLoading) {
        this.handleAnalysisError({
          message: 'timeout',
          code: 408
        });
      }
    }, this.ANALYSIS_TIMEOUT);
  }

  /**
   * 停止进度模拟
   */
  private stopProgressSimulation(): void {
    this.clearTimers();
    if (this.isLoading) {
      this.analysisProgress = 100;
      this.progressText = '分析完成';
    }
  }

  async pickFile() {
    try {
      const documentPicker = new file.DocumentPicker();
      const result = await documentPicker.select({
        MIMEType: file.DocumentPickerType.MIME_TYPE_DOCUMENT,
        maxNumberOfFiles: 1
      });

      if (result && result.length > 0) {
        // 验证文件类型
        const fileName = result[0].name || '';
        const validExtensions = ['.pdf', '.doc', '.docx'];
        const isValidType = validExtensions.some(ext =>
          fileName.toLowerCase().endsWith(ext)
        );

        if (!isValidType) {
          promptAction.showToast({
            message: '请选择 PDF 或 Word 格式的文件',
            duration: 2000
          });
          return;
        }

        this.selectedFileName = fileName;
        this.currentFile = result[0];
        this.uploadAndAnalyze(result[0]);
      }
    } catch (err) {
      console.error('[ResumePage] Pick file failed:', err);
      // 用户取消选择，不显示错误
      if (err?.message?.includes('cancel')) {
        return;
      }
      promptAction.showToast({
        message: '文件选择失败，请重试',
        duration: 2000
      });
    }
  }

  async uploadAndAnalyze(file: file.File) {
    // 重置状态
    this.isLoading = true;
    this.hasResume = true;
    this.hasError = false;
    this.errorInfo = null;
    this.isCancelling = false;
    this.currentFile = file;

    // 开始进度模拟
    this.startProgressSimulation();

    try {
      const result = await this.chatService.analyzeResume(file);

      // 停止进度模拟
      this.stopProgressSimulation();

      // 检查是否已取消
      if (this.isCancelling) {
        return;
      }

      this.analysisResult = result;

      // 保存到历史记录
      await this.saveToHistory();

      // 更新全局页面状态
      this.updateGlobalPageState();

      // 显示成功提示
      promptAction.showToast({
        message: '简历分析完成',
        duration: 1500
      });
    } catch (error) {
      // 停止进度模拟
      this.stopProgressSimulation();

      // 检查是否已取消
      if (this.isCancelling) {
        return;
      }

      // 处理错误
      this.handleAnalysisError(error);
    } finally {
      if (!this.hasError && !this.isCancelling) {
        this.isLoading = false;
      }
    }
  }

  /**
   * 处理分析错误
   */
  private handleAnalysisError(error: any): void {
    console.error('[ResumePage] Analysis failed:', error);

    // 解析错误类型
    this.errorInfo = this.parseError(error);
    this.hasError = true;
    this.isLoading = false;

    // 记录错误日志
    this.logError(error);

    // 显示错误提示
    promptAction.showToast({
      message: this.errorInfo.message,
      duration: 3000
    });
  }

  /**
   * 记录错误日志
   */
  private logError(error: any): void {
    const errorLog = {
      timestamp: new Date().toISOString(),
      page: 'Resume',
      fileName: this.selectedFileName,
      errorType: this.errorInfo?.type || 'UNKNOWN',
      errorMessage: error?.message || error?.toString(),
      errorStack: error?.stack
    };

    console.error('[ResumePage] Error log:', JSON.stringify(errorLog));

    // 可以在这里添加发送到远程日志服务的逻辑
    // 例如：ErrorReportingService.report(errorLog);
  }

  /**
   * 取消分析
   */
  private cancelAnalysis(): void {
    this.isCancelling = true;
    this.clearTimers();

    // 延迟重置状态，让用户看到取消状态
    setTimeout(() => {
      this.resetResume();
      promptAction.showToast({
        message: '已取消分析',
        duration: 1500
      });
    }, 500);
  }

  /**
   * 重试分析
   */
  private retryAnalysis(): void {
    if (this.currentFile) {
      this.hasError = false;
      this.errorInfo = null;
      this.uploadAndAnalyze(this.currentFile);
    } else {
      promptAction.showToast({
        message: '无法重试，请重新上传文件',
        duration: 2000
      });
      this.resetResume();
    }
  }

  /**
   * 保存简历分析结果到历史记录
   */
  private async saveToHistory(): Promise<void> {
    if (this.analysisResult) {
      try {
        await this.historyService.addHistory({
          type: 'resume',
          title: `简历分析 - ${this.selectedFileName || '未命名简历'}`,
          content: `ATS评分: ${this.analysisResult.atsScore}分，${this.analysisResult.summary.substring(0, 50)}...`,
          metadata: {
            atsScore: this.analysisResult.atsScore,
            fileName: this.selectedFileName,
            keywords: this.analysisResult.keywords
          }
        });
      } catch (error) {
        console.error('[ResumePage] Save to history failed:', error);
        // 历史记录保存失败不影响主流程
      }
    }
  }

  /**
   * 重置简历状态
   */
  private resetResume(): void {
    this.hasResume = false;
    this.analysisResult = null;
    this.isLoading = false;
    this.selectedFileName = '';
    this.resumeContent = '';
    this.isEditing = false;
    this.isContinueRestore = false;
    this.hasError = false;
    this.errorInfo = null;
    this.isCancelling = false;
    this.currentFile = null;
    this.analysisProgress = 0;
    this.progressText = '正在上传文件...';

    // 清理定时器
    this.clearTimers();

    // 更新全局页面状态
    this.updateGlobalPageState();
  }
}
