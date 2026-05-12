/**
 * 数据模型 - Offer 分析模型
 *
 * 提供 Offer 输入、分析结果、维度评分等数据结构定义，
 * 以及福利类型枚举和默认福利常量。
 */

// ============================================
// 福利类型枚举
// ============================================
export enum BenefitType {
  /** 补充医疗保险 */
  SUPPLEMENTAL_MEDICAL = 'SUPPLEMENTAL_MEDICAL',
  /** 额外年假 */
  EXTRA_LEAVE = 'EXTRA_LEAVE',
  /** 餐补 */
  MEAL_ALLOWANCE = 'MEAL_ALLOWANCE',
  /** 交通补贴 */
  TRANSPORT_ALLOWANCE = 'TRANSPORT_ALLOWANCE',
  /** 住房补贴 */
  HOUSING_ALLOWANCE = 'HOUSING_ALLOWANCE',
  /** 年度体检 */
  HEALTH_CHECKUP = 'HEALTH_CHECKUP',
  /** 其他 */
  OTHER = 'OTHER',
}

/** 福利类型中文标签映射 */
export const BenefitTypeLabels: Record<BenefitType, string> = {
  [BenefitType.SUPPLEMENTAL_MEDICAL]: '补充医疗',
  [BenefitType.EXTRA_LEAVE]: '额外年假',
  [BenefitType.MEAL_ALLOWANCE]: '餐补',
  [BenefitType.TRANSPORT_ALLOWANCE]: '交通补贴',
  [BenefitType.HOUSING_ALLOWANCE]: '住房补贴',
  [BenefitType.HEALTH_CHECKUP]: '年度体检',
  [BenefitType.OTHER]: '其他',
};

// ============================================
// 默认福利常量
// ============================================
export const DEFAULT_BENEFITS: BenefitType[] = [
  BenefitType.SUPPLEMENTAL_MEDICAL,
  BenefitType.MEAL_ALLOWANCE,
  BenefitType.TRANSPORT_ALLOWANCE,
  BenefitType.HEALTH_CHECKUP,
];

// ============================================
// Offer 输入接口
// ============================================
export interface OfferInput {
  /** 公司名称 */
  company: string;
  /** 职位名称 */
  position: string;
  /** 月薪（元） */
  monthlySalary: number;
  /** 年终奖（月数） */
  annualBonus: number;
  /** 股权/期权描述 */
  equity: string;
  /** 五险一金比例（0-1） */
  socialInsurance: number;
  /** 补充福利数组 */
  benefits: BenefitType[];
  /** 每周工作时长（小时） */
  workHours: number;
  /** 加班频率 */
  overtimeFrequency: OvertimeFrequency;
  /** 通勤时间（分钟） */
  commuteMinutes: number;
  /** 备注 */
  note: string;
}

/** 加班频率枚举 */
export type OvertimeFrequency = 'never' | 'rarely' | 'sometimes' | 'often' | 'always';

/** 加班频率中文标签映射 */
export const OvertimeFrequencyLabels: Record<OvertimeFrequency, string> = {
  never: '几乎不加班',
  rarely: '偶尔加班',
  sometimes: '有时加班',
  often: '经常加班',
  always: '频繁加班',
};

/** 创建空白 Offer 输入 */
export function createEmptyOfferInput(): OfferInput {
  return {
    company: '',
    position: '',
    monthlySalary: 0,
    annualBonus: 0,
    equity: '',
    socialInsurance: 0.2,
    benefits: [...DEFAULT_BENEFITS],
    workHours: 40,
    overtimeFrequency: 'sometimes',
    commuteMinutes: 30,
    note: '',
  };
}

// ============================================
// 维度评分接口
// ============================================
export interface DimensionScore {
  /** 维度名称 */
  name: string;
  /** 评分 0-100 */
  score: number;
  /** 评分标签（如：优秀、良好、一般、较差） */
  label: string;
  /** 维度描述 */
  description: string;
}

// ============================================
// 市场对比数据
// ============================================
export interface MarketComparison {
  /** 薪资百分位（如 75 表示超过 75% 的市场水平） */
  salaryPercentile: number;
  /** 市场平均月薪 */
  marketAvgSalary: number;
  /** 市场薪资范围 */
  salaryRange: {
    low: number;
    median: number;
    high: number;
  };
  /** 对比描述 */
  description: string;
}

// ============================================
// Offer 分析结果接口
// ============================================
export interface OfferAnalysisResult {
  /** 综合评分 0-100 */
  overallScore: number;
  /** 各维度评分 */
  dimensions: DimensionScore[];
  /** AI 建议 */
  suggestions: string[];
  /** 谈判建议 */
  negotiationTips: string[];
  /** 市场对比 */
  marketComparison: MarketComparison;
}

