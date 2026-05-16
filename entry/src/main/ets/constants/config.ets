// ============================================
// 环境枚举
// ============================================
export enum Environment {
  DEVELOPMENT = 'development',
  TESTING = 'testing',
  PRODUCTION = 'production'
}

// ============================================
// 日志级别枚举
// ============================================
export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

// ============================================
// 主配置对象类型定义
// ============================================
interface FeatureFlags {
  enableAIChat: boolean;
  enableVoiceInterview: boolean;
  enableResumeAnalysis: boolean;
  enableAssessment: boolean;
  enableOfferAnalysis: boolean;
  enableKanban: boolean;
  enableResumeOptimization: boolean;
  enableCrossDevice: boolean;
  enableDistributed: boolean;
  enableXiaoyiAgent: boolean;
  enableContinuation: boolean;
  enableNewFeatureX: boolean;
}

export class PushTopics {
  ALL_USERS: string = 'all_users';
  VIP_USERS: string = 'vip_users';
  NEW_USERS: string = 'new_users';
}

interface HMSConfig {
  ENABLE_HMS: boolean;
  PUSH_TOPICS: PushTopics;
}

interface NetworkConfig {
  timeout: number;
  maxRetries: number;
  retryInterval: number;
  checkUrl: string;
}

interface LoggingConfig {
  enabled: boolean;
  level: LogLevel;
  disableInProduction: boolean;
}

interface DataConfig {
  assessmentFile: string;
  interviewFile: string;
  knowledgeFile: string;
  batchSize: number;
  preloadCategories: boolean;
  lazyLoadContent: boolean;
  maxCachedItems: number;
  preloadPages: number;
}

interface AppConfig {
  environment: Environment;
  API_VERSION: string;
  featureFlags: FeatureFlags;
  defaultRetryCount: number;
  defaultRetryDelay: number;
  requestTimeout: number;
  STORAGE_TOKEN: string;
  STORAGE_USER_INFO: string;
  STORAGE_CHAT_HISTORY: string;
  STORAGE_SETTINGS: string;
  PAGE_SIZE: number;
  REQUEST_TIMEOUT: number;
  MAX_MESSAGE_LENGTH: number;
  VERIFY_CODE_COOLDOWN: number;
  ANIMATION_DURATION: number;
  appVersion: string;
  buildNumber: number;
  HMS: HMSConfig;
  network: NetworkConfig;
  logging: LoggingConfig;
  dataConfig: DataConfig;
}

// ============================================
// 主配置对象
// ============================================
export const Config = {
  // ============================================
  // 环境配置
  // ============================================
  // 当前环境（可根据构建类型自动切换）
  environment: Environment.DEVELOPMENT,

  // API 版本
  API_VERSION: 'v1',

  // ============================================
  // 功能开关
  // ============================================
  featureFlags: {
    enableAIChat: true,
    enableVoiceInterview: true,
    enableResumeAnalysis: true,
    enableAssessment: true,
    enableOfferAnalysis: true,
    enableKanban: true,
    enableResumeOptimization: true,
    enableCrossDevice: true,
    enableDistributed: true,
    enableXiaoyiAgent: true,
    enableContinuation: true,
    enableNewFeatureX: false,
  } as FeatureFlags,

  // ============================================
  // 重试配置
  // ============================================
  defaultRetryCount: 3,
  defaultRetryDelay: 1000,
  requestTimeout: 30000,

  // ============================================
  // Storage Keys
  // ============================================
  STORAGE_TOKEN: 'token',
  STORAGE_USER_INFO: 'userInfo',
  STORAGE_CHAT_HISTORY: 'chatHistory',
  STORAGE_SETTINGS: 'settings',

  // ============================================
  // 分页
  // ============================================
  PAGE_SIZE: 20,

  // ============================================
  // 超时时间（毫秒）
  // ============================================
  REQUEST_TIMEOUT: 30000,

  // ============================================
  // 消息最大长度
  // ============================================
  MAX_MESSAGE_LENGTH: 2000,

  // ============================================
  // 验证码倒计时
  // ============================================
  VERIFY_CODE_COOLDOWN: 60,

  // ============================================
  // 动画时长（毫秒）
  // ============================================
  ANIMATION_DURATION: 300,

  // ============================================
  // App 版本信息
  // ============================================
  appVersion: '1.0.0',
  buildNumber: 1,

  // ============================================
  // HMS Core 配置
  // ============================================
  HMS: {
    ENABLE_HMS: true,
    PUSH_TOPICS: new PushTopics()
  } as HMSConfig,

  // ============================================
  // 网络配置
  // ============================================
  network: {
    timeout: 30000,
    maxRetries: 3,
    retryInterval: 1000,
    checkUrl: 'https://www.baidu.com',
  } as NetworkConfig,

  // ============================================
  // 日志配置
  // ============================================
  logging: {
    // 是否启用日志
    enabled: true,
    // 日志级别
    level: LogLevel.INFO,
    // 是否在生产环境禁用日志
    disableInProduction: false,
  },

  // ============================================
  // 数据文件配置（懒加载优化）
  // ============================================
  // 注意：rawfile 中的大型 JSON 文件（>5MB）使用懒加载策略，
  // 启动时仅加载元数据（分类、统计），内容按需分批加载。
  // 主要文件：
  //   - data/assessment_questions.json  (~3MB, MBTI/Holland测评题)
  //   - data/interview_questions_v2.json (~5MB, 10000+面试题)
  //   - data/knowledge_articles_v2.json  (~4MB, 知识库文章)
  // 总计约 12MB，全量加载会导致启动阻塞 2-5 秒。
  dataConfig: {
    // 测评数据文件路径
    assessmentFile: 'data/assessment_questions.json',
    // 面试题数据文件路径
    interviewFile: 'data/interview_questions_v2.json',
    // 知识库文章文件路径
    knowledgeFile: 'data/knowledge_articles_v2.json',
    // 每批加载数量
    batchSize: 100,
    // 是否预加载分类信息（启动时）
    preloadCategories: true,
    // 是否启用内容懒加载
    lazyLoadContent: true,
    // 最大内存缓存条数
    maxCachedItems: 500,
    // 启动时预加载的页数
    preloadPages: 1,
  },
};

