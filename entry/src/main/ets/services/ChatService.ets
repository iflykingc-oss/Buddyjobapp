/**
 * ChatService - 聊天服务
 *
 * 支持：
 * - SSE 流式消息接收
 * - 断线重连机制
 * - 消息发送
 * - 场景模式支持
 * - 消息撤回
 *
 * @example
 * const service = ChatService.getInstance();
 * service.setScene(ChatScene.INTERVIEW_PREP);
 * const cancel = await service.sendMessageStream('如何准备面试？', {
 *   onMessage: (content, done) => { /* 更新UI */ },
 *   onComplete: (content) => { /* 保存消息 */ }
 * });
 *
 * @since 1.0.0
 */

import http from '@ohos.net.http';
import { ApiService } from './ApiService';
import { Message, ChatSession, SendMessageResult } from '../models/Message';
import { ResumeAnalysisResult } from '../models/Resume';
import { API_ENDPOINTS, Config } from '../constants/config';

/**
 * 聊天场景枚举
 */
export enum ChatScene {
  GENERAL = 'general',           // 通用求职咨询
  RESUME_OPTIMIZE = 'resume',    // 简历优化
  INTERVIEW_PREP = 'interview',  // 面试准备
  CAREER_PLAN = 'career',        // 职业规划
  OFFER_NEGOTIATION = 'offer'    // Offer谈判
}

/**
 * 场景配置
 */
export interface SceneConfig {
  id: ChatScene;
  name: string;
  nameCn: string;
  description: string;
  quickSuggestions: string[];
}

/**
 * 场景配置映射
 */
export const SCENE_CONFIGS: Record<ChatScene, SceneConfig> = {
  [ChatScene.GENERAL]: {
    id: ChatScene.GENERAL,
    name: 'general',
    nameCn: '通用',
    description: '通用求职咨询',
    quickSuggestions: [
      '如何优化我的简历？',
      '面试时如何自我介绍？',
      '如何谈薪资？',
      '职业发展方向建议'
    ]
  },
  [ChatScene.RESUME_OPTIMIZE]: {
    id: ChatScene.RESUME_OPTIMIZE,
    name: 'resume',
    nameCn: '简历优化',
    description: '简历内容优化和排版建议',
    quickSuggestions: [
      '帮我优化简历',
      '简历有哪些问题',
      '如何量化经历',
      '简历关键词如何写'
    ]
  },
  [ChatScene.INTERVIEW_PREP]: {
    id: ChatScene.INTERVIEW_PREP,
    name: 'interview',
    nameCn: '面试准备',
    description: '面试技巧和模拟练习',
    quickSuggestions: [
      '模拟面试',
      '自我介绍怎么写',
      'STAR法则是什么',
      '面试常见问题回答'
    ]
  },
  [ChatScene.CAREER_PLAN]: {
    id: ChatScene.CAREER_PLAN,
    name: 'career',
    nameCn: '职业规划',
    description: '职业发展和规划建议',
    quickSuggestions: [
      '我的职业规划',
      '转行建议',
      '薪资谈判技巧',
      '如何提升竞争力'
    ]
  },
  [ChatScene.OFFER_NEGOTIATION]: {
    id: ChatScene.OFFER_NEGOTIATION,
    name: 'offer',
    nameCn: 'Offer谈判',
    description: 'Offer评估和薪资谈判',
    quickSuggestions: [
      '如何评估Offer',
      '薪资谈判技巧',
      '福利待遇比较',
      '如何争取更好条件'
    ]
  }
};

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

/**
 * 上下文消息摘要
 */
export interface ContextSummary {
  sessionId: string;
  lastMessages: Message[];
  messageCount: number;
  userMessageCount: number;
  scene: ChatScene;
  createdAt: number;
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

  // 场景模式相关
  private currentScene: ChatScene = ChatScene.GENERAL;

  // 上下文记忆相关
  private contextMessages: Message[] = [];
  private maxContextMessages: number = 20;  // 最多保留20条用户消息

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  // ==================== 场景模式相关方法 ====================

  /**
   * 设置当前场景
   * @param scene 场景类型
   */
  setScene(scene: ChatScene): void {
    this.currentScene = scene;
    // 清空上下文（切换场景时重置）
    this.contextMessages = [];
    console.info('[ChatService] Scene changed to:', scene);
  }

