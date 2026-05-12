/**
 * 反馈服务 - 处理用户反馈和常见问题
 */

// 反馈类型
export enum FeedbackType {
  ISSUE = 'issue',
  SUGGESTION = 'suggestion',
  OTHER = 'other'
}

// 反馈类型显示文本
export const FeedbackTypeLabels: Record<FeedbackType, string> = {
  [FeedbackType.ISSUE]: '问题反馈',
  [FeedbackType.SUGGESTION]: '功能建议',
  [FeedbackType.OTHER]: '其他'
};

// 问题分类
export enum FAQCategory {
  ACCOUNT = 'account',
  RESUME = 'resume',
  ASSESSMENT = 'assessment',
  PAYMENT = 'payment',
  OTHER = 'other'
}

// 问题分类显示文本
export const FAQCategoryLabels: Record<FAQCategory, string> = {
  [FAQCategory.ACCOUNT]: '账号相关',
  [FAQCategory.RESUME]: '简历相关',
  [FAQCategory.ASSESSMENT]: '测评相关',
  [FAQCategory.PAYMENT]: '支付相关',
  [FAQCategory.OTHER]: '其他问题'
};

// 反馈数据接口
export interface FeedbackData {
  id?: string;
  type: FeedbackType;
  title: string;
  content: string;
  contact?: string;
  createTime?: number;
  status?: 'pending' | 'processing' | 'resolved';
}

// FAQ 数据接口
export interface FAQItem {
  id: string;
  category: FAQCategory;
  question: string;
  answer: string;
}

// 客服联系方式
export const ContactInfo = {
  email: 'support@buddyjob.com',
  phone: '400-888-9999',
  workHours: '周一至周五 9:00-18:00'
} as const;

// 本地存储键名
const STORAGE_KEYS = {
  FEEDBACKS: 'buddyjob_feedbacks',
  FAQS: 'buddyjob_faqs'
} as const;

/**
 * 提交反馈
 * @param data 反馈数据
 * @returns 是否提交成功
 */
export async function submitFeedback(data: FeedbackData): Promise<boolean> {
  try {
    const feedback: FeedbackData = {
      ...data,
      id: generateId(),
      createTime: Date.now(),
      status: 'pending'
    };

    // 获取已有反馈列表
    const existingFeedbacks = await getStoredFeedbacks();
    existingFeedbacks.push(feedback);

    // 保存到本地存储
    AppStorage.setOrCreate(STORAGE_KEYS.FEEDBACKS, JSON.stringify(existingFeedbacks));

    // TODO: 这里可以添加实际的后端 API 调用
    // await ApiService.post('/feedback', feedback);

    console.info('Feedback submitted successfully:', feedback.id);
    return true;
  } catch (error) {
    console.error('Failed to submit feedback:', error);
    return false;
  }
}

/**
 * 获取常见问题列表
 * @param category 可选的分类筛选
 * @returns FAQ 列表
 */
export async function getFAQs(category?: FAQCategory): Promise<FAQItem[]> {
  try {
    // 首先尝试从本地存储获取
    let faqs = await getStoredFAQs();

    // 如果没有数据，使用默认数据
    if (faqs.length === 0) {
      faqs = getDefaultFAQs();
      // 保存默认数据到本地
      AppStorage.setOrCreate(STORAGE_KEYS.FAQS, JSON.stringify(faqs));
    }

    // 如果指定了分类，进行筛选
    if (category) {
      return faqs.filter(item => item.category === category);
    }

    return faqs;
  } catch (error) {
    console.error('Failed to get FAQs:', error);
    return getDefaultFAQs();
  }
}

/**
 * 获取存储的反馈列表
 */
async function getStoredFeedbacks(): Promise<FeedbackData[]> {
  try {
    const data = AppStorage.get<string>(STORAGE_KEYS.FEEDBACKS);
    if (data) {
      return JSON.parse(data);
    }
  } catch (error) {
    console.error('Failed to parse stored feedbacks:', error);
  }
  return [];
}

/**
 * 获取存储的 FAQ 列表
 */
async function getStoredFAQs(): Promise<FAQItem[]> {
  try {
    const data = AppStorage.get<string>(STORAGE_KEYS.FAQS);
    if (data) {
      return JSON.parse(data);
    }
  } catch (error) {
    console.error('Failed to parse stored FAQs:', error);
  }
  return [];
}

/**
 * 生成唯一 ID
 */
