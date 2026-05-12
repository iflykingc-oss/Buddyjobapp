/**
 * 简历分析页面
 * 
 * 功能：
 * 1. 使用鸿蒙原生 DocumentPicker 选择文件
 * 2. 全屏沉浸式分析体验（Progress + 动态文字）
 * 3. Swiper 卡片式结果展示
 * 4. 支持取消分析、导出 PDF、重新分析
 * 
 * 设计规范：严格遵循鸿蒙设计规范
 */

import picker from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import { ResumeAnalysisResult, Dimension, Suggestion } from '../models/Resume';
import { ResumeService, AnalysisStage, StageTextMap } from '../services/ResumeService';
import { HistoryService } from '../services/HistoryService';
import { ResumeResultSwiper } from '../components/resume/ResumeResultSwiper';
import { PageStateSync, ResumePageState } from '../utils/distributed';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { WindowUtil } from '../utils/WindowUtil';
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

// 页面状态枚举
enum PageState {
  IDLE = 'idle',           // 空闲，等待上传
  UPLOADING = 'uploading', // 上传中
  ANALYZING = 'analyzing', // 分析中
  ERROR = 'error',         // 错误
  RESULT = 'result'        // 结果展示
}

@Component
export struct ResumePage {
  // 页面状态
  @State private pageState: PageState = PageState.IDLE;

  // 分析结果
  @State private analysisResult: ResumeAnalysisResult | null = null;

  // 文件信息
  @State private selectedFileName: string = '';
  @State private selectedFileUri: string = '';

  // 进度状态
  @State private progress: number = 0;
  @State private progressStage: AnalysisStage = AnalysisStage.UPLOADING;
  @State private progressText: string = '正在上传...';

  // 错误状态
  @State private hasError: boolean = false;
  @State private errorInfo: AnalysisError | null = null;

  // 取消状态
  @State private isCancelling: boolean = false;

  // 跨设备流转状态
  @State private isContinueRestore: boolean = false;

  // 暗黑模式
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;

  // 服务实例
  private resumeService: ResumeService = ResumeService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private pageStateSync: PageStateSync = new PageStateSync('pages/Resume');

  // 当前选中的文件
  private currentFile: picker.DocumentPickerResult | null = null;

  // 超时定时器
  private timeoutTimer: number = -1;
  private readonly ANALYSIS_TIMEOUT = 90000; // 90秒超时

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
      
      if (state.analysisResult) {
        this.analysisResult = state.analysisResult;
        this.pageState = PageState.RESULT;
      }
      
      this.selectedFileName = state.selectedFileName || '';

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
      hasResume: this.pageState !== PageState.IDLE,
      analysisResult: this.analysisResult,
      selectedFileName: this.selectedFileName,
      resumeContent: '',
      isEditing: false
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
      this.buildTitleBar()

