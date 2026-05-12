/**
 * ChatService - 聊天服务
 * 
 * 支持：
 * - SSE 流式消息接收
 * - 断线重连机制
 * - 消息发送
 */

import http from '@ohos.net.http';
import { ApiService } from './ApiService';
import { Message, ChatSession, SendMessageResult } from '../models/Message';
import { ResumeAnalysisResult } from '../models/Resume';
import { API_ENDPOINTS, Config } from '../constants/config';

/**
 * SSE 事件类型
 */
export interface SSEEvent {
  event: string;
  data: string;
  id?: string;
  retry?: number;
}

/**
 * SSE 连接状态
 */
export type SSEConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

/**
 * SSE 连接配置
 */
export interface SSEConfig {
  url: string;
  headers?: Record<string, string>;
  retryInterval?: number;  // 重试间隔（毫秒）
  maxRetries?: number;     // 最大重试次数
  timeout?: number;        // 连接超时（毫秒）
}

/**
 * 流式消息回调
 */
export interface StreamCallbacks {
  onMessage?: (content: string, done: boolean) => void;
  onError?: (error: string) => void;
  onComplete?: (fullContent: string) => void;
  onConnectionStateChange?: (state: SSEConnectionState) => void;
}

export class ChatService {
  private apiService: ApiService;
  private static instance: ChatService;
  
  // SSE 相关
  private httpRequest: http.HttpRequest | null = null;
  private connectionState: SSEConnectionState = 'disconnected';
  private retryCount: number = 0;
  private maxRetries: number = 3;
  private retryInterval: number = 1000;
  private reconnectTimer: number = -1;
  private accumulatedContent: string = '';
  private currentCallbacks: StreamCallbacks | null = null;
  private currentConfig: SSEConfig | null = null;
  private lastRequestBody: Record<string, any> = {};
  private streamTimer: number = -1;

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  /**
   * 发送消息（非流式）
   */
  async sendMessage(content: string): Promise<SendMessageResult> {
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: content,
      timestamp: Date.now(),
      status: 'sent'
    };

