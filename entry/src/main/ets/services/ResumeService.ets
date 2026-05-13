/**
 * 简历分析服务
 * 对接后端 /api/resume/analyze 接口
 * 支持 PDF/Word 文件上传和分析
 * 
 * 增强功能：
 * - 简历草稿保存
 * - 简历历史记录管理
 * - 本地数据持久化
 */

import file from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import request from '@ohos.request';
import { ApiService } from './ApiService';
import { ResumeAnalysisResult, Dimension, Suggestion, UploadResumeResult } from '../models/Resume';
import { Storage } from '../utils/storage';
import { API_ENDPOINTS, Config } from '../constants/config';

// 分析进度回调类型
export type ProgressCallback = (progress: number, stage: AnalysisStage) => void;

// 分析阶段枚举
export enum AnalysisStage {
  UPLOADING = 'uploading',       // 上传中
  PARSING = 'parsing',           // 解析中
  ANALYZING = 'analyzing',       // AI分析中
  GENERATING = 'generating',     // 生成报告中
  COMPLETED = 'completed',       // 完成
  ERROR = 'error'                // 错误
}

// 分析阶段文本映射
export const StageTextMap: Record<AnalysisStage, string> = {
  [AnalysisStage.UPLOADING]: '正在上传...',
  [AnalysisStage.PARSING]: '正在解析...',
  [AnalysisStage.ANALYZING]: '正在AI分析...',
  [AnalysisStage.GENERATING]: '正在生成报告...',
  [AnalysisStage.COMPLETED]: '分析完成',
  [AnalysisStage.ERROR]: '分析失败'
};

// 文件类型验证结果
interface FileValidationResult {
  valid: boolean;
  error?: string;
  fileType?: 'pdf' | 'word';
}

// 上传响应
interface UploadResponse {
  fileId: string;
  fileName: string;
  fileSize: number;
  uploadTime: string;
}

// 简历草稿
export interface ResumeDraft {
  id: string;
  basicInfo: BasicInfo;
  education: Education[];
  workExperience: WorkExperience[];
  projects: Project[];
  skills: Skill[];
  updatedAt: number;
  createdAt: number;
}

// 基本信息
export interface BasicInfo {
  name: string;
  gender: string;
  age: string;
  phone: string;
  email: string;
  location: string;
  summary: string;
}

// 教育经历
export interface Education {
  id: string;
  school: string;
  major: string;
  degree: string;
  startDate: string;
  endDate: string;
  gpa: string;
  honors: string;
}

// 工作经历
export interface WorkExperience {
  id: string;
  company: string;
  position: string;
  startDate: string;
  endDate: string;
  description: string;
  achievements: string;
}

// 项目经验
export interface Project {
  id: string;
  name: string;
  role: string;
  startDate: string;
  endDate: string;
  description: string;
  results: string;
  technologies: string;
}

// 技能
export interface Skill {
  id: string;
  name: string;
  level: string;
  category: string;
}

// 简历历史记录
export interface ResumeHistoryItem {
  id: string;
  fileName: string;
  analysisDate: string;
  atsScore: number;
  summary: string;
  keywords: string[];
  analysisResult?: ResumeAnalysisResult;
}

// 存储键名
const STORAGE_KEYS = {
  RESUME_DRAFTS: 'resume_drafts',
  RESUME_HISTORY: 'resume_history',
  CURRENT_DRAFT: 'current_resume_draft'
};

export class ResumeService {
  private static instance: ResumeService;
  private apiService: ApiService;
  private storage: Storage;
  
  // 最大文件大小 10MB
  private readonly MAX_FILE_SIZE = 10 * 1024 * 1024;
  
  // 支持的文件扩展名
  private readonly SUPPORTED_EXTENSIONS = ['.pdf', '.doc', '.docx'];
  
