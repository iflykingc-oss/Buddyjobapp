import { ExtensionAbility, Want, common } from '@kit.AbilityKit';
import { selectionInput } from '@ohos.selectionInput.selectionManager';
import { SelectionService, SelectionAnalysisResult } from './SelectionService';
import { XiaoyiService } from './XiaoyiService';
import { Logger } from '../utils/logger';

const TAG = 'SelectionExtensionAbility';

/**
 * 小艺圈选扩展能力
 * 继承 SelectionExtensionAbility，处理划词面板的创建和内容展示
 * 
 * 当用户在系统任意位置划选文本时，系统会拉起此扩展能力，
 * 展示"小艺分析"选项，用户点击后进行 AI 分析并展示结果面板。
 */
export default class SelectionExtensionAbility extends ExtensionAbility {
  private selectionService: SelectionService;
  private xiaoyiService: XiaoyiService;

  onCreate(want: Want): void {
    Logger.info(TAG, 'SelectionExtensionAbility onCreate');
    this.selectionService = SelectionService.getInstance();
    this.xiaoyiService = XiaoyiService.getInstance();
  }

  onDestroy(): void {
    Logger.info(TAG, 'SelectionExtensionAbility onDestroy');
    this.selectionService.destroy();
  }

  /**
   * 处理划词请求
   * 当用户划选文本后，系统调用此方法
   * @param want 包含选中文本的 Want 对象
   */
  onRequest(want: Want, startId: number): void {
    Logger.info(TAG, `SelectionExtensionAbility onRequest, startId: ${startId}`);

    try {
      // 从 Want 中获取选中的文本
      const selectedText = this.extractSelectedText(want);

      if (selectedText && selectedText.trim().length > 0) {
        Logger.info(TAG, `Extracted selected text: ${selectedText.substring(0, 100)}...`);

        // 异步处理分析
        this.handleSelectionAnalysis(selectedText, want);
      } else {
        Logger.warn(TAG, 'No text selected or text extraction failed');
      }
    } catch (error) {
      Logger.error(TAG, 'Error in onRequest:', JSON.stringify(error));
    }
  }

  /**
   * 从 Want 参数中提取选中的文本
   * @param want Want 对象
   * @returns 选中的文本内容
   */
  private extractSelectedText(want: Want): string {
    // 方式1：从 Want parameters 中获取
    if (want.parameters) {
      // 尝试获取 ohos.extra.text（系统划词传递的文本参数）
      const extraText = want.parameters['ohos.extra.text'] as string;
      if (extraText) {
        return extraText;
      }

      // 尝试获取 selectedText 参数
      const selectedText = want.parameters['selectedText'] as string;
      if (selectedText) {
        return selectedText;
      }

      // 尝试获取 text 参数
      const text = want.parameters['text'] as string;
      if (text) {
        return text;
      }

      // 尝试获取 uri 中的文本
      const uri = want.uri as string;
      if (uri && uri.startsWith('text:')) {
        return decodeURIComponent(uri.substring(5));
      }
    }

    // 方式2：从 Want 的 text 字段获取
    if (want.text) {
      return want.text;
    }

    return '';
  }

