// 数据模型 - 测评模型
export interface Assessment {
  id: string;
  title: string;
  description: string;
  type: AssessmentType;
  icon: string;
  duration: number; // 分钟
  category: string;
  dimensions: string[]; // 维度名称列表
  questions: Question[];
  status: AssessmentStatus;
}

export type AssessmentType = 'personality' | 'career' | 'skill' | 'value' | 'eq' | 'interview_readiness';

export type AssessmentStatus = 'not_started' | 'in_progress' | 'completed';

export interface Question {
  id: string;
  type: 'single' | 'multiple' | 'text';
  title: string;
  options?: Option[];
  required: boolean;
}

export interface Option {
  id: string;
  text: string;
  score?: number;
  dimension?: string;   // 所属维度
  direction?: number;   // 方向得分 (1 或 -1)
}

export interface AssessmentResult {
  assessmentId: string;
  score: number;
  dimensionScores: DimensionScore[];
  suggestions: string[];
  reportUrl?: string;
  dimensionDetails?: DimensionDetail[];  // 维度详细解读
  nextActions?: string[];                // 推荐下一步行动
  typeDescription?: string;              // 性格/兴趣类型描述
  careerMatch?: string[];                // 匹配的职业方向
}

export interface DimensionScore {
  dimension: string;
  score: number;
  description: string;
}

export interface DimensionDetail {
  dimension: string;
  score: number;
  level: string;        // 'high' | 'medium' | 'low'
  interpretation: string;  // 维度解读
  advice: string;          // 提升建议
}