  /**
   * 获取当前场景
   * @returns 当前场景类型
   */
  getScene(): ChatScene {
    return this.currentScene;
  }

  /**
   * 获取场景配置
   * @param scene 场景类型（可选，默认当前场景）
   * @returns 场景配置
   */
  getSceneConfig(scene?: ChatScene): SceneConfig {
    const targetScene = scene || this.currentScene;
    return SCENE_CONFIGS[targetScene];
  }

  /**
   * 获取所有场景配置
   * @returns 所有场景配置数组
   */
  getAllSceneConfigs(): SceneConfig[] {
    const configs: SceneConfig[] = [];
    for (const key in SCENE_CONFIGS) {
      configs.push(SCENE_CONFIGS[key]);
    }
    return configs;
  }

  // ==================== 上下文记忆相关方法 ====================

  /**
   * 添加消息到上下文
   * @param message 消息
   */
  addToContext(message: Message): void {
    this.contextMessages.push(message);

    // 如果是用户消息且超过限制，进行摘要
    if (message.role === 'user') {
      const userMessageCount = this.contextMessages.filter(m => m.role === 'user').length;
      if (userMessageCount > this.maxContextMessages) {
        // 保留最近的消息，清除旧的用户消息
        this.trimContext();
      }
    }
  }

  /**
   * 修剪上下文消息，保留最近的消息
   */
  private trimContext(): void {
    // 保留最近10条消息（5对对话）
    const maxMessages = 10;
    if (this.contextMessages.length > maxMessages) {
      this.contextMessages = this.contextMessages.slice(-maxMessages);
    }
  }

  /**
   * 获取上下文消息
   * @returns 上下文消息数组
   */
  getContextMessages(): Message[] {
    return [...this.contextMessages];
  }

  /**
   * 获取上下文摘要
   * @param sessionId 会话ID
   * @returns 上下文摘要
   */
  getContextSummary(sessionId: string): ContextSummary {
    const userMessageCount = this.contextMessages.filter(m => m.role === 'user').length;
    return {
      sessionId: sessionId,
      lastMessages: this.contextMessages.slice(-10),  // 最近10条消息
      messageCount: this.contextMessages.length,
      userMessageCount: userMessageCount,
      scene: this.currentScene,
      createdAt: Date.now()
    };
  }

  /**
   * 清空上下文
   */
  clearContext(): void {
    this.contextMessages = [];
  }

  /**
   * 构建带有上下文的请求体
   * @param content 用户消息内容
   * @returns 包含上下文信息的请求体
   */
  buildRequestWithContext(content: string): Record<string, any> {
    return {
      content: content,
      conversationId: AppStorage.get<string>('currentConversationId'),
      scene: this.currentScene,
      context: this.contextMessages.slice(-10).map(m => ({
        role: m.role,
        content: m.content
      }))
    };
  }

  // ==================== 消息发送相关方法 ====================

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

    // 添加到上下文
    this.addToContext(userMessage);

