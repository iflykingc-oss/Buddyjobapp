import { Storage } from '../utils/storage';

/**
 * 历史记录类型
 */
export type HistoryType = 'all' | 'resume' | 'assessment' | 'chat' | 'interview';

/**
 * 历史记录项
 */
export interface HistoryItem {
  id: string;
  type: Exclude<HistoryType, 'all'>;
  title: string;
  content: string;
  timestamp: number;
  metadata?: Record<string, Object>;
}

const HISTORY_STORAGE_KEY = 'buddyjob_history';
const MAX_HISTORY_ITEMS = 100;

/**
 * 历史记录服务
 */
export class HistoryService {
  private static instance: HistoryService;
  private storage: Storage = Storage.getInstance();

  private constructor() {}

  static getInstance(): HistoryService {
    if (!HistoryService.instance) {
      HistoryService.instance = new HistoryService();
    }
    return HistoryService.instance;
  }

  /**
   * 获取历史记录
   * @param type 记录类型，默认为 'all' 获取全部
   * @returns 历史记录列表
   */
  async getHistory(type: HistoryType = 'all'): Promise<HistoryItem[]> {
    try {
      const historyStr = await this.storage.get(HISTORY_STORAGE_KEY, '[]');
      const history: HistoryItem[] = JSON.parse(historyStr);

      if (type === 'all') {
        return history.sort((a, b) => b.timestamp - a.timestamp);
      }

      return history
        .filter(item => item.type === type)
        .sort((a, b) => b.timestamp - a.timestamp);
    } catch (error) {
      console.error('[HistoryService] Get history failed:', error);
      return [];
    }
  }

  /**
   * 添加历史记录
   * @param item 历史记录项
   */
  async addHistory(item: Omit<HistoryItem, 'id' | 'timestamp'>): Promise<void> {
    try {
      const historyStr = await this.storage.get(HISTORY_STORAGE_KEY, '[]');
      const history: HistoryItem[] = JSON.parse(historyStr);

      const newItem: HistoryItem = {
        ...item,
        id: this.generateId(),
        timestamp: Date.now()
      };

      // 添加到开头
      history.unshift(newItem);

      // 限制最大数量
      if (history.length > MAX_HISTORY_ITEMS) {
        history.length = MAX_HISTORY_ITEMS;
      }

      await this.storage.set(HISTORY_STORAGE_KEY, JSON.stringify(history));
      console.info('[HistoryService] History added:', newItem.id);
    } catch (error) {
      console.error('[HistoryService] Add history failed:', error);
    }
  }

  /**
   * 删除单条历史记录
   * @param id 记录ID
   */
  async removeHistory(id: string): Promise<void> {
    try {
      const historyStr = await this.storage.get(HISTORY_STORAGE_KEY, '[]');
      const history: HistoryItem[] = JSON.parse(historyStr);

      const filteredHistory = history.filter(item => item.id !== id);

      await this.storage.set(HISTORY_STORAGE_KEY, JSON.stringify(filteredHistory));
      console.info('[HistoryService] History removed:', id);
    } catch (error) {
      console.error('[HistoryService] Remove history failed:', error);
    }
  }

  /**
   * 清空历史记录
   * @param type 记录类型，不传则清空全部
   */
  async clearHistory(type?: HistoryType): Promise<void> {
    try {
      if (!type || type === 'all') {
        await this.storage.set(HISTORY_STORAGE_KEY, '[]');
        console.info('[HistoryService] All history cleared');
      } else {
        const historyStr = await this.storage.get(HISTORY_STORAGE_KEY, '[]');
        const history: HistoryItem[] = JSON.parse(historyStr);

        const filteredHistory = history.filter(item => item.type !== type);

        await this.storage.set(HISTORY_STORAGE_KEY, JSON.stringify(filteredHistory));
        console.info('[HistoryService] History cleared for type:', type);
      }
    } catch (error) {
      console.error('[HistoryService] Clear history failed:', error);
    }
  }

  /**
   * 获取历史记录数量
   * @param type 记录类型
   */
  async getHistoryCount(type: HistoryType = 'all'): Promise<number> {
    const history = await this.getHistory(type);
    return history.length;
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substring(2, 9);
  }

  /**
   * 格式化时间戳
   * @param timestamp 时间戳
   */
  static formatTimestamp(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;

    // 小于1分钟
    if (diff < 60 * 1000) {
      return '刚刚';
    }

    // 小于1小时
    if (diff < 60 * 60 * 1000) {
      return Math.floor(diff / (60 * 1000)) + '分钟前';
    }

    // 小于24小时
    if (diff < 24 * 60 * 60 * 1000) {
      return Math.floor(diff / (60 * 60 * 1000)) + '小时前';
    }

    // 小于7天
    if (diff < 7 * 24 * 60 * 60 * 1000) {
      return Math.floor(diff / (24 * 60 * 60 * 1000)) + '天前';
    }

    // 显示日期
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }

  /**
   * 获取类型标签
   * @param type 历史记录类型
   */
  static getTypeLabel(type: HistoryType): string {
    const labels: Record<HistoryType, string> = {
      all: '全部',
      resume: '简历分析',
      assessment: '测评',
      chat: '对话',
      interview: '面试'
    };
    return labels[type];
  }

  /**
   * 获取类型图标
   * @param type 历史记录类型
   */
  static getTypeIcon(type: Exclude<HistoryType, 'all'>): Resource {
    const icons: Record<Exclude<HistoryType, 'all'>, Resource> = {
      resume: $r('app.media.media_ic_resume'),
      assessment: $r('app.media.media_ic_assessment'),
      chat: $r('app.media.media_ic_chat'),
      interview: $r('app.media.media_ic_interview')
    };
    return icons[type];
  }
}
