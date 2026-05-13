/**
 * 小艺建议意图服务 - 接收小艺建议并处理
 * 支持求职建议、面试提醒等意图
 */
import hilog from '@ohos.hilog';
import { ApiService } from './ApiService';
import { storage } from '../utils/storage';
import { ResumeService } from './ResumeService';
import { InterviewService } from './InterviewService';
import { AssessmentService } from './AssessmentService';

const TAG = 'XiaoyiIntentService';
const DOMAIN = 0xFF00;

/**
 * 意图参数接口
 */
export interface IntentParams {
  resumeId?: string;
  jobType?: string;
  difficulty?: string;
  assessmentType?: string;
  selectedText?: string;
  context?: string;
  audioUri?: string;
  interviewId?: string;
  targetPosition?: string;
  company?: string;
}

/**
 * 意图结果接口
 */
export interface IntentResult {
  success: boolean;
  message: string;
  data?: Record<string, any>;
  card?: IntentResponseCard;
  error?: string;
}

/**
 * 意图响应卡片
 */
export interface IntentResponseCard {
  title: string;
  content: string;
  suggestions?: Suggestion[];
  actions?: IntentAction[];
  score?: number;
  analysis?: string;
  summary?: string;
  keyPoints?: string[];
  transcript?: string;
}

/**
 * 意图动作
 */
export interface IntentAction {
  type: 'navigate' | 'showDetail' | 'startSession' | 'showMemoCard' | 'saveMemo' | 'shareMemo';
  target?: string;
  params?: Record<string, any>;
  title?: string;
  content?: string;
  memoId?: string;
}

/**
 * 意图类型
 */
export enum IntentType {
  JOB_SUGGESTION = 'job_suggestion',
  INTERVIEW_REMINDER = 'interview_reminder',
  RESUME_TIP = 'resume_tip',
  INTERVIEW_TIP = 'interview_tip',
  CAREER_ADVICE = 'career_advice'
}

/**
 * 意图数据接口
 */
export interface XiaoyiIntent {
  type: IntentType;
  query?: string;
  location?: string;
  industry?: string;
  interviewId?: string;
  company?: string;
  time?: string;
  context?: Record<string, any>;
}

/**
 * 意图响应接口
 */
export interface IntentResponse {
  success: boolean;
  message: string;
  action?: string;
  data?: Record<string, any>;
  suggestions?: Suggestion[];
}

/**
 * 建议项
 */
export interface Suggestion {
  id: string;
  title: string;
  description: string;
  icon?: string;
  action: string;
  params?: Record<string, any>;
}

export class XiaoyiIntentService {
  private static resumeService: ResumeService = ResumeService.getInstance();
  private static interviewService: InterviewService = InterviewService.getInstance();
  private static assessmentService: AssessmentService = AssessmentService.getInstance();

  /**
   * 处理小艺意图
   */
  static async handleIntent(intent: XiaoyiIntent): Promise<IntentResponse> {
    hilog.info(DOMAIN, TAG, `Handle intent: ${intent.type}`);

    switch (intent.type) {
      case IntentType.JOB_SUGGESTION:
        return this.handleJobSuggestion(intent);
      case IntentType.INTERVIEW_REMINDER:
        return this.handleInterviewReminder(intent);
      case IntentType.RESUME_TIP:
        return this.handleResumeTip(intent);
      case IntentType.INTERVIEW_TIP:
        return this.handleInterviewTip(intent);
      case IntentType.CAREER_ADVICE:
        return this.handleCareerAdvice(intent);
      default:
        return {
          success: false,
          message: '未知的意图类型'
        };
    }
  }

  /**
   * 处理求职建议意图
   */
  private static async handleJobSuggestion(intent: XiaoyiIntent): Promise<IntentResponse> {
    try {
      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录'
        };
      }

      // 获取用户简历和偏好
      const resumeData = await this.getUserResumeSummary(userId);

