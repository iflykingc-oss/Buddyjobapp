import { ExtensionAbility, Want } from '@kit.AbilityKit';
import { agentFramework } from '@kit.IntelligentAgentKit';
import { XiaoyiService } from './XiaoyiService';
import { Logger } from '../utils/logger';

const TAG = 'XiaoyiAgentExtension';

/**
 * 小艺智能体扩展能力
 * 作为系统入口接收小艺意图调用
 */
export default class XiaoyiAgentExtension extends ExtensionAbility {
  private xiaoyiService: XiaoyiService;

  onCreate(want: Want): void {
    Logger.info(TAG, 'XiaoyiAgentExtension onCreate');
    this.xiaoyiService = XiaoyiService.getInstance();

    // 初始化小艺服务
    this.initializeService();
  }

  onDestroy(): void {
    Logger.info(TAG, 'XiaoyiAgentExtension onDestroy');
  }

  onRequest(want: Want, startId: number): void {
    Logger.info(TAG, `XiaoyiAgentExtension onRequest, startId: ${startId}`);

    // 处理来自小艺的请求
    const intentName = want.parameters?.['intentName'] as string;
    const params = want.parameters?.['params'] as Record<string, object>;

    if (intentName) {
      this.handleIntent(intentName, params || {});
    }
  }

  /**
   * 初始化服务
   */
  private async initializeService(): Promise<void> {
    try {
      const success = await this.xiaoyiService.initialize();
      if (success) {
        Logger.info(TAG, 'XiaoyiService initialized in Extension');
      } else {
        Logger.error(TAG, 'Failed to initialize XiaoyiService in Extension');
      }
    } catch (error) {
      Logger.error(TAG, 'Error initializing XiaoyiService:', error);
    }
  }

  /**
   * 处理意图
   */
  private async handleIntent(intentName: string, params: Record<string, object>): Promise<void> {
    Logger.info(TAG, `Handling intent: ${intentName}`, params);

    try {
      const result = await this.xiaoyiService.triggerIntent(intentName, params);

      // 将结果返回给小艺
      agentFramework.sendResponse({
        intentName,
        success: result.success,
        message: result.message,
        data: result.data,
        actions: result.actions
      });
    } catch (error) {
      Logger.error(TAG, `Error handling intent ${intentName}:`, error);
      agentFramework.sendResponse({
        intentName,
        success: false,
        message: '处理请求时出现错误',
        error: error.message
      });
    }
  }
}