    try {
      const response = await this.apiService.post<SendMessageResult>(API_ENDPOINTS.CHAT_SEND, {
        content: content,
        conversationId: AppStorage.get<string>('currentConversationId')
      });

      if (response.success && response.data) {
        return response.data;
      } else {
        return {
          content: response.error || '抱歉，发生了错误，请稍后重试。',
          sessionId: AppStorage.get<string>('currentConversationId') || ''
        };
      }
    } catch (error) {
      console.error('[ChatService] Send message failed:', error);
      return {
        content: 'AI助手暂时无法回复，请检查网络后重试。',
        sessionId: AppStorage.get<string>('currentConversationId') || ''
      };
    }
  }

  /**
   * 发送消息并接收流式响应（SSE）
   * @param content 用户消息内容
   * @param callbacks 流式回调
   * @returns 取消连接的函数
   */
  async sendMessageStream(
    content: string,
    callbacks: StreamCallbacks
  ): Promise<() => void> {
    // 保存回调
    this.currentCallbacks = callbacks;
    
    // 构造 SSE URL
    const baseUrl = AppStorage.get<string>('baseUrl') || Config.API_BASE_URL;
    const token = AppStorage.get<string>('token');
    const conversationId = AppStorage.get<string>('currentConversationId');
    
    // SSE 配置
    this.currentConfig = {
      url: `${baseUrl}${API_ENDPOINTS.CHAT_SEND}/stream`,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : '',
        'Accept': 'text/event-stream'
      },
      retryInterval: 1000,
      maxRetries: 3,
      timeout: 60000
    };

    // 重置状态
    this.accumulatedContent = '';
    this.retryCount = 0;
    
    // 开始 SSE 连接
    await this.connectSSE({
      content: content,
      conversationId: conversationId
    });

    // 返回取消函数
    return () => this.disconnectSSE();
  }

  /**
   * 连接 SSE
   */
  private async connectSSE(body: object): Promise<void> {
    // 保存请求体，用于断线重连
    this.lastRequestBody = { ...body };

    if (!this.currentConfig) {
      return;
    }

    // 更新连接状态
    this.updateConnectionState('connecting');

    try {
      // 创建 HTTP 请求
      this.httpRequest = http.createHttp();
      
      // 设置超时
      const timeout = this.currentConfig.timeout || 60000;
      
      // 发起请求
      const response = await this.httpRequest.request(
        this.currentConfig.url,
        {
          method: http.RequestMethod.POST,
          header: this.currentConfig.headers,
          extraData: JSON.stringify(body),
          connectTimeout: timeout,
          readTimeout: timeout,
          expectDataType: http.HttpDataType.STRING
        }
      );

      // 检查响应状态
      if (response.responseCode === 200) {
        this.updateConnectionState('connected');
        this.retryCount = 0;
        
        // 解析 SSE 响应
        this.parseSSEResponse(response.result as string);
      } else if (response.responseCode === 401) {
        // 未授权
        this.updateConnectionState('error');
        this.currentCallbacks?.onError?.('登录已过期，请重新登录');
      } else {
        // 其他错误
        this.updateConnectionState('error');
        this.handleConnectionError(`请求失败: ${response.responseCode}`);
      }
    } catch (error) {
      console.error('[ChatService] SSE connection failed:', error);
      this.updateConnectionState('error');
      this.handleConnectionError(String(error));
    }
  }

  /**
   * 解析 SSE 响应
   */
  private parseSSEResponse(responseText: string): void {
    const lines = responseText.split('\n');
    let currentEvent: SSEEvent = { event: '', data: '' };

    for (const line of lines) {
      if (line.startsWith('event:')) {
        currentEvent.event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        currentEvent.data = line.substring(5).trim();
      } else if (line.startsWith('id:')) {
        currentEvent.id = line.substring(3).trim();
      } else if (line.startsWith('retry:')) {
        currentEvent.retry = parseInt(line.substring(6).trim());
      } else if (line === '') {
        // 空行表示事件结束
        if (currentEvent.data) {
          this.handleSSEEvent(currentEvent);
        }
        currentEvent = { event: '', data: '' };
      }
    }

    // 处理最后一个事件
    if (currentEvent.data) {
      this.handleSSEEvent(currentEvent);
    }
  }

  /**
   * 处理 SSE 事件
   */
  private handleSSEEvent(event: SSEEvent): void {
    try {
      // 解析数据
      const data = JSON.parse(event.data);
      
      switch (event.event) {
        case 'message':
        case 'delta':
          // 增量消息
          if (data.content) {
            this.accumulatedContent += data.content;
            this.currentCallbacks?.onMessage?.(this.accumulatedContent, false);
          }
          break;
          
        case 'done':
        case 'complete':
          // 完成
          if (data.content) {
            this.accumulatedContent = data.content;
          }
          this.currentCallbacks?.onMessage?.(this.accumulatedContent, true);
          this.currentCallbacks?.onComplete?.(this.accumulatedContent);
          this.disconnectSSE();
          break;
          
        case 'error':
          // 错误
          this.currentCallbacks?.onError?.(data.message || '未知错误');
          this.disconnectSSE();
          break;
          
        default:
          // 默认处理：尝试作为增量消息
          if (data.content) {
            this.accumulatedContent += data.content;
            this.currentCallbacks?.onMessage?.(this.accumulatedContent, false);
          } else if (data.delta) {
            this.accumulatedContent += data.delta;
            this.currentCallbacks?.onMessage?.(this.accumulatedContent, false);
          } else if (data.done === true) {
            this.currentCallbacks?.onMessage?.(this.accumulatedContent, true);
            this.currentCallbacks?.onComplete?.(this.accumulatedContent);
            this.disconnectSSE();
          }
      }
    } catch (e) {
      // JSON 解析失败，可能是纯文本数据
      if (event.data && event.data !== '[DONE]') {
        this.accumulatedContent += event.data;
        this.currentCallbacks?.onMessage?.(this.accumulatedContent, false);
      } else if (event.data === '[DONE]') {
        this.currentCallbacks?.onMessage?.(this.accumulatedContent, true);
        this.currentCallbacks?.onComplete?.(this.accumulatedContent);
        this.disconnectSSE();
      }
    }
  }

  /**
   * 处理连接错误
   */
  private handleConnectionError(error: string): void {
    console.error('[ChatService] Connection error:', error);
    
    // 检查是否需要重连
    if (this.retryCount < this.maxRetries) {
      this.retryCount++;
      const delay = this.retryInterval * Math.pow(2, this.retryCount - 1); // 指数退避
      
      console.log(`[ChatService] Retrying in ${delay}ms (attempt ${this.retryCount}/${this.maxRetries})`);
      
      this.reconnectTimer = setTimeout(() => {
        if (this.currentConfig) {
          this.connectSSE(this.lastRequestBody);
        }
      }, delay);
    } else {
      // 超过最大重试次数，返回明确的错误提示而非模拟数据
      this.currentCallbacks?.onError?.('AI助手暂时无法回复，请检查网络后重试');
      this.updateConnectionState('disconnected');
    }
  }

  /**
   * 断开 SSE 连接
   */
  disconnectSSE(): void {
    // 清除重连定时器
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }

    // 清除模拟流式输出定时器
    if (this.streamTimer !== -1) {
      clearInterval(this.streamTimer);
      this.streamTimer = -1;
    }
    
    // 销毁 HTTP 请求
    if (this.httpRequest) {
      this.httpRequest.destroy();
      this.httpRequest = null;
    }
    
    // 更新状态
    this.updateConnectionState('disconnected');
    
    // 清理
    this.currentCallbacks = null;
    this.currentConfig = null;
  }

  /**
   * 更新连接状态
   */
  private updateConnectionState(state: SSEConnectionState): void {
    this.connectionState = state;
    this.currentCallbacks?.onConnectionStateChange?.(state);
  }

  /**
   * 获取当前连接状态
   */
  getConnectionState(): SSEConnectionState {
    return this.connectionState;
  }

  /**
   * 是否已连接
   */
  isConnected(): boolean {
    return this.connectionState === 'connected';
  }

  /**
   * 获取聊天历史
   */
  async getChatHistory(sessionId: string): Promise<Message[]> {
    const response = await this.apiService.get<Message[]>(API_ENDPOINTS.CHAT_HISTORY, {
      sessionId: sessionId
    });

    if (!response.success || !response.data) {
      throw new Error(response.error || '获取聊天历史失败');
    }

    return response.data;
  }

  /**
   * 获取会话列表
   */
  async getSessions(): Promise<ChatSession[]> {
    const response = await this.apiService.get<ChatSession[]>(API_ENDPOINTS.CHAT_SESSIONS);

    if (!response.success || !response.data) {
      throw new Error(response.error || '获取会话列表失败');
    }

    return response.data;
  }

  /**
   * 分析简历
   */
  async analyzeResume(fileUri: string): Promise<ResumeAnalysisResult> {
    try {
      const response = await this.apiService.post<ResumeAnalysisResult>(API_ENDPOINTS.RESUME_ANALYZE, {
        fileUri: fileUri
      });

      if (response.success && response.data) {
        return response.data;
      } else {
        throw new Error(response.error || '简历分析失败');
      }
    } catch (error) {
      console.error('[ChatService] Analyze resume failed:', error);
      throw error;
    }
  }

  /**
   * 生成模拟回复
   * [仅用于开发调试] 生产环境中 API 请求失败时应返回明确的错误提示，不应使用模拟数据
   * @deprecated 审核期间禁用，API 失败时请直接返回错误提示
   */
  generateMockReply(content: string): string {
    const tips = [
      '根据您的情况，我建议您可以从以下几个方面提升简历质量：\n\n1. 突出项目经验中的量化成果\n2. 优化技能描述，使用行业关键词\n3. 完善自我评价，展现个人优势',
      '面试技巧方面，建议您注意以下几点：\n\n1. 提前了解公司背景和岗位要求\n2. 准备STAR法则描述项目经历\n3. 准备一些反问面试官的问题',
      '关于职业规划，我建议您：\n\n1. 明确短期（1-2年）和长期（3-5年）目标\n2. 了解目标岗位的发展路径\n3. 持续学习相关技能',
      '根据当前市场情况，Java开发工程师的薪资范围大致如下：\n\n- 初级：8-15K\n- 中级：15-25K\n- 高级：25-40K\n\n具体还要看城市、公司规模和您的经验水平。',
      '简历投递建议：\n\n1. 针对不同岗位定制简历关键词\n2. 选择上午9-11点投递简历\n3. 关注目标公司的招聘节奏\n4. 积极通过内推渠道'
    ];

    if (content.includes('简历')) {
      return tips[0];
    } else if (content.includes('面试')) {
      return tips[1];
    } else if (content.includes('规划') || content.includes('发展')) {
      return tips[2];
    } else if (content.includes('薪资') || content.includes('工资')) {
      return tips[3];
    } else if (content.includes('投递') || content.includes('渠道')) {
      return tips[4];
    }

    return tips[Math.floor(Math.random() * tips.length)];
  }

  /**
   * 模拟流式输出
   * [仅用于开发调试] 生产环境中 API 请求失败时应返回明确的错误提示，不应使用模拟数据
   * @deprecated 审核期间禁用，API 失败时请直接返回错误提示
   * @param content 用户消息
   * @param callbacks 流式回调
   * @param charDelay 字符延迟（毫秒）
   */
  async simulateStreamOutput(
    content: string,
    callbacks: StreamCallbacks,
    charDelay: number = 40
  ): Promise<void> {
    const fullResponse = this.generateMockReply(content);
    let currentIndex = 0;
    
    this.updateConnectionState('connecting');
    this.updateConnectionState('connected');
    
    return new Promise<void>((resolve) => {
      this.streamTimer = setInterval(() => {
        if (currentIndex < fullResponse.length) {
          currentIndex++;
          const partialContent = fullResponse.substring(0, currentIndex);
          callbacks.onMessage?.(partialContent, false);
        } else {
          clearInterval(this.streamTimer);
          this.streamTimer = -1;
          callbacks.onMessage?.(fullResponse, true);
          callbacks.onComplete?.(fullResponse);
          this.updateConnectionState('disconnected');
          resolve();
        }
      }, charDelay);
    });
  }
}
