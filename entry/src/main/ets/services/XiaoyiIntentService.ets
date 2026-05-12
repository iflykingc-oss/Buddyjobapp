/**
 * 小艺建议意图服务 - 接收小艺建议并处理
 * 支持求职建议、面试提醒等意图
 */
import hilog from '@ohos.hilog';
import { ApiService } from './ApiService';
import { storage } from '../utils/storage';

const TAG = 'XiaoyiIntentService';
const DOMAIN = 0xFF00;

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
}