// ============================================
// Offer 对比结果接口
// ============================================
export interface ComparisonResult {
  /** 对比的 Offer 列表 */
  offers: ComparisonOfferItem[];
  /** 推荐的 Offer 索引 */
  recommendedIndex: number;
  /** 对比总结 */
  summary: string;
  /** 各维度对比 */
  dimensionComparison: DimensionComparison[];
}

export interface ComparisonOfferItem {
  /** 公司名称 */
  company: string;
  /** 职位名称 */
  position: string;
  /** 综合评分 */
  overallScore: number;
  /** 优势 */
  advantages: string[];
  /** 劣势 */
  disadvantages: string[];
}

export interface DimensionComparison {
  /** 维度名称 */
  name: string;
  /** 各 Offer 在该维度的得分 */
  scores: number[];
  /** 说明 */
  description: string;
}

// ============================================
// 场景模板（新增）
// ============================================
export interface ScenarioTemplate {
  id: string;
  title: string;
  description: string;
  icon: string;
  presetOffers: Partial<OfferInput>[];
}

export const SCENARIO_TEMPLATES: ScenarioTemplate[] = [
  {
    id: 'salary_vs_balance',
    title: '高薪 vs 事少',
    description: '高薪资但加班多，还是薪资一般但工作生活平衡？',
    icon: 'ic_balance',
    presetOffers: [
      { company: '大厂A', position: '高级工程师', monthlySalary: 35000, annualBonus: 4, workHours: 50, overtimeFrequency: 'often', commuteMinutes: 45 },
      { company: '外企B', position: '工程师', monthlySalary: 22000, annualBonus: 2, workHours: 38, overtimeFrequency: 'rarely', commuteMinutes: 20 },
    ]
  },
  {
    id: 'startup_vs_stable',
    title: '创业公司 vs 国企',
    description: '高成长潜力还是稳定保障？',
    icon: 'ic_growth',
    presetOffers: [
      { company: '创业公司', position: '技术负责人', monthlySalary: 28000, annualBonus: 6, equity: '0.5%期权，4年归属', workHours: 55, overtimeFrequency: 'always', commuteMinutes: 30 },
      { company: '国企', position: '技术岗', monthlySalary: 15000, annualBonus: 3, socialInsurance: 0.3, workHours: 35, overtimeFrequency: 'never', commuteMinutes: 40, benefits: [BenefitType.SUPPLEMENTAL_MEDICAL, BenefitType.EXTRA_LEAVE, BenefitType.MEAL_ALLOWANCE, BenefitType.TRANSPORT_ALLOWANCE, BenefitType.HOUSING_ALLOWANCE, BenefitType.HEALTH_CHECKUP] },
    ]
  },
  {
    id: 'city_compare',
    title: '跨城市选择',
    description: '不同城市的 Offer 怎么选？',
    icon: 'ic_city',
    presetOffers: [
      { company: '北京公司', position: '产品经理', monthlySalary: 30000, annualBonus: 3, commuteMinutes: 60 },
      { company: '成都公司', position: '产品经理', monthlySalary: 18000, annualBonus: 2, commuteMinutes: 15 },
    ]
  },
  {
    id: 'custom',
    title: '自由录入',
    description: '手动输入 Offer 信息进行分析',
    icon: 'ic_edit',
    presetOffers: []
  }
];

// ============================================
// 权重配置（新增）
// ============================================
export interface WeightConfig {
  salary: number;    // 薪资待遇权重 0-100
  balance: number;   // 工作生活平衡权重
  benefit: number;   // 福利保障权重
  commute: number;   // 通勤体验权重
  growth: number;    // 发展潜力权重
}

export const DEFAULT_WEIGHTS: WeightConfig = {
  salary: 35,
  balance: 25,
  benefit: 15,
  commute: 10,
  growth: 15,
};

export const WEIGHT_LABELS: Record<keyof WeightConfig, { name: string; description: string }> = {
  salary: { name: '薪资待遇', description: '月薪、年终奖、股权等' },
  balance: { name: '工作生活平衡', description: '工时、加班频率' },
  benefit: { name: '福利保障', description: '五险一金、补充福利' },
  commute: { name: '通勤体验', description: '通勤时间' },
  growth: { name: '发展潜力', description: '公司前景、成长空间' },
};

// ============================================
// 对话消息（新增）
// ============================================
export interface OfferChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  type: 'text' | 'card' | 'suggestion' | 'action';
  actions?: OfferChatAction[];
}

export interface OfferChatAction {
  label: string;
  action: string;
  data?: Record<string, Object>;
}
