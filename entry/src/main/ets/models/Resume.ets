// 数据模型 - 简历分析模型
export interface ResumeAnalysisResult {
  atsScore: number;
  dimensions: Dimension[];
  suggestions: Suggestion[];
  summary: string;
  keywords: string[];
}

export interface Dimension {
  name: string;
  score: number;
  description: string;
}

export interface Suggestion {
  type: 'add' | 'modify' | 'delete';
  priority: 'high' | 'medium' | 'low';
  title: string;
  description: string;
}

export interface UploadResumeResult {
  fileId: string;
  fileName: string;
  fileSize: number;
}
