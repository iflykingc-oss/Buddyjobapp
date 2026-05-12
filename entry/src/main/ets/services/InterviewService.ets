/**
 * 模拟面试服务
 *
 * 提供面试问题生成、回答提交、AI点评等功能
 * 支持语音录制和语音识别
 */
import { ApiService } from './ApiService';
import { HistoryService } from './HistoryService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  FontSize,
  FontWeight
} from '../constants/design-tokens';

// 面试问题类型
export interface InterviewQuestion {
  id: string;
  category: string; // 'behavioral' | 'technical' | 'situational'
  question: string;
  tips?: string; // 回答提示
  starGuide?: StarGuide; // STAR法则引导
  referenceAnswer?: string; // 参考答案
  difficulty: 'easy' | 'medium' | 'hard';
}

// STAR法则引导
export interface StarGuide {
  situation: string; // 情境描述
  task: string; // 任务说明
  action: string; // 行动建议
  result: string; // 结果展示
}

// 用户回答
export interface InterviewAnswer {
  questionId: string;
  content: string; // 回答内容（文字或语音识别结果）
  audioPath?: string; // 录音文件路径
  duration?: number; // 回答时长（秒）
  timestamp: number;
}

// AI点评结果
export interface InterviewFeedback {
  questionId: string;
  strengths: string[]; // 优点
  improvements: string[]; // 改进点
  referenceAnswer: string; // 参考答案
  score: number; // 评分 0-100
  suggestions: string[]; // 建议
  starAnalysis?: StarAnalysis; // STAR分析
}

// STAR分析
export interface StarAnalysis {
  situation: { score: number; comment: string };
  task: { score: number; comment: string };
  action: { score: number; comment: string };
  result: { score: number; comment: string };
}

// 面试会话
export interface InterviewSession {
  id: string;
  jobPosition: string; // 目标岗位
  questions: InterviewQuestion[];
  answers: InterviewAnswer[];
  feedbacks: InterviewFeedback[];
  currentQuestionIndex: number;
  status: 'preparing' | 'in_progress' | 'completed';
  startTime?: number;
  endTime?: number;
  totalScore?: number;
}

// 面试配置
export interface InterviewConfig {
  jobPosition: string;
  questionCount: number;
  categories: string[];
  difficulty: 'easy' | 'medium' | 'hard' | 'mixed';
}

export class InterviewService {
  private static instance: InterviewService;
  private apiService: ApiService = ApiService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();

  // 录音相关
  private isRecording: boolean = false;
  private recordingStartTime: number = 0;
  private audioFilePath: string = '';

  private constructor() {}

  static getInstance(): InterviewService {
    if (!InterviewService.instance) {
      InterviewService.instance = new InterviewService();
    }
    return InterviewService.instance;
  }

  /**
   * 创建面试会话
   */
  async createInterviewSession(config: InterviewConfig): Promise<InterviewSession> {
    try {
      const response = await this.apiService.post<InterviewSession>('/interview/create', config);
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Create session failed:', error);
    }

    // 使用默认数据
    return this.generateDefaultSession(config);
  }

  /**
   * 生成默认面试会话
   */
  private generateDefaultSession(config: InterviewConfig): InterviewSession {
    const questions = this.generateQuestions(config);
    return {
      id: Date.now().toString(),
      jobPosition: config.jobPosition,
      questions: questions,
      answers: [],
      feedbacks: [],
      currentQuestionIndex: 0,
      status: 'preparing'
    };
  }