// ============================================
// API 端点类型定义
// ============================================
interface ApiEndpoints {
  LOGIN: string;
  SEND_CODE: string;
  LOGOUT: string;
  USER_INFO: string;
  UPDATE_USER: string;
  CHAT_SEND: string;
  CHAT_HISTORY: string;
  CHAT_SESSIONS: string;
  RESUME_UPLOAD: string;
  RESUME_ANALYZE: string;
  RESUME_RESULT: string;
  ASSESSMENT_LIST: string;
  ASSESSMENT_START: string;
  ASSESSMENT_SUBMIT: string;
  ASSESSMENT_RESULT: string;
  PAYMENT_PRODUCTS: string;
  PAYMENT_VERIFY: string;
  PUSH_REGISTER: string;
  PUSH_UNREGISTER: string;
  PUSH_MESSAGES: string;
  PUSH_READ: string;
  KNOWLEDGE_LIST: string;
  KNOWLEDGE_DETAIL: string;
  ANNOUNCEMENTS: string;
  ANNOUNCEMENTS_DETAIL: string;
}

// ============================================
// API 端点
// ============================================
export const API_ENDPOINTS: ApiEndpoints = {
  // 认证
  LOGIN: '/auth/login',
  SEND_CODE: '/auth/sendCode',
  LOGOUT: '/auth/logout',

  // 用户
  USER_INFO: '/user/info',
  UPDATE_USER: '/user/update',

  // 聊天
  CHAT_SEND: '/chat/send',
  CHAT_HISTORY: '/chat/history',
  CHAT_SESSIONS: '/chat/sessions',

  // 简历
  RESUME_UPLOAD: '/resume/upload',
  RESUME_ANALYZE: '/resume/analyze',
  RESUME_RESULT: '/resume/result',

  // 测评
  ASSESSMENT_LIST: '/assessment/list',
  ASSESSMENT_START: '/assessment/start',
  ASSESSMENT_SUBMIT: '/assessment/submit',
  ASSESSMENT_RESULT: '/assessment/result',

  // 支付
  PAYMENT_PRODUCTS: '/payment/products',
  PAYMENT_VERIFY: '/payment/huawei/verify',

  // 推送
  PUSH_REGISTER: '/push/register',
  PUSH_UNREGISTER: '/push/unregister',
  PUSH_MESSAGES: '/push/messages',
  PUSH_READ: '/push/read',

  // 知识库
  KNOWLEDGE_LIST: '/knowledge/list',
  KNOWLEDGE_DETAIL: '/knowledge/detail',

  // 公告
  ANNOUNCEMENTS: '/announcements',
  ANNOUNCEMENTS_DETAIL: '/announcements/detail',
};

// ============================================
// Tab 配置类型定义
// ============================================
interface TabItem {
  index: number;
  title: string;
  icon: string;
}

