import { Message, ChatSession } from '../models/Message';
import { ChatScene } from '../services/ChatService';

/**
 * 上下文摘要信息
 */
export interface ChatContextSummary {
  sessionId: string;
  lastMessages: Message[];
  messageCount: number;
  userMessageCount: number;
  scene: ChatScene;
  createdAt: number;
}

/**
 * 聊天状态管理
 * 支持：
 * - 基础聊天历史管理
 * - 场景模式管理
 * - 上下文记忆管理
 */
export class ChatStore {
  private static instance: ChatStore;

  // 存储键名
  private readonly KEYS = {
    CHAT_HISTORY: 'chatHistory',
    CHAT_SESSIONS: 'chatSessions',
    CURRENT_SESSION: 'currentSessionId',
    CURRENT_SCENE: 'currentScene',
    CONTEXT_SUMMARY: 'contextSummary'
  };

  private constructor() {}

  static getInstance(): ChatStore {
    if (!ChatStore.instance) {
      ChatStore.instance = new ChatStore();
    }
    return ChatStore.instance;
  }

  // ==================== 基础历史管理 ====================

  /**
   * 保存聊天历史
   * @param messages 消息列表
   */
  saveHistory(messages: Message[]): void {
    AppStorage.setOrCreate(this.KEYS.CHAT_HISTORY, JSON.stringify(messages));
  }

  /**
   * 获取聊天历史
   * @returns 消息列表
   */
  getHistory(): Message[] {
    const historyStr = AppStorage.get<string>(this.KEYS.CHAT_HISTORY);
    if (historyStr) {
      try {
        return JSON.parse(historyStr);
      } catch (e) {
        console.error('[ChatStore] Parse history failed:', e);
        return [];
      }
    }
    return [];
  }

  /**
   * 清除聊天历史
   */
  clearHistory(): void {
    AppStorage.delete(this.KEYS.CHAT_HISTORY);
  }

  /**
   * 添加单条消息
   * @param message 消息
   */
  addMessage(message: Message): void {
    const messages = [...this.getHistory(), message];
    this.saveHistory(messages);
  }

  /**
   * 删除指定消息
   * @param messageId 消息ID
   * @returns 删除后的消息列表
   */
  deleteMessage(messageId: string): Message[] {
    const messages = this.getHistory().filter(m => m.id !== messageId);
    this.saveHistory(messages);
    return messages;
  }

  /**
   * 更新指定消息
   * @param messageId 消息ID
   * @param updates 更新的字段
   */
  updateMessage(messageId: string, updates: Partial<Message>): void {
    const messages = this.getHistory();
    const index = messages.findIndex(m => m.id === messageId);
    if (index !== -1) {
      messages[index] = { ...messages[index], ...updates };
      this.saveHistory(messages);
    }
  }

  // ==================== 会话管理 ====================

  /**
   * 保存会话列表
   * @param sessions 会话列表
   */
  saveSessions(sessions: ChatSession[]): void {
    AppStorage.setOrCreate(this.KEYS.CHAT_SESSIONS, JSON.stringify(sessions));
  }

  /**
   * 获取会话列表
   * @returns 会话列表
   */
  getSessions(): ChatSession[] {
    const sessionsStr = AppStorage.get<string>(this.KEYS.CHAT_SESSIONS);
    if (sessionsStr) {
      try {
        return JSON.parse(sessionsStr);
      } catch (e) {
        console.error('[ChatStore] Parse sessions failed:', e);
        return [];
      }
    }
    return [];
  }

  /**
   * 获取当前会话 ID
   * @returns 会话ID
   */
  getCurrentSessionId(): string | null {
    return AppStorage.get<string>(this.KEYS.CURRENT_SESSION);
  }

  /**
   * 设置当前会话 ID
   * @param sessionId 会话ID
   */
  setCurrentSessionId(sessionId: string): void {
    AppStorage.setOrCreate(this.KEYS.CURRENT_SESSION, sessionId);
  }

  /**
   * 消息数量
   * @returns 消息数量
   */
  getMessageCount(): number {
    return this.getHistory().length;
  }

  // ==================== 场景模式管理 ====================

  /**
   * 获取当前场景
   * @returns 场景类型
   */
  getCurrentScene(): ChatScene {
    const sceneStr = AppStorage.get<string>(this.KEYS.CURRENT_SCENE);
    return (sceneStr as ChatScene) || ChatScene.GENERAL;
  }

  /**
   * 设置当前场景
   * @param scene 场景类型
   */
  setCurrentScene(scene: ChatScene): void {
    AppStorage.setOrCreate(this.KEYS.CURRENT_SCENE, scene);
    console.info('[ChatStore] Scene saved:', scene);
  }

  // ==================== 上下文记忆管理 ====================

  /**
   * 保存上下文摘要
   * @param summary 上下文摘要
   */
  saveContextSummary(summary: ChatContextSummary): void {
    AppStorage.setOrCreate(this.KEYS.CONTEXT_SUMMARY, JSON.stringify(summary));
  }

  /**
   * 获取上下文摘要
   * @returns 上下文摘要
   */
  getContextSummary(): ChatContextSummary | null {
    const summaryStr = AppStorage.get<string>(this.KEYS.CONTEXT_SUMMARY);
    if (summaryStr) {
      try {
        return JSON.parse(summaryStr);
      } catch (e) {
        console.error('[ChatStore] Parse context summary failed:', e);
        return null;
      }
    }
    return null;
  }

  /**
   * 清空上下文摘要
   */
  clearContextSummary(): void {
    AppStorage.delete(this.KEYS.CONTEXT_SUMMARY);
  }

  /**
   * 构建上下文摘要
   * @param sessionId 会话ID
   * @param messages 消息列表
   * @param scene 场景类型
   * @returns 上下文摘要
   */
  buildContextSummary(sessionId: string, messages: Message[], scene: ChatScene): ChatContextSummary {
    // 过滤出最近的消息用于摘要
    const recentMessages = messages.slice(-10);
    const userMessageCount = messages.filter(m => m.role === 'user').length;

    const summary: ChatContextSummary = {
      sessionId: sessionId,
      lastMessages: recentMessages,
      messageCount: messages.length,
      userMessageCount: userMessageCount,
      scene: scene,
      createdAt: Date.now()
    };

    this.saveContextSummary(summary);
    return summary;
  }

  /**
   * 将消息添加到上下文
   * @param message 消息
   */
  addToContext(message: Message): void {
    const summary = this.getContextSummary();
    if (summary) {
      summary.lastMessages.push(message);
      // 保持最近10条消息
      if (summary.lastMessages.length > 10) {
        summary.lastMessages = summary.lastMessages.slice(-10);
      }
      summary.messageCount++;
      if (message.role === 'user') {
        summary.userMessageCount++;
      }
      this.saveContextSummary(summary);
    }
  }

  /**
   * 获取带上下文的请求参数
   * @param content 用户消息内容
   * @returns 包含上下文信息的请求参数
   */
  getRequestWithContext(content: string): Record<string, any> {
    const sessionId = this.getCurrentSessionId() || '';
    const scene = this.getCurrentScene();
    const summary = this.getContextSummary();

    return {
      content: content,
      conversationId: sessionId,
      scene: scene,
      context: summary?.lastMessages.slice(-10).map(m => ({
        role: m.role,
        content: m.content
      })) || []
    };
  }

  /**
   * 重置对话（清除历史和上下文）
   */
  resetConversation(): void {
    this.clearHistory();
    this.clearContextSummary();
    console.info('[ChatStore] Conversation reset');
  }
}