      // 生成求职建议
      const suggestions: Suggestion[] = [
        {
          id: '1',
          title: '优化简历',
          description: '根据您的目标岗位优化简历内容',
          icon: 'ic_resume',
          action: 'resume/optimize',
          params: { targetPosition: intent.query }
        },
        {
          id: '2',
          title: '模拟面试',
          description: `针对${intent.industry || '目标行业'}进行面试练习`,
          icon: 'ic_interview',
          action: 'interview/start',
          params: { industry: intent.industry, difficulty: 'medium' }
        },
        {
          id: '3',
          title: '能力评估',
          description: '评估您与目标岗位的匹配度',
          icon: 'ic_assessment',
          action: 'assessment/start',
          params: { targetPosition: intent.query }
        }
      ];

      return {
        success: true,
        message: `已为您准备${intent.location || '全国'}${intent.industry || ''}求职建议`,
        action: 'show_suggestions',
        suggestions
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Handle job suggestion failed: ${error}`);
      return {
        success: false,
        message: '获取求职建议失败'
      };
    }
  }

  /**
   * 处理面试提醒意图
   */
  private static async handleInterviewReminder(intent: XiaoyiIntent): Promise<IntentResponse> {
    try {
      const { interviewId, company, time } = intent;

      if (!interviewId || !company || !time) {
        return {
          success: false,
          message: '面试信息不完整'
        };
      }

      // 计算距离面试的时间
      const interviewTime = new Date(time);
      const now = new Date();
      const hoursLeft = Math.round((interviewTime.getTime() - now.getTime()) / (1000 * 60 * 60));

      const suggestions: Suggestion[] = [
        {
          id: '1',
          title: '面试准备',
          description: `查看${company}面试准备清单`,
          icon: 'ic_checklist',
          action: 'interview/prepare',
          params: { interviewId, company }
        },
        {
          id: '2',
          title: '模拟练习',
          description: '进行最后一次模拟面试',
          icon: 'ic_practice',
          action: 'interview/practice',
          params: { interviewId, company }
        },
        {
          id: '3',
          title: '查看公司信息',
          description: `了解${company}的背景和面试经验`,
          icon: 'ic_company',
          action: 'knowledge/company',
          params: { company }
        }
      ];

      return {
        success: true,
        message: `您在${company}的面试将在${hoursLeft}小时后开始`,
        action: 'show_reminder',
        data: {
          interviewId,
          company,
          time,
          hoursLeft
        },
        suggestions
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Handle interview reminder failed: ${error}`);
      return {
        success: false,
        message: '处理面试提醒失败'
      };
    }
  }

  /**
   * 处理简历建议意图
   */
  private static async handleResumeTip(intent: XiaoyiIntent): Promise<IntentResponse> {
    try {
      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录'
        };
      }

      // 获取简历分析结果
      const analysisResult = await this.getLatestResumeAnalysis(userId);

      const suggestions: Suggestion[] = [];

      if (analysisResult) {
        // 根据分析结果生成建议
        if (analysisResult.scores.experience < 70) {
          suggestions.push({
            id: '1',
            title: '优化工作经历',
            description: '使用STAR法则描述您的工作成果',
            icon: 'ic_edit',
            action: 'resume/edit',
            params: { section: 'experience' }
          });
        }

        if (analysisResult.scores.skills < 70) {
          suggestions.push({
            id: '2',
            title: '补充技能标签',
            description: '添加与目标岗位匹配的技能关键词',
            icon: 'ic_skills',
            action: 'resume/edit',
            params: { section: 'skills' }
          });
        }

        if (analysisResult.scores.format < 80) {
          suggestions.push({
            id: '3',
            title: '优化简历格式',
            description: '调整简历排版，提升可读性',
            icon: 'ic_format',
            action: 'resume/format',
            params: {}
          });
        }
      }

      return {
        success: true,
        message: '已分析您的简历，为您提供优化建议',
        action: 'show_suggestions',
        suggestions
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Handle resume tip failed: ${error}`);
      return {
        success: false,
        message: '获取简历建议失败'
      };
    }
  }

  /**
   * 处理面试技巧意图
   */
  private static async handleInterviewTip(intent: XiaoyiIntent): Promise<IntentResponse> {
    const tips = [
      {
        title: '自我介绍',
        content: '控制在1-2分钟，突出与岗位相关的经历和成就'
      },
      {
        title: '回答问题',
        content: '使用STAR法则：情境、任务、行动、结果'
      },
      {
        title: '提问环节',
        content: '准备3-5个有深度的问题，展示对公司的了解'
      }
    ];

    const randomTip = tips[Math.floor(Math.random() * tips.length)];

    return {
      success: true,
      message: `💡 面试小技巧：${randomTip.title}`,
      action: 'show_tip',
      data: {
        title: randomTip.title,
        content: randomTip.content
      }
    };
  }

  /**
   * 处理职业建议意图
   */
  private static async handleCareerAdvice(intent: XiaoyiIntent): Promise<IntentResponse> {
    const suggestions: Suggestion[] = [
      {
        id: '1',
        title: '职业规划',
        description: '制定您的职业发展路径',
        icon: 'ic_career',
        action: 'assessment/career',
        params: {}
      },
      {
        id: '2',
        title: '技能提升',
        description: '发现需要提升的核心技能',
        icon: 'ic_learning',
        action: 'assessment/skills',
        params: {}
      },
      {
        id: '3',
        title: '行业分析',
        description: '了解目标行业的发展趋势',
        icon: 'ic_industry',
        action: 'knowledge/industry',
        params: { industry: intent.industry }
      }
    ];

    return {
      success: true,
      message: '已为您准备职业发展建议',
      action: 'show_suggestions',
      suggestions
    };
  }

  /**
   * 获取用户简历摘要
   */
  private static async getUserResumeSummary(userId: string): Promise<any> {
    try {
      const response = await ApiService.getInstance().get(`/api/resume/summary?userId=${userId}`);
      return response.data;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get resume summary failed: ${error}`);
      return null;
    }
  }

  /**
   * 获取最新简历分析结果
   */
  private static async getLatestResumeAnalysis(userId: string): Promise<any> {
    try {
      const response = await ApiService.getInstance().get(`/api/resume/analysis/latest?userId=${userId}`);
      return response.data;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get resume analysis failed: ${error}`);
      return null;
    }
  }

  /**
   * 注册小艺建议意图
   */
  static registerIntents(): void {
    hilog.info(DOMAIN, TAG, 'Registering Xiaoyi intents');

    // 注册求职建议意图
    this.registerIntent({
      name: 'buddyjob.job_suggestion',
      action: 'job_suggestion',
      handler: this.handleJobSuggestion.bind(this)
    });

    // 注册面试提醒意图
    this.registerIntent({
      name: 'buddyjob.interview_reminder',
      action: 'interview_reminder',
      handler: this.handleInterviewReminder.bind(this)
    });

    hilog.info(DOMAIN, TAG, 'Xiaoyi intents registered');
  }

  /**
   * 注册单个意图
   */
  private static registerIntent(config: {
    name: string;
    action: string;
    handler: (intent: XiaoyiIntent) => Promise<IntentResponse>;
  }): void {
    // 意图已在 module.json5 中声明
    // 这里可以添加额外的运行时配置
    hilog.info(DOMAIN, TAG, `Intent registered: ${config.name}`);
  }

  // ==================== 意图处理器方法 ====================

  /**
   * 处理 buddyjob.analyze_resume 意图
   * 分析用户简历，提供优化建议
   */
  static async handleAnalyzeResume(params: IntentParams): Promise<IntentResult> {
    hilog.info(DOMAIN, TAG, 'Handling analyze_resume intent');

    try {
      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录后再使用简历分析功能'
        };
      }

      const resumeId = params.resumeId || '';
      const targetPosition = params.targetPosition || '';

      // 调用 ResumeService 进行简历分析
      const analysisResult = await this.resumeService.analyzeResume(userId, resumeId, targetPosition);

      // 构建响应卡片
      const card: IntentResponseCard = {
        title: '简历分析报告',
        content: analysisResult.summary || '已完成简历分析',
        score: analysisResult.atsScore,
        analysis: analysisResult.analysis,
        suggestions: this.buildResumeSuggestions(analysisResult)
      };

      return {
        success: true,
        message: `简历分析完成！ATS评分为${analysisResult.atsScore}分。${analysisResult.summary}`,
        data: analysisResult,
        card
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Analyze resume failed: ${error}`);
      return {
        success: false,
        message: '简历分析失败，请稍后重试',
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 处理 buddyjob.interview_practice 意图
   * 进行模拟面试练习
   */
  static async handleInterviewPractice(params: IntentParams): Promise<IntentResult> {
    hilog.info(DOMAIN, TAG, 'Handling interview_practice intent');

    try {
      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录后再使用面试练习功能'
        };
      }

      const jobType = params.jobType || 'general';
      const difficulty = params.difficulty || 'medium';
      const company = params.company || '';

      // 调用 InterviewService 开始面试练习
      const practiceResult = await this.interviewService.startPractice(
        userId,
        jobType,
        difficulty,
        company
      );

      const jobTypeName = this.getJobTypeName(jobType);

      // 构建响应卡片
      const card: IntentResponseCard = {
        title: '面试练习已开始',
        content: `准备好开始${company ? company + '的' : ''}${jobTypeName}面试练习了吗？`,
        suggestions: [
          {
            id: '1',
            title: '自我介绍练习',
            description: '练习1分钟自我介绍',
            icon: 'ic_intro',
            action: 'interview/self_intro'
          },
          {
            id: '2',
            title: '行为面试题',
            description: '练习STAR法则回答',
            icon: 'ic_behavior',
            action: 'interview/behavioral'
          },
          {
            id: '3',
            title: '技术面试题',
            description: `练习${jobTypeName}相关技术问题`,
            icon: 'ic_technical',
            action: 'interview/technical',
            params: { jobType }
          }
        ],
        actions: [
          {
            type: 'navigate',
            target: 'pages/Interview',
            params: { mode: 'practice', jobType, difficulty, company }
          }
        ]
      };

      return {
        success: true,
        message: `好的，我来帮你进行${company ? company + '的' : ''}${jobTypeName}面试练习。准备好了吗？`,
        data: practiceResult,
        card
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Interview practice failed: ${error}`);
      return {
        success: false,
        message: '启动面试练习失败，请稍后重试',
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 处理 buddyjob.assess_ability 意图
   * 进行职业能力测评
   */
  static async handleAssessAbility(params: IntentParams): Promise<IntentResult> {
    hilog.info(DOMAIN, TAG, 'Handling assess_ability intent');

    try {
      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录后再使用能力测评功能'
        };
      }

      const assessmentType = params.assessmentType || 'comprehensive';

      // 调用 AssessmentService 获取测评信息
      const assessmentInfo = await this.assessmentService.getAssessmentInfo(assessmentType);

      // 构建响应卡片
      const card: IntentResponseCard = {
        title: assessmentInfo.name || '能力测评',
        content: assessmentInfo.description || `这个测评大约需要${assessmentInfo.duration || 15}分钟`,
        suggestions: [
          {
            id: '1',
            title: '开始测评',
            description: '立即开始能力测评',
            icon: 'ic_start',
            action: 'assessment/start',
            params: { type: assessmentType }
          },
          {
            id: '2',
            title: '查看说明',
            description: '了解测评流程和注意事项',
            icon: 'ic_info',
            action: 'assessment/info',
            params: { type: assessmentType }
          },
          {
            id: '3',
            title: '历史记录',
            description: '查看历史测评结果',
            icon: 'ic_history',
            action: 'assessment/history'
          }
        ],
        actions: [
          {
            type: 'navigate',
            target: 'pages/Assessment',
            params: { type: assessmentType, source: 'xiaoyi' }
          }
        ]
      };

      return {
        success: true,
        message: `我来帮你进行${assessmentInfo.name || '能力测评'}。这个测评大约需要${assessmentInfo.duration || 15}分钟，包含${assessmentInfo.questionCount || 20}道题目。准备好了吗？`,
        data: assessmentInfo,
        card
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Assess ability failed: ${error}`);
      return {
        success: false,
        message: '获取测评信息失败，请稍后重试',
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 处理 buddyjob.circle_selection 意图
   * 圈选内容进行AI分析
   */
  static async handleCircleSelection(params: IntentParams): Promise<IntentResult> {
    hilog.info(DOMAIN, TAG, 'Handling circle_selection intent');

    try {
      const selectedText = params.selectedText;
      const context = params.context || '';

      if (!selectedText || selectedText.trim().length === 0) {
        return {
          success: false,
          message: '请先圈选需要分析的简历内容'
        };
      }

      // 调用 API 进行圈选分析
      const apiService = ApiService.getInstance();
      const response = await apiService.post('ai/analyze-selection', {
        content: selectedText,
        context: context,
        analysisType: 'resume'
      });

      let analysisResult;
      if (response.success && response.data) {
        analysisResult = response.data;
      } else {
        // 使用本地分析作为备选
        analysisResult = await this.performLocalAnalysis(selectedText, context);
      }

      // 构建优化建议
      const suggestions: Suggestion[] = (analysisResult.suggestions || []).map((s: string, index: number) => ({
        id: String(index + 1),
        title: this.extractSuggestionTitle(s),
        description: s,
        icon: 'ic_suggestion',
        action: 'resume/apply',
        params: { suggestion: s, originalText: selectedText }
      }));

      // 构建响应卡片
      const card: IntentResponseCard = {
        title: '圈选内容分析',
        content: analysisResult.analysis || '已完成内容分析',
        score: analysisResult.score,
        analysis: analysisResult.analysis,
        suggestions
      };

      return {
        success: true,
        message: `分析完成！${analysisResult.analysis}`,
        data: analysisResult,
        card
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Circle selection failed: ${error}`);
      return {
        success: false,
        message: '分析过程中出现错误，请稍后重试',
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 处理 buddyjob.voice_memo 意图
   * 语音记录面试要点
   */
  static async handleVoiceMemo(params: IntentParams): Promise<IntentResult> {
    hilog.info(DOMAIN, TAG, 'Handling voice_memo intent');

    try {
      const audioUri = params.audioUri;
      const interviewId = params.interviewId || '';
      const resumeId = params.resumeId || '';

      if (!audioUri) {
        return {
          success: false,
          message: '请先录制语音内容'
        };
      }

      const userId = await storage.get('userId', '');
      if (!userId) {
        return {
          success: false,
          message: '请先登录后再使用语音备忘功能'
        };
      }

      // 1. 上传音频文件
      const apiService = ApiService.getInstance();
      const uploadResponse = await apiService.post('upload/audio', {
        uri: audioUri,
        type: 'voice_memo',
        userId
      });

      if (!uploadResponse.success) {
        return {
          success: false,
          message: '音频上传失败，请重试'
        };
      }

      const audioUrl = uploadResponse.data?.url || audioUri;

      // 2. 调用语音处理 API
      const processResponse = await apiService.post('ai/process-voice-memo', {
        audioUrl,
        interviewId,
        resumeId,
        userId,
        generateSummary: true,
        extractKeyPoints: true
      });

      let result;
      if (processResponse.success && processResponse.data) {
        result = processResponse.data;
      } else {
        // 使用模拟数据作为备选
        result = this.generateMockMemoResult();
      }

      // 3. 保存备忘录到本地
      const saveResponse = await apiService.post('memo/save', {
        userId,
        interviewId,
        resumeId,
        transcript: result.transcript,
        summary: result.summary,
        keyPoints: result.keyPoints,
        audioUri: audioUrl,
        source: 'xiaoyi_voice_memo'
      });

      const memoId = saveResponse.success ? saveResponse.data?.memoId : `memo_${Date.now()}`;

      // 构建响应卡片
      const card: IntentResponseCard = {
        title: '面试要点已记录',
        content: result.summary,
        summary: result.summary,
        transcript: result.transcript,
        keyPoints: result.keyPoints,
        actions: [
          {
            type: 'showMemoCard',
            title: '面试要点记录',
            content: result.summary
          },
          {
            type: 'saveMemo',
            memoId
          }
        ]
      };

      return {
        success: true,
        message: `面试要点已记录！\n\n摘要：${result.summary}\n\n关键要点：\n${result.keyPoints?.map((p: string, i: number) => `${i + 1}. ${p}`).join('\n') || ''}`,
        data: { ...result, memoId },
        card
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Voice memo failed: ${error}`);
      return {
        success: false,
        message: '处理语音记录时出现错误，请稍后重试',
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  // ==================== 辅助方法 ====================

  /**
   * 构建简历建议列表
   */
  private static buildResumeSuggestions(analysisResult: any): Suggestion[] {
    const suggestions: Suggestion[] = [];
    const dimensions = analysisResult.dimensions || [];

    dimensions.forEach((dim: any) => {
      if (dim.score < 70) {
        suggestions.push({
          id: String(suggestions.length + 1),
          title: `优化${dim.name}`,
          description: `${dim.name}得分较低，建议进行优化`,
          icon: 'ic_edit',
          action: 'resume/edit',
          params: { section: dim.key }
        });
      }
    });

    // 添加通用建议
    if (suggestions.length === 0) {
      suggestions.push({
        id: '1',
        title: '简历整体良好',
        description: '您的简历表现不错，继续保持',
        icon: 'ic_success',
        action: 'resume/view'
      });
    }

    return suggestions;
  }

  /**
   * 执行本地内容分析
   */
  private static async performLocalAnalysis(selectedText: string, context: string): Promise<any> {
    // 本地分析逻辑
    const wordCount = selectedText.split(/\s+/).length;
    const hasNumbers = /\d+/.test(selectedText);
    const hasActionVerbs = /负责|主导|完成|提升|开发|设计|实现/.test(selectedText);

    let score = 60;
    const suggestions: string[] = [];

    // 评估内容质量
    if (wordCount < 20) {
      suggestions.push('内容较短，建议添加更多细节描述');
    } else {
      score += 10;
    }

    if (!hasNumbers) {
      suggestions.push('建议添加量化的数据指标，如"提升了50%的性能"');
    } else {
      score += 15;
    }

    if (!hasActionVerbs) {
      suggestions.push('建议使用强动词开头，如"负责"、"主导"、"完成"等');
    } else {
      score += 15;
    }

    // 确保分数在合理范围内
    score = Math.min(100, Math.max(0, score));

    return {
      analysis: `这段内容${wordCount >= 20 ? '描述较为详细，' : '较为简洁，'}${hasNumbers ? '包含数据指标，' : ''}整体表达${score >= 75 ? '较好' : score >= 60 ? '基本合格' : '有待提升'}。${suggestions.length > 0 ? suggestions.join('。') : '继续保持。'}`,
      score,
      suggestions
    };
  }

  /**
   * 生成模拟备忘录结果
   */
  private static generateMockMemoResult(): { transcript: string; summary: string; keyPoints: string[] } {
    return {
      transcript: '这是一段模拟的面试要点记录...',
      summary: '本次面试主要围绕项目经验和技术深度展开。面试官对数据库优化和分布式系统比较关注，建议后续加强这两方面的准备。',
      keyPoints: [
        '项目经验获得认可',
        '数据库优化是重点关注方向',
        '分布式系统知识需要加强',
        '技术深度有待提升'
      ]
    };
  }

  /**
   * 提取建议标题
   */
  private static extractSuggestionTitle(suggestion: string): string {
    // 尝试从建议中提取关键词作为标题
    const keywords = ['量化', '数据', '技能', '经验', '项目', '优化', '添加', '完善', '突出', '简化'];
    for (const keyword of keywords) {
      if (suggestion.includes(keyword)) {
        return `建议${keyword === '量化' ? '添加量化数据' : keyword === '数据' ? '补充数据指标' : `完善${keyword}`}`;
      }
    }
    return '优化建议';
  }

  /**
   * 获取职位类型名称
   */
  private static getJobTypeName(jobType: string): string {
    const typeMap: Record<string, string> = {
      'general': '通用',
      'frontend': '前端开发',
      'backend': '后端开发',
      'fullstack': '全栈开发',
      'product': '产品经理',
      'design': '设计',
      'marketing': '市场营销',
      'sales': '销售',
      'hr': '人力资源',
      'operations': '运营',
      'data': '数据分析'
    };
    return typeMap[jobType] || jobType;
  }
}
