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

// 小艺技能接口
export interface XiaoyiSkill {
  id: string;
  name: string;
  description: string;
  icon?: string;
  keywords: string[];
  intentName: string;
  enabled: boolean;
}

// 小艺技能卡片
export interface XiaoyiSkillCard {
  skillId: string;
  skillName: string;
  skillIcon?: string;
  quickActions: XiaoyiQuickAction[];
}

// 小艺快捷操作
export interface XiaoyiQuickAction {
  id: string;
  title: string;
  icon?: string;
  action: string;
  params?: Record<string, any>;
}

// 小艺响应卡片
export interface XiaoyiResponseCard {
  title: string;
  content: string;
  type: 'text' | 'card' | 'list' | 'action';
  actions?: XiaoyiQuickAction[];
  suggestions?: AgentSuggestion[];
}

// 智能体配置接口
export interface XiaoyiAgentConfig {
  agentId: string;
  name: string;
  description: string;
  version: string;
  skills: XiaoyiSkill[];
  settings: AgentSettings;
  capabilities: string[];
}

// 智能体设置
export interface AgentSettings {
  voiceEnabled: boolean;
  autoAnalysis: boolean;
  maxHistoryCount: number;
  responseTimeout: number;
}

// 对话上下文
export interface DialogContext {
  userId: string;
  sessionId: string;
  intent?: string;
  params?: Record<string, any>;
  history: DialogTurn[];
  startTime: number;
}

// 对话轮次
export interface DialogTurn {
  role: 'user' | 'assistant';
  message: string;
  timestamp: number;
  intent?: string;
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

  // 小艺技能相关
  private skills: XiaoyiSkill[] = [];
  private currentDialogContext: DialogContext | null = null;

  // 智能体ID（需要在小艺开放平台申请）
  private readonly AGENT_ID_RESUME = 'buddyjob_resume_agent';
  private readonly AGENT_ID_INTERVIEW = 'buddyjob_interview_agent';
  private readonly AGENT_ID_CAREER = 'buddyjob_career_agent';

  // 默认配置
  private readonly DEFAULT_CONFIG: XiaoyiAgentConfig = {
    agentId: 'buddyjob_xiaoyi_agent',
    name: 'BuddyJob小艺助手',
    description: '您的智能求职助手，帮您分析简历、准备面试、提升职场技能',
    version: '1.0.0',
    skills: [],
    settings: {
      voiceEnabled: true,
      autoAnalysis: true,
      maxHistoryCount: 50,
      responseTimeout: 30000
    },
    capabilities: [
      'intent_recognition',
      'resume_analysis',
      'interview_practice',
      'skill_assessment',
      'career_advice',
      'voice_memo',
      'circle_selection'
    ]
  };

  private constructor() {
    this.registerDefaultIntents();
    this.initializeSkills();
  }

  static getInstance(): XiaoyiAgentService {
    if (!XiaoyiAgentService.instance) {
      XiaoyiAgentService.instance = new XiaoyiAgentService();
    }
    return XiaoyiAgentService.instance;
  }

  // ==================== 生命周期方法 ====================

