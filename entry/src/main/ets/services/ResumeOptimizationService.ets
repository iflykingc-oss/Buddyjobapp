/**
 * AI简历优化元服务 - Atomic Service
 * 独立的简历优化服务，可被其他应用调用
 */
import hilog from '@ohos.hilog';
import { ApiService } from './ApiService';
import { storage } from '../utils/storage';

const TAG = 'ResumeOptimizationService';
const DOMAIN = 0xFF00;

/**
 * 优化类型
 */
export enum OptimizationType {
  CONTENT = 'content',      // 内容优化
  FORMAT = 'format',        // 格式优化
  KEYWORDS = 'keywords',    // 关键词优化
  ATS = 'ats',             // ATS适配
  FULL = 'full'            // 全面优化
}

/**
 * 优化建议
 */
export interface OptimizationSuggestion {
  id: string;
  type: OptimizationType;
  section: string;
  original: string;
  optimized: string;
  reason: string;
  impact: 'high' | 'medium' | 'low';
  applied: boolean;
}

/**
 * 优化结果
 */
export interface OptimizationResult {
  resumeId: string;
  overallScore: {
    before: number;
    after: number;
    improvement: number;
  };
  suggestions: OptimizationSuggestion[];
  optimizedContent: string;
  atsCompatibility: number;
  keywordMatch: number;
  processingTime: number;
}

/**
 * 目标岗位信息
 */
export interface TargetPosition {
  title: string;
  industry?: string;
  company?: string;
  keywords?: string[];
}

/**
 * 优化配置
 */
export interface OptimizationConfig {
  types: OptimizationType[];
  targetPosition?: TargetPosition;
  preserveSections?: string[];
  maxSuggestions?: number;
}