      // 根据状态显示不同内容（宽屏限制最大宽度）
      Column() {
        if (this.pageState === PageState.IDLE) {
          // 上传区域
          this.buildUploadArea();
        } else if (this.pageState === PageState.UPLOADING || this.pageState === PageState.ANALYZING) {
          // 全屏沉浸式分析动画
          this.buildFullScreenAnalysis();
        } else if (this.pageState === PageState.ERROR) {
          // 错误状态
          this.buildErrorView();
        } else if (this.pageState === PageState.RESULT) {
          // Swiper 卡片式结果展示
          this.buildResultView();
        }
      }
      .layoutWeight(1)
      .constraintSize({ maxWidth: this.windowUtil?.getContentMaxWidth() })
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }

  /**
   * 构建标题栏
   */
  @Builder
  buildTitleBar() {
    Row() {
      // 返回按钮（分析中显示）
      if (this.pageState === PageState.UPLOADING || this.pageState === PageState.ANALYZING) {
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        }
        .backgroundColor('transparent')
        .width(40)
        .height(40)
        .onClick(() => {
          this.cancelAnalysis();
        })
      }

      Text('简历分析')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

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
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
        .borderRadius(SemanticRadius.Pill)
      } else {
        // 占位，保持标题居中
        Row().width(40)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .shadow({
      radius: 8,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 构建上传区域
   */
  @Builder
  buildUploadArea() {
    Column() {
      // 上传卡片
      Column() {
        // 上传图标
        Column() {
          Image($r('app.media.ic_upload'))
            .width(48)
            .height(48)
            .fillColor(BrandColors.Brand400)
        }
        .width(96)
        .height(96)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(48)
        .justifyContent(FlexAlign.Center)

        Text('点击上传简历')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .margin({ top: SemanticSpacing.Xl })

        Text('支持 PDF、Word 格式，最大 10MB')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ top: Spacing.Space3 })

        // 文件来源提示
        Row() {
          this.buildSourceTag('本地文件');
          this.buildSourceTag('iCloud');
          this.buildSourceTag('微信文件');
        }
        .margin({ top: SemanticSpacing.Lg })
      }
      .width('85%')
      .padding(SemanticSpacing.Xxl3)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius(SemanticRadius.Component)
      .border({
        width: 2,
        color: this.isDarkMode ? DarkSemanticColors.Accent : BrandColors.Brand200,
        style: BorderStyle.Dashed
      })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.pickFile();
      })

      // 使用说明
      Column() {
        Text('AI 简历分析功能')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

        Text('上传简历后，AI 将从多个维度分析您的简历质量，并提供专业的优化建议')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ top: Spacing.Space3 })
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      }
      .width('85%')
      .margin({ top: SemanticSpacing.Xl })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 构建来源标签
   */
  @Builder
  buildSourceTag(text: string) {
    Row() {
        Image($r('app.media.ic_file'))
          .width(12)
          .height(12)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)

        Text(text)
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ left: Spacing.Space1 })
      }
      .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
      .borderRadius(SemanticRadius.Pill)
      .margin({ left: Spacing.Space2, right: Spacing.Space2 })
  }

  /**
   * 构建全屏沉浸式分析动画
   */
  @Builder
  buildFullScreenAnalysis() {
    Column() {
      // 顶部装饰
      Column() {
        // 渐变背景圆
        Stack() {
          // 外圈光晕
          Circle()
            .width(200)
            .height(200)
            .fill(BrandColors.Brand50)

          // 中圈
          Circle()
            .width(160)
            .height(160)
            .fill(BrandColors.Brand100)

          // 进度圆环
          Stack() {
            // 背景圆环
            Circle()
              .width(120)
              .height(120)
              .fill('transparent')
              .stroke(this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
              .strokeWidth(8)

            // 进度圆环
            Circle()
              .width(120)
              .height(120)
              .fill('transparent')
              .stroke(BrandColors.Brand500)
              .strokeWidth(8)
              .strokeDashArray([this.progress / 100 * 377, 377])
              .rotate({ angle: -90, centerX: '50%', centerY: '50%' })

            // 进度百分比
            Column() {
              Text(`${Math.floor(this.progress)}%`)
                .fontSize(FontSize.Xxl)
                .fontWeight(FontWeight.Bold)
                .fontColor(BrandColors.Brand500)
            }
          }
          .width(120)
          .height(120)
        }
        .width(200)
        .height(200)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 80 })

      // 状态文字
      Column() {
        // 当前阶段
        Text(this.progressText)
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

        // 文件名
        if (this.selectedFileName) {
          Row() {
            Image($r('app.media.ic_file'))
              .width(16)
              .height(16)
              .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)

            Text(this.selectedFileName)
              .fontSize(FontSize.Sm)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space2 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ top: Spacing.Space4 })
        }

        // 阶段指示器
        this.buildStageIndicator();
      }
      .margin({ top: SemanticSpacing.Xxl3 })

      Blank()

      // 取消按钮
      Button() {
        Row() {
          if (this.isCancelling) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(ErrorColors.Error500)
          } else {
            Image($r('app.media.ic_close'))
              .width(16)
              .height(16)
              .fillColor(ErrorColors.Error500)
          }

          Text(this.isCancelling ? '取消中...' : '取消分析')
            .fontSize(FontSize.Sm)
            .fontColor(ErrorColors.Error500)
            .margin({ left: Spacing.Space2 })
        }
      }
      .backgroundColor('transparent')
      .border({ width: 1, color: ErrorColors.Error500 })
      .borderRadius(SemanticRadius.Pill)
      .width(140)
      .height(44)
      .margin({ bottom: 60 })
      .enabled(!this.isCancelling)
      .onClick(() => {
        this.cancelAnalysis();
      })
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 构建阶段指示器
   */
  @Builder
  buildStageIndicator() {
    Row() {
      this.buildStageDot('上传', this.progressStage === AnalysisStage.UPLOADING ||
        [AnalysisStage.PARSING, AnalysisStage.ANALYZING, AnalysisStage.GENERATING, AnalysisStage.COMPLETED]
          .includes(this.progressStage));

      this.buildStageLine([AnalysisStage.PARSING, AnalysisStage.ANALYZING, AnalysisStage.GENERATING, AnalysisStage.COMPLETED]
        .includes(this.progressStage));

      this.buildStageDot('解析', [AnalysisStage.PARSING, AnalysisStage.ANALYZING, AnalysisStage.GENERATING, AnalysisStage.COMPLETED]
        .includes(this.progressStage));

      this.buildStageLine([AnalysisStage.ANALYZING, AnalysisStage.GENERATING, AnalysisStage.COMPLETED]
        .includes(this.progressStage));

      this.buildStageDot('分析', [AnalysisStage.ANALYZING, AnalysisStage.GENERATING, AnalysisStage.COMPLETED]
        .includes(this.progressStage));

      this.buildStageLine([AnalysisStage.GENERATING, AnalysisStage.COMPLETED].includes(this.progressStage));

      this.buildStageDot('完成', this.progressStage === AnalysisStage.COMPLETED);
    }
    .margin({ top: SemanticSpacing.Xl })
  }

  /**
   * 构建阶段点
   */
  @Builder
  buildStageDot(label: string, isActive: boolean) {
    Column() {
      Column()
        .width(isActive ? 12 : 8)
        .height(isActive ? 12 : 8)
        .backgroundColor(isActive ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Text4 : NeutralColors.Neutral300))
        .borderRadius(isActive ? 6 : 4)

      Text(label)
        .fontSize(FontSize.Xs)
        .fontColor(isActive ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3))
        .margin({ top: Spacing.Space2 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建阶段连接线
   */
  @Builder
  buildStageLine(isActive: boolean) {
    Column()
      .width(24)
      .height(2)
      .backgroundColor(isActive ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200))
      .margin({ bottom: 16 })
  }

  /**
   * 构建错误视图
   */
  @Builder
  buildErrorView() {
    Column() {
      // 错误图标
      Column() {
        Image($r('app.media.ic_error'))
          .width(48)
          .height(48)
          .fillColor(ErrorColors.Error500)
      }
      .width(96)
      .height(96)
      .backgroundColor(ErrorColors.Error50)
      .borderRadius(48)
      .justifyContent(FlexAlign.Center)

      Text('分析失败')
        .fontSize(FontSize.Xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .margin({ top: SemanticSpacing.Xl })

      // 错误详情
      if (this.errorInfo) {
        Text(this.errorInfo.message)
          .fontSize(FontSize.Base)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ top: Spacing.Space4 })
          .textAlign(TextAlign.Center)
          .width('80%')

        // 解决建议
        Column() {
          Row() {
            Image($r('app.media.ic_tip'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)

            Text('解决建议')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .margin({ left: Spacing.Space2 })
          }

          Text(this.errorInfo.suggestion)
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
            .margin({ top: Spacing.Space3 })
            .lineHeight(20)
        }
        .width('85%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
        .borderRadius(SemanticRadius.Component)
        .margin({ top: SemanticSpacing.Xl })
      }

      // 操作按钮
      Row() {
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

        Button('重新上传')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Pill)
          .border({ width: 1, color: BrandColors.Brand500 })
          .width(120)
          .height(44)
          .margin({ left: Spacing.Space4 })
          .onClick(() => {
            this.resetPage();
          })
      }
      .margin({ top: SemanticSpacing.Xxl3 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 构建结果视图（Swiper 卡片式）
   */
  @Builder
  buildResultView() {
    Column() {
      // 流转提示
      if (this.isContinueRestore) {
        Row() {
          Image($r('app.media.ic_info'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)

          Text('已从其他设备恢复简历数据')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
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
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
        .borderRadius(SemanticRadius.Component)
        .margin({ top: Spacing.Space4, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }

      // Swiper 结果展示
      ResumeResultSwiper({
        analysisResult: this.analysisResult
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  /**
   * 选择文件
   */
  async pickFile(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentPicker();
      const result = await documentPicker.select({
        MIMEType: picker.DocumentPickerType.MIME_TYPE_DOCUMENT,
        maxNumberOfFiles: 1
      });

      if (result && result.length > 0) {
        const file = result[0];
        const fileName = file.name || '';

        // 验证文件类型
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
        this.selectedFileUri = file.uri || '';
        this.currentFile = result;

        // 开始分析
        this.startAnalysis(file);
      }
    } catch (err) {
      console.error('[ResumePage] Pick file failed:', err);
      
      // 用户取消选择，不显示错误
      if (err?.message?.includes('cancel') || err?.code === 13900042) {
        return;
      }
      
      promptAction.showToast({
        message: '文件选择失败，请重试',
        duration: 2000
      });
    }
  }

  /**
   * 开始分析
   */
  private async startAnalysis(file: picker.DocumentPickerResult): Promise<void> {
    // 更新状态
    this.pageState = PageState.UPLOADING;
    this.progress = 0;
    this.progressStage = AnalysisStage.UPLOADING;
    this.progressText = StageTextMap[AnalysisStage.UPLOADING];
    this.hasError = false;
    this.errorInfo = null;
    this.isCancelling = false;

    // 设置超时
    this.timeoutTimer = setTimeout(() => {
      if (this.pageState === PageState.UPLOADING || this.pageState === PageState.ANALYZING) {
        this.handleAnalysisError({
          message: 'timeout',
          code: 408
        });
      }
    }, this.ANALYSIS_TIMEOUT);

    try {
      // 调用分析服务
      const result = await this.resumeService.analyzeResume(file, (progress, stage) => {
        // 更新进度
        this.progress = progress;
        this.progressStage = stage;
        this.progressText = StageTextMap[stage];
        
        // 更新页面状态
        if (stage === AnalysisStage.ANALYZING) {
          this.pageState = PageState.ANALYZING;
        }
      });

      // 清除超时
      this.clearTimers();

      // 检查是否已取消
      if (this.isCancelling) {
        return;
      }

      // 保存结果
      this.analysisResult = result;
      this.pageState = PageState.RESULT;

      // 保存到历史记录
      await this.saveToHistory();

      // 更新全局状态
      this.updateGlobalPageState();

      // 显示成功提示
      promptAction.showToast({
        message: '简历分析完成',
        duration: 1500
      });
    } catch (error) {
      // 清除超时
      this.clearTimers();

      // 检查是否已取消
      if (this.isCancelling) {
        return;
      }

      // 处理错误
      this.handleAnalysisError(error);
    }
  }

  /**
   * 处理分析错误
   */
  private handleAnalysisError(error: any): void {
    console.error('[ResumePage] Analysis failed:', error);

    // 解析错误类型
    this.errorInfo = this.parseError(error);
    this.pageState = PageState.ERROR;

    // 显示错误提示
    promptAction.showToast({
      message: this.errorInfo.message,
      duration: 3000
    });
  }

  /**
   * 解析错误类型
   */
  private parseError(error: any): AnalysisError {
    const errorMessage = error?.message || error?.toString() || '';
    const errorCode = error?.code || 0;

    // 网络错误
    if (errorMessage.includes('网络') || errorMessage.includes('network') ||
        errorMessage.includes('connection') || errorCode === -1) {
      return {
        type: AnalysisErrorType.NETWORK_ERROR,
        message: '网络连接失败',
        suggestion: '请检查网络连接后重试，可以尝试切换 Wi-Fi 或移动数据网络。'
      };
    }

    // 超时错误
    if (errorMessage.includes('timeout') || errorMessage.includes('超时') || errorCode === 408) {
      return {
        type: AnalysisErrorType.TIMEOUT_ERROR,
        message: '分析请求超时',
        suggestion: '网络较慢或文件较大，请检查网络后重试。'
      };
    }

    // 文件格式错误
    if (errorMessage.includes('format') || errorMessage.includes('格式') || errorCode === 415) {
      return {
        type: AnalysisErrorType.FILE_FORMAT_ERROR,
        message: '文件格式不支持',
        suggestion: '请上传 PDF 或 Word 格式（.pdf, .doc, .docx）的文件。'
      };
    }

    // 文件大小错误
    if (errorMessage.includes('size') || errorMessage.includes('大小') || errorCode === 413) {
      return {
        type: AnalysisErrorType.FILE_SIZE_ERROR,
        message: '文件过大',
        suggestion: '请确保文件大小不超过 10MB。'
      };
    }

    // 服务器错误
    if (errorCode >= 500) {
      return {
        type: AnalysisErrorType.SERVER_ERROR,
        message: '服务器暂时不可用',
        suggestion: '请稍后重试。'
      };
    }

    // 默认错误
    return {
      type: AnalysisErrorType.UNKNOWN_ERROR,
      message: '分析失败',
      suggestion: '请检查网络和文件后重试。'
    };
  }

  /**
   * 取消分析
   */
  private cancelAnalysis(): void {
    this.isCancelling = true;
    this.clearTimers();

    setTimeout(() => {
      this.resetPage();
      promptAction.showToast({
        message: '已取消分析',
        duration: 1500
      });
    }, 300);
  }

  /**
   * 重试分析
   */
  private retryAnalysis(): void {
    if (this.currentFile && this.currentFile.length > 0) {
      this.pageState = PageState.IDLE;
      this.hasError = false;
      this.errorInfo = null;
      this.startAnalysis(this.currentFile);
    } else {
      promptAction.showToast({
        message: '无法重试，请重新上传文件',
        duration: 2000
      });
      this.resetPage();
    }
  }

  /**
   * 保存到历史记录
   */
  private async saveToHistory(): Promise<void> {
    if (this.analysisResult) {
      try {
        await this.historyService.addHistory({
          type: 'resume',
          title: `简历分析 - ${this.selectedFileName || '未命名简历'}`,
          content: `ATS评分: ${this.analysisResult.atsScore}分`,
          metadata: {
            atsScore: this.analysisResult.atsScore,
            fileName: this.selectedFileName,
            keywords: this.analysisResult.keywords
          }
        });
      } catch (error) {
        console.error('[ResumePage] Save to history failed:', error);
      }
    }
  }

  /**
   * 重置页面
   */
  private resetPage(): void {
    this.pageState = PageState.IDLE;
    this.analysisResult = null;
    this.selectedFileName = '';
    this.selectedFileUri = '';
    this.progress = 0;
    this.progressStage = AnalysisStage.UPLOADING;
    this.progressText = '正在上传...';
    this.hasError = false;
    this.errorInfo = null;
    this.isCancelling = false;
    this.currentFile = null;
    this.isContinueRestore = false;

    this.clearTimers();
    this.updateGlobalPageState();
  }
}