interface TabConfig {
  CHAT: TabItem;
  RESUME: TabItem;
  ASSESSMENT: TabItem;
  KNOWLEDGE: TabItem;
  PROFILE: TabItem;
}

// ============================================
// Tab 配置
// ============================================
export const TAB_CONFIG: TabConfig = {
  CHAT: { index: 0, title: '聊天', icon: 'ic_chat' },
  RESUME: { index: 1, title: '简历', icon: 'ic_resume' },
  ASSESSMENT: { index: 2, title: '测评', icon: 'ic_assessment' },
  KNOWLEDGE: { index: 3, title: '知识库', icon: 'ic_knowledge' },
  PROFILE: { index: 4, title: '我的', icon: 'ic_profile' },
};

// ============================================
// 会员配置类型定义
// ============================================
interface VipItem {
  productId: string;
  name: string;
  duration: number;
  price: number;
}

interface VipConfig {
  MONTHLY: VipItem;
  QUARTERLY: VipItem;
  YEARLY: VipItem;
}

// ============================================
// 会员配置
// ============================================
export const VIP_CONFIG: VipConfig = {
  MONTHLY: {
    productId: 'vip_monthly',
    name: '月度会员',
    duration: 30,
    price: 19.9,
  },
  QUARTERLY: {
    productId: 'vip_quarterly',
    name: '季度会员',
    duration: 90,
    price: 49.9,
  },
  YEARLY: {
    productId: 'vip_yearly',
    name: '年度会员',
    duration: 365,
    price: 168.0,
  },
};

// ============================================
// 环境特定的常量类型定义
// ============================================
interface EnvConfig {
  apiBaseUrl: string;
  enableDebugTools: boolean;
  enableMockData: boolean;
  logLevel: LogLevel;
}

class EnvironmentConfigClass {
  private configs: Map<Environment, EnvConfig> = new Map<Environment, EnvConfig>([
    [Environment.DEVELOPMENT, {
      apiBaseUrl: 'https://dev-api.buddyjob.com',
      enableDebugTools: true,
      enableMockData: true,
      logLevel: LogLevel.DEBUG,
    } as EnvConfig],
    [Environment.TESTING, {
      apiBaseUrl: 'https://test-api.buddyjob.com',
      enableDebugTools: true,
      enableMockData: false,
      logLevel: LogLevel.INFO,
    } as EnvConfig],
    [Environment.PRODUCTION, {
      apiBaseUrl: 'https://api.buddyjob.com',
      enableDebugTools: false,
      enableMockData: false,
      logLevel: LogLevel.WARN,
    } as EnvConfig],
  ]);

  get(env: Environment): EnvConfig | undefined {
    return this.configs.get(env);
  }
}

// ============================================
// 环境特定的常量
// ============================================
export const EnvironmentConfig = new EnvironmentConfigClass();

// ============================================
// 工具函数
// ============================================

/**
 * 获取当前环境的配置
 */
export function getEnvironmentConfig(): EnvConfig | undefined {
  return EnvironmentConfig.get(Config.environment);
}

/**
 * 检查是否为开发环境
 */
export function isDevelopment(): boolean {
  return Config.environment === Environment.DEVELOPMENT;
}

/**
 * 检查是否为测试环境
 */
export function isTesting(): boolean {
  return Config.environment === Environment.TESTING;
}

/**
 * 检查是否为生产环境
 */
export function isProduction(): boolean {
  return Config.environment === Environment.PRODUCTION;
}

/**
 * 获取功能开关值
 */
export function isFeatureEnabled(featureKey: keyof FeatureFlags): boolean {
  const flags: FeatureFlags = Config.featureFlags;
  switch (featureKey) {
    case 'enableAIChat':
      return flags.enableAIChat;
    case 'enableVoiceInterview':
      return flags.enableVoiceInterview;
    case 'enableResumeAnalysis':
      return flags.enableResumeAnalysis;
    case 'enableAssessment':
      return flags.enableAssessment;
    case 'enableOfferAnalysis':
      return flags.enableOfferAnalysis;
    case 'enableKanban':
      return flags.enableKanban;
    case 'enableResumeOptimization':
      return flags.enableResumeOptimization;
    case 'enableCrossDevice':
      return flags.enableCrossDevice;
    case 'enableDistributed':
      return flags.enableDistributed;
    case 'enableXiaoyiAgent':
      return flags.enableXiaoyiAgent;
    case 'enableContinuation':
      return flags.enableContinuation;
    case 'enableNewFeatureX':
      return flags.enableNewFeatureX;
    default:
      return false;
  }
}
