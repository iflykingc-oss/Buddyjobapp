import { BusinessError } from '@kit.BasicServicesKit';
import { agentFramework } from '@kit.IntelligentAgentKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from './ApiService';
import { Logger } from '../utils/logger';

const TAG = 'XiaoyiService';

/**
 * 小艺智能体服务
 * 封装 AgentFrameworkKit API，实现意图注册和处理
 */
export class XiaoyiService {
  private static instance: XiaoyiService;
  private apiService: ApiService;
  private isInitialized: boolean = false;

  // 意图定义
  public static readonly INTENTS = {
    ANALYZE_RESUME: 'buddyjob.analyze_resume',
    INTERVIEW_PRACTICE: 'buddyjob.interview_practice',
    ASSESS_ABILITY: 'buddyjob.assess_ability',
    CIRCLE_SELECTION: 'buddyjob.circle_selection',
    VOICE_MEMO: 'buddyjob.voice_memo'
  } as const;

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): XiaoyiService {
    if (!XiaoyiService.instance) {
      XiaoyiService.instance = new XiaoyiService();
    }
    return XiaoyiService.instance;
  }

  /**
   * 初始化小艺智能体服务
   */
  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      Logger.info(TAG, 'XiaoyiService already initialized');
      return true;
    }

    try {
      // 注册所有意图
      await this.registerIntents();
      this.isInitialized = true;
      Logger.info(TAG, 'XiaoyiService initialized successfully');
      return true;
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize XiaoyiService:', error);
      return false;
    }
  }

  /**
   * 注册所有意图
   */
  private async registerIntents(): Promise<void> {
    // 1. 注册"分析我的简历"意图
    await this.registerIntent({
      intentName: XiaoyiService.INTENTS.ANALYZE_RESUME,
      displayName: '分析我的简历',
      description: '分析简历内容，提供优化建议',
      keywords: ['分析简历', '简历分析', '优化简历', '查看简历评分'],
      parameters: [
        {
          name: 'resumeId',
          type: 'string',
          description: '简历ID',
          required: false
        }
      ],
      handler: this.handleAnalyzeResume.bind(this)
    });

    // 2. 注册"帮我做面试练习"意图
    await this.registerIntent({
      intentName: XiaoyiService.INTENTS.INTERVIEW_PRACTICE,
      displayName: '帮我做面试练习',
      description: '进行模拟面试练习',
      keywords: ['面试练习', '模拟面试', '面试准备', '练习面试', '面试辅导'],
      parameters: [
        {
          name: 'jobType',
          type: 'string',
          description: '职位类型',
          required: false
        },
        {
          name: 'difficulty',
          type: 'string',
          description: '难度级别',
          required: false
        }
      ],
      handler: this.handleInterviewPractice.bind(this)
    });

    // 3. 注册"测评我的能力"意图
    await this.registerIntent({
      intentName: XiaoyiService.INTENTS.ASSESS_ABILITY,
      displayName: '测评我的能力',
      description: '进行职业能力测评',
      keywords: ['能力测评', '职业测评', '技能测试', '评估能力', '测能力'],
      parameters: [
        {
          name: 'assessmentType',
          type: 'string',
          description: '测评类型',
          required: false
        }
      ],
      handler: this.handleAssessAbility.bind(this)
    });

    // 4. 注册"圈选分析"意图（小艺圈选）
    await this.registerIntent({
      intentName: XiaoyiService.INTENTS.CIRCLE_SELECTION,
      displayName: '圈选分析简历',
      description: '圈选简历内容进行AI分析',
      keywords: ['圈选', '选中分析', '分析这段', '分析选中内容'],
      parameters: [
        {
          name: 'selectedText',
          type: 'string',
          description: '选中的文本内容',
          required: true
        },
        {
          name: 'context',
          type: 'string',
          description: '上下文信息',
          required: false
        }
      ],
      handler: this.handleCircleSelection.bind(this)
    });

    // 5. 注册"语音记录"意图（小艺帮记）
    await this.registerIntent({
      intentName: XiaoyiService.INTENTS.VOICE_MEMO,
      displayName: '记录面试要点',
      description: '语音记录面试要点并生成摘要',
      keywords: ['记录面试', '面试笔记', '语音记录', '帮记面试', '记录要点'],
      parameters: [
        {
          name: 'audioUri',
          type: 'string',
          description: '音频文件URI',
          required: true
        },
        {
          name: 'interviewId',
          type: 'string',
          description: '关联的面试ID',
          required: false
        }
      ],
      handler: this.handleVoiceMemo.bind(this)
    });
  }

  /**
   * 注册单个意图
   */
  private async registerIntent(config: IntentConfig): Promise<void> {
    try {
      await agentFramework.registerIntent({
        intentName: config.intentName,
        displayName: config.displayName,
        description: config.description,
        keywords: config.keywords,
        parameters: config.parameters
      });
      Logger.info(TAG, `Intent registered: ${config.intentName}`);

      // 设置意图处理回调
      agentFramework.onIntentTrigger(config.intentName, (params: Record<string, object>) => {
        return config.handler(params);
      });
    } catch (error) {
      Logger.error(TAG, `Failed to register intent ${config.intentName}:`, error);
      throw error;
    }
  }

  /**
   * 处理"分析我的简历"意图
   */
  private async handleAnalyzeResume(params: Record<string, object>): Promise<IntentResult> {
    Logger.info(TAG, 'Handling analyze resume intent:', params);

    try {
      const resumeId = params['resumeId'] as string;

      // 调用后端API进行简历分析
      const response = await this.apiService.post('resume/analyze', {
        resumeId: resumeId,
        source: 'xiaoyi'
      });

      if (response.success) {
        const analysisResult = response.data;

        // 构建小艺回复
        const reply = this.buildResumeAnalysisReply(analysisResult);

        return {
          success: true,
          message: reply,
          data: analysisResult,
          actions: [
            {
              type: 'navigate',
              target: 'pages/Resume',
              params: { tab: 'analysis' }
            },
            {
              type: 'showDetail',
              title: '详细分析报告',
              content: analysisResult.summary
            }
          ]
        };
      } else {
        return {
          success: false,
          message: '简历分析失败，请稍后重试',
          error: response.error
        };
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling analyze resume:', error);
      return {
        success: false,
        message: '分析过程中出现错误',
        error: error.message
      };
    }
  }

  /**
   * 处理"面试练习"意图
   */
  private async handleInterviewPractice(params: Record<string, object>): Promise<IntentResult> {
    Logger.info(TAG, 'Handling interview practice intent:', params);

    try {
      const jobType = (params['jobType'] as string) || 'general';
      const difficulty = (params['difficulty'] as string) || 'medium';

      // 获取面试题目
      const response = await this.apiService.post('interview/practice', {
        jobType,
        difficulty,
        source: 'xiaoyi'
      });

      if (response.success) {
        const practiceData = response.data;

        return {
          success: true,
          message: `好的，我来帮你进行${this.getJobTypeName(jobType)}的面试练习。准备好了吗？第一题：\n\n${practiceData.firstQuestion}`,
          data: practiceData,
          actions: [
            {
              type: 'navigate',
              target: 'pages/Chat',
              params: {
                mode: 'interview',
                jobType,
                difficulty
              }
            },
            {
              type: 'startSession',
              sessionType: 'interview_practice'
            }
          ]
        };
      } else {
        return {
          success: false,
          message: '获取面试题目失败，请稍后重试',
          error: response.error
        };
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling interview practice:', error);
      return {
        success: false,
        message: '启动面试练习时出现错误',
        error: error.message
      };
    }
  }

  /**
   * 处理"能力测评"意图
   */
  private async handleAssessAbility(params: Record<string, object>): Promise<IntentResult> {
    Logger.info(TAG, 'Handling assess ability intent:', params);

    try {
      const assessmentType = (params['assessmentType'] as string) || 'comprehensive';

      // 获取测评信息
      const response = await this.apiService.get(`assessment/types/${assessmentType}`);

      if (response.success) {
        const assessmentData = response.data;

        return {
          success: true,
          message: `我来帮你进行${assessmentData.name}。这个测评大约需要${assessmentData.duration}分钟，包含${assessmentData.questionCount}道题目。准备好了吗？`,
          data: assessmentData,
          actions: [
            {
              type: 'navigate',
              target: 'pages/Assessment',
              params: {
                type: assessmentType,
                source: 'xiaoyi'
              }
            },
            {
              type: 'startAssessment',
              assessmentId: assessmentData.id
            }
          ]
        };
      } else {
        return {
          success: false,
          message: '获取测评信息失败，请稍后重试',
          error: response.error
        };
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling assess ability:', error);
      return {
        success: false,
        message: '启动能力测评时出现错误',
        error: error.message
      };
    }
  }

  /**
   * 处理"圈选分析"意图（小艺圈选功能）
   */
  private async handleCircleSelection(params: Record<string, object>): Promise<IntentResult> {
    Logger.info(TAG, 'Handling circle selection intent:', params);

    try {
      const selectedText = params['selectedText'] as string;
      const context = (params['context'] as string) || '';

      if (!selectedText || selectedText.trim().length === 0) {
        return {
          success: false,
          message: '请先圈选需要分析的简历内容'
        };
      }

      // 调用AI分析选中的内容
      const response = await this.apiService.post('ai/analyze-selection', {
        content: selectedText,
        context: context,
        analysisType: 'resume'
      });

      if (response.success) {
        const analysisResult = response.data;

        // 构建分析回复
        const reply = this.buildCircleSelectionReply(analysisResult);

        return {
          success: true,
          message: reply,
          data: analysisResult,
          actions: [
            {
              type: 'showAnalysisCard',
              title: '内容分析',
              content: analysisResult.analysis,
              suggestions: analysisResult.suggestions
            },
            {
              type: 'applySuggestion',
              suggestionId: analysisResult.suggestionId
            }
          ]
        };
      } else {
        return {
          success: false,
          message: '分析失败，请稍后重试',
          error: response.error
        };
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling circle selection:', error);
      return {
        success: false,
        message: '分析过程中出现错误',
        error: error.message
      };
    }
  }

  /**
   * 处理"语音记录"意图（小艺帮记功能）
   */
  private async handleVoiceMemo(params: Record<string, object>): Promise<IntentResult> {
    Logger.info(TAG, 'Handling voice memo intent:', params);

    try {
      const audioUri = params['audioUri'] as string;
      const interviewId = params['interviewId'] as string;

      if (!audioUri) {
        return {
          success: false,
          message: '请先录制语音内容'
        };
      }

      // 1. 上传音频文件
      const uploadResponse = await this.uploadAudioFile(audioUri);
      if (!uploadResponse.success) {
        return {
          success: false,
          message: '音频上传失败',
          error: uploadResponse.error
        };
      }

      // 2. 调用语音转文字和AI摘要
      const processResponse = await this.apiService.post('ai/process-voice-memo', {
        audioUrl: uploadResponse.data.url,
        interviewId: interviewId,
        generateSummary: true,
        extractKeyPoints: true
      });

      if (processResponse.success) {
        const result = processResponse.data;

        // 构建回复
        const reply = this.buildVoiceMemoReply(result);

        return {
          success: true,
          message: reply,
          data: result,
          actions: [
            {
              type: 'showMemoCard',
              title: '面试要点记录',
              transcript: result.transcript,
              summary: result.summary,
              keyPoints: result.keyPoints
            },
            {
              type: 'saveMemo',
              memoId: result.memoId
            },
            {
              type: 'shareMemo',
              content: result.summary
            }
          ]
        };
      } else {
        return {
          success: false,
          message: '语音处理失败，请稍后重试',
          error: processResponse.error
        };
      }
    } catch (error) {
      Logger.error(TAG, 'Error handling voice memo:', error);
      return {
        success: false,
        message: '处理语音记录时出现错误',
        error: error.message
      };
    }
  }

  /**
   * 上传音频文件
   */
  private async uploadAudioFile(audioUri: string): Promise<ApiResult<{ url: string }>> {
    try {
      // 使用ApiService上传文件
      const response = await this.apiService.post('upload/audio', {
        uri: audioUri,
        type: 'voice_memo'
      });

      return {
        success: response.success,
        data: response.data,
        error: response.error
      };
    } catch (error) {
      Logger.error(TAG, 'Failed to upload audio:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * 构建简历分析回复
   */
  private buildResumeAnalysisReply(analysisResult: ResumeAnalysisResult): string {
    const { atsScore, summary, dimensions } = analysisResult;

    let reply = `简历分析完成！\n\n`;
    reply += `**ATS评分：${atsScore}分**\n\n`;
    reply += `${summary}\n\n`;

    if (dimensions && dimensions.length > 0) {
      reply += `各维度得分：\n`;
      dimensions.forEach(dim => {
        reply += `- ${dim.name}: ${dim.score}分\n`;
      });
    }

    reply += `\n需要查看详细的优化建议吗？`;

    return reply;
  }

  /**
   * 构建圈选分析回复
   */
  private buildCircleSelectionReply(result: CircleSelectionResult): string {
    let reply = `**内容分析结果**\n\n`;
    reply += `${result.analysis}\n\n`;

    if (result.suggestions && result.suggestions.length > 0) {
      reply += `**优化建议：**\n`;
      result.suggestions.forEach((suggestion, index) => {
        reply += `${index + 1}. ${suggestion}\n`;
      });
    }

    return reply;
  }

  /**
   * 构建语音记录回复
   */
  private buildVoiceMemoReply(result: VoiceMemoResult): string {
    let reply = `**面试要点已记录**\n\n`;

    if (result.summary) {
      reply += `**摘要：**\n${result.summary}\n\n`;
    }

    if (result.keyPoints && result.keyPoints.length > 0) {
      reply += `**关键要点：**\n`;
      result.keyPoints.forEach((point, index) => {
        reply += `${index + 1}. ${point}\n`;
      });
    }

    reply += `\n已关联到你的简历，可随时查看。`;

    return reply;
  }

  /**
   * 获取职位类型名称
   */
  private getJobTypeName(jobType: string): string {
    const typeMap: Record<string, string> = {
      'general': '通用',
      'frontend': '前端开发',
      'backend': '后端开发',
      'product': '产品经理',
      'design': '设计',
      'marketing': '市场营销',
      'sales': '销售',
      'hr': '人力资源'
    };
    return typeMap[jobType] || jobType;
  }

  /**
   * 检查小艺服务是否可用
   */
  async isAvailable(): Promise<boolean> {
    try {
      return await agentFramework.isAvailable();
    } catch (error) {
      Logger.error(TAG, 'Error checking Xiaoyi availability:', error);
      return false;
    }
  }

  /**
   * 主动触发意图（用于测试或内部调用）
   */
  async triggerIntent(intentName: string, params: Record<string, object>): Promise<IntentResult> {
    try {
      const result = await agentFramework.triggerIntent(intentName, params);
      return result as IntentResult;
    } catch (error) {
      Logger.error(TAG, `Error triggering intent ${intentName}:`, error);
      return {
        success: false,
        message: '触发意图失败',
        error: error.message
      };
    }
  }
}

// 类型定义
interface IntentConfig {
  intentName: string;
  displayName: string;
  description: string;
  keywords: string[];
  parameters: IntentParameter[];
  handler: (params: Record<string, object>) => Promise<IntentResult>;
}

interface IntentParameter {
  name: string;
  type: string;
  description: string;
  required: boolean;
}

interface IntentResult {
  success: boolean;
  message: string;
  data?: object;
  error?: string;
  actions?: IntentAction[];
}

interface IntentAction {
  type: string;
  target?: string;
  params?: Record<string, object>;
  title?: string;
  content?: string;
  sessionType?: string;
  assessmentId?: string;
  suggestionId?: string;
  memoId?: string;
  transcript?: string;
  summary?: string;
  keyPoints?: string[];
  suggestions?: string[];
}

interface ApiResult<T> {
  success: boolean;
  data?: T;
  error?: string;
}

interface ResumeAnalysisResult {
  atsScore: number;
  summary: string;
  dimensions: Array<{
    name: string;
    score: number;
  }>;
}

interface CircleSelectionResult {
  analysis: string;
  suggestions: string[];
  suggestionId?: string;
}

interface VoiceMemoResult {
  transcript: string;
  summary: string;
  keyPoints: string[];
  memoId: string;
}

export default XiaoyiService.getInstance();