export class ResumeOptimizationService {
  /**
   * 执行简历优化
   */
  static async optimize(
    resumeId: string,
    config: OptimizationConfig
  ): Promise<OptimizationResult | null> {
    try {
      hilog.info(DOMAIN, TAG, `Starting optimization for resume: ${resumeId}`);

      const startTime = Date.now();

      // 获取简历内容
      const resumeContent = await this.getResumeContent(resumeId);
      if (!resumeContent) {
        hilog.error(DOMAIN, TAG, 'Resume content not found');
        return null;
      }

      // 分析当前简历
      const analysis = await this.analyzeResume(resumeContent, config.targetPosition);

      // 生成优化建议
      const suggestions = await this.generateSuggestions(
        resumeContent,
        analysis,
        config
      );

      // 应用优化
      const optimizedContent = await this.applyOptimizations(
        resumeContent,
        suggestions.filter(s => s.impact === 'high')
      );

      // 计算优化后分数
      const afterAnalysis = await this.analyzeResume(optimizedContent, config.targetPosition);

      const processingTime = Date.now() - startTime;

      const result: OptimizationResult = {
        resumeId,
        overallScore: {
          before: analysis.overallScore,
          after: afterAnalysis.overallScore,
          improvement: afterAnalysis.overallScore - analysis.overallScore
        },
        suggestions,
        optimizedContent,
        atsCompatibility: afterAnalysis.atsScore,
        keywordMatch: afterAnalysis.keywordMatch,
        processingTime
      };

      // 保存优化结果
      await this.saveOptimizationResult(result);

      hilog.info(DOMAIN, TAG, `Optimization completed in ${processingTime}ms`);
      return result;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Optimization failed: ${error}`);
      return null;
    }
  }

  /**
   * 快速优化 - 仅优化高影响项
   */
  static async quickOptimize(
    resumeId: string,
    targetPosition?: TargetPosition
  ): Promise<OptimizationSuggestion[]> {
    try {
      const result = await this.optimize(resumeId, {
        types: [OptimizationType.KEYWORDS, OptimizationType.ATS],
        targetPosition,
        maxSuggestions: 5
      });

      return result?.suggestions.filter(s => s.impact === 'high') || [];
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Quick optimization failed: ${error}`);
      return [];
    }
  }

  /**
   * 获取优化建议预览
   */
  static async getPreview(
    resumeId: string,
    suggestionId: string
  ): Promise<{ before: string; after: string; diff: DiffItem[] } | null> {
    try {
      const result = await storage.get(`optimization_${resumeId}`, null);
      if (!result) {
        return null;
      }

      const parsed = JSON.parse(result) as OptimizationResult;
      const suggestion = parsed.suggestions.find(s => s.id === suggestionId);

      if (!suggestion) {
        return null;
      }

      const diff = this.computeDiff(suggestion.original, suggestion.optimized);

      return {
        before: suggestion.original,
        after: suggestion.optimized,
        diff
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get preview failed: ${error}`);
      return null;
    }
  }

  /**
   * 应用单个优化建议
   */
  static async applySuggestion(
    resumeId: string,
    suggestionId: string
  ): Promise<boolean> {
    try {
      const result = await storage.get(`optimization_${resumeId}`, null);
      if (!result) {
        return false;
      }

      const parsed = JSON.parse(result) as OptimizationResult;
      const suggestion = parsed.suggestions.find(s => s.id === suggestionId);

      if (!suggestion || suggestion.applied) {
        return false;
      }

      // 调用API应用优化
      const response = await ApiService.getInstance().post('/api/resume/apply-optimization', {
        resumeId,
        section: suggestion.section,
        content: suggestion.optimized
      });

      if (response.success) {
        suggestion.applied = true;
        await storage.set(`optimization_${resumeId}`, JSON.stringify(parsed));
        return true;
      }

      return false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Apply suggestion failed: ${error}`);
      return false;
    }
  }

  /**
   * 批量应用优化建议
   */
  static async applyAllSuggestions(
    resumeId: string,
    impactLevel?: 'high' | 'medium' | 'low'
  ): Promise<number> {
    try {
      const result = await storage.get(`optimization_${resumeId}`, null);
      if (!result) {
        return 0;
      }

      const parsed = JSON.parse(result) as OptimizationResult;
      let appliedCount = 0;

      const toApply = parsed.suggestions.filter(s => {
        if (s.applied) return false;
        if (impactLevel && s.impact !== impactLevel) return false;
        return true;
      });

      for (let i = 0; i < toApply.length; i++) {
        const suggestion = toApply[i];
        const success = await this.applySuggestion(resumeId, suggestion.id);
        if (success) {
          appliedCount++;
        }
      }

      return appliedCount;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Apply all suggestions failed: ${error}`);
      return 0;
    }
  }

  /**
   * 获取简历内容
   */
  private static async getResumeContent(resumeId: string): Promise<string | null> {
    try {
      const response = await ApiService.getInstance().get(`/api/resume/${resumeId}/content`);
      return response.data?.content || null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get resume content failed: ${error}`);
      return null;
    }
  }

  /**
   * 分析简历
   */
  private static async analyzeResume(
    content: string,
    targetPosition?: TargetPosition
  ): Promise<Record<string, Object>> {
    try {
      const response = await ApiService.getInstance().post('/api/resume/analyze', {
        content,
        targetPosition
      });

      return (response.data as Record<string, Object>) || {
        overallScore: 60,
        atsScore: 70,
        keywordMatch: 50
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Analyze resume failed: ${error}`);
      return {
        overallScore: 60,
        atsScore: 70,
        keywordMatch: 50
      };
    }
  }

  /**
   * 生成优化建议
   */
  private static async generateSuggestions(
    content: string,
    analysis: Record<string, Object>,
    config: OptimizationConfig
  ): Promise<OptimizationSuggestion[]> {
    try {
      const response = await ApiService.getInstance().post('/api/resume/generate-suggestions', {
        content,
        analysis,
        config
      });

      if (response.success && response.data) {
        return response.data as OptimizationSuggestion[];
      }

      // 返回模拟建议
      return this.getMockSuggestions();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Generate suggestions failed: ${error}`);
      return this.getMockSuggestions();
    }
  }

  /**
   * 应用优化
   */
  private static async applyOptimizations(
    content: string,
    suggestions: OptimizationSuggestion[]
  ): Promise<string> {
    let optimized = content;

    for (let i = 0; i < suggestions.length; i++) {
      const suggestion = suggestions[i];
      optimized = optimized.replace(suggestion.original, suggestion.optimized);
    }

    return optimized;
  }

  /**
   * 保存优化结果
   */
  private static async saveOptimizationResult(result: OptimizationResult): Promise<void> {
    await storage.set(`optimization_${result.resumeId}`, JSON.stringify(result));
  }

  /**
   * 计算文本差异
   */
  private static computeDiff(before: string, after: string): DiffItem[] {
    const diff: DiffItem[] = [];
    const beforeLines = before.split('\n');
    const afterLines = after.split('\n');

    const maxLines = Math.max(beforeLines.length, afterLines.length);

    for (let i = 0; i < maxLines; i++) {
      const beforeLine = beforeLines[i] || '';
      const afterLine = afterLines[i] || '';

      if (beforeLine === afterLine) {
        diff.push({ type: 'unchanged', content: beforeLine });
      } else if (!beforeLine) {
        diff.push({ type: 'added', content: afterLine });
      } else if (!afterLine) {
        diff.push({ type: 'removed', content: beforeLine });
      } else {
        diff.push({ type: 'removed', content: beforeLine });
        diff.push({ type: 'added', content: afterLine });
      }
    }

    return diff;
  }

  /**
   * 获取模拟建议
   */
  private static getMockSuggestions(): OptimizationSuggestion[] {
    return [
      {
        id: '1',
        type: OptimizationType.CONTENT,
        section: 'experience',
        original: '负责前端开发工作',
        optimized: '主导前端架构设计，使用React+TypeScript技术栈，将页面加载速度提升40%，用户满意度提升25%',
        reason: '使用STAR法则量化工作成果，增强说服力',
        impact: 'high',
        applied: false
      },
      {
        id: '2',
        type: OptimizationType.KEYWORDS,
        section: 'skills',
        original: 'JavaScript, CSS, HTML',
        optimized: 'JavaScript/TypeScript, React, Vue, Node.js, CSS3/Sass, HTML5, Webpack, Git',
        reason: '补充技术栈关键词，提升ATS匹配率',
        impact: 'high',
        applied: false
      },
      {
        id: '3',
        type: OptimizationType.ATS,
        section: 'summary',
        original: '我是一名前端开发工程师',
        optimized: '5年经验的前端开发工程师，擅长React生态和性能优化',
        reason: '避免第一人称，突出经验和专长',
        impact: 'medium',
        applied: false
      }
    ];
  }
}

/**
 * 差异项
 */
interface DiffItem {
  type: 'unchanged' | 'added' | 'removed';
  content: string;
}
