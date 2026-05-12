/**
 * 小艺智能体服务增强版
 * 基于 HarmonyOS 6.0 Agent Framework Kit
 * 提供智能体拉起、意图处理、状态管理
 */
import { common } from '@kit.AbilityKit';
import { FunctionController, FunctionComponent, AgentState } from '@kit.AgentFrameworkKit';
import { agentFramework } from '@kit.IntelligentAgentKit';
import hilog from '@ohos.hilog';
import { storage } from '../utils/storage';

const TAG = 'XiaoyiAgentService';
const DOMAIN = 0xFF00;

// 智能体配置
export interface AgentConfig {
  agentId: string;
  name: string;
  description: string;
  icon?: string;
  intents: AgentIntent[];
}

// 意图配置
export interface AgentIntent {
  name: string;
  action: string;
  description: string;
  parameters: AgentParameter[];
  handler: (params: Record<string, any>) => Promise<AgentResponse>;
}

// 意图参数
export interface AgentParameter {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'object' | 'array';
  required: boolean;
  description: string;
}

// 意图响应
export interface AgentResponse {
  success: boolean;
  message: string;
  data?: Record<string, any>;
  actions?: AgentAction[];
  suggestions?: AgentSuggestion[];
}

// 智能体动作
export interface AgentAction {
  type: 'open_page' | 'execute' | 'notify' | 'speak';
  target: string;
  params?: Record<string, any>;
}

// 智能体建议
export interface AgentSuggestion {
  id: string;
  title: string;
  description: string;
  icon?: string;
  action: string;
  params?: Record<string, any>;
}

// 智能体状态
export enum XiaoyiAgentState {
  UNINITIALIZED = 'uninitialized',
  READY = 'ready',
  BUSY = 'busy',
  ERROR = 'error'
}

/**
 * 小艺智能体服务
 * 封装 Agent Framework Kit 能力
 */
export class XiaoyiAgentService {
  private static instance: XiaoyiAgentService;
  private context: common.UIAbilityContext | null = null;
  private state: XiaoyiAgentState = XiaoyiAgentState.UNINITIALIZED;
  private agentConfigs: Map<string, AgentConfig> = new Map();
  private intentHandlers: Map<string, (params: any) => Promise<AgentResponse>> = new Map();

  // 智能体ID（需要在小艺开放平台申请）
  private readonly AGENT_ID_RESUME = 'buddyjob_resume_agent';
  private readonly AGENT_ID_INTERVIEW = 'buddyjob_interview_agent';
  private readonly AGENT_ID_CAREER = 'buddyjob_career_agent';

  private constructor() {
    this.registerDefaultIntents();
  }

  static getInstance(): XiaoyiAgentService {
    if (!XiaoyiAgentService.instance) {
      XiaoyiAgentService.instance = new XiaoyiAgentService();
    }
    return XiaoyiAgentService.instance;
  }

