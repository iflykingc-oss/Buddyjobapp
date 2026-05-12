import { Message, ChatSession } from '../models/Message';

/**
 * 聊天状态管理
 */
export class ChatStore {
  private static instance: ChatStore;

  private constructor() {}

  static getInstance(): ChatStore {
    if (!ChatStore.instance) {
      ChatStore.instance = new ChatStore();
    }
    return ChatStore.instance;
  }

  // 保存聊天历史
  saveHistory(messages: Message[]): void {
    AppStorage.setOrCreate('chatHistory', JSON.stringify(messages));
  }

  // 获取聊天历史
  getHistory(): Message[] {
    const historyStr = AppStorage.get<string>('chatHistory');
    if (historyStr) {
      try {
        return JSON.parse(historyStr);
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // 清除聊天历史
  clearHistory(): void {
    AppStorage.delete('chatHistory');
  }

  // 添加单条消息
  addMessage(message: Message): void {
    const messages = this.getHistory();
    messages.push(message);
    this.saveHistory(messages);
  }

  // 保存会话列表
  saveSessions(sessions: ChatSession[]): void {
    AppStorage.setOrCreate('chatSessions', JSON.stringify(sessions));
  }

  // 获取会话列表
  getSessions(): ChatSession[] {
    const sessionsStr = AppStorage.get<string>('chatSessions');
    if (sessionsStr) {
      try {
        return JSON.parse(sessionsStr);
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // 获取当前会话 ID
  getCurrentSessionId(): string | null {
    return AppStorage.get<string>('currentSessionId');
  }

  // 设置当前会话 ID
  setCurrentSessionId(sessionId: string): void {
    AppStorage.setOrCreate('currentSessionId', sessionId);
  }

  // 消息数量
  getMessageCount(): number {
    return this.getHistory().length;
  }
}
