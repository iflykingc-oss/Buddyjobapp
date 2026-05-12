// 配置常量
export const Config = {
  // API 配置
  API_BASE_URL: 'https://api.buddyjob.com',
  API_VERSION: 'v1',

  // Storage Keys
  STORAGE_TOKEN: 'token',
  STORAGE_USER_INFO: 'userInfo',
  STORAGE_CHAT_HISTORY: 'chatHistory',
  STORAGE_SETTINGS: 'settings',

  // 分页
  PAGE_SIZE: 20,

  // 超时时间（毫秒）
  REQUEST_TIMEOUT: 30000,

  // 消息最大长度
  MAX_MESSAGE_LENGTH: 2000,

  // 验证码倒计时
  VERIFY_CODE_COOLDOWN: 60,

  // 动画时长
  ANIMATION_DURATION: 300,

  // HMS Core 配置
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
} as const;

// API 端点
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

// Tab 配置
export const TAB_CONFIG = {
  CHAT: { index: 0, title: '聊天', icon: 'ic_chat' },
  RESUME: { index: 1, title: '简历', icon: 'ic_resume' },
  ASSESSMENT: { index: 2, title: '测评', icon: 'ic_assessment' },
  KNOWLEDGE: { index: 3, title: '知识库', icon: 'ic_knowledge' },
  PROFILE: { index: 4, title: '我的', icon: 'ic_profile' },
} as const;

// 会员配置
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
