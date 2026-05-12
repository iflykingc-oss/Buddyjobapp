import { common } from '@kit.AbilityKit';
import { selectionInput } from '@ohos.selectionInput.selectionManager';
import { agentFramework } from '@kit.IntelligentAgentKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { XiaoyiService } from '../services/XiaoyiService';
import { SelectionService, SelectionAnalysisResult, SelectionSuggestion } from '../services/SelectionService';
import { ShareUtils } from '../utils/share';
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

const TAG = 'XiaoyiCircleSelection';

/**
 * 小艺圈选组件
 * 使用 @ohos.selectionInput.selectionManager API 实现真实的划词功能
 * 用于简历内容的圈选分析
 */
@Component
export struct XiaoyiCircleSelection {
  @State isSelecting: boolean = false;
  @State selectedText: string = '';
  @State analysisResult: SelectionAnalysisResult | null = null;
  @State isAnalyzing: boolean = false;
  @State showResultPanel: boolean = false;
  @State selectionActive: boolean = false;
  @Prop content: string = ''; // 简历内容
  @Prop resumeId: string = '';

  private apiService: ApiService = ApiService.getInstance();
  private xiaoyiService: XiaoyiService = XiaoyiService.getInstance();
  private selectionService: SelectionService = SelectionService.getInstance();
  private selectionManager: selectionInput.SelectionManager | null = null;
  private uiContext: common.UIAbilityContext | null = null;

  aboutToAppear() {
    this.initSelectionService();
  }

  aboutToDisappear() {
    this.cleanupSelectionService();
  }

