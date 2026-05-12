import file from '@ohos.file.picker';
import { ApiService } from './ApiService';
import { Message, ChatSession, SendMessageResult } from '../models/Message';
import { ResumeAnalysisResult } from '../models/Resume';
import { API_ENDPOINTS } from '../constants/config';

export class ChatService {
  private apiService: ApiService;
  private static instance: ChatService;

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
   * 发送消息
   */
  async sendMessage(content: string): Promise<SendMessageResult> {
    // 构造用户消息
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: content,
      timestamp: Date.now(),
      status: 'sent'
    };

    try {
      // 调用真实 API
      const response = await this.apiService.post<SendMessageResult>(API_ENDPOINTS.CHAT_SEND, {
        content: content,
        conversationId: AppStorage.get<string>('currentConversationId')
      });

      if (response.success && response.data) {
        return response.data;
      } else {
        // 返回错误消息
        return {
          content: response.error || '抱歉，发生了错误，请稍后重试。',
          sessionId: AppStorage.get<string>('currentConversationId') || ''
        };
      }
    } catch (error) {
      console.error('[ChatService] Send message failed:', error);
      return {
        content: '网络连接失败，请检查网络后重试。',
        sessionId: AppStorage.get<string>('currentConversationId') || ''
      };
    }
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
  async analyzeResume(file: file.File): Promise<ResumeAnalysisResult> {
    try {
      // 调用真实 API
      const response = await this.apiService.post<ResumeAnalysisResult>(API_ENDPOINTS.RESUME_ANALYZE, {
        fileUri: file.uri
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
   * 生成模拟回复（备用）
   */
  private generateMockReply(content: string): string {
    const tips = [
      '根据您的情况，我建议您可以从以下几个方面提升简历质量：\n\n1. 突出项目经验中的量化成果\n2. 优化技能描述，使用行业关键词\n3. 完善自我评价，展现个人优势',
      '面试技巧方面，建议您注意以下几点：\n\n1. 提前了解公司背景和岗位要求\n2. 准备STAR法则描述项目经历\n3. 准备一些反问面试官的问题',
      '关于职业规划，我建议您：\n\n1. 明确短期（1-2年）和长期（3-5年）目标\n2. 了解目标岗位的发展路径\n3. 持续学习相关技能',
      '根据当前市场情况，Java开发工程师的薪资范围大致如下：\n\n- 初级：8-15K\n- 中级：15-25K\n- 高级：25-40K\n\n具体还要看城市、公司规模和您的经验水平。',
      '简历投递建议：\n\n1. 针对不同岗位定制简历关键词\n2. 选择上午9-11点投递简历\n3. 关注目标公司的招聘节奏\n4. 积极通过内推渠道'
    ];

    // 简单匹配关键词
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
}