  // 支持的 MIME 类型
  private readonly SUPPORTED_MIME_TYPES = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ];

  // 历史记录最大数量
  private readonly MAX_HISTORY_COUNT = 50;

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.storage = Storage.getInstance();
  }

  static getInstance(): ResumeService {
    if (!ResumeService.instance) {
      ResumeService.instance = new ResumeService();
    }
    return ResumeService.instance;
  }

  // ============================================
  // 简历草稿管理
  // ============================================

  /**
   * 保存简历草稿
   */
  async saveResumeDraft(draft: ResumeDraft): Promise<boolean> {
    try {
      // 获取现有草稿
      const drafts = await this.getResumeDrafts();
      
      // 检查是否已存在
      const existingIndex = drafts.findIndex(d => d.id === draft.id);
      
      // 更新草稿
      draft.updatedAt = Date.now();
      
      if (existingIndex >= 0) {
        drafts[existingIndex] = draft;
      } else {
        draft.createdAt = Date.now();
        drafts.unshift(draft);
      }

      // 保存到存储
      await this.storage.setObject(STORAGE_KEYS.RESUME_DRAFTS, drafts);
      
      console.info('[ResumeService] Resume draft saved:', draft.id);
      return true;
    } catch (error) {
      console.error('[ResumeService] Save draft failed:', error);
      return false;
    }
  }

  /**
   * 获取所有简历草稿
   */
  async getResumeDrafts(): Promise<ResumeDraft[]> {
    try {
      const drafts = await this.storage.getObject<ResumeDraft[]>(STORAGE_KEYS.RESUME_DRAFTS);
      return drafts || [];
    } catch (error) {
      console.error('[ResumeService] Get drafts failed:', error);
      return [];
    }
  }

  /**
   * 获取单个简历草稿
   */
  async getResumeDraft(id: string): Promise<ResumeDraft | null> {
    try {
      const drafts = await this.getResumeDrafts();
      return drafts.find(d => d.id === id) || null;
    } catch (error) {
      console.error('[ResumeService] Get draft failed:', error);
      return null;
    }
  }

  /**
   * 删除简历草稿
   */
  async deleteResumeDraft(id: string): Promise<boolean> {
    try {
      const drafts = await this.getResumeDrafts();
      const filteredDrafts = drafts.filter(d => d.id !== id);
      
      await this.storage.setObject(STORAGE_KEYS.RESUME_DRAFTS, filteredDrafts);
      
      console.info('[ResumeService] Resume draft deleted:', id);
      return true;
    } catch (error) {
      console.error('[ResumeService] Delete draft failed:', error);
      return false;
    }
  }

  /**
   * 获取当前编辑的草稿
   */
  async getCurrentDraft(): Promise<ResumeDraft | null> {
    try {
      return await this.storage.getObject<ResumeDraft>(STORAGE_KEYS.CURRENT_DRAFT);
    } catch (error) {
      console.error('[ResumeService] Get current draft failed:', error);
      return null;
    }
  }

  /**
   * 保存当前编辑的草稿
   */
  async saveCurrentDraft(draft: ResumeDraft): Promise<boolean> {
    try {
      await this.storage.setObject(STORAGE_KEYS.CURRENT_DRAFT, draft);
      return true;
    } catch (error) {
      console.error('[ResumeService] Save current draft failed:', error);
      return false;
    }
  }

  /**
   * 清除当前编辑的草稿
   */
  async clearCurrentDraft(): Promise<boolean> {
    try {
      await this.storage.delete(STORAGE_KEYS.CURRENT_DRAFT);
      return true;
    } catch (error) {
      console.error('[ResumeService] Clear current draft failed:', error);
      return false;
    }
  }

  // ============================================
  // 简历历史记录管理
  // ============================================

  /**
   * 获取简历历史记录（分页）
   */
  async getResumeHistory(page: number = 1, pageSize: number = 10): Promise<ResumeHistoryItem[]> {
    try {
      const history = await this.storage.getObject<ResumeHistoryItem[]>(STORAGE_KEYS.RESUME_HISTORY);
      const allHistory = history || [];
      
      // 分页处理
      const startIndex = (page - 1) * pageSize;
      const endIndex = startIndex + pageSize;
      
      if (startIndex >= allHistory.length) {
        return [];
      }
      
      return allHistory.slice(startIndex, endIndex);
    } catch (error) {
      console.error('[ResumeService] Get resume history failed:', error);
      return [];
    }
  }

  /**
   * 保存简历分析结果到历史记录
   */
  async saveToHistory(result: ResumeAnalysisResult, fileName: string): Promise<boolean> {
    try {
      const history = await this.storage.getObject<ResumeHistoryItem[]>(STORAGE_KEYS.RESUME_HISTORY);
      const allHistory = history || [];

      // 创建历史记录项
      const historyItem: ResumeHistoryItem = {
        id: Date.now().toString(36) + Math.random().toString(36).substring(2),
        fileName: fileName,
        analysisDate: new Date().toLocaleDateString('zh-CN', {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit'
        }),
        atsScore: result.atsScore,
        summary: result.summary,
        keywords: result.keywords,
        analysisResult: result
      };

      // 添加到列表开头
      allHistory.unshift(historyItem);

      // 限制最大数量
      if (allHistory.length > this.MAX_HISTORY_COUNT) {
        allHistory.length = this.MAX_HISTORY_COUNT;
      }

      await this.storage.setObject(STORAGE_KEYS.RESUME_HISTORY, allHistory);
      
      console.info('[ResumeService] Resume saved to history:', historyItem.id);
      return true;
    } catch (error) {
      console.error('[ResumeService] Save to history failed:', error);
      return false;
    }
  }

  /**
   * 删除历史记录
   */
  async deleteHistoryItem(id: string): Promise<boolean> {
    try {
      const history = await this.storage.getObject<ResumeHistoryItem[]>(STORAGE_KEYS.RESUME_HISTORY);
      const allHistory = history || [];
      
      const filteredHistory = allHistory.filter(item => item.id !== id);
      
      await this.storage.setObject(STORAGE_KEYS.RESUME_HISTORY, filteredHistory);
      
      console.info('[ResumeService] History item deleted:', id);
      return true;
    } catch (error) {
      console.error('[ResumeService] Delete history failed:', error);
      return false;
    }
  }

  /**
   * 清空历史记录
   */
  async clearHistory(): Promise<boolean> {
    try {
      await this.storage.delete(STORAGE_KEYS.RESUME_HISTORY);
      console.info('[ResumeService] History cleared');
      return true;
    } catch (error) {
      console.error('[ResumeService] Clear history failed:', error);
      return false;
    }
  }

  /**
   * 获取历史记录总数
   */
  async getHistoryCount(): Promise<number> {
    try {
      const history = await this.storage.getObject<ResumeHistoryItem[]>(STORAGE_KEYS.RESUME_HISTORY);
      return (history || []).length;
    } catch (error) {
      console.error('[ResumeService] Get history count failed:', error);
      return 0;
    }
  }

  // ============================================
  // 简历分析相关方法
  // ============================================

  /**
   * 验证文件类型和大小
   */
  validateFile(file: file.File): FileValidationResult {
    // 获取文件名
    const fileName = file.name || '';
    
    // 检查文件扩展名
    const extension = this.getFileExtension(fileName);
    if (!extension) {
      return {
        valid: false,
        error: '无法识别文件类型'
      };
    }
    
    if (!this.SUPPORTED_EXTENSIONS.includes(extension.toLowerCase())) {
      return {
        valid: false,
        error: `不支持的文件格式，仅支持 ${this.SUPPORTED_EXTENSIONS.join('、')} 格式`
      };
    }
    
    // 检查文件大小
    const fileSize = file.size || 0;
    if (fileSize > this.MAX_FILE_SIZE) {
      return {
        valid: false,
        error: `文件大小超过限制（最大 ${this.MAX_FILE_SIZE / 1024 / 1024}MB）`
      };
    }
    
    // 确定文件类型
    const fileType: 'pdf' | 'word' = extension.toLowerCase() === '.pdf' ? 'pdf' : 'word';
    
    return {
      valid: true,
      fileType
    };
  }

  /**
   * 获取文件扩展名
   */
  private getFileExtension(fileName: string): string {
    const lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex === -1) {
      return '';
    }
    return fileName.substring(lastDotIndex).toLowerCase();
  }

  /**
   * 上传简历文件
   */
  async uploadResume(
    file: file.File,
    onProgress?: ProgressCallback
  ): Promise<UploadResumeResult> {
    try {
      // 验证文件
      const validation = this.validateFile(file);
      if (!validation.valid) {
        throw new Error(validation.error);
      }

      // 通知上传开始
      onProgress?.(0, AnalysisStage.UPLOADING);

      // 读取文件内容
      const fileContent = await this.readFileContent(file.uri);
      
      // 模拟上传进度
      const uploadProgress = this.simulateProgress(0, 30, 500, (progress) => {
        onProgress?.(progress, AnalysisStage.UPLOADING);
      });

      try {
        // 调用上传 API
        const response = await this.apiService.post<UploadResponse>(API_ENDPOINTS.RESUME_UPLOAD, {
          fileName: file.name,
          fileSize: file.size,
          fileType: validation.fileType,
          content: fileContent
        });

        if (!response.success || !response.data) {
          throw new Error(response.error || '文件上传失败');
        }

        return {
          fileId: response.data.fileId,
          fileName: response.data.fileName,
          fileSize: response.data.fileSize
        };
      } finally {
        // 确保清除进度模拟定时器
        clearInterval(uploadProgress);
      }
    } catch (error) {
      console.error('[ResumeService] Upload failed:', error);
      throw error;
    }
  }

  /**
   * 分析简历
   */
  async analyzeResume(
    file: file.File,
    onProgress?: ProgressCallback
  ): Promise<ResumeAnalysisResult> {
    try {
      // 验证文件
      const validation = this.validateFile(file);
      if (!validation.valid) {
        throw new Error(validation.error);
      }

      // 阶段1: 上传文件
      onProgress?.(0, AnalysisStage.UPLOADING);
      const uploadResult = await this.uploadResume(file, onProgress);

      // 阶段2: 解析简历
      onProgress?.(35, AnalysisStage.PARSING);
      await this.delay(800);
      onProgress?.(45, AnalysisStage.PARSING);

      // 阶段3: AI 分析
      onProgress?.(50, AnalysisStage.ANALYZING);
      
      // 调用分析 API
      const analyzeResponse = await this.apiService.post<ResumeAnalysisResult>(
        API_ENDPOINTS.RESUME_ANALYZE,
        {
          fileId: uploadResult.fileId,
          fileName: uploadResult.fileName,
          fileType: validation.fileType
        }
      );

      if (!analyzeResponse.success || !analyzeResponse.data) {
        throw new Error(analyzeResponse.error || '简历分析失败');
      }

      // 模拟分析进度
      await this.simulateProgressAsync(55, 85, 1500, (progress) => {
        onProgress?.(progress, AnalysisStage.ANALYZING);
      });

      // 阶段4: 生成报告
      onProgress?.(88, AnalysisStage.GENERATING);
      await this.delay(500);
      onProgress?.(95, AnalysisStage.GENERATING);
      await this.delay(300);

      // 完成
      onProgress?.(100, AnalysisStage.COMPLETED);

      // 保存到历史记录
      await this.saveToHistory(analyzeResponse.data, uploadResult.fileName);

      return analyzeResponse.data;
    } catch (error) {
      console.error('[ResumeService] Analyze failed:', error);
      onProgress?.(0, AnalysisStage.ERROR);
      throw error;
    }
  }

  /**
   * 获取分析结果
   */
  async getAnalysisResult(fileId: string): Promise<ResumeAnalysisResult> {
    const response = await this.apiService.get<ResumeAnalysisResult>(
      `${API_ENDPOINTS.RESUME_RESULT}/${fileId}`
    );

    if (!response.success || !response.data) {
      throw new Error(response.error || '获取分析结果失败');
    }

    return response.data;
  }

  /**
   * 导出分析报告为 PDF
   */
  async exportToPdf(result: ResumeAnalysisResult): Promise<string> {
    try {
      // 调用导出 API
      const response = await this.apiService.post<{ downloadUrl: string }>(
        '/resume/export/pdf',
        { result }
      );

      if (!response.success || !response.data) {
        throw new Error(response.error || '导出PDF失败');
      }

      return response.data.downloadUrl;
    } catch (error) {
      console.error('[ResumeService] Export PDF failed:', error);
      throw error;
    }
  }

  /**
   * 读取文件内容
   */
  private async readFileContent(fileUri: string): Promise<string> {
    try {
      // 打开文件
      const file = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
      
      // 获取文件大小
      const stat = fs.statSync(file.fd);
      const fileSize = stat.size;
      
      // 读取文件内容（Base64 编码）
      const buffer = new ArrayBuffer(fileSize);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      
      // 转換为 Base64
      return this.arrayBufferToBase64(buffer);
    } catch (error) {
      console.error('[ResumeService] Read file failed:', error);
      throw new Error('读取文件失败');
    }
  }

  /**
   * ArrayBuffer 转 Base64
   */
  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const uint8Array = new Uint8Array(buffer);
    let binary = '';
    const len = uint8Array.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(uint8Array[i]);
    }
    return btoa(binary);
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 模拟进度（同步版本）
   */
  private simulateProgress(
    start: number,
    end: number,
    duration: number,
    onUpdate: (progress: number) => void
  ): number {
    const startTime = Date.now();
    const interval = 50;
    
    const timer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(
        start + (end - start) * (elapsed / duration),
        end
      );
      onUpdate(Math.floor(progress));
      
      if (elapsed >= duration) {
        clearInterval(timer);
      }
    }, interval);
    
    return timer;
  }

  /**
   * 模拟进度（异步版本）
   */
  private async simulateProgressAsync(
    start: number,
    end: number,
    duration: number,
    onUpdate: (progress: number) => void
  ): Promise<void> {
    const startTime = Date.now();
    const interval = 50;
    
    return new Promise(resolve => {
      const timer = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(
          start + (end - start) * (elapsed / duration),
          end
        );
        onUpdate(Math.floor(progress));
        
        if (elapsed >= duration) {
          clearInterval(timer);
          resolve();
        }
      }, interval);
    });
  }

  /**
   * 获取维度图标名称
   */
  getDimensionIcon(dimensionName: string): string {
    const iconMap: Record<string, string> = {
      '基本信息': 'ic_user',
      '工作经历': 'ic_work',
      '教育背景': 'ic_education',
      '技能特长': 'ic_skill',
      '项目经验': 'ic_project',
      '自我评价': 'ic_evaluation',
      '语言能力': 'ic_language',
      '证书资质': 'ic_certificate'
    };
    return iconMap[dimensionName] || 'ic_analysis';
  }

  /**
   * 获取建议优先级颜色
   */
  getSuggestionPriorityColor(priority: string): string {
    switch (priority) {
      case 'high':
        return '#E84026'; // Error500
      case 'medium':
        return '#FF9800'; // Warning500
      case 'low':
        return '#64BB5C'; // Success500
      default:
        return '#8B5CF6'; // Brand500
    }
  }
}

export default ResumeService;