  /**
   * 处理选中文本的 AI 分析
   * @param selectedText 选中的文本
   * @param want 原始 Want 对象
   */
  private async handleSelectionAnalysis(selectedText: string, want: Want): Promise<void> {
    try {
      // 初始化 SelectionService
      const initialized = await this.selectionService.initialize(this.context as common.UIAbilityContext);
      if (!initialized) {
        Logger.error(TAG, 'Failed to initialize SelectionService');
        return;
      }

      // 获取上下文信息（如果有）
      const contextText = want.parameters?.['context'] as string || '';

      // 调用 AI 分析
      const result = await this.selectionService.analyzeText(selectedText, contextText);

      if (result) {
        Logger.info(TAG, 'Analysis completed successfully');

        // 创建分析结果面板
        await this.createAnalysisPanel(result);

        // 通过小艺服务返回结果
        this.notifyXiaoyiResult(selectedText, result);
      } else {
        Logger.error(TAG, 'Analysis returned null result');
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling selection analysis:', JSON.stringify(error));
    }
  }

  /**
   * 创建分析结果面板
   * 使用 selectionManager 的 createPanel API 在系统划词面板中展示分析结果
   * @param result 分析结果
   */
  private async createAnalysisPanel(result: SelectionAnalysisResult): Promise<void> {
    try {
      // 构建 PanelConfig
      const panelContent = this.formatAnalysisContent(result);

      const panelConfig: selectionInput.PanelConfig = {
        title: '小艺简历分析',
        content: panelContent,
        icon: 'app.media.ic_xiaoyi',
        actions: [
          {
            text: '查看详情',
            type: 'primary',
            action: () => {
              // 跳转到应用内详情页面
              this.navigateToDetail(result);
            }
          },
          {
            text: '复制结果',
            type: 'secondary',
            action: () => {
              // 复制分析结果到剪贴板
              this.copyToClipboard(panelContent);
            }
          }
        ]
      };

      // 使用 SelectionService 创建面板
      await this.selectionService.createAnalysisPanel(
        result.originalText,
        panelContent
      );

      Logger.info(TAG, 'Analysis panel created');
    } catch (error) {
      Logger.error(TAG, 'Failed to create analysis panel:', JSON.stringify(error));
    }
  }

  /**
   * 格式化分析内容用于面板展示
   * @param result 分析结果
   * @returns 格式化后的文本
   */
  private formatAnalysisContent(result: SelectionAnalysisResult): string {
    let content = '';

    // 评分信息
    if (result.score !== undefined) {
      content += `评分: ${result.score}/100\n\n`;
    }

    // 分析内容
    content += `${result.analysis}\n\n`;

    // 优化建议
    if (result.suggestions.length > 0) {
      content += '优化建议:\n';
      result.suggestions.forEach((suggestion, index) => {
        const priorityIcon = suggestion.priority === 'high' ? '!!' :
          suggestion.priority === 'medium' ? '!' : '-';
        content += `${index + 1}. ${priorityIcon} ${suggestion.title}\n   ${suggestion.description}\n`;
      });
    }

    return content;
  }

  /**
   * 通知小艺服务分析结果
   * @param originalText 原始选中文本
   * @param result 分析结果
   */
  private notifyXiaoyiResult(originalText: string, result: SelectionAnalysisResult): void {
    try {
      // 通过小艺意图系统通知结果
      this.xiaoyiService.triggerIntent(
        XiaoyiService.INTENTS.CIRCLE_SELECTION,
        {
          selectedText: originalText,
          analysisResult: result as unknown as Record<string, object>
        }
      );
    } catch (error) {
      Logger.error(TAG, 'Failed to notify Xiaoyi:', JSON.stringify(error));
    }
  }

  /**
   * 跳转到应用内详情页面
   * @param result 分析结果
   */
  private navigateToDetail(result: SelectionAnalysisResult): void {
    try {
      // 使用 Want 跳转到应用内的分析详情页面
      const want: Want = {
        bundleName: 'com.buddyjob.app',
        abilityName: 'EntryAbility',
        uri: 'pages/Resume',
        parameters: {
          action: 'show_analysis',
          analysisResult: JSON.stringify(result)
        }
      };
      this.context.startAbility(want);
    } catch (error) {
      Logger.error(TAG, 'Failed to navigate to detail:', JSON.stringify(error));
    }
  }

  /**
   * 复制文本到剪贴板
   * @param text 要复制的文本
   */
  private async copyToClipboard(text: string): Promise<void> {
    try {
      const pasteData = await import('@ohos.pasteboard');
      const systemPasteboard = pasteData.getSystemPasteboard();
      await systemPasteboard.setData(pasteData.createPlainTextData(text));
      Logger.info(TAG, 'Analysis result copied to clipboard');
    } catch (error) {
      Logger.error(TAG, 'Failed to copy to clipboard:', JSON.stringify(error));
    }
  }
}
