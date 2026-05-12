import { selectionInput } from '@ohos.selectionInput.selectionManager';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from './ApiService';
import { XiaoyiService } from './XiaoyiService';
import { Logger } from '../utils/logger';

const TAG = 'SelectionService';

/**
 * 圈选分析结果
 */
export interface SelectionAnalysisResult {
  analysis: string;
  suggestions: SelectionSuggestion[];
  originalText: string;
  score?: number;
}

/**
 * 圈选优化建议
 */
export interface SelectionSuggestion {
  priority: 'high' | 'medium' | 'low';
  title: string;
  description: string;
}

/**
 * 圈选服务监听回调
 */
export interface SelectionCallback {
  onSelectionComplete?: (text: string, context?: string) => void;
  onAnalysisStart?: () => void;
  onAnalysisComplete?: (result: SelectionAnalysisResult) => void;
  onAnalysisError?: (error: string) => void;
}

/**
 * 小艺圈选服务
 * 使用 @ohos.selectionInput.selectionManager API 实现划词功能
 * 监听划词完成事件，获取选中文本，调用 AI 分析
 */
export class SelectionService {
  private static instance: SelectionService;
  private apiService: ApiService;
  private xiaoyiService: XiaoyiService;
  private selectionManager: selectionInput.SelectionManager | null = null;
  private isListening: boolean = false;
  private callback: SelectionCallback | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.xiaoyiService = XiaoyiService.getInstance();
  }

  static getInstance(): SelectionService {
    if (!SelectionService.instance) {
      SelectionService.instance = new SelectionService();
    }
    return SelectionService.instance;
  }

  /**
   * 初始化圈选服务
   * @param uiContext UIAbility 上下文
   */
  async initialize(uiContext: common.UIAbilityContext): Promise<boolean> {
    try {
      this.context = uiContext;

      // 创建 SelectionManager 实例
      this.selectionManager = selectionInput.createSelectionManager(uiContext);

      if (!this.selectionManager) {
        Logger.error(TAG, 'Failed to create SelectionManager');
        return false;
      }

      Logger.info(TAG, 'SelectionService initialized successfully');
      return true;
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize SelectionService:', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 注册划词监听
   * 监听划词完成事件，获取选中文本
   * @param callback 回调函数集合
   */
  async startListening(callback: SelectionCallback): Promise<boolean> {
    if (!this.selectionManager) {
      Logger.error(TAG, 'SelectionManager not initialized');
      return false;
    }

    try {
      this.callback = callback;

      // 监听划词完成事件
      this.selectionManager.on('selectComplete', async (selectResult: selectionInput.SelectResult) => {
        Logger.info(TAG, 'Selection complete event received');

        try {
          // 获取选中的文本内容
          const selectedText = await this.getSelectionContent(selectResult);

          if (selectedText && selectedText.trim().length > 0) {
            Logger.info(TAG, `Selected text: ${selectedText.substring(0, 100)}...`);

            // 通知划词完成
            if (this.callback?.onSelectionComplete) {
              this.callback.onSelectionComplete(selectedText);
            }
          }
        } catch (error) {
          Logger.error(TAG, 'Error processing selection:', JSON.stringify(error));
        }
      });

      this.isListening = true;
      Logger.info(TAG, 'Selection listening started');
      return true;
    } catch (error) {
      Logger.error(TAG, 'Failed to start selection listening:', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 停止监听划词事件
   */
  stopListening(): void {
    if (this.selectionManager && this.isListening) {
      try {
        this.selectionManager.off('selectComplete');
        this.isListening = false;
        this.callback = null;
        Logger.info(TAG, 'Selection listening stopped');
      } catch (error) {
        Logger.error(TAG, 'Error stopping selection listening:', JSON.stringify(error));
      }
    }
  }

  /**
   * 获取选中的文本内容
   * 通过 getSelectionContent() 获取划词面板中的文本
   * @param selectResult 划词结果
   * @returns 选中的文本内容
   */
  async getSelectionContent(selectResult: selectionInput.SelectResult): Promise<string> {
    try {
      if (!this.selectionManager) {
        Logger.error(TAG, 'SelectionManager not available');
        return '';
      }

      // 使用 selectionManager 获取选中文本
      const content = await this.selectionManager.getSelectionContent(selectResult);

      if (content && content.text) {
        return content.text;
      }

      // 备选：从 selectResult 中直接获取
      if (selectResult && selectResult.text) {
        return selectResult.text;
      }

      return '';
    } catch (error) {
      Logger.error(TAG, 'Error getting selection content:', JSON.stringify(error));
      return '';
    }
  }

  /**
   * 创建分析结果面板
   * 在划词完成后弹出分析面板，展示 AI 分析结果
   * @param selectedText 选中的文本
   * @param contextText 上下文文本（可选）
   */
  async createAnalysisPanel(selectedText: string, contextText?: string): Promise<void> {
    if (!this.selectionManager || !this.context) {
      Logger.error(TAG, 'Cannot create panel: SelectionManager or context not available');
      return;
    }

    try {
      // 通知分析开始
      if (this.callback?.onAnalysisStart) {
        this.callback.onAnalysisStart();
      }

      // 调用 AI 分析选中的简历内容
      const analysisResult = await this.analyzeSelectedText(selectedText, contextText);

      if (analysisResult) {
        // 通知分析完成
        if (this.callback?.onAnalysisComplete) {
          this.callback.onAnalysisComplete(analysisResult);
        }

        // 创建系统划词面板展示分析结果
        await this.showAnalysisInPanel(analysisResult);
      } else {
        if (this.callback?.onAnalysisError) {
          this.callback.onAnalysisError('分析失败，请稍后重试');
        }
      }
    } catch (error) {
      Logger.error(TAG, 'Error creating analysis panel:', JSON.stringify(error));
      if (this.callback?.onAnalysisError) {
        this.callback.onAnalysisError('分析过程中出现错误');
      }
    }
  }

  /**
   * 调用 AI 分析选中的文本内容
   * @param selectedText 选中的文本
   * @param contextText 上下文文本
   * @returns 分析结果
   */
  private async analyzeSelectedText(
    selectedText: string,
    contextText?: string
  ): Promise<SelectionAnalysisResult | null> {
    try {
      // 1. 优先通过小艺服务进行分析
      const xiaoyiResult = await this.xiaoyiService.triggerIntent(
        XiaoyiService.INTENTS.CIRCLE_SELECTION,
        {
          selectedText: selectedText,
          context: contextText || ''
        }
      );

      if (xiaoyiResult.success && xiaoyiResult.data) {
        const data = xiaoyiResult.data as {
          analysis: string;
          suggestions: string[];
          suggestionId?: string;
        };

        return {
          analysis: data.analysis,
          suggestions: (data.suggestions || []).map((s, index) => ({
            priority: index === 0 ? 'high' : index < 3 ? 'medium' : 'low',
            title: s.length > 20 ? s.substring(0, 20) + '...' : s,
            description: s
          })),
          originalText: selectedText,
          score: xiaoyiResult.data['score'] as number
        };
      }

      // 2. 使用本地 API 作为备选
      return await this.analyzeWithLocalAPI(selectedText, contextText);
    } catch (error) {
      Logger.error(TAG, 'Xiaoyi analysis failed, trying local API:', JSON.stringify(error));
      return await this.analyzeWithLocalAPI(selectedText, contextText);
    }
  }

  /**
   * 使用本地 API 分析选中文本
   * @param selectedText 选中的文本
   * @param contextText 上下文文本
   * @returns 分析结果
   */
  private async analyzeWithLocalAPI(
    selectedText: string,
    contextText?: string
  ): Promise<SelectionAnalysisResult | null> {
    try {
      const response = await this.apiService.post('ai/analyze-selection', {
        content: selectedText,
        context: contextText || '',
        analysisType: 'resume'
      });

      if (response.success && response.data) {
        const data = response.data as SelectionAnalysisResult;
        return {
          analysis: data.analysis,
          suggestions: data.suggestions || [],
          originalText: selectedText,
          score: data.score
        };
      }

      // 返回默认分析结果
      return this.getDefaultAnalysisResult(selectedText);
    } catch (error) {
      Logger.error(TAG, 'Local API analysis failed:', JSON.stringify(error));
      return this.getDefaultAnalysisResult(selectedText);
    }
  }

  /**
   * 获取默认分析结果（当 API 不可用时）
   * @param selectedText 选中的文本
   * @returns 默认分析结果
   */
  private getDefaultAnalysisResult(selectedText: string): SelectionAnalysisResult {
    return {
      analysis: '这段内容描述了您的经历，整体表达清晰。建议在描述中增加更多量化的成果数据，例如"提升了50%的性能"或"服务了10万+用户"等具体指标，同时突出核心技术栈和关键成果。',
      suggestions: [
        {
          priority: 'high',
          title: '增加量化数据',
          description: '建议添加具体的数字和百分比来展示成果'
        },
        {
          priority: 'medium',
          title: '突出技术栈',
          description: '明确列出使用的核心技术和框架'
        },
        {
          priority: 'low',
          title: '精简描述',
          description: '部分句子可以更加简洁有力'
        }
      ],
      originalText: selectedText,
      score: 70
    };
  }

  /**
   * 在划词面板中展示分析结果
   * 使用 createPanel API 创建系统面板
   * @param result 分析结果
   */
  private async showAnalysisInPanel(result: SelectionAnalysisResult): Promise<void> {
    try {
      if (!this.selectionManager) {
        Logger.error(TAG, 'SelectionManager not available for panel');
        return;
      }

      // 构建面板展示内容
      const panelContent = this.buildPanelContent(result);

      // 使用 createPanel 创建分析结果面板
      const panelConfig: selectionInput.PanelConfig = {
        title: '小艺分析结果',
        content: panelContent,
        actions: [
          {
            text: '应用到简历',
            type: 'primary'
          },
          {
            text: '分享分析',
            type: 'secondary'
          }
        ]
      };

      await this.selectionManager.createPanel(panelConfig);

      Logger.info(TAG, 'Analysis panel created successfully');
    } catch (error) {
      Logger.error(TAG, 'Failed to create analysis panel:', JSON.stringify(error));
      // 面板创建失败时通过 Toast 提示
      promptAction.showToast({
        message: '分析完成，请在页面中查看结果',
        duration: 2000
      });
    }
  }

  /**
   * 构建面板展示内容
   * @param result 分析结果
   * @returns 格式化的面板内容文本
   */
  private buildPanelContent(result: SelectionAnalysisResult): string {
    let content = `【内容分析】\n${result.analysis}\n\n`;

    if (result.score !== undefined) {
      content += `【评分】${result.score}分\n\n`;
    }

    if (result.suggestions.length > 0) {
      content += `【优化建议】\n`;
      result.suggestions.forEach((suggestion, index) => {
        const priorityLabel = suggestion.priority === 'high' ? '重要' :
          suggestion.priority === 'medium' ? '建议' : '可选';
        content += `${index + 1}. [${priorityLabel}] ${suggestion.title}: ${suggestion.description}\n`;
      });
    }

    return content;
  }

  /**
   * 手动触发文本分析（用于组件内直接调用）
   * @param selectedText 选中的文本
   * @param contextText 上下文文本
   * @returns 分析结果
   */
  async analyzeText(
    selectedText: string,
    contextText?: string
  ): Promise<SelectionAnalysisResult | null> {
    if (!selectedText || selectedText.trim().length === 0) {
      Logger.warn(TAG, 'Empty text provided for analysis');
      return null;
    }

    return await this.analyzeSelectedText(selectedText, contextText);
  }

  /**
   * 销毁服务，释放资源
   */
  destroy(): void {
    this.stopListening();
    if (this.selectionManager) {
      try {
        this.selectionManager.destroy();
      } catch (error) {
        Logger.error(TAG, 'Error destroying SelectionManager:', JSON.stringify(error));
      }
      this.selectionManager = null;
    }
    this.context = null;
    Logger.info(TAG, 'SelectionService destroyed');
  }
}

export default SelectionService.getInstance();
