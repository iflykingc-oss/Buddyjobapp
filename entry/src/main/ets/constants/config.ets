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
// 主配置对象
// ============================================
export const Config = {
  // ============================================
  // 环境配置
  // ============================================
  // 当前环境（可根据构建类型自动切换）
  environment: Environment.DEVELOPMENT,

  // 获取 API 基础 URL（根据环境自动切换）
  get API_BASE_URL(): string {
    switch (this.environment) {
      case Environment.DEVELOPMENT:
        return 'https://dev-api.buddyjob.com';
      case Environment.TESTING:
        return 'https://test-api.buddyjob.com';
      case Environment.PRODUCTION:
        return 'https://api.buddyjob.com';
      default:
        return 'https://api.buddyjob.com';
    }
  },

  // API 版本
  API_VERSION: 'v1',

  // ============================================
  // 功能开关
  // ============================================
  featureFlags: {
    // AI 对话
    enableAIChat: true,
    // 语音面试
    enableVoiceInterview: true,
    // 简历分析
    enableResumeAnalysis: true,
    // 测评功能
    enableAssessment: true,
    // offer 分析
    enableOfferAnalysis: true,
    // 看板功能
    enableKanban: true,
    // 简历优化
    enableResumeOptimization: true,
    // 跨设备面试
    enableCrossDevice: true,
    // 分布式功能
    enableDistributed: true,
    // 小艺助手
    enableXiaoyiAgent: true,
    // 接续功能
    enableContinuation: true,
    // 新功能 X（灰度测试用）
    enableNewFeatureX: false,
  },

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
    // 是否启用 HMS Core
    ENABLE_HMS: true,
    // 推送主题
    PUSH_TOPICS: {
      ALL_USERS: 'all_users',
      VIP_USERS: 'vip_users',
      NEW_USERS: 'new_users',
    },
  },

  // ============================================
  // 网络配置
  // ============================================
  network: {
    // 网络超时时间（毫秒）
    timeout: 30000,
    // 最大重试次数
    maxRetries: 3,
    // 重试间隔（毫秒）
    retryInterval: 1000,
    // 网络检测 URL
    checkUrl: 'https://www.baidu.com',
  },

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
} as const;

// ============================================
// API 端点
// ============================================
export const API_ENDPOINTS = {
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
} as const;

// ============================================
// Tab 配置
// ============================================
export const TAB_CONFIG = {
  CHAT: { index: 0, title: '聊天', icon: 'ic_chat' },
  RESUME: { index: 1, title: '简历', icon: 'ic_resume' },
  ASSESSMENT: { index: 2, title: '测评', icon: 'ic_assessment' },
  KNOWLEDGE: { index: 3, title: '知识库', icon: 'ic_knowledge' },
  PROFILE: { index: 4, title: '我的', icon: 'ic_profile' },
} as const;

// ============================================
// 会员配置
// ============================================
export const VIP_CONFIG = {
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
} as const;

// ============================================
// 环境特定的常量
// ============================================
export const EnvironmentConfig = {
  // 开发环境
  [Environment.DEVELOPMENT]: {
    apiBaseUrl: 'https://dev-api.buddyjob.com',
    enableDebugTools: true,
    enableMockData: true,
    logLevel: LogLevel.DEBUG,
  },
  // 测试环境
  [Environment.TESTING]: {
    apiBaseUrl: 'https://test-api.buddyjob.com',
    enableDebugTools: true,
    enableMockData: false,
    logLevel: LogLevel.INFO,
  },
  // 生产环境
  [Environment.PRODUCTION]: {
    apiBaseUrl: 'https://api.buddyjob.com',
    enableDebugTools: false,
    enableMockData: false,
    logLevel: LogLevel.WARN,
  },
} as const;

// ============================================
// 工具函数
// ============================================

/**
 * 获取当前环境的配置
 */
export function getEnvironmentConfig() {
  return EnvironmentConfig[Config.environment];
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
export function isFeatureEnabled(featureKey: keyof typeof Config.featureFlags): boolean {
  return Config.featureFlags[featureKey] ?? false;
}
