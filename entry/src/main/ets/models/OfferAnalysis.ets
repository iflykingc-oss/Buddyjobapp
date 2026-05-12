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
