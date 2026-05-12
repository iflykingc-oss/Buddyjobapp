/**
 * Offer 分析服务
 *
 * 负责调用后端 API 进行 Offer 分析和对比，
 * 包含网络请求失败时的模拟数据 fallback。
 */

import { ApiService } from './ApiService';
import {
  OfferInput,
  OfferAnalysisResult,
  ComparisonResult,
  DimensionScore,
  MarketComparison,
  ComparisonOfferItem,
  DimensionComparison,
  WeightConfig,
  DEFAULT_WEIGHTS,
} from '../models/OfferAnalysis';

const OFFER_ANALYZE_URL = '/offer/analyze';
const OFFER_COMPARE_URL = '/offer/compare';

export class OfferAnalysisService {
  private static instance: OfferAnalysisService;
  private apiService: ApiService;

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): OfferAnalysisService {
    if (!OfferAnalysisService.instance) {
      OfferAnalysisService.instance = new OfferAnalysisService();
    }
    return OfferAnalysisService.instance;
  }

  /**
   * 分析单个 Offer
   */
  async analyzeOffer(input: OfferInput): Promise<OfferAnalysisResult> {
    try {
      const response = await this.apiService.post<OfferAnalysisResult>(
        OFFER_ANALYZE_URL,
        input as unknown as Record<string, Object>
      );

      if (response.success && response.data) {
        return response.data;
      }

      // 后端返回失败，使用模拟数据
      console.warn('[OfferAnalysisService] API failed, using mock data:', response.error);
      return this.generateMockAnalysisResult(input);
    } catch (error) {
      console.error('[OfferAnalysisService] analyzeOffer error:', error);
      return this.generateMockAnalysisResult(input);
    }
  }

  /**
   * 对比多个 Offer
   */
  async compareOffers(offers: OfferInput[]): Promise<ComparisonResult> {
    if (offers.length < 2) {
      throw new Error('至少需要两个 Offer 才能进行对比');
    }

    try {
      const response = await this.apiService.post<ComparisonResult>(
        OFFER_COMPARE_URL,
        { offers } as unknown as Record<string, Object>
      );

      if (response.success && response.data) {
        return response.data;
      }

      console.warn('[OfferAnalysisService] Compare API failed, using mock data:', response.error);
      return this.generateMockComparisonResult(offers);
    } catch (error) {
      console.error('[OfferAnalysisService] compareOffers error:', error);
      return this.generateMockComparisonResult(offers);
    }
  }

  /**
   * 带自定义权重的分析
   */
  async analyzeWithWeights(input: OfferInput, weights: WeightConfig): Promise<OfferAnalysisResult> {
    try {
      const response = await this.apiService.post<OfferAnalysisResult>(
        OFFER_ANALYZE_URL,
        { ...input, weights } as unknown as Record<string, Object>
      );
      if (response.success && response.data) {
        return response.data;
      }
      return this.generateMockAnalysisResult(input, weights);
    } catch (error) {
      console.error('[OfferAnalysisService] analyzeWithWeights error:', error);
      return this.generateMockAnalysisResult(input, weights);
    }
  }

  /**
   * What-if 分析：修改单个参数后的评分变化
   */
  whatIfAnalysis(
    baseOffer: OfferInput,
    field: keyof OfferInput,
    newValue: number | string,
    weights?: WeightConfig
  ): { field: string; oldValue: number | string; newValue: number | string; scoreChange: number; newScore: number } {
    const w = weights || DEFAULT_WEIGHTS;
    const baseResult = this.generateMockAnalysisResult(baseOffer, w);
    const modifiedOffer = { ...baseOffer, [field]: newValue };
    const newResult = this.generateMockAnalysisResult(modifiedOffer, w);
    
    return {
      field,
      oldValue: baseOffer[field] as number | string,
      newValue,
      scoreChange: newResult.overallScore - baseResult.overallScore,
      newScore: newResult.overallScore,
    };
  }

  // ============================================
  // 模拟数据生成
  // ============================================

  /**
   * 生成模拟分析结果
   */
  private generateMockAnalysisResult(input: OfferInput, weights?: WeightConfig): OfferAnalysisResult {
    const w = weights || DEFAULT_WEIGHTS;
    const totalWeight = w.salary + w.balance + w.benefit + w.commute + w.growth;
    
    const salaryScore = this.calcSalaryScore(input);
    const balanceScore = this.calcBalanceScore(input);
    const benefitScore = this.calcBenefitScore(input);
    const commuteScore = this.calcCommuteScore(input);
    const growthScore = this.calcGrowthScore(input);

    const overallScore = Math.round(
      (salaryScore * w.salary + balanceScore * w.balance + benefitScore * w.benefit +
       commuteScore * w.commute + growthScore * w.growth) / totalWeight
    );

    const dimensions: DimensionScore[] = [
      { name: '薪资待遇', score: salaryScore, label: this.getScoreLabel(salaryScore), description: '综合月薪、年终奖、股权等收入因素' },
      { name: '工作生活平衡', score: balanceScore, label: this.getScoreLabel(balanceScore), description: '工作时长与加班频率评估' },
      { name: '福利保障', score: benefitScore, label: this.getScoreLabel(benefitScore), description: '五险一金、补充福利等保障水平' },
      { name: '通勤体验', score: commuteScore, label: this.getScoreLabel(commuteScore), description: '通勤时间对生活质量的影响' },
      { name: '发展潜力', score: growthScore, label: this.getScoreLabel(growthScore), description: '公司规模、行业前景等成长空间' },
    ];

    const suggestions = this.generateSuggestions(input, dimensions);
    const negotiationTips = this.generateNegotiationTips(input, dimensions);
    const marketComparison = this.generateMarketComparison(input);

    return {
      overallScore,
      dimensions,
      suggestions,
      negotiationTips,
      marketComparison,
    };
  }

  private calcSalaryScore(input: OfferInput): number {
    let score = 50;
    // 月薪基准：以 15000 为中位数
    const salaryNorm = Math.min(input.monthlySalary / 30000, 1.5);
    score += salaryNorm * 25;
    // 年终奖加分
    score += Math.min(input.annualBonus * 3, 15);
    // 股权加分
    if (input.equity && input.equity.length > 0) {
      score += 5;
    }
    return Math.round(Math.min(Math.max(score, 0), 100));
  }

  private calcBalanceScore(input: OfferInput): number {
    let score = 80;
    // 加班扣分
    const overtimeMap: Record<string, number> = { never: 0, rarely: -5, sometimes: -15, often: -30, always: -45 };
    score += overtimeMap[input.overtimeFrequency] || -15;
    // 工作时长扣分（超过 40 小时部分）
    if (input.workHours > 40) {
      score -= (input.workHours - 40) * 1.5;
    }
    return Math.round(Math.min(Math.max(score, 0), 100));
  }

  private calcBenefitScore(input: OfferInput): number {
    let score = 40;
    // 五险一金比例（0.2 为基准）
    score += Math.min(input.socialInsurance * 150, 30);
    // 福利数量加分
    score += Math.min(input.benefits.length * 5, 30);
    return Math.round(Math.min(Math.max(score, 0), 100));
  }

  private calcCommuteScore(input: OfferInput): number {
    if (input.commuteMinutes <= 15) return 95;
    if (input.commuteMinutes <= 30) return 80;
    if (input.commuteMinutes <= 45) return 65;
    if (input.commuteMinutes <= 60) return 50;
    if (input.commuteMinutes <= 90) return 35;
    return 20;
  }

  private calcGrowthScore(input: OfferInput): number {
    // 模拟：基于公司名称长度和职位做简单随机
    let score = 55;
    if (input.equity && input.equity.length > 0) score += 15;
    if (input.note && input.note.length > 10) score += 5;
    // 加入一些基于输入的确定性变化
    score += (input.company.length % 5) * 3;
    return Math.round(Math.min(Math.max(score, 0), 100));
  }

  private getScoreLabel(score: number): string {
    if (score >= 85) return '优秀';
    if (score >= 70) return '良好';
    if (score >= 55) return '一般';
    if (score >= 40) return '较差';
    return '很差';
  }

  private generateSuggestions(input: OfferInput, dimensions: DimensionScore[]): string[] {
    const suggestions: string[] = [];

    const balanceDim = dimensions.find(d => d.name === '工作生活平衡');
    if (balanceDim && balanceDim.score < 60) {
      suggestions.push('当前 Offer 的工作强度较高，建议关注长期身心健康，考虑是否与个人生活目标匹配。');
    }

    const salaryDim = dimensions.find(d => d.name === '薪资待遇');
    if (salaryDim && salaryDim.score < 55) {
      suggestions.push('薪资水平低于市场平均，建议在谈判中争取更高的月薪或年终奖。');
    }

    const commuteDim = dimensions.find(d => d.name === '通勤体验');
    if (commuteDim && commuteDim.score < 50) {
      suggestions.push('通勤时间较长，建议考虑是否有远程办公选项或是否可以搬到公司附近。');
    }

    const benefitDim = dimensions.find(d => d.name === '福利保障');
    if (benefitDim && benefitDim.score < 60) {
      suggestions.push('福利保障较为基础，建议了解补充医疗保险、年假天数等细节。');
    }

    if (suggestions.length === 0) {
      suggestions.push('这是一份综合条件不错的 Offer，建议仔细评估个人职业规划后做出决定。');
      suggestions.push('建议与行业内的其他机会做横向对比，确保做出最优选择。');
    }

    return suggestions;
  }

  private generateNegotiationTips(input: OfferInput, dimensions: DimensionScore[]): string[] {
    const tips: string[] = [];

    const salaryDim = dimensions.find(d => d.name === '薪资待遇');
    if (salaryDim && salaryDim.score < 70) {
      tips.push('可以以市场薪资数据为依据，提出薪资期望值，建议在当前基础上上浮 10%-20%。');
    }

    if (input.annualBonus <= 1) {
      tips.push('年终奖月数较低，可以尝试谈判提高至 2-3 个月，或争取绩效奖金。');
    }

    if (input.socialInsurance < 0.2) {
      tips.push('五险一金比例低于法定标准，建议确认是否按实际工资基数缴纳。');
    }

    tips.push('谈判时展示自己的独特价值和过往业绩，用数据说话更有说服力。');
    tips.push('除了薪资，也可以争取更多年假、弹性工作等非货币性福利。');

    return tips;
  }

  private generateMarketComparison(input: OfferInput): MarketComparison {
    const annualTotal = input.monthlySalary * (12 + input.annualBonus);
    const marketAvg = input.monthlySalary * 0.9;
    const percentile = Math.min(Math.round((annualTotal / (marketAvg * 14)) * 50), 95);

    return {
      salaryPercentile: Math.max(percentile, 20),
      marketAvgSalary: Math.round(marketAvg),
      salaryRange: {
        low: Math.round(marketAvg * 0.7),
        median: Math.round(marketAvg),
        high: Math.round(marketAvg * 1.5),
      },
      description: `您的 Offer 年包约 ${annualTotal.toLocaleString()} 元，${percentile > 60 ? '高于' : '接近'}市场平均水平。`,
    };
  }

  /**
   * 生成模拟对比结果
   */
  private generateMockComparisonResult(offers: OfferInput[]): ComparisonResult {
    const results = offers.map((offer, index) => {
      const analysis = this.generateMockAnalysisResult(offer);
      return { offer, analysis, index };
    });

    // 找出最高分
    let maxScore = 0;
    let recommendedIndex = 0;
    results.forEach(r => {
      if (r.analysis.overallScore > maxScore) {
        maxScore = r.analysis.overallScore;
        recommendedIndex = r.index;
      }
    });

    const offerItems: ComparisonOfferItem[] = results.map(r => ({
      company: r.offer.company,
      position: r.offer.position,
      overallScore: r.analysis.overallScore,
      advantages: r.analysis.dimensions
        .filter(d => d.score >= 70)
        .map(d => `${d.name}表现${d.label}（${d.score}分）`),
      disadvantages: r.analysis.dimensions
        .filter(d => d.score < 55)
        .map(d => `${d.name}有待改善（${d.score}分）`),
    }));

    const dimensionNames = ['薪资待遇', '工作生活平衡', '福利保障', '通勤体验', '发展潜力'];
    const dimensionComparison: DimensionComparison[] = dimensionNames.map(name => {
      const scores = results.map(r => {
        const dim = r.analysis.dimensions.find(d => d.name === name);
        return dim ? dim.score : 50;
      });
      const maxDimScore = Math.max(...scores);
      const minDimScore = Math.min(...scores);
      const diff = maxDimScore - minDimScore;
      let description = '';
      if (diff > 20) {
        description = `各 Offer 在${name}方面差异显著，最高 ${maxDimScore} 分，最低 ${minDimScore} 分。`;
      } else {
        description = `各 Offer 在${name}方面差距不大，均在 ${minDimScore}-${maxDimScore} 分之间。`;
      }
      return { name, scores, description };
    });

    const summary = `综合对比 ${offers.length} 份 Offer，推荐选择「${offers[recommendedIndex].company}」的「${offers[recommendedIndex].position}」岗位，综合评分 ${maxScore} 分。`;

    return {
      offers: offerItems,
      recommendedIndex,
      summary,
      dimensionComparison,
    };
  }
}
