/**
 * 简历分析服务
 * 对接后端 /api/resume/analyze 接口
 * 支持 PDF/Word 文件上传和分析
 */

import file from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import request from '@ohos.request';
import { ApiService } from './ApiService';
import { ResumeAnalysisResult, Dimension, Suggestion, UploadResumeResult } from '../models/Resume';
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

export class ResumeService {
  private static instance: ResumeService;
  private apiService: ApiService;
  
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

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): ResumeService {
    if (!ResumeService.instance) {
      ResumeService.instance = new ResumeService();
    }
    return ResumeService.instance;
  }

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
