// 数据模型 - 消息模型
export interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  status?: 'sending' | 'sent' | 'error';
}

export interface ChatSession {
  id: string;
  title: string;
  messages: Message[];
  createdAt: number;
  updatedAt: number;
}

export interface SendMessageParams {
  content: string;
  sessionId?: string;
}

export interface SendMessageResult {
  content: string;
  sessionId: string;
}
