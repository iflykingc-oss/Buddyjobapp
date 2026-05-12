import { ApiService } from './ApiService';
import { HMSUtils, HMSErrorCode, HMSServiceType, HMSPushUtils } from '../utils/hms';
import { API_ENDPOINTS } from '../constants/config';
import { Router } from '../utils/Router';
import promptAction from '@ohos.promptAction';
import { hmsPush } from '@hw-agconnect/push';

/**
 * 推送消息类型
 */
export enum PushMessageType {
  CHAT = 'chat',           // 聊天消息
  SYSTEM = 'system',       // 系统通知
  VIP_EXPIRE = 'vip_expire', // 会员到期提醒
  ORDER = 'order',         // 订单通知
  ACTIVITY = 'activity',   // 活动通知
}

/**
 * 推送消息数据结构
 */
export interface PushMessage {
  // 消息唯一标识
  messageId: string;
  // 消息类型
  type: PushMessageType;
  // 消息标题
  title: string;
  // 消息内容
  content: string;
  // 附加数据
  payload?: Record<string, any>;
  // 发送时间
  timestamp: number;
  // 是否已读
  isRead?: boolean;
}

/**
 * 聊天消息推送数据
 */
export interface ChatPushData {
  sessionId: string;
  senderId: string;
  senderName: string;
  messageType: 'text' | 'image' | 'file';
  content: string;
  timestamp: number;
}

/**
 * 系统通知推送数据
 */
export interface SystemPushData {
  noticeId: string;
  category: string;
  actionUrl?: string;
  priority: 'high' | 'normal' | 'low';
}

/**
 * 会员到期提醒数据
 */
export interface VipExpirePushData {
  expireTime: number;
  daysRemaining: number;
  productId: string;
}

/**
 * 推送服务配置
 */
export interface PushServiceConfig {
  // 是否自动获取 token
  autoGetToken: boolean;
  // 是否显示通知
  showNotification: boolean;
  // 消息点击处理方式
  onMessageClick?: (message: PushMessage) => void;
}

/**
 * 推送服务 - 集成华为 Push Kit
 */
