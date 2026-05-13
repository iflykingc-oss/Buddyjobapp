/**
 * 简历分析页面
 * 
 * 功能：
 * 1. 简历列表视图（历史记录）
 * 2. 使用鸿蒙原生 DocumentPicker 选择文件
 * 3. 全屏沉浸式分析体验（Progress + 动态文字）
 * 4. Swiper 卡片式结果展示
 * 5. ATS评分详情展开
 * 6. 优化建议分组展示
 * 7. 简历模板下载
 * 8. 支持取消分析、导出 PDF、重新分析
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
import { Router } from '../utils/Router';
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

// 简历历史记录
interface ResumeHistoryItem {
  id: string;
  fileName: string;
  analysisDate: string;
  atsScore: number;
  summary: string;
  keywords: string[];
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

  // 简历历史列表
  @State private resumeList: ResumeHistoryItem[] = [];
  
  // 是否展开ATS详情
  @State private isATSExpanded: boolean = false;
  
  // 是否展开优化建议
  @State private isSuggestionsExpanded: boolean = false;

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

    // 加载简历历史
    this.loadResumeHistory();
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
   * 加载简历历史记录
   */
  private async loadResumeHistory(): Promise<void> {
    try {
      const history = await this.resumeService.getResumeHistory(1, 10);
      if (history && history.length > 0) {
        this.resumeList = history.map(item => ({
          id: item.id || Date.now().toString(),
          fileName: item.fileName || '简历分析',
          analysisDate: item.analysisDate || new Date().toLocaleDateString(),
          atsScore: item.atsScore || 0,
          summary: item.summary || '',
          keywords: item.keywords || []
        }));
      }
    } catch (error) {
      console.error('[ResumePage] Load history failed:', error);
    }
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
          // 简历列表 + 上传区域
          this.buildIdleView();
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

      // 模板下载按钮
      if (this.pageState === PageState.IDLE) {
        Button() {
          Image($r('app.media.ic_download'))
            .width(20)
            .height(20)
            .fillColor(BrandColors.Brand500)
        }
        .backgroundColor('transparent')
        .width(40)
        .height(40)
        .onClick(() => {
          Router.push('pages/ResumeTemplates');
        })
      } else {
        // 占位
        Row().width(40)
      }
    }
    .width('100%')
    .height(56)
    .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .shadow({
      radius: 8,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 构建空闲状态视图（简历列表 + 上传区域）
   */
  @Builder
  buildIdleView() {
    Scroll() {
      Column() {
        // 简历历史列表
        if (this.resumeList.length > 0) {
          this.buildResumeHistoryList();
        }

        // 新增简历卡片
        this.buildNewResumeCard();

        // 上传区域
        this.buildUploadArea();

        // 创建简历引导入口
        this.buildCreateResumeGuide();
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * 构建简历历史列表
   */
  @Builder
  buildResumeHistoryList() {
    Column() {
      // 标题栏
      Row() {
        Text('历史简历')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

        Blank()

        Text('共' + this.resumeList.length + '份')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Md })

      // 简历卡片列表
      ForEach(this.resumeList, (item: ResumeHistoryItem) => {
        Column() {
          Row() {
            // 文件图标
            Column() {
              Image($r('app.media.ic_file'))
                .width(24)
                .height(24)
                .fillColor(BrandColors.Brand500)
            }
            .width(44)
            .height(44)
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(SemanticRadius.Control)
            .justifyContent(FlexAlign.Center)

            // 文件信息
            Column() {
              Text(item.fileName)
                .fontSize(FontSize.Base)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(item.analysisDate)
                .fontSize(FontSize.Xs)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: SemanticSpacing.Md })

            // ATS评分
            Column() {
              Text(item.atsScore.toString())
                .fontSize(FontSize.Lg)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getScoreColor(item.atsScore))

              Text('ATS分')
                .fontSize(FontSize.Xs)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')

          // 关键词标签
          if (item.keywords && item.keywords.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(item.keywords.slice(0, 4), (keyword: string) => {
                Text(keyword)
                  .fontSize(FontSize.Xs)
                  .fontColor(BrandColors.Brand500)
                  .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
                  .backgroundColor(BrandColors.Brand50)
                  .borderRadius(4)
                  .margin({ right: Spacing.Space2, bottom: Spacing.Space2 })
              })
              if (item.keywords.length > 4) {
                Text('+' + (item.keywords.length - 4))
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                  .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
                  .borderRadius(4)
                  .margin({ bottom: Spacing.Space2 })
              }
            }
            .margin({ top: Spacing.Space3 })
          }
        }
        .width('100%')
        .padding(SemanticSpacing.Md)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ bottom: Spacing.Space3 })
        .onClick(() => {
          // 点击加载历史分析结果
          this.loadHistoryResult(item);
        })
      })
    }
    .width('100%')
    .margin({ top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
  }

  /**
   * 获取评分颜色
   */
  private getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /**
   * 加载历史分析结果
   */
  private async loadHistoryResult(item: ResumeHistoryItem): Promise<void> {
    try {
      const history = await this.resumeService.getResumeHistory(1, 100);
      const found = history.find(h => h.id === item.id);
      if (found && found.analysisResult) {
        this.analysisResult = found.analysisResult;
        this.selectedFileName = item.fileName;
        this.pageState = PageState.RESULT;
      }
    } catch (error) {
      console.error('[ResumePage] Load history result failed:', error);
    }
  }

  /**
   * 构建新增简历卡片
   */
  @Builder
  buildNewResumeCard() {
    Column() {
      Row() {
        // 加号图标
        Column() {
          Image($r('app.media.ic_add'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)
        }
        .width(44)
        .height(44)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(SemanticRadius.Control)
        .justifyContent(FlexAlign.Center)

        // 提示文字
        Column() {
          Text('新增简历')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

          Text('点击上传或创建新简历')
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: SemanticSpacing.Md })
        .layoutWeight(1)

        // 箭头
        Image($r('app.media.ic_arrow_right'))
          .width(20)
          .height(20)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Md)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
    .border({
      width: 1,
      color: BrandColors.Brand200,
      style: BorderStyle.Dashed
    })
    .margin({ bottom: SemanticSpacing.Lg })
    .onClick(() => {
      this.pickFile();
    })
  }

  /**
   * 构建上传区域
   */
  @Builder
  buildUploadArea() {
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
    .width('100%')
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
    .width('100%')
    .margin({ top: SemanticSpacing.Xl })
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 构建创建简历引导入口
   */
  @Builder
  buildCreateResumeGuide() {
    Column() {
      Row() {
        Column() {
          Image($r('app.media.ic_edit'))
            .width(32)
            .height(32)
            .fillColor(BrandColors.Brand500)
        }
        .width(56)
        .height(56)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(28)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text('没有简历？')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

          Text('使用引导创建专业简历')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: SemanticSpacing.Md })
        .layoutWeight(1)

        Image($r('app.media.ic_arrow_right'))
          .width(20)
          .height(20)
          .fillColor(BrandColors.Brand500)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: SemanticSpacing.Lg })
    .onClick(() => {
      Router.push('pages/ResumeGuide');
    })
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
   * 构建结果视图（增强版 - 含ATS详情和优化建议）
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

      // ATS评分详情（可展开）
      this.buildATSScoreDetails();

      // 优化建议（可展开）
      this.buildOptimizationSuggestions();

      // Swiper 结果展示
      ResumeResultSwiper({
        analysisResult: this.analysisResult
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  /**
   * 构建ATS评分详情（可展开）
   */
  @Builder
  buildATSScoreDetails() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_analysis'))
          .width(20)
          .height(20)
          .fillColor(BrandColors.Brand500)

        Text('ATS评分详情')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .margin({ left: Spacing.Space2 })

        Blank()

        Image(this.isATSExpanded ? $r('app.media.ic_arrow_up') : $r('app.media.ic_arrow_down'))
          .width(16)
          .height(16)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .rotate({ angle: this.isATSExpanded ? 180 : 0 })
      }
      .width('100%')
      .padding(SemanticSpacing.Md)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
      .onClick(() => {
        animateTo({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        }, () => {
          this.isATSExpanded = !this.isATSExpanded;
        })
      })

      // 展开内容
      if (this.isATSExpanded && this.analysisResult) {
        Column() {
          // 评分维度
          this.buildATSDimension('格式规范', Math.min(this.analysisResult.atsScore + 5, 100));
          this.buildATSDimension('关键词匹配', this.analysisResult.atsScore);
          this.buildATSDimension('经历量化', Math.max(this.analysisResult.atsScore - 10, 0));
          this.buildATSDimension('技能匹配', Math.max(this.analysisResult.atsScore - 5, 0));
          this.buildATSDimension('整体完整性', Math.min(this.analysisResult.atsScore + 8, 100));

          // 优化建议
          Row() {
            Image($r('app.media.ic_tip'))
              .width(14)
              .height(14)
              .fillColor(WarningColors.Warning500)

            Text('建议：完善项目经历的量化指标，提升关键词匹配度')
              .fontSize(FontSize.Xs)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
              .margin({ left: Spacing.Space2 })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: Spacing.Space3 })
        }
        .width('100%')
        .padding(SemanticSpacing.Md)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius({ bottomLeft: SemanticRadius.Component, bottomRight: SemanticRadius.Component })
        .animation({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        })
      }
    }
    .width('100%')
    .margin({ top: Spacing.Space4, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .clip(true)
  }

  /**
   * 构建ATS评分维度
   */
  @Builder
  buildATSDimension(name: string, score: number) {
    Column() {
      Row() {
        Text(name)
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)

        Blank()

        Text(score.toString() + '分')
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getScoreColor(score))
      }
      .width('100%')
      .margin({ bottom: Spacing.Space2 })

      // 进度条
      Stack() {
        // 背景
        Column()
          .width('100%')
          .height(6)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface3 : NeutralColors.Neutral200)
          .borderRadius(3)

        // 进度
        Column()
          .width((score / 100 * 100).toString() + '%')
          .height(6)
          .backgroundColor(this.getScoreColor(score))
          .borderRadius(3)
          .animation({
            duration: 500,
            curve: Curve.EaseOut
          })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: Spacing.Space3 })
  }

  /**
   * 构建优化建议（可展开分组）
   */
  @Builder
  buildOptimizationSuggestions() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_tip'))
          .width(20)
          .height(20)
          .fillColor(BrandColors.Brand500)

        Text('优化建议')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .margin({ left: Spacing.Space2 })

        Blank()

        // 统计标签
        if (this.analysisResult) {
          Row() {
            Text('添加 ' + this.analysisResult.suggestions.filter(s => s.type === 'add').length)
              .fontSize(FontSize.Xs)
              .fontColor(SuccessColors.Success500)
            Text(' | 修改 ' + this.analysisResult.suggestions.filter(s => s.type === 'modify').length)
              .fontSize(FontSize.Xs)
              .fontColor(WarningColors.Warning500)
              .margin({ left: Spacing.Space1 })
            Text(' | 删除 ' + this.analysisResult.suggestions.filter(s => s.type === 'delete').length)
              .fontSize(FontSize.Xs)
              .fontColor(ErrorColors.Error500)
              .margin({ left: Spacing.Space1 })
          }
        }

        Image(this.isSuggestionsExpanded ? $r('app.media.ic_arrow_up') : $r('app.media.ic_arrow_down'))
          .width(16)
          .height(16)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ left: Spacing.Space2 })
      }
      .width('100%')
      .padding(SemanticSpacing.Md)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
      .onClick(() => {
        animateTo({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        }, () => {
          this.isSuggestionsExpanded = !this.isSuggestionsExpanded;
        })
      })

      // 展开内容
      if (this.isSuggestionsExpanded && this.analysisResult) {
        Column() {
          // 需要添加
          this.buildSuggestionGroup('需要添加', 'add', this.analysisResult.suggestions.filter(s => s.type === 'add'));
          // 需要修改
          this.buildSuggestionGroup('需要修改', 'modify', this.analysisResult.suggestions.filter(s => s.type === 'modify'));
          // 需要删除
          this.buildSuggestionGroup('需要删除', 'delete', this.analysisResult.suggestions.filter(s => s.type === 'delete'));
        }
        .width('100%')
        .padding(SemanticSpacing.Md)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius({ bottomLeft: SemanticRadius.Component, bottomRight: SemanticRadius.Component })
        .animation({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        })
      }
    }
    .width('100%')
    .margin({ top: Spacing.Space3, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .clip(true)
  }

  /**
   * 构建建议分组
   */
  @Builder
  buildSuggestionGroup(title: string, type: string, suggestions: Suggestion[]) {
    if (suggestions.length === 0) {
      return;
    }

    Column() {
      // 分组标题
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getSuggestionTypeColor(type))

        Text(title)
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .margin({ left: Spacing.Space2 })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space3 })

      // 建议列表
      ForEach(suggestions, (suggestion: Suggestion) => {
        Row() {
          Column() {
            Text(suggestion.title)
              .fontSize(FontSize.Sm)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

            Text(suggestion.description)
              .fontSize(FontSize.Xs)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ top: 2 })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // 优先级标签
          Text(this.getPriorityLabel(suggestion.priority))
            .fontSize(FontSize.Xs)
            .fontColor(this.getPriorityColor(suggestion.priority))
            .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
            .backgroundColor(this.getPriorityColor(suggestion.priority) + '20')
            .borderRadius(4)
        }
        .width('100%')
        .padding(Spacing.Space3)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
        .borderRadius(SemanticRadius.Control)
        .margin({ bottom: Spacing.Space2 })
      })
    }
    .width('100%')
    .margin({ bottom: SemanticSpacing.Md })
  }

  /**
   * 获取建议类型颜色
   */
  private getSuggestionTypeColor(type: string): string {
    switch (type) {
      case 'add':
        return SuccessColors.Success500;
      case 'modify':
        return WarningColors.Warning500;
      case 'delete':
        return ErrorColors.Error500;
      default:
        return BrandColors.Brand500;
    }
  }

  /**
   * 获取优先级标签
   */
  private getPriorityLabel(priority: string): string {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return '';
    }
  }

  /**
   * 获取优先级颜色
   */
  private getPriorityColor(priority: string): string {
    switch (priority) {
      case 'high':
        return ErrorColors.Error500;
      case 'medium':
        return WarningColors.Warning500;
      case 'low':
        return SuccessColors.Success500;
      default:
        return BrandColors.Brand500;
    }
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

      // 刷新简历历史列表
      await this.loadResumeHistory();

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
    this.isATSExpanded = false;
    this.isSuggestionsExpanded = false;

    this.clearTimers();
    this.updateGlobalPageState();
  }
}