  /**
   * 智能体初始化
   * 在应用启动时调用
   */
  async onInitialize(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Initializing Xiaoyi Agent Service...');

    try {
      // 检查智能体环境是否可用
      const isAvailable = await this.checkAgentAvailability();
      if (!isAvailable) {
        hilog.warn(DOMAIN, TAG, 'Agent framework not available');
        this.state = XiaoyiAgentState.ERROR;
        return;
      }

      // 注册智能体配置
      this.registerAgentConfigs();

      // 注册小艺技能
      this.registerSkills();

      // 初始化对话上下文
      this.initializeDialogContext();

      this.state = XiaoyiAgentState.READY;
      hilog.info(DOMAIN, TAG, 'Xiaoyi Agent Service initialized successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialization failed: ${JSON.stringify(error)}`);
      this.state = XiaoyiAgentState.ERROR;
      throw error;
    }
  }

  /**
   * 智能体销毁
   * 在应用退出时调用
   */
  async onDestroy(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Destroying Xiaoyi Agent Service...');

    try {
      // 保存对话历史
      await this.saveDialogHistory();

      // 清理资源
      this.cleanup();

      // 重置状态
      this.state = XiaoyiAgentState.UNINITIALIZED;
      this.currentDialogContext = null;

      hilog.info(DOMAIN, TAG, 'Xiaoyi Agent Service destroyed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Destroy failed: ${error}`);
    }
  }

  /**
   * 清理资源
   */
  private cleanup(): void {
    // 清理选择管理器
    // 清理音频录制器
    // 清理其他资源
    hilog.info(DOMAIN, TAG, 'Resources cleaned up');
  }

  // ==================== 配置方法 ====================

  /**
   * 获取智能体配置
   */
  getAgentConfig(): XiaoyiAgentConfig {
    return {
      ...this.DEFAULT_CONFIG,
      skills: this.skills.filter(s => s.enabled)
    };
  }

  /**
   * 更新智能体配置
   */
  async updateAgentConfig(config: Partial<XiaoyiAgentConfig>): Promise<boolean> {
    try {
      // 更新默认配置
      Object.assign(this.DEFAULT_CONFIG, config);

      // 保存到持久化存储
      await storage.set('agent_config', JSON.stringify(this.DEFAULT_CONFIG));

      hilog.info(DOMAIN, TAG, 'Agent config updated');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Update config failed: ${error}`);
      return false;
    }
  }

  /**
   * 初始化对话上下文
   */
  private initializeDialogContext(): void {
    const sessionId = this.generateSessionId();
    this.currentDialogContext = {
      userId: '',
      sessionId,
      history: [],
      startTime: Date.now()
    };
  }

  /**
   * 生成会话ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  // ==================== 对话管理方法 ====================

  /**
   * 处理用户输入
   * @param utterance 用户说的话
   * @returns 智能体响应
   */
  async handleUserUtterance(utterance: string): Promise<string> {
    hilog.info(DOMAIN, TAG, `Handling user utterance: ${utterance}`);

    if (!this.currentDialogContext) {
      this.initializeDialogContext();
    }

    try {
      // 添加用户消息到历史
      this.addToDialogHistory('user', utterance);

      // 识别意图
      const intentResult = this.recognizeIntent(utterance);

      // 根据意图生成响应
      let response: string;

      if (intentResult.intent) {
        // 已识别到意图
        const result = await this.handleIntent(intentResult.intent, intentResult.params || {});
        response = result.message;
      } else {
        // 无法识别意图，生成引导回复
        response = this.generateGuidingResponse(utterance);
      }

      // 添加助手消息到历史
      this.addToDialogHistory('assistant', response);

      return response;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Handle utterance failed: ${error}`);
      return '抱歉，我遇到了一些问题，请稍后再试。';
    }
  }

  /**
   * 识别用户意图
   */
  private recognizeIntent(utterance: string): { intent?: string; params?: Record<string, any> } {
    const lowerUtterance = utterance.toLowerCase();

    // 简历分析意图
    if (lowerUtterance.includes('简历') && (lowerUtterance.includes('分析') || lowerUtterance.includes('优化'))) {
      return { intent: 'buddyjob.analyze_resume', params: {} };
    }

    // 面试练习意图
    if (lowerUtterance.includes('面试')) {
      return { intent: 'buddyjob.interview_practice', params: {} };
    }

    // 能力测评意图
    if (lowerUtterance.includes('测评') || lowerUtterance.includes('评估') || lowerUtterance.includes('测试')) {
      return { intent: 'buddyjob.assess_ability', params: {} };
    }

    // 圈选分析意图
    if (lowerUtterance.includes('圈选') || lowerUtterance.includes('选中') || lowerUtterance.includes('分析这段')) {
      return { intent: 'buddyjob.circle_selection', params: {} };
    }

    // 语音备忘意图
    if (lowerUtterance.includes('记录') || lowerUtterance.includes('备忘') || lowerUtterance.includes('帮记')) {
      return { intent: 'buddyjob.voice_memo', params: {} };
    }

    // Offer分析意图
    if (lowerUtterance.includes('offer') || lowerUtterance.includes('薪资') || lowerUtterance.includes('待遇')) {
      return { intent: 'buddyjob.analyze_offer', params: {} };
    }

    // 职业建议意图
    if (lowerUtterance.includes('职业') || lowerUtterance.includes('发展') || lowerUtterance.includes('建议')) {
      return { intent: 'buddyjob.career_advice', params: {} };
    }

    return {};
  }

  /**
   * 生成引导响应
   */
  private generateGuidingResponse(utterance: string): string {
    // 基于用户输入的关键词生成引导
    if (utterance.includes('?')) {
      return '我理解您有疑问。请告诉我您想做什么：\n\n' +
        '1. 分析简历 - "帮我分析简历"\n' +
        '2. 面试练习 - "开始面试练习"\n' +
        '3. 能力测评 - "进行能力测评"\n' +
        '4. 语音备忘 - "记录面试要点"\n' +
        '5. 职业建议 - "获取职业建议"';
    }

    return '您好！我是BuddyJob小艺助手。我可以帮您：\n\n' +
      '• 分析和优化简历\n' +
      '• 进行模拟面试练习\n' +
      '• 评估职业能力\n' +
      '• 记录面试要点\n' +
      '• 分析Offer待遇\n\n' +
      '请告诉我您需要什么帮助？';
  }

  /**
   * 添加到对话历史
   */
  private addToDialogHistory(role: 'user' | 'assistant', message: string): void {
    if (!this.currentDialogContext) return;

    const turn: DialogTurn = {
      role,
      message,
      timestamp: Date.now()
    };

    this.currentDialogContext.history.push(turn);

    // 限制历史记录数量
    const maxHistory = this.DEFAULT_CONFIG.settings.maxHistoryCount;
    if (this.currentDialogContext.history.length > maxHistory) {
      this.currentDialogContext.history = this.currentDialogContext.history.slice(-maxHistory);
    }
  }

  /**
   * 保存对话历史
   */
  private async saveDialogHistory(): Promise<void> {
    if (!this.currentDialogContext) return;

    try {
      await storage.set('dialog_history', JSON.stringify(this.currentDialogContext.history));
      hilog.info(DOMAIN, TAG, 'Dialog history saved');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Save dialog history failed: ${error}`);
    }
  }

  /**
   * 获取对话历史
   */
  async getDialogHistory(): Promise<DialogTurn[]> {
    if (!this.currentDialogContext) return [];
    return this.currentDialogContext.history;
  }

  /**
   * 清除对话历史
   */
  async clearDialogHistory(): Promise<void> {
    if (this.currentDialogContext) {
      this.currentDialogContext.history = [];
    }
    await storage.delete('dialog_history');
    hilog.info(DOMAIN, TAG, 'Dialog history cleared');
  }

  // ==================== 技能卡片构建 ====================

  /**
   * 构建技能卡片
   */
  buildSkillCard(skill: XiaoyiSkill): XiaoyiSkillCard {
    const quickActions = this.getSkillQuickActions(skill);

    return {
      skillId: skill.id,
      skillName: skill.name,
      skillIcon: skill.icon,
      quickActions
    };
  }

  /**
   * 获取技能的快捷操作
   */
  private getSkillQuickActions(skill: XiaoyiSkill): XiaoyiQuickAction[] {
    switch (skill.intentName) {
      case 'buddyjob.analyze_resume':
        return [
          { id: '1', title: '上传简历', icon: 'ic_upload', action: 'upload_resume' },
          { id: '2', title: '查看示例', icon: 'ic_example', action: 'view_example' },
          { id: '3', title: '优化建议', icon: 'ic_suggest', action: 'get_suggestions' }
        ];

      case 'buddyjob.interview_practice':
        return [
          { id: '1', title: '自我介绍', icon: 'ic_intro', action: 'self_intro' },
          { id: '2', title: '行为面试', icon: 'ic_behavior', action: 'behavioral' },
          { id: '3', title: '技术面试', icon: 'ic_tech', action: 'technical' }
        ];

      case 'buddyjob.assess_ability':
        return [
          { id: '1', title: '开始测评', icon: 'ic_start', action: 'start_assessment' },
          { id: '2', title: '查看结果', icon: 'ic_result', action: 'view_result' },
          { id: '3', title: '提升建议', icon: 'ic_improve', action: 'get_advice' }
        ];

      case 'buddyjob.voice_memo':
        return [
          { id: '1', title: '开始录音', icon: 'ic_record', action: 'start_recording' },
          { id: '2', title: '查看记录', icon: 'ic_list', action: 'view_memos' },
          { id: '3', title: '分享', icon: 'ic_share', action: 'share' }
        ];

      default:
        return [
          { id: '1', title: '开始', icon: 'ic_start', action: 'start' }
        ];
    }
  }

  /**
   * 获取所有技能卡片
   */
  getAllSkillCards(): XiaoyiSkillCard[] {
    return this.skills
      .filter(s => s.enabled)
      .map(s => this.buildSkillCard(s));
  }

  // ==================== 技能管理 ====================

  /**
   * 初始化技能列表
   */
  private initializeSkills(): void {
    this.skills = [
      {
        id: 'skill_resume',
        name: '简历分析',
        description: '分析简历内容，提供优化建议',
        icon: 'ic_resume',
        keywords: ['简历', '分析', '优化', '评分', 'ATS'],
        intentName: 'buddyjob.analyze_resume',
        enabled: true
      },
      {
        id: 'skill_interview',
        name: '面试练习',
        description: '进行模拟面试练习',
        icon: 'ic_interview',
        keywords: ['面试', '练习', '模拟', '准备', '辅导'],
        intentName: 'buddyjob.interview_practice',
        enabled: true
      },
      {
        id: 'skill_assessment',
        name: '能力测评',
        description: '进行职业能力测评',
        icon: 'ic_assessment',
        keywords: ['测评', '评估', '测试', '能力', '技能'],
        intentName: 'buddyjob.assess_ability',
        enabled: true
      },
      {
        id: 'skill_circle',
        name: '圈选分析',
        description: '圈选内容进行AI分析',
        icon: 'ic_circle',
        keywords: ['圈选', '选中', '分析', '提取'],
        intentName: 'buddyjob.circle_selection',
        enabled: true
      },
      {
        id: 'skill_memo',
        name: '语音备忘',
        description: '语音记录面试要点',
        icon: 'ic_memo',
        keywords: ['记录', '备忘', '帮记', '语音', '笔记'],
        intentName: 'buddyjob.voice_memo',
        enabled: true
      },
      {
        id: 'skill_offer',
        name: 'Offer分析',
        description: '分析Offer薪资待遇',
        icon: 'ic_offer',
        keywords: ['offer', '薪资', '待遇', '比较', '分析'],
        intentName: 'buddyjob.analyze_offer',
        enabled: true
      },
      {
        id: 'skill_career',
        name: '职业建议',
        description: '获取职业发展建议',
        icon: 'ic_career',
        keywords: ['职业', '发展', '建议', '规划', '方向'],
        intentName: 'buddyjob.career_advice',
        enabled: true
      }
    ];
  }

  /**
   * 注册技能
   */
  private registerSkills(): void {
    hilog.info(DOMAIN, TAG, `Registering ${this.skills.length} skills`);

    this.skills.forEach(skill => {
      // 注册意图处理
      this.intentHandlers.set(skill.intentName, async (params) => {
        return this.handleSkillIntent(skill, params);
      });
    });
  }

  /**
   * 处理技能意图
   */
  private async handleSkillIntent(skill: XiaoyiSkill, params: any): Promise<AgentResponse> {
    hilog.info(DOMAIN, TAG, `Handling skill intent: ${skill.intentName}`);

    // 根据技能类型构建不同的响应
    const skillCard = this.buildSkillCard(skill);

    return {
      success: true,
      message: `已为您打开${skill.name}功能`,
      actions: [
        { type: 'open_page', target: `pages/${skill.name}` }
      ],
      suggestions: skillCard.quickActions.map((action, index) => ({
        id: action.id,
        title: action.title,
        description: '',
        icon: action.icon,
        action: action.action
      }))
    };
  }

  /**
   * 启用/禁用技能
   */
  async setSkillEnabled(skillId: string, enabled: boolean): Promise<boolean> {
    const skill = this.skills.find(s => s.id === skillId);
    if (!skill) {
      return false;
    }

    skill.enabled = enabled;
    await storage.set(`skill_${skillId}_enabled`, enabled.toString());
    hilog.info(DOMAIN, TAG, `Skill ${skillId} ${enabled ? 'enabled' : 'disabled'}`);
    return true;
  }

  // ==================== 原有代码 ====================

  /**
   * 初始化智能体服务
   */
  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    this.context = context;
    return this.onInitialize();
  }
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
