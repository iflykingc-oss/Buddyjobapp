/**
 * Offer 分析服务
 *
 * 负责调用后端 API 进行 Offer 分析和对比，
 * API 请求失败时返回明确的错误提示。
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

      // API 返回失败，抛出错误而非使用模拟数据
      console.error('[OfferAnalysisService] API failed:', response.error);
      throw new Error('分析服务暂时不可用，请稍后重试');
    } catch (error) {
      console.error('[OfferAnalysisService] analyzeOffer error:', error);
      throw new Error('分析服务暂时不可用，请稍后重试');
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

      // API 返回失败，抛出错误而非使用模拟数据
      console.error('[OfferAnalysisService] Compare API failed:', response.error);
      throw new Error('对比服务暂时不可用，请稍后重试');
    } catch (error) {
      console.error('[OfferAnalysisService] compareOffers error:', error);
      throw new Error('对比服务暂时不可用，请稍后重试');
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
      // API 返回失败，抛出错误而非使用模拟数据
      throw new Error('分析服务暂时不可用，请稍后重试');
    } catch (error) {
      console.error('[OfferAnalysisService] analyzeWithWeights error:', error);
      throw new Error('分析服务暂时不可用，请稍后重试');
    }
  }

}