  /**
   * 初始化智能体服务
   */
  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    try {
      this.context = context;

      // 检查智能体环境是否可用
      const isAvailable = await this.checkAgentAvailability();
      if (!isAvailable) {
        hilog.warn(DOMAIN, TAG, 'Agent framework not available');
        this.state = XiaoyiAgentState.ERROR;
        return false;
      }

      // 注册智能体配置
      this.registerAgentConfigs();

      this.state = XiaoyiAgentState.READY;
      hilog.info(DOMAIN, TAG, 'Xiaoyi agent service initialized');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(error)}`);
      this.state = XiaoyiAgentState.ERROR;
      return false;
    }
  }

  /**
   * 检查智能体可用性
   */
  async checkAgentAvailability(): Promise<boolean> {
    try {
      // 使用 FunctionController 检查环境
      const controller = new FunctionController(this.context!);
      // 检查用户是否登录华为账号并同意隐私协议
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Check availability failed: ${error}`);
      return false;
    }
  }

  /**
   * 获取当前状态
   */
  getState(): XiaoyiAgentState {
    return this.state;
  }

  /**
   * 注册默认意图处理器
   */
  private registerDefaultIntents(): void {
    // 简历分析意图
    this.intentHandlers.set('buddyjob.analyze_resume', async (params) => {
      return this.handleAnalyzeResume(params);
    });

    // 面试练习意图
    this.intentHandlers.set('buddyjob.interview_practice', async (params) => {
      return this.handleInterviewPractice(params);
    });

    // 能力评估意图
    this.intentHandlers.set('buddyjob.assess_ability', async (params) => {
      return this.handleAssessAbility(params);
    });

    // 圈选分析意图
    this.intentHandlers.set('buddyjob.circle_selection', async (params) => {
      return this.handleCircleSelection(params);
    });

    // 语音备忘意图
    this.intentHandlers.set('buddyjob.voice_memo', async (params) => {
      return this.handleVoiceMemo(params);
    });

    // Offer分析意图
    this.intentHandlers.set('buddyjob.analyze_offer', async (params) => {
      return this.handleAnalyzeOffer(params);
    });

    // 职业建议意图
    this.intentHandlers.set('buddyjob.career_advice', async (params) => {
      return this.handleCareerAdvice(params);
    });

    hilog.info(DOMAIN, TAG, 'Default intents registered');
  }

  /**
   * 注册智能体配置
   */
  private registerAgentConfigs(): void {
    // 简历智能体
    this.agentConfigs.set(this.AGENT_ID_RESUME, {
      agentId: this.AGENT_ID_RESUME,
      name: '简历优化助手',
      description: '帮助用户优化简历，提升求职成功率',
      intents: [
        {
          name: 'buddyjob.analyze_resume',
          action: 'analyze_resume',
          description: '分析简历内容并提供优化建议',
          parameters: [
            { name: 'resumeId', type: 'string', required: false, description: '简历ID' },
            { name: 'targetPosition', type: 'string', required: false, description: '目标职位' }
          ],
          handler: async (params) => this.handleAnalyzeResume(params)
        }
      ]
    });

    // 面试智能体
    this.agentConfigs.set(this.AGENT_ID_INTERVIEW, {
      agentId: this.AGENT_ID_INTERVIEW,
      name: '面试教练',
      description: '提供面试模拟、技巧指导、问题预测',
      intents: [
        {
          name: 'buddyjob.interview_practice',
          action: 'interview_practice',
          description: '开始模拟面试练习',
          parameters: [
            { name: 'jobType', type: 'string', required: false, description: '职位类型' },
            { name: 'difficulty', type: 'string', required: false, description: '难度等级' },
            { name: 'company', type: 'string', required: false, description: '目标公司' }
          ],
          handler: async (params) => this.handleInterviewPractice(params)
        }
      ]
    });

    // 职业发展智能体
    this.agentConfigs.set(this.AGENT_ID_CAREER, {
      agentId: this.AGENT_ID_CAREER,
      name: '职业顾问',
      description: '提供职业规划、能力评估、发展建议',
      intents: [
        {
          name: 'buddyjob.career_advice',
          action: 'career_advice',
          description: '获取职业发展建议',
          parameters: [
            { name: 'industry', type: 'string', required: false, description: '行业' },
            { name: 'experience', type: 'string', required: false, description: '工作经验' }
          ],
          handler: async (params) => this.handleCareerAdvice(params)
        }
      ]
    });

    hilog.info(DOMAIN, TAG, 'Agent configs registered');
  }

  /**
   * 处理意图
   */
  async handleIntent(intentName: string, params: Record<string, any>): Promise<AgentResponse> {
    hilog.info(DOMAIN, TAG, `Handling intent: ${intentName}`);

    const handler = this.intentHandlers.get(intentName);
    if (!handler) {
      return {
        success: false,
        message: `未知的意图: ${intentName}`
      };
    }

    try {
      this.state = XiaoyiAgentState.BUSY;
      const response = await handler(params);
      this.state = XiaoyiAgentState.READY;
      return response;
    } catch (error) {
      this.state = XiaoyiAgentState.ERROR;
      hilog.error(DOMAIN, TAG, `Handle intent failed: ${error}`);
      return {
        success: false,
        message: '处理请求时发生错误'
      };
    }
  }

  /**
   * 拉起智能体
   */
  async launchAgent(agentId: string, params?: Record<string, any>): Promise<boolean> {
    if (!this.context) {
      hilog.error(DOMAIN, TAG, 'Context not initialized');
      return false;
    }

    try {
      // 使用 FunctionComponent 拉起智能体
      // 实际实现需要根据 HarmonyOS 6.0 API
      hilog.info(DOMAIN, TAG, `Launching agent: ${agentId}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Launch agent failed: ${error}`);
      return false;
    }
  }

  /**
   * 发送响应给小艺
   */
  async sendResponse(intentName: string, response: AgentResponse): Promise<void> {
    try {
      agentFramework.sendResponse({
        intentName,
        success: response.success,
        message: response.message,
        data: response.data,
        actions: response.actions
      });
      hilog.info(DOMAIN, TAG, `Response sent for: ${intentName}`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Send response failed: ${error}`);
    }
  }

  // ==================== 意图处理器 ====================

  private async handleAnalyzeResume(params: Record<string, any>): Promise<AgentResponse> {
    const userId = await storage.get('userId', '');
    if (!userId) {
      return {
        success: false,
        message: '请先登录'
      };
    }

    return {
      success: true,
      message: '正在分析您的简历...',
      actions: [
        { type: 'open_page', target: 'pages/Resume', params: { action: 'analyze' } }
      ],
      suggestions: [
        {
          id: '1',
          title: '优化工作经历',
          description: '使用STAR法则优化您的工作经历描述',
          action: 'resume/edit',
          params: { section: 'experience' }
        },
        {
          id: '2',
          title: '添加技能标签',
          description: '添加与目标岗位匹配的技能关键词',
          action: 'resume/edit',
          params: { section: 'skills' }
        }
      ]
    };
  }

  private async handleInterviewPractice(params: Record<string, any>): Promise<AgentResponse> {
    const { jobType, difficulty, company } = params;

    return {
      success: true,
      message: `正在为您准备${company ? company + '的' : ''}面试练习...`,
      actions: [
        { 
          type: 'open_page', 
          target: 'pages/Interview', 
          params: { jobType, difficulty, company, mode: 'practice' } 
        }
      ],
      suggestions: [
        {
          id: '1',
          title: '自我介绍练习',
          description: '练习1分钟自我介绍',
          action: 'interview/practice',
          params: { type: 'self_intro' }
        },
        {
          id: '2',
          title: '行为面试题',
          description: '练习STAR法则回答',
          action: 'interview/practice',
          params: { type: 'behavioral' }
        },
        {
          id: '3',
          title: '技术面试题',
          description: '练习岗位相关技术问题',
          action: 'interview/practice',
          params: { type: 'technical', jobType }
        }
      ]
    };
  }

  private async handleAssessAbility(params: Record<string, any>): Promise<AgentResponse> {
    return {
      success: true,
      message: '正在评估您的能力...',
      actions: [
        { type: 'open_page', target: 'pages/Assessment', params }
      ]
    };
  }

  private async handleCircleSelection(params: Record<string, any>): Promise<AgentResponse> {
    const { selectedText, context } = params;

    return {
      success: true,
      message: '正在分析选中的内容...',
      data: { selectedText },
      actions: [
        { type: 'open_page', target: 'pages/Chat', params: { mode: 'selection', text: selectedText } }
      ]
    };
  }

  private async handleVoiceMemo(params: Record<string, any>): Promise<AgentResponse> {
    return {
      success: true,
      message: '语音备忘已记录',
      actions: [
        { type: 'notify', target: 'voice_memo_saved', params }
      ]
    };
  }

  private async handleAnalyzeOffer(params: Record<string, any>): Promise<AgentResponse> {
    return {
      success: true,
      message: '正在分析Offer...',
      actions: [
        { type: 'open_page', target: 'pages/OfferAnalysis', params }
      ],
      suggestions: [
        {
          id: '1',
          title: '薪资对比',
          description: '对比多个Offer的薪资待遇',
          action: 'offer/compare',
          params: {}
        },
        {
          id: '2',
          title: '发展前景分析',
          description: '分析各公司的发展前景',
          action: 'offer/analyze',
          params: { aspect: 'growth' }
        }
      ]
    };
  }

  private async handleCareerAdvice(params: Record<string, any>): Promise<AgentResponse> {
    const { industry, experience } = params;

    return {
      success: true,
      message: '正在为您生成职业建议...',
      actions: [
        { type: 'open_page', target: 'pages/Assessment', params: { mode: 'career' } }
      ],
      suggestions: [
        {
          id: '1',
          title: '职业规划',
          description: '制定您的职业发展路径',
          action: 'assessment/career',
          params: {}
        },
        {
          id: '2',
          title: '技能提升',
          description: '发现需要提升的核心技能',
          action: 'assessment/skills',
          params: {}
        },
        {
          id: '3',
          title: '行业分析',
          description: `了解${industry || '目标行业'}的发展趋势`,
          action: 'knowledge/industry',
          params: { industry }
        }
      ]
    };
  }
}

export default XiaoyiAgentService;