  /**
   * 生成面试问题
   */
  private generateQuestions(config: InterviewConfig): InterviewQuestion[] {
    const allQuestions: InterviewQuestion[] = [
      // 行为面试题
      {
        id: 'b1',
        category: 'behavioral',
        question: '请描述一次你成功解决团队冲突的经历。',
        tips: '重点关注你在冲突解决中扮演的角色和采取的具体行动。',
        starGuide: {
          situation: '描述冲突发生的背景和原因',
          task: '说明你在解决冲突中的责任',
          action: '详细描述你采取的具体步骤',
          result: '展示冲突解决后的积极成果'
        },
        referenceAnswer: '在上一个项目中，团队成员对技术方案产生了分歧。作为技术负责人，我组织了一次技术评审会议，让各方充分表达观点，最终通过数据对比和原型验证，达成了统一方案。这个经历让我学会了倾听和协调的重要性。',
        difficulty: 'medium'
      },
      {
        id: 'b2',
        category: 'behavioral',
        question: '请分享一个你在压力下完成任务的经历。',
        tips: '展示你的时间管理和抗压能力。',
        starGuide: {
          situation: '描述面临的压力和紧迫性',
          task: '说明任务的具体要求',
          action: '描述你如何规划和管理时间',
          result: '展示任务完成的结果和收获'
        },
        referenceAnswer: '在项目上线前一天，发现了一个严重bug。我快速评估了影响范围，制定了修复方案，并与团队协作在4小时内完成了修复和测试。这次经历让我更注重代码质量和提前测试。',
        difficulty: 'medium'
      },
      {
        id: 'b3',
        category: 'behavioral',
        question: '请举例说明你是如何学习一项新技能的。',
        tips: '展示你的学习能力和主动性。',
        starGuide: {
          situation: '说明学习新技能的背景和动机',
          task: '描述学习目标和要求',
          action: '详细说明学习方法和过程',
          result: '展示学习成果和应用效果'
        },
        referenceAnswer: '为了适应项目需求，我需要在两周内掌握React框架。我制定了学习计划，每天学习4小时，通过官方文档、视频教程和实践项目相结合的方式学习。最终按时完成了项目开发，并将经验分享给团队。',
        difficulty: 'easy'
      },
      // 技术面试题
      {
        id: 't1',
        category: 'technical',
        question: '请描述你熟悉的一个技术架构，并说明其优缺点。',
        tips: '选择你最熟悉的架构，从多个维度进行分析。',
        starGuide: {
          situation: '说明架构的应用场景',
          task: '描述架构要解决的问题',
          action: '分析架构的设计和实现',
          result: '评估架构的效果和改进空间'
        },
        referenceAnswer: '我熟悉微服务架构。优点包括：服务独立部署、技术栈灵活、易于扩展。缺点包括：运维复杂度高、分布式事务处理困难、服务间通信开销。在实际项目中，需要根据团队规模和业务复杂度权衡选择。',
        difficulty: 'hard'
      },
      {
        id: 't2',
        category: 'technical',
        question: '你是如何保证代码质量的？',
        tips: '从多个角度说明你的质量保障措施。',
        starGuide: {
          situation: '说明代码质量问题的背景',
          task: '描述质量保障的目标',
          action: '列举具体的质量保障措施',
          result: '展示质量改进的效果'
        },
        referenceAnswer: '我通过多层保障来确保代码质量：编码阶段遵循规范和设计模式；提交前进行自测和代码审查；CI/CD流程中集成单元测试和静态分析；上线前进行集成测试和性能测试。这些措施显著降低了bug率。',
        difficulty: 'medium'
      },
      // 情景面试题
      {
        id: 's1',
        category: 'situational',
        question: '如果团队成员对你的方案持反对意见，你会如何处理？',
        tips: '展示你的沟通能力和开放心态。',
        starGuide: {
          situation: '描述意见分歧的场景',
          task: '说明你的目标是什么',
          action: '描述你的处理方式',
          result: '展示最终达成的结果'
        },
        referenceAnswer: '我会首先认真倾听反对意见，理解对方的顾虑。然后通过数据和事实来支持我的观点，同时保持开放心态，如果对方有更好的建议，我会积极采纳。最终目标是找到最优解决方案，而不是证明自己正确。',
        difficulty: 'medium'
      },
      {
        id: 's2',
        category: 'situational',
        question: '如果项目进度落后，你会采取什么措施？',
        tips: '展示你的问题分析和解决能力。',
        starGuide: {
          situation: '描述进度落后的情况',
          task: '说明需要达成的目标',
          action: '列举具体的应对措施',
          result: '展示措施的效果'
        },
        referenceAnswer: '首先分析进度落后的原因：是需求变更、技术难点还是资源不足？然后制定针对性措施：优化任务优先级、申请额外资源、与产品沟通调整范围等。同时加强进度跟踪和风险预警，确保项目可控。',
        difficulty: 'medium'
      }
    ];

    // 根据配置筛选问题
    let filteredQuestions = allQuestions;
    if (config.categories.length > 0) {
      filteredQuestions = allQuestions.filter(q => config.categories.includes(q.category));
    }

    // 根据难度筛选
    if (config.difficulty !== 'mixed') {
      filteredQuestions = filteredQuestions.filter(q => q.difficulty === config.difficulty);
    }

    // 随机选择指定数量的问题
    const shuffled = filteredQuestions.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, config.questionCount);
  }

  /**
   * 提交回答并获取AI点评
   */
  async submitAnswer(
    sessionId: string,
    answer: InterviewAnswer
  ): Promise<InterviewFeedback> {
    try {
      const response = await this.apiService.post<InterviewFeedback>('/interview/submit', {
        sessionId,
        answer
      });
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Submit answer failed:', error);
    }

    // 生成模拟点评
    return this.generateMockFeedback(answer);
  }

  /**
   * 生成模拟AI点评
   */
  private generateMockFeedback(answer: InterviewAnswer): InterviewFeedback {
    const content = answer.content;
    const wordCount = content.length;

    // 基于回答内容生成点评
    const hasSituation = content.includes('在') || content.includes('当时') || content.includes('项目');
    const hasAction = content.includes('我') && (content.includes('做') || content.includes('采取') || content.includes('完成'));
    const hasResult = content.includes('结果') || content.includes('成功') || content.includes('完成') || content.includes('提升');

    const strengths: string[] = [];
    const improvements: string[] = [];

    if (wordCount > 100) {
      strengths.push('回答内容充实，提供了足够的细节');
    } else {
      improvements.push('建议提供更多具体细节，让回答更有说服力');
    }

    if (hasSituation) {
      strengths.push('清晰地描述了情境背景');
    } else {
      improvements.push('建议先描述情境背景，让面试官理解上下文');
    }

    if (hasAction) {
      strengths.push('明确说明了自己的行动和贡献');
    } else {
      improvements.push('需要更清晰地说明你采取的具体行动');
    }

    if (hasResult) {
      strengths.push('展示了行动的结果和成效');
    } else {
      improvements.push('建议补充行动的结果，用数据或具体成果来支撑');
    }

    // 计算分数
    let score = 60;
    if (wordCount > 100) score += 10;
    if (wordCount > 200) score += 5;
    if (hasSituation) score += 8;
    if (hasAction) score += 10;
    if (hasResult) score += 7;
    score = Math.min(score, 95);

    return {
      questionId: answer.questionId,
      strengths: strengths.length > 0 ? strengths : ['回答态度认真'],
      improvements: improvements.length > 0 ? improvements : ['继续保持，可以尝试更深入的分析'],
      referenceAnswer: '这是一个参考答案示例，展示了如何运用STAR法则组织回答。',
      score: score,
      suggestions: [
        '使用STAR法则组织回答结构',
        '提供具体的数据和成果',
        '突出个人贡献和成长'
      ],
      starAnalysis: {
        situation: {
          score: hasSituation ? 80 : 50,
          comment: hasSituation ? '情境描述清晰' : '需要补充情境描述'
        },
        task: {
          score: 70,
          comment: '任务说明可以更明确'
        },
        action: {
          score: hasAction ? 85 : 55,
          comment: hasAction ? '行动描述详细' : '需要说明具体行动'
        },
        result: {
          score: hasResult ? 80 : 45,
          comment: hasResult ? '结果展示到位' : '需要补充结果展示'
        }
      }
    };
  }

  /**
   * 完成面试会话
   */
  async completeInterview(session: InterviewSession): Promise<InterviewSession> {
    // 计算总分
    const totalScore = session.feedbacks.reduce((sum, f) => sum + f.score, 0) / session.feedbacks.length;

    const completedSession: InterviewSession = {
      ...session,
      status: 'completed',
      endTime: Date.now(),
      totalScore: Math.round(totalScore)
    };

    // 保存到历史记录
    await this.historyService.addHistory({
      type: 'interview',
      title: `模拟面试 - ${session.jobPosition}`,
      content: `完成${session.questions.length}道题目，平均得分${Math.round(totalScore)}分`,
      metadata: {
        sessionId: session.id,
        jobPosition: session.jobPosition,
        questionCount: session.questions.length,
        totalScore: totalScore
      }
    });

    try {
      await this.apiService.post('/interview/complete', {
        sessionId: session.id,
        totalScore
      });
    } catch (error) {
      console.error('[InterviewService] Complete interview failed:', error);
    }

    return completedSession;
  }

  /**
   * 开始录音
   * 使用 AVRecorder 进行录音
   */
  async startRecording(): Promise<boolean> {
    if (this.isRecording) {
      return false;
    }

    try {
      // 生成录音文件路径
      this.audioFilePath = `/data/local/tmp/interview_${Date.now()}.m4a`;
      this.recordingStartTime = Date.now();
      this.isRecording = true;

      // TODO: 集成 AVRecorder API
      // import media from '@ohos.multimedia.media';
      // const avRecorder = await media.createAVRecorder();
      // 配置录音参数并开始录音

      console.log('[InterviewService] Recording started');
      return true;
    } catch (error) {
      console.error('[InterviewService] Start recording failed:', error);
      this.isRecording = false;
      return false;
    }
  }

  /**
   * 停止录音
   */
  async stopRecording(): Promise<{ path: string; duration: number } | null> {
    if (!this.isRecording) {
      return null;
    }

    try {
      const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
      this.isRecording = false;

      // TODO: 停止 AVRecorder 并保存文件

      console.log('[InterviewService] Recording stopped, duration:', duration);
      return {
        path: this.audioFilePath,
        duration: duration
      };
    } catch (error) {
      console.error('[InterviewService] Stop recording failed:', error);
      this.isRecording = false;
      return null;
    }
  }

  /**
   * 语音识别
   * 使用 IntelligentVoice 进行语音转文字
   */
  async recognizeSpeech(audioPath: string): Promise<string> {
    try {
      // TODO: 集成 IntelligentVoice API
      // import intelligentVoice from '@ohos.ai.intelligentVoice';
      // 使用语音识别服务将音频转为文字

      // 模拟识别结果
      console.log('[InterviewService] Recognizing speech from:', audioPath);
      return '这是语音识别的结果示例。在实际项目中，会通过IntelligentVoice API将录音转换为文字。';
    } catch (error) {
      console.error('[InterviewService] Speech recognition failed:', error);
      return '';
    }
  }

  /**
   * 获取录音状态
   */
  getRecordingStatus(): { isRecording: boolean; duration: number } {
    return {
      isRecording: this.isRecording,
      duration: this.isRecording ? Math.floor((Date.now() - this.recordingStartTime) / 1000) : 0
    };
  }

  /**
   * 获取面试统计
   */
  async getInterviewStats(): Promise<{
    totalSessions: number;
    averageScore: number;
    recentSessions: InterviewSession[];
  }> {
    try {
      const response = await this.apiService.get<{
        totalSessions: number;
        averageScore: number;
        recentSessions: InterviewSession[];
      }>('/interview/stats');

      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Get stats failed:', error);
    }

    return {
      totalSessions: 0,
      averageScore: 0,
      recentSessions: []
    };
  }
}
