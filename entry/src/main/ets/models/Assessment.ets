// 数据模型 - 测评模型
export interface Assessment {
  id: string;
  title: string;
  description: string;
  type: AssessmentType;
  questions: Question[];
  duration: number; // 分钟
  status: AssessmentStatus;
}

export type AssessmentType = 'personality' | 'career' | 'skill' | 'value';

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
}

export interface AssessmentResult {
  assessmentId: string;
  score: number;
  dimensionScores: DimensionScore[];
  suggestions: string[];
  reportUrl?: string;
}

export interface DimensionScore {
  dimension: string;
  score: number;
  description: string;
}