export class PushService {
  private static instance: PushService;
  private apiService: ApiService;
  private hmsUtils: HMSUtils;
  private isInitialized: boolean = false;
  private pushToken: string = '';
  private messageListeners: Set<(message: PushMessage) => void> = new Set();
  private config: PushServiceConfig = {
    autoGetToken: true,
    showNotification: true,
  };

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.hmsUtils = HMSUtils.getInstance();
  }

  static getInstance(): PushService {
    if (!PushService.instance) {
      PushService.instance = new PushService();
    }
    return PushService.instance;
  }

  /**
   * 初始化推送服务
   */
  async init(config?: Partial<PushServiceConfig>): Promise<boolean> {
    try {
      // 合并配置
      if (config) {
        this.config = { ...this.config, ...config };
      }

      // 检查推送服务是否可用
      const isAvailable = await this.hmsUtils.checkServiceAvailability(HMSServiceType.PUSH);
      if (!isAvailable) {
        console.warn('[PushService] Huawei Push Kit is not available');
        return false;
      }

      // 注册推送回调
      this.registerPushCallbacks();

      // 自动获取 token
      if (this.config.autoGetToken) {
        await this.getPushToken();
      }

      this.isInitialized = true;
      console.info('[PushService] Initialized successfully');
      return true;
    } catch (error) {
      console.error('[PushService] Init failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 注册推送回调
   */
  private registerPushCallbacks(): void {
    // 注册 Token 回调
    HMSPushUtils.onToken((token: string) => {
      this.handleTokenCallback(token);
    });

    // 注册消息接收回调
    HMSPushUtils.onMessage((message: hmsPush.PushMessage) => {
      this.handleMessageCallback(message);
    });

    // 注册消息点击回调
    HMSPushUtils.onMessageClicked((message: hmsPush.PushMessage) => {
      this.handleMessageClickCallback(message);
    });
  }

  /**
   * 处理 token 回调
   */
  private handleTokenCallback(token: string): void {
    if (token) {
      this.pushToken = token;
      console.info('[PushService] Token received:', token.substring(0, 10) + '...');

      // 上报 token 到服务器
      this.reportTokenToServer(token);
    } else {
      console.error('[PushService] Token callback error: empty token');
    }
  }

  /**
   * 处理消息接收回调
   */
  private handleMessageCallback(message: hmsPush.PushMessage): void {
    try {
      console.info('[PushService] Message received:', message);

      const parsedMessage = this.parsePushMessage(message);
      if (parsedMessage) {
        // 通知所有监听器
        this.messageListeners.forEach(listener => {
          try {
            listener(parsedMessage);
          } catch (e) {
            console.error('[PushService] Message listener error:', e);
          }
        });

        // 显示本地通知
        if (this.config.showNotification) {
          this.showLocalNotification(parsedMessage);
        }
      }
    } catch (error) {
      console.error('[PushService] Handle message callback error:', error);
    }
  }

  /**
   * 处理消息点击回调
   */
  private handleMessageClickCallback(message: hmsPush.PushMessage): void {
    try {
      console.info('[PushService] Message clicked:', message);

      const parsedMessage = this.parsePushMessage(message);
      if (parsedMessage) {
        // 标记消息已读
        this.markMessageAsRead(parsedMessage.messageId);

        // 执行自定义点击处理
        if (this.config.onMessageClick) {
          this.config.onMessageClick(parsedMessage);
        } else {
          // 默认处理：根据消息类型跳转
          this.handleDefaultMessageClick(parsedMessage);
        }
      }
    } catch (error) {
      console.error('[PushService] Handle message click error:', error);
    }
  }

  /**
   * 解析推送消息
   */
  private parsePushMessage(data: hmsPush.PushMessage): PushMessage | null {
    try {
      // 解析消息数据
      let messageData: any;

      if (typeof data.data === 'string') {
        messageData = JSON.parse(data.data);
      } else {
        messageData = data.data || data;
      }

      return {
        messageId: messageData.messageId || data.messageId || String(Date.now()),
        type: messageData.type || PushMessageType.SYSTEM,
        title: messageData.title || data.title || '新消息',
        content: messageData.content || messageData.message || data.content || '',
        payload: messageData.payload || messageData.extras,
        timestamp: messageData.timestamp || Date.now(),
        isRead: false,
      };
    } catch (error) {
      console.error('[PushService] Parse message error:', error);
      return null;
    }
  }

  /**
   * 默认消息点击处理
   */
  private handleDefaultMessageClick(message: PushMessage): void {
    switch (message.type) {
      case PushMessageType.CHAT:
        // 跳转到聊天页面
        if (message.payload?.sessionId) {
          Router.push('pages/Chat', { sessionId: message.payload.sessionId });
        }
        break;

      case PushMessageType.SYSTEM:
        // 跳转到系统通知详情
        if (message.payload?.noticeId) {
          Router.push('pages/NotificationDetail', { noticeId: message.payload.noticeId });
        }
        break;

      case PushMessageType.VIP_EXPIRE:
        // 跳转到会员页面
        Router.push('pages/Vip');
        break;

      case PushMessageType.ORDER:
        // 跳转到订单详情
        if (message.payload?.orderId) {
          Router.push('pages/OrderDetail', { orderId: message.payload.orderId });
        }
        break;

      default:
        console.info('[PushService] Unknown message type:', message.type);
    }
  }

  /**
   * 显示本地通知
   */
  private showLocalNotification(message: PushMessage): void {
    // 使用 promptAction 显示简单的通知提示
    // 实际项目中可以使用更复杂的本地通知 API
    promptAction.showToast({
      message: `${message.title}: ${message.content.substring(0, 50)}`,
      duration: 3000,
    });
  }

  /**
   * 获取推送 token
   */
  async getPushToken(): Promise<string | null> {
    try {
      const token = await HMSPushUtils.getToken();

      if (token) {
        this.pushToken = token;
        await this.reportTokenToServer(token);
        return token;
      }

      return null;
    } catch (error) {
      console.error('[PushService] Get token failed:', error);
      this.hmsUtils.handleHMSError(error);
      return null;
    }
  }

  /**
   * 上报 token 到服务器
   */
  private async reportTokenToServer(token: string): Promise<void> {
    try {
      const response = await this.apiService.post(API_ENDPOINTS.PUSH_REGISTER, {
        pushToken: token,
        platform: 'huawei',
        deviceType: 'harmony',
      });

      if (response.success) {
        console.info('[PushService] Token reported to server successfully');
      } else {
        console.error('[PushService] Report token failed:', response.error);
      }
    } catch (error) {
      console.error('[PushService] Report token error:', error);
    }
  }

  /**
   * 删除推送 token（注销推送）
   */
  async deletePushToken(): Promise<boolean> {
    try {
      const result = await HMSPushUtils.deleteToken();

      if (result) {
        // 通知服务器删除 token
        if (this.pushToken) {
          await this.apiService.post(API_ENDPOINTS.PUSH_UNREGISTER, {
            pushToken: this.pushToken,
          });
        }

        this.pushToken = '';
        console.info('[PushService] Token deleted successfully');
        return true;
      }

      return false;
    } catch (error) {
      console.error('[PushService] Delete token failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 订阅消息主题
   */
  async subscribeTopic(topic: string): Promise<boolean> {
    try {
      return await HMSPushUtils.subscribeTopic(topic);
    } catch (error) {
      console.error('[PushService] Subscribe topic failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 取消订阅消息主题
   */
  async unsubscribeTopic(topic: string): Promise<boolean> {
    try {
      return await HMSPushUtils.unsubscribeTopic(topic);
    } catch (error) {
      console.error('[PushService] Unsubscribe topic failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 添加消息监听
   */
  addMessageListener(listener: (message: PushMessage) => void): () => void {
    this.messageListeners.add(listener);

    // 返回取消订阅函数
    return () => {
      this.messageListeners.delete(listener);
    };
  }

  /**
   * 移除消息监听
   */
  removeMessageListener(listener: (message: PushMessage) => void): void {
    this.messageListeners.delete(listener);
  }

  /**
   * 标记消息已读
   */
  private async markMessageAsRead(messageId: string): Promise<void> {
    try {
      await this.apiService.post(API_ENDPOINTS.PUSH_READ, { messageId });
    } catch (error) {
      console.error('[PushService] Mark message as read failed:', error);
    }
  }

  /**
   * 获取未读消息列表
   */
  async getUnreadMessages(): Promise<PushMessage[]> {
    try {
      const response = await this.apiService.get<PushMessage[]>(
        API_ENDPOINTS.PUSH_MESSAGES,
        { unreadOnly: true }
      );

      if (response.success && response.data) {
        return response.data;
      }

      return [];
    } catch (error) {
      console.error('[PushService] Get unread messages failed:', error);
      return [];
    }
  }

  /**
   * 发送本地通知（用于测试）
   */
  sendLocalNotification(message: Omit<PushMessage, 'messageId' | 'timestamp'>): void {
    const fullMessage: PushMessage = {
      ...message,
      messageId: `local_${Date.now()}`,
      timestamp: Date.now(),
    };

    this.showLocalNotification(fullMessage);
  }

  /**
   * 检查推送服务是否可用
   */
  isAvailable(): boolean {
    return this.isInitialized;
  }

  /**
   * 获取当前推送 token
   */
  getCurrentToken(): string {
    return this.pushToken;
  }

  /**
   * 销毁推送服务
   */
  async destroy(): Promise<void> {
    // 移除回调监听
    HMSPushUtils.offAll();

    // 清空监听器
    this.messageListeners.clear();

    // 删除 token
    await this.deletePushToken();

    this.isInitialized = false;
    console.info('[PushService] Destroyed');
  }
}

export default PushService.getInstance();