    try {
      const response = await this.apiService.post<SendMessageResult>(API_ENDPOINTS.CHAT_SEND, {
        content: content,
        conversationId: AppStorage.get<string>('currentConversationId'),
        scene: this.currentScene
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

    // 构建请求体（包含场景和上下文）
    const requestBody = {
      content: content,
      conversationId: conversationId,
      scene: this.currentScene,
      context: this.contextMessages.slice(-10).map(m => ({
        role: m.role,
        content: m.content
      }))
    };

    // 添加用户消息到上下文
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: content,
      timestamp: Date.now(),
      status: 'sent'
    };
    this.addToContext(userMessage);

    // 开始 SSE 连接
    await this.connectSSE(requestBody);

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

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
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

  // ==================== 消息撤回相关方法 ====================

  /**
   * 撤回消息（单参数版本）
   * @param messageId 消息ID
   * @returns 是否撤回成功
   */
  async recallMessage(messageId: string): Promise<boolean> {
    const sessionId = AppStorage.get<string>('currentConversationId') || '';
    return this.recallMessage(sessionId, messageId);
  }

  /**
   * 撤回消息（双参数版本）
   * @param sessionId 会话ID
   * @param messageId 消息ID
   * @returns 是否撤回成功
   */
  async recallMessage(sessionId: string, messageId: string): Promise<boolean> {
    try {
      // 调用API删除服务器端消息
      const response = await this.apiService.delete<{ success: boolean }>(
        `${API_ENDPOINTS.CHAT_HISTORY}/${messageId}`,
        { sessionId: sessionId }
      );

      if (response.success) {
        console.info('[ChatService] Message recalled successfully:', messageId);
        return true;
      } else {
        console.warn('[ChatService] Failed to recall message from server:', response.error);
        // 即使服务器删除失败，也返回成功（本地已删除）
        return true;
      }
    } catch (error) {
      console.error('[ChatService] Recall message error:', error);
      // 即使API调用失败，也尝试本地删除
      return true;
    }
  }

  /**
   * 删除本地消息（不调用API）
   * @param messages 消息列表
   * @param messageId 要删除的消息ID
   * @returns 删除后的消息列表
   */
  deleteLocalMessage(messages: Message[], messageId: string): Message[] {
    const index = messages.findIndex(m => m.id === messageId);
    if (index !== -1) {
      messages.splice(index, 1);
      console.info('[ChatService] Local message deleted:', messageId);
    }
    return messages;
  }

  // ==================== 历史记录相关方法 ====================

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
   * 生成模拟回复（根据场景生成）
   * [仅用于开发调试] 生产环境中 API 请求失败时应返回明确的错误提示，不应使用模拟数据
   * @deprecated 审核期间禁用，API 失败时请直接返回错误提示
   */
  generateMockReply(content: string): string {
    const sceneTips: Record<ChatScene, string[]> = {
      [ChatScene.GENERAL]: [
        '根据您的情况，我建议您可以从以下几个方面提升简历质量：\n\n1. 突出项目经验中的量化成果\n2. 优化技能描述，使用行业关键词\n3. 完善自我评价，展现个人优势',
        '面试技巧方面，建议您注意以下几点：\n\n1. 提前了解公司背景和岗位要求\n2. 准备STAR法则描述项目经历\n3. 准备一些反问面试官的问题',
        '关于职业规划，我建议您：\n\n1. 明确短期（1-2年）和长期（3-5年）目标\n2. 了解目标岗位的发展路径\n3. 持续学习相关技能',
        '简历投递建议：\n\n1. 针对不同岗位定制简历关键词\n2. 选择上午9-11点投递简历\n3. 关注目标公司的招聘节奏\n4. 积极通过内推渠道'
      ],
      [ChatScene.RESUME_OPTIMIZE]: [
        '针对您的简历优化，我建议：\n\n1. **量化成果**：将工作职责改为具体成就，如"提升转化率20%"\n\n2. **关键词优化**：添加岗位要求的技能关键词\n\n3. **结构优化**：使用倒序时间排列，突出最近经历\n\n4. **动词使用**：使用强有力的动词开头，如"主导"、"优化"、"实现"',
        '简历常见问题及解决方案：\n\n1. **经历描述空洞** → 补充具体的项目背景、行动和结果\n\n2. **技能与岗位不匹配** → 根据JD调整关键词\n\n3. **缺乏数据支撑** → 尽可能量化工作成果\n\n4. **排版不专业** → 统一格式，使用简洁模板',
        '量化工作经历的技巧：\n\n使用公式：**动词 + 工作内容 + 数据指标 + 结果**\n\n例如：\n- 原：负责用户增长工作\n- 优化：主导用户增长策略，实现DAU提升35%\n\n数据来源：\n- 同比/环比增长\n- 效率提升百分比\n- 成本节约金额'
      ],
      [ChatScene.INTERVIEW_PREP]: [
        '面试准备技巧：\n\n1. **STAR法则回答**：\n   - Situation（背景）\n   - Task（任务）\n   - Action（行动）\n   - Result（结果）\n\n2. **常见问题准备**：\n   - 自我介绍（2分钟内）\n   - 离职原因\n   - 优劣势分析\n   - 职业规划\n\n3. **反向提问**：准备3-5个有深度的问题',
        '自我介绍模板（2分钟）：\n\n"面试官好，我是XXX。\n\n目前从事XXX工作X年，主要擅长XXX。\n\n最近一个项目是XXX，我负责XXX，实现了XXX成果。\n\n我对贵司的XXX岗位很感兴趣，认为我的XXX经验可以很好匹配。\n\n谢谢！"',
        'STAR法则详解：\n\n**S - Situation（背景）**\n项目是在什么背景下发生的？\n\n**T - Task（任务）**\n你面临的核心挑战或目标是什么？\n\n**A - Action（行动）**\n你采取了哪些具体行动？\n\n**R - Result（结果）**\n最终取得了什么成果？（尽量量化）\n\n示例：\n在用户留存率下降15%的背景下（S），我负责优化新用户引导流程（T）。通过AB测试优化了5个关键节点（A），使用户次日留存率提升了8个百分点（R）。'
      ],
      [ChatScene.CAREER_PLAN]: [
        '职业规划建议：\n\n**短期规划（1-2年）**：\n- 深化专业技能，成为团队核心\n- 积累项目经验，提升解决复杂问题能力\n- 建立行业人脉，了解发展趋势\n\n**长期规划（3-5年）**：\n- 向技术专家或管理方向发展\n- 培养跨领域能力\n- 考虑创业或转型可能',
        '转行建议：\n\n1. **评估匹配度**：分析目标岗位与现有技能的关联\n\n2. **补足差距**：\n   - 学习新技能（在线课程、实战项目）\n   - 考取相关证书\n   - 寻找过渡岗位\n\n3. **降低风险**：\n   - 先兼职/外包试水\n   - 内部转岗机会\n   - 积累相关经验后再跳槽\n\n4. **展示迁移能力**：用现有经验证明学习能力',
        '提升职场竞争力：\n\n1. **硬技能**：\n   - 专业技术深度\n   - 数据分析能力\n   - 项目管理能力\n\n2. **软技能**：\n   - 沟通协作\n   - 问题解决\n   - 领导力\n\n3. **个人品牌**：\n   - 分享技术博客\n   - 参与开源项目\n   - 行业会议分享'
      ],
      [ChatScene.OFFER_NEGOTIATION]: [
        'Offer评估要点：\n\n1. **薪资结构**：\n   - 基本工资（最重要）\n   - 绩效奖金\n   - 年终奖\n   - 股票/期权\n\n2. **福利待遇**：\n   - 五险一金缴纳比例\n   - 补充医疗\n   - 年假天数\n   - 弹性工作\n\n3. **发展空间**：\n   - 职级体系\n   - 晋升周期\n   - 培训机会',
        '薪资谈判技巧：\n\n1. **不要先开口**：等HR先给薪资\n\n2. **基于数据**：\n   - 了解市场行情\n   - 参考同级别薪资\n   - 准备好期望薪资范围\n\n3. **谈整体包**：\n   - 现金、股票、福利综合考虑\n   - 强调综合价值\n\n4. **留有余地**：\n   - 给出范围而非固定数字\n   - 表示诚意但不过于急切\n\n5. **敢于开口**：大多数情况下可以谈到更高',
        '如何争取更好条件：\n\n**可以谈的内容**：\n- 基本薪资\n- 签字费\n- 股票/期权\n- 起始假期\n- 灵活工作安排\n\n**谈判话术**：\n"我对这个机会很感兴趣，目前期望薪资是XX。基于我的经验和能力，希望能有XX的薪资。如果在这方面有困难，其他条件是否还有调整空间？"\n\n**注意事项**：\n- 保持专业和友好\n- 不要威胁或最后通牒\n- 准备多个备选方案'
      ]
    };

    // 根据当前场景选择回复
    const tips = sceneTips[this.currentScene] || sceneTips[ChatScene.GENERAL];

    // 根据内容关键词选择更具体的回复
    if (content.includes('简历')) {
      return tips[0];
    } else if (content.includes('面试')) {
      return tips[1];
    } else if (content.includes('规划') || content.includes('发展')) {
      return tips[2];
    } else if (content.includes('薪资') || content.includes('工资') || content.includes('Offer')) {
      return tips[3] || tips[0];
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