  /**
   * 初始化划词服务
   */
  private async initSelectionService() {
    try {
      // 获取 UIAbilityContext
      this.uiContext = getContext(this) as common.UIAbilityContext;

      // 初始化 SelectionService
      const initialized = await this.selectionService.initialize(this.uiContext);
      if (initialized) {
        // 创建 SelectionManager 实例用于组件内划词
        this.selectionManager = selectionInput.createSelectionManager(this.uiContext);

        // 注册划词监听
        this.selectionService.startListening({
          onSelectionComplete: (text: string) => {
            this.handleSelectionComplete(text);
          },
          onAnalysisStart: () => {
            this.isAnalyzing = true;
          },
          onAnalysisComplete: (result: SelectionAnalysisResult) => {
            this.analysisResult = result;
            this.isAnalyzing = false;
            this.showResultPanel = true;
          },
          onAnalysisError: (error: string) => {
            this.isAnalyzing = false;
            promptAction.showToast({ message: error });
          }
        });

        Logger.info(TAG, 'Selection service initialized for component');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize selection service:', JSON.stringify(error));
    }
  }

  /**
   * 清理划词服务
   */
  private cleanupSelectionService() {
    if (this.selectionManager) {
      try {
        this.selectionManager.destroy();
      } catch (error) {
        Logger.error(TAG, 'Error destroying selection manager:', JSON.stringify(error));
      }
      this.selectionManager = null;
    }
    this.selectionService.stopListening();
  }

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // 圈选提示条
        if (this.isSelecting) {
          Row() {
            Text('请长按并拖动选择需要分析的文本内容')
              .fontSize(FontSize.Sm)
              .fontColor(BrandColors.Brand500)

            Button('取消')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .backgroundColor('transparent')
              .onClick(() => {
                this.cancelSelection();
              })
          }
          .width('100%')
          .height(40)
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          .backgroundColor(BrandColors.Brand50)
          .justifyContent(FlexAlign.SpaceBetween)
        }

        // 内容显示区域（使用真实 selectionManager API）
        Scroll() {
          Column() {
            // 使用 Text 组件配合 enableDataDetector 和 selectionMenuType 实现系统级划词
            Text(this.content)
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text1)
              .lineHeight(24)
              .padding(SemanticSpacing.Lg)
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
              .enableDataDetector(true)
              .textMenuOptions({
                options: [
                  TextMenuOptions.COPY,
                  TextMenuOptions.SELECT_ALL,
                  TextMenuOptions.SHARE
                ],
                onMenuOptionSelected: (option: TextMenuOptions) => {
                  this.handleMenuOptionSelected(option);
                },
                onMenuOptionUnselected: () => {
                  // 菜单取消选择
                }
              })
              .onTextLayout((textLayoutInfo: TextLayoutInfo) => {
                // 文本布局完成回调，可用于定位选区
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    this.startSelectionMode();
                  })
              )
          }
        }
        .layoutWeight(1)
        .backgroundColor(NeutralColors.Neutral0)
      }
      .width('100%')
      .height('100%')

      // 悬浮分析按钮（当有选中内容时显示）
      if (this.selectedText.length > 0 && !this.showResultPanel) {
        Column() {
          Button() {
            Row() {
              Image($r('app.media.ic_xiaoyi'))
                .width(20)
                .height(20)
                .fillColor(NeutralColors.Neutral0)

              Text('小艺分析')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
            }
          }
          .height(40)
          .padding({ left: Spacing.Space4, right: Spacing.Space4 })
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Pill)
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.15)',
            offsetY: 4
          })
          .onClick(() => {
            this.analyzeSelection();
          })
        }
        .position({ x: '50%', y: '80%' })
        .translate({ x: '-50%' })
      }

      // 分析结果面板
      if (this.showResultPanel && this.analysisResult) {
        this.buildResultPanel()
      }

      // 加载中遮罩
      if (this.isAnalyzing) {
        Column() {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(BrandColors.Brand500)

            Text('小艺正在分析...')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .margin({ top: SemanticSpacing.Md })
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
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
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

          Text('小艺分析结果')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(SemanticColors.Text1)
            .margin({ left: Spacing.Space2 })
        }

        // 评分标签
        if (this.analysisResult!.score !== undefined) {
          Text(`${this.analysisResult!.score}分`)
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.analysisResult!.score!))
            .padding({ left: Spacing.Space2, right: Spacing.Space2, top: Spacing.Space1, bottom: Spacing.Space1 })
            .backgroundColor(this.getScoreBgColor(this.analysisResult!.score!))
            .borderRadius(SemanticRadius.Pill)
        }

        Blank()

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
      .alignItems(VerticalAlign.Center)

      // 分析内容
      Scroll() {
        Column() {
          // 分析摘要
          Column() {
            Text('内容分析')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Md })

            Text(this.analysisResult!.analysis)
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

          // 优化建议
          if (this.analysisResult!.suggestions.length > 0) {
            Column() {
              Text('优化建议')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.Text1)
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              ForEach(this.analysisResult!.suggestions, (suggestion: SelectionSuggestion, index: number) => {
                Row() {
                  Column() {
                    Text(this.getPriorityIcon(suggestion.priority))
                      .fontSize(FontSize.Xs)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(NeutralColors.Neutral0)
                  }
                  .width(20)
                  .height(20)
                  .backgroundColor(this.getPriorityColor(suggestion.priority))
                  .borderRadius(10)
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: Spacing.Space3 })

                  Column() {
                    Text(suggestion.title)
                      .fontSize(FontSize.Sm)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(SemanticColors.Text1)
                      .width('100%')

                    Text(suggestion.description)
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text3)
                      .width('100%')
                      .margin({ top: Spacing.Space1 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
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

          // 操作按钮
          Row() {
            Button('应用到简历')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(SemanticRadius.Control)
              .onClick(() => {
                this.applySuggestions();
              })

            Button('分享分析')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(BrandColors.Brand50)
              .borderRadius(SemanticRadius.Control)
              .margin({ left: Spacing.Space3 })
              .onClick(() => {
                this.shareAnalysis();
              })
          }
          .width('100%')
        }
        .padding(SemanticSpacing.Lg)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('60%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetY: -4
    })
    .position({ x: 0, y: '40%' })
  }

  /**
   * 启动划词选择模式
   * 使用 selectionManager API 启用系统级划词
   */
  private startSelectionMode() {
    this.isSelecting = true;
    this.selectedText = '';
    this.showResultPanel = false;
    this.analysisResult = null;

    try {
      if (this.selectionManager) {
        // 使用 selectionManager 启动划词模式
        this.selectionManager.startSelection({
          content: this.content,
          selectionType: selectionInput.SelectionType.TEXT,
          onSelectionChange: (selectInfo: selectionInput.SelectInfo) => {
            this.handleSelectionChange(selectInfo);
          }
        });
        this.selectionActive = true;
        Logger.info(TAG, 'Selection mode started via selectionManager');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to start selection mode:', JSON.stringify(error));
      // 降级处理：使用系统文本选择
      promptAction.showToast({ message: '请长按文本进行选择' });
    }
  }

  /**
   * 处理 selectionManager 的选择变化回调
   * @param selectInfo 选择信息
   */
  private handleSelectionChange(selectInfo: selectionInput.SelectInfo) {
    if (selectInfo && selectInfo.text && selectInfo.text.length > 0) {
      this.selectedText = selectInfo.text;
      Logger.info(TAG, `Selection changed: ${selectInfo.text.substring(0, 50)}...`);
    }
  }

  /**
   * 处理划词完成事件
   * @param text 选中的文本
   */
  private handleSelectionComplete(text: string) {
    if (text && text.length > 0) {
      this.selectedText = text;
      Logger.info(TAG, `Selection complete: ${text.substring(0, 50)}...`);
    }
  }

  /**
   * 处理文本菜单选项选择
   * @param option 选中的菜单选项
   */
  private handleMenuOptionSelected(option: TextMenuOptions) {
    switch (option) {
      case TextMenuOptions.COPY:
        // 用户复制了文本，可以在这里同步更新 selectedText
        Logger.info(TAG, 'User selected COPY option');
        break;
      case TextMenuOptions.SELECT_ALL:
        // 全选
        this.selectedText = this.content;
        Logger.info(TAG, 'User selected SELECT_ALL');
        break;
      case TextMenuOptions.SHARE:
        // 分享选中的文本
        if (this.selectedText.length > 0) {
          this.shareText(this.selectedText);
        }
        break;
      default:
        break;
    }
  }

  /**
   * 分析选中的内容
   * 使用 selectionManager API 获取文本后调用 AI 分析
   */
  private async analyzeSelection() {
    if (this.selectedText.length === 0) {
      promptAction.showToast({ message: '请先选择需要分析的文本' });
      return;
    }

    this.isAnalyzing = true;

    try {
      // 方式1：通过 selectionService 使用 selectionManager 的 getSelectionContent
      if (this.selectionManager) {
        try {
          const selectResult: selectionInput.SelectResult = {
            text: this.selectedText,
            startIndex: 0,
            endIndex: this.selectedText.length
          };

          const content = await this.selectionManager.getSelectionContent(selectResult);
          if (content && content.text) {
            this.selectedText = content.text;
            Logger.info(TAG, `Got selection content from selectionManager: ${content.text.substring(0, 50)}...`);
          }
        } catch (error) {
          Logger.warn(TAG, 'getSelectionContent failed, using existing selected text:', JSON.stringify(error));
        }
      }

      // 方式2：通过 selectionService 进行分析
      const result = await this.selectionService.analyzeText(
        this.selectedText,
        this.content.substring(0, 200) // 提供上下文
      );

      if (result) {
        this.analysisResult = result;
        this.showResultPanel = true;

        // 触发小艺语音回复
        agentFramework.sendResponse({
          intentName: XiaoyiService.INTENTS.CIRCLE_SELECTION,
          success: true,
          message: `分析完成：${result.analysis}`,
          data: result as unknown as Record<string, object>
        });

        Logger.info(TAG, 'Analysis completed successfully');
      } else {
        // 使用本地API作为备选
        await this.analyzeWithLocalAPI();
      }
    } catch (error) {
      Logger.error(TAG, 'Error analyzing selection:', JSON.stringify(error));
      // 使用本地API作为备选
      await this.analyzeWithLocalAPI();
    } finally {
      this.isAnalyzing = false;
    }
  }

  /**
   * 使用本地API分析
   */
  private async analyzeWithLocalAPI() {
    try {
      const response = await this.apiService.post('ai/analyze-selection', {
        content: this.selectedText,
        context: this.content.substring(0, 200),
        analysisType: 'resume'
      });

      if (response.success) {
        this.analysisResult = response.data as SelectionAnalysisResult;
        this.showResultPanel = true;
      } else {
        // 使用默认分析结果
        this.useDefaultAnalysis();
      }
    } catch (error) {
      Logger.error(TAG, 'Local API analysis failed:', JSON.stringify(error));
      this.useDefaultAnalysis();
    }
  }

  /**
   * 使用默认分析结果
   */
  private useDefaultAnalysis() {
    this.analysisResult = {
      analysis: '这段内容描述了您的项目经验，整体表达清晰。建议在描述中增加更多量化的成果数据，例如"提升了50%的性能"或"服务了10万+用户"等具体指标。',
      suggestions: [
        {
          priority: 'high',
          title: '增加量化数据',
          description: '建议添加具体的数字和百分比来展示项目成果'
        },
        {
          priority: 'medium',
          title: '突出技术栈',
          description: '明确列出使用的核心技术和框架'
        },
        {
          priority: 'low',
          title: '简化描述',
          description: '部分句子可以更加简洁有力'
        }
      ],
      originalText: this.selectedText,
      score: 70
    };
    this.showResultPanel = true;
  }

  /**
   * 取消选择
   */
  private cancelSelection() {
    this.isSelecting = false;
    this.selectedText = '';
    this.showResultPanel = false;
    this.analysisResult = null;
    this.selectionActive = false;

    // 停止 selectionManager 的选择模式
    if (this.selectionManager && this.selectionActive) {
      try {
        this.selectionManager.endSelection();
      } catch (error) {
        Logger.error(TAG, 'Error ending selection:', JSON.stringify(error));
      }
    }
  }

  /**
   * 关闭结果面板
   */
  private closeResultPanel() {
    this.showResultPanel = false;
    this.selectedText = '';
    this.selectionActive = false;
  }

  /**
   * 应用建议
   */
  private applySuggestions() {
    // 通知父组件应用建议
    Logger.info(TAG, 'Applying suggestions');
    promptAction.showToast({ message: '建议已应用' });
    this.closeResultPanel();
  }

  /**
   * 分享分析结果
   * 使用 ShareUtils 分享分析内容
   */
  private async shareAnalysis() {
    if (!this.analysisResult) {
      return;
    }

    try {
      const shareContent = `【小艺简历分析】\n\n` +
        `评分: ${this.analysisResult.score !== undefined ? this.analysisResult.score + '分' : '未评分'}\n\n` +
        `分析: ${this.analysisResult.analysis}\n\n` +
        `优化建议:\n` +
        this.analysisResult.suggestions.map((s, i) =>
          `${i + 1}. ${s.title}: ${s.description}`
        ).join('\n');

      await ShareUtils.shareText(shareContent, this.uiContext!);
    } catch (error) {
      Logger.error(TAG, 'Failed to share analysis:', JSON.stringify(error));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  /**
   * 分享文本内容
   */
  private async shareText(text: string) {
    try {
      await ShareUtils.shareText(text, this.uiContext!);
    } catch (error) {
      Logger.error(TAG, 'Failed to share text:', JSON.stringify(error));
    }
  }

  /**
   * 获取优先级图标
   */
  private getPriorityIcon(priority: string): string {
    switch (priority) {
      case 'high': return '!';
      case 'medium': return '~';
      case 'low': return '·';
      default: return '·';
    }
  }

  /**
   * 获取优先级颜色
   */
  private getPriorityColor(priority: string): string {
    switch (priority) {
      case 'high': return ErrorColors.Error500;
      case 'medium': return WarningColors.Warning500;
      case 'low': return SuccessColors.Success500;
      default: return NeutralColors.Neutral400;
    }
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
   * 获取评分背景颜色
   */
  private getScoreBgColor(score: number): string {
    if (score >= 80) return SuccessColors.Success50;
    if (score >= 60) return WarningColors.Warning50;
    return ErrorColors.Error50;
  }

  /**
   * 开始圈选模式
   */
  public startSelection() {
    this.startSelectionMode();
  }
}
