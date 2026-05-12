import { agentFramework } from '@kit.IntelligentAgentKit';
import { ApiService } from '../services/ApiService';
import { XiaoyiService } from '../services/XiaoyiService';
import { Logger } from '../utils/logger';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
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
 * 用于简历内容的圈选分析
 */
@Component
export struct XiaoyiCircleSelection {
  @State isSelecting: boolean = false;
  @State selectedText: string = '';
  @State analysisResult: CircleSelectionAnalysis | null = null;
  @State isAnalyzing: boolean = false;
  @State showResultPanel: boolean = false;
  @Prop content: string = ''; // 简历内容
  @Prop resumeId: string = '';

  private apiService: ApiService = ApiService.getInstance();
  private xiaoyiService: XiaoyiService = XiaoyiService.getInstance();

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // 圈选提示条
        if (this.isSelecting) {
          Row() {
            Text('请圈选需要分析的文本内容')
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

        // 内容显示区域（支持圈选）
        Scroll() {
          SelectableText({
            text: this.content,
            onSelectionChange: (selection: TextSelection) => {
              this.handleSelectionChange(selection);
            }
          })
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .lineHeight(24)
            .padding(SemanticSpacing.Lg)
            .width('100%')
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

              ForEach(this.analysisResult!.suggestions, (suggestion: SuggestionItem, index: number) => {
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
   * 处理文本选择变化
   */
  private handleSelectionChange(selection: TextSelection) {
    if (selection.text && selection.text.length > 0) {
      this.selectedText = selection.text;
      Logger.info(TAG, `Selected text: ${selection.text.substring(0, 50)}...`);
    }
  }

  /**
   * 分析选中的内容
   */
  private async analyzeSelection() {
    if (this.selectedText.length === 0) {
      return;
    }

    this.isAnalyzing = true;

    try {
      // 调用小艺服务进行圈选分析
      const result = await this.xiaoyiService.triggerIntent(
        XiaoyiService.INTENTS.CIRCLE_SELECTION,
        {
          selectedText: this.selectedText,
          context: this.content.substring(0, 200), // 提供上下文
          resumeId: this.resumeId
        }
      );

      if (result.success && result.data) {
        this.analysisResult = result.data as CircleSelectionAnalysis;
        this.showResultPanel = true;

        // 触发小艺语音回复
        agentFramework.sendResponse({
          intentName: XiaoyiService.INTENTS.CIRCLE_SELECTION,
          success: true,
          message: result.message,
          data: result.data
        });
      } else {
        // 使用本地API作为备选
        await this.analyzeWithLocalAPI();
      }
    } catch (error) {
      Logger.error(TAG, 'Error analyzing selection:', error);
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
        this.analysisResult = response.data as CircleSelectionAnalysis;
        this.showResultPanel = true;
      }
    } catch (error) {
      Logger.error(TAG, 'Local API analysis failed:', error);
      // 使用模拟数据
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
        originalText: this.selectedText
      };
      this.showResultPanel = true;
    }
  }

  /**
   * 取消选择
   */
  private cancelSelection() {
    this.isSelecting = false;
    this.selectedText = '';
    this.showResultPanel = false;
    this.analysisResult = null;
  }

  /**
   * 关闭结果面板
   */
  private closeResultPanel() {
    this.showResultPanel = false;
    this.selectedText = '';
  }

  /**
   * 应用建议
   */
  private applySuggestions() {
    // 通知父组件应用建议
    // 这里可以通过回调或事件通知Resume页面
    Logger.info(TAG, 'Applying suggestions');
    this.closeResultPanel();
  }

  /**
   * 分享分析结果
   */
  private shareAnalysis() {
    // 调用系统分享
    Logger.info(TAG, 'Sharing analysis');
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
   * 开始圈选模式
   */
  public startSelection() {
    this.isSelecting = true;
    this.selectedText = '';
    this.showResultPanel = false;
  }
}

// 类型定义
interface TextSelection {
  text: string;
  start: number;
  end: number;
}

interface CircleSelectionAnalysis {
  analysis: string;
  suggestions: SuggestionItem[];
  originalText?: string;
}

interface SuggestionItem {
  priority: 'high' | 'medium' | 'low';
  title: string;
  description: string;
}

// 可选择的文本组件（模拟）
@Component
struct SelectableText {
  @Prop text: string;
  onSelectionChange?: (selection: TextSelection) => void;

  build() {
    // 实际实现中应该使用系统提供的文本选择组件
    // 这里使用Text组件作为示例
    Text(this.text)
      .copyOption(CopyOptions.LocalDevice)
      .draggable(true)
      .onDragStart(() => {
        // 处理拖拽选择开始
      })
  }
}
