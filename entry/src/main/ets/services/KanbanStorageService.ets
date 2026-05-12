/**
 * 求职看板本地存储服务
 * 所有数据存储在本地，不依赖服务端
 */
import hilog from '@ohos.hilog';
import { storage } from '../utils/storage';
import {
  KanbanData, JobCard, KanbanColumnStatus, DEFAULT_COLUMNS
} from '../models/Kanban';

const TAG = 'KanbanStorageService';
const DOMAIN = 0xFF00;
const STORAGE_KEY = 'kanban_data';

export class KanbanStorageService {

  /**
   * 初始化看板数据（首次使用时写入默认列配置）
   */
  static async initialize(): Promise<KanbanData> {
    try {
      const existing = await this.load();
      if (existing) {
        return existing;
      }

      // 首次使用，创建默认数据
      const defaultData: KanbanData = {
        columns: DEFAULT_COLUMNS,
        cards: []
      };

      await this.save(defaultData);
      hilog.info(DOMAIN, TAG, 'Kanban data initialized');
      return defaultData;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${error}`);
      return { columns: DEFAULT_COLUMNS, cards: [] };
    }
  }

  /**
   * 加载看板数据
   */
  static async load(): Promise<KanbanData | null> {
    try {
      const raw = await storage.get(STORAGE_KEY, '');
      if (!raw) {
        return null;
      }
      return JSON.parse(raw) as KanbanData;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Load failed: ${error}`);
      return null;
    }
  }

  /**
   * 保存看板数据
   */
  static async save(data: KanbanData): Promise<void> {
    try {
      await storage.set(STORAGE_KEY, JSON.stringify(data));
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Save failed: ${error}`);
    }
  }

  // ==================== 卡片操作 ====================

  /**
   * 新增卡片
   */
  static async addCard(card: Omit<JobCard, 'id' | 'createdAt' | 'updatedAt' | 'sortWeight'>): Promise<JobCard> {
    const data = await this.loadOrCreate();
    const now = new Date().toISOString();

    // 计算排序权重：同列最后一张卡片的 weight + 1
    const columnCards = data.cards.filter(c => c.columnStatus === card.columnStatus);
    const maxWeight = columnCards.reduce((max, c) => Math.max(max, c.sortWeight), 0);

    const newCard: JobCard = {
      ...card,
      id: `card_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
      createdAt: now,
      updatedAt: now,
      sortWeight: maxWeight + 1
    };

    data.cards.push(newCard);
    await this.save(data);
    return newCard;
  }

  /**
   * 更新卡片
   */
  static async updateCard(cardId: string, updates: Partial<JobCard>): Promise<JobCard | null> {
    const data = await this.loadOrCreate();
    const index = data.cards.findIndex(c => c.id === cardId);
    if (index === -1) {
      return null;
    }

    data.cards[index] = {
      ...data.cards[index],
      ...updates,
      updatedAt: new Date().toISOString()
    };

    await this.save(data);
    return data.cards[index];
  }

  /**
   * 删除卡片
   */
  static async deleteCard(cardId: string): Promise<boolean> {
    const data = await this.loadOrCreate();
    const index = data.cards.findIndex(c => c.id === cardId);
    if (index === -1) {
      return false;
    }

    data.cards.splice(index, 1);
    await this.save(data);
    return true;
  }

  /**
   * 移动卡片到目标列
   */
  static async moveCard(
    cardId: string,
    targetColumn: KanbanColumnStatus,
    targetIndex?: number
  ): Promise<JobCard | null> {
    const data = await this.loadOrCreate();
    const card = data.cards.find(c => c.id === cardId);
    if (!card) {
      return null;
    }

    const oldColumn = card.columnStatus;
    card.columnStatus = targetColumn;
    card.updatedAt = new Date().toISOString();

    // 如果指定了目标位置，重新计算 sortWeight
    if (targetIndex !== undefined) {
      const targetColumnCards = data.cards
        .filter(c => c.columnStatus === targetColumn && c.id !== cardId)
        .sort((a, b) => a.sortWeight - b.sortWeight);

      // 在目标位置插入
      let newWeight: number;
      if (targetIndex === 0) {
        newWeight = targetColumnCards.length > 0
          ? targetColumnCards[0].sortWeight - 1
          : 0;
      } else if (targetIndex >= targetColumnCards.length) {
        newWeight = targetColumnCards.length > 0
          ? targetColumnCards[targetColumnCards.length - 1].sortWeight + 1
          : 0;
      } else {
        const before = targetColumnCards[targetIndex - 1].sortWeight;
        const after = targetColumnCards[targetIndex].sortWeight;
        newWeight = (before + after) / 2;
      }

      card.sortWeight = newWeight;
    }

    await this.save(data);
    return card;
  }

  /**
   * 获取指定列的卡片（按 sortWeight 排序）
   */
  static async getCardsByColumn(columnStatus: KanbanColumnStatus): Promise<JobCard[]> {
    const data = await this.loadOrCreate();
    return data.cards
      .filter(c => c.columnStatus === columnStatus)
      .sort((a, b) => a.sortWeight - b.sortWeight);
  }

  /**
   * 获取所有卡片
   */
  static async getAllCards(): Promise<JobCard[]> {
    const data = await this.loadOrCreate();
    return data.cards;
  }

  /**
   * 获取看板统计
   */
  static async getStatistics(): Promise<Record<KanbanColumnStatus, number>> {
    const data = await this.loadOrCreate();
    const stats: Record<string, number> = {};

    for (const col of data.columns) {
      stats[col.status] = data.cards.filter(c => c.columnStatus === col.status).length;
    }

    return stats as Record<KanbanColumnStatus, number>;
  }

  /**
   * 搜索卡片
   */
  static async searchCards(keyword: string): Promise<JobCard[]> {
    const data = await this.loadOrCreate();
    const lowerKeyword = keyword.toLowerCase();

    return data.cards.filter(c =>
      c.company.toLowerCase().includes(lowerKeyword) ||
      c.position.toLowerCase().includes(lowerKeyword) ||
      c.location.toLowerCase().includes(lowerKeyword) ||
      c.tags.some(t => t.toLowerCase().includes(lowerKeyword)) ||
      (c.note && c.note.toLowerCase().includes(lowerKeyword))
    );
  }

  /**
   * 清空所有数据
   */
  static async clearAll(): Promise<void> {
    const defaultData: KanbanData = {
      columns: DEFAULT_COLUMNS,
      cards: []
    };
    await this.save(defaultData);
  }

  /**
   * 加载或创建
   */
  private static async loadOrCreate(): Promise<KanbanData> {
    const data = await this.load();
    if (data) {
      return data;
    }
    return this.initialize();
  }
}