function generateId(): string {
  return 'fb_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

/**
 * 获取默认 FAQ 数据
 */
function getDefaultFAQs(): FAQItem[] {
  return [
    // 账号相关
    {
      id: 'faq_001',
      category: FAQCategory.ACCOUNT,
      question: '如何修改绑定的手机号？',
      answer: '进入"我的"-"设置"-"账号与安全"-"手机号"，按照提示完成手机号更换。更换前需要验证原手机号。'
    },
    {
      id: 'faq_002',
      category: FAQCategory.ACCOUNT,
      question: '忘记密码怎么办？',
      answer: '在登录页面点击"忘记密码"，通过绑定的手机号接收验证码，验证通过后即可重置密码。'
    },
    {
      id: 'faq_003',
      category: FAQCategory.ACCOUNT,
      question: '如何注销账号？',
      answer: '进入"我的"-"设置"-"账号与安全"-"注销账号"，按照提示完成注销。注销后数据将无法恢复，请谨慎操作。'
    },
    // 简历相关
    {
      id: 'faq_004',
      category: FAQCategory.RESUME,
      question: '如何创建简历？',
      answer: '点击底部"简历"标签，进入简历页面后点击"创建简历"，按照模板填写个人信息、教育背景、工作经历等内容。'
    },
    {
      id: 'faq_005',
      category: FAQCategory.RESUME,
      question: '简历可以导出吗？',
      answer: '可以。在简历详情页点击右上角"更多"按钮，选择"导出简历"，支持导出为 PDF 或 Word 格式。'
    },
    {
      id: 'faq_006',
      category: FAQCategory.RESUME,
      question: 'AI简历分析如何使用？',
      answer: '创建简历后，点击"AI分析"按钮，系统将自动分析您的简历内容，给出优化建议和岗位匹配度评分。'
    },
    // 测评相关
    {
      id: 'faq_007',
      category: FAQCategory.ASSESSMENT,
      question: '职业测评有哪些类型？',
      answer: '我们提供多种职业测评：MBTI性格测试、霍兰德职业兴趣测试、职业能力评估、岗位匹配度测试等。'
    },
    {
      id: 'faq_008',
      category: FAQCategory.ASSESSMENT,
      question: '测评结果准确吗？',
      answer: '我们的测评基于专业的心理学和职业发展理论，结果仅供参考。建议结合个人实际情况综合考虑。'
    },
    {
      id: 'faq_009',
      category: FAQCategory.ASSESSMENT,
      question: '可以免费测评吗？',
      answer: '部分基础测评可免费使用，高级测评和详细报告需要开通VIP会员。新用户首次使用可享受一次免费高级测评。'
    },
    // 支付相关
    {
      id: 'faq_010',
      category: FAQCategory.PAYMENT,
      question: 'VIP会员有哪些权益？',
      answer: 'VIP会员享受：无限次简历分析、无限次岗位测评、AI对话优先响应、专属职业规划报告、简历AI智能润色等权益。'
    },
    {
      id: 'faq_011',
      category: FAQCategory.PAYMENT,
      question: '如何开通VIP会员？',
      answer: '进入"我的"页面，点击"开通VIP"按钮，选择套餐后完成支付即可。支持支付宝、微信支付、华为支付等多种方式。'
    },
    {
      id: 'faq_012',
      category: FAQCategory.PAYMENT,
      question: '支付失败怎么办？',
      answer: '请检查网络连接和支付方式余额。如果问题持续，请联系客服：' + ContactInfo.phone + ' 或发送邮件至 ' + ContactInfo.email
    },
    // 其他问题
    {
      id: 'faq_013',
      category: FAQCategory.OTHER,
      question: '如何联系客服？',
      answer: '您可以通过以下方式联系我们：\n客服电话：' + ContactInfo.phone + '\n客服邮箱：' + ContactInfo.email + '\n工作时间：' + ContactInfo.workHours
    },
    {
      id: 'faq_014',
      category: FAQCategory.OTHER,
      question: 'APP闪退/卡顿怎么办？',
      answer: '请尝试以下方法：\n1. 清理APP缓存\n2. 重启APP\n3. 检查是否有新版本更新\n4. 如问题持续，请通过"帮助与反馈"提交问题详情'
    },
    {
      id: 'faq_015',
      category: FAQCategory.OTHER,
      question: '如何保护个人隐私？',
      answer: '我们严格保护用户隐私，所有数据传输采用加密技术。您可以在"设置"-"隐私政策"中查看详细说明，或在"设置"中管理个人数据授权。'
    }
  ];
}

/**
 * 获取用户反馈历史
 * @returns 反馈历史列表
 */
export async function getFeedbackHistory(): Promise<FeedbackData[]> {
  return await getStoredFeedbacks();
}

/**
 * 清除所有本地反馈数据（调试用）
 */
export async function clearAllFeedbacks(): Promise<void> {
  AppStorage.setOrCreate(STORAGE_KEYS.FEEDBACKS, JSON.stringify([]));
}
