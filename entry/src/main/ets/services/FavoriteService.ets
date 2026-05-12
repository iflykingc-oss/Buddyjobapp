import { ApiService } from './ApiService';
import { API_ENDPOINTS } from '../constants/config';

/**
 * 收藏类型枚举
 */
export enum FavoriteType {
  ARTICLE = 'article',      // 文章
  ASSESSMENT = 'assessment', // 测评
  RESUME_TEMPLATE = 'resume_template', // 简历模板
  JOB = 'job',              // 职位
  COURSE = 'course'         // 课程
}

/**
 * 收藏项接口
 */
export interface FavoriteItem {
  id: string;
  type: FavoriteType;
  title: string;
  subtitle?: string;
  imageUrl?: string;
  sourceId: string;        // 原始内容ID
  extraData?: string;      // 额外JSON数据
  createTime: number;
  updateTime: number;
}

/**
 * 收藏服务 - 管理用户收藏内容
 * 支持本地存储(LocalStorage)和远程API两种模式
 */
export class FavoriteService {
  private apiService: ApiService;
  private static instance: FavoriteService;
  private readonly STORAGE_KEY = 'user_favorites';
  private useLocalStorage: boolean = true; // 默认使用本地存储

  private constructor() {
    this.apiService = ApiService.getInstance();
    // 检查是否有登录token，如果有则优先使用API
    this.useLocalStorage = !this.apiService.hasToken();
  }

  static getInstance(): FavoriteService {
    if (!FavoriteService.instance) {
      FavoriteService.instance = new FavoriteService();
    }
    return FavoriteService.instance;
  }

  /**
   * 设置存储模式
   * @param useLocal true使用本地存储, false使用远程API
   */
  setStorageMode(useLocal: boolean): void {
    this.useLocalStorage = useLocal;
  }

  /**
   * 获取收藏列表
   * @param type 可选，按类型筛选
   * @returns 收藏项数组
   */
  async getFavorites(type?: FavoriteType): Promise<FavoriteItem[]> {
    if (this.useLocalStorage) {
      return this.getLocalFavorites(type);
    } else {
      return this.getRemoteFavorites(type);
    }
  }

  /**
   * 添加收藏
   * @param item 收藏项（不需要传id和createTime）
   * @returns 完整的收藏项
   */
  async addFavorite(item: Omit<FavoriteItem, 'id' | 'createTime' | 'updateTime'>): Promise<FavoriteItem> {
    const fullItem: FavoriteItem = {
      ...item,
      id: this.generateId(),
      createTime: Date.now(),
      updateTime: Date.now()
    };

    if (this.useLocalStorage) {
      return this.addLocalFavorite(fullItem);
    } else {
      return this.addRemoteFavorite(fullItem);
    }
  }

  /**
   * 取消收藏
   * @param id 收藏项ID
   * @returns 是否成功
   */
  async removeFavorite(id: string): Promise<boolean> {
    if (this.useLocalStorage) {
      return this.removeLocalFavorite(id);
    } else {
      return this.removeRemoteFavorite(id);
    }
  }

  /**
   * 根据sourceId和type取消收藏
   * @param sourceId 原始内容ID
   * @param type 收藏类型
   * @returns 是否成功
   */
  async removeFavoriteBySource(sourceId: string, type: FavoriteType): Promise<boolean> {
    if (this.useLocalStorage) {
      const favorites = this.getAllLocalFavorites();
      const target = favorites.find(f => f.sourceId === sourceId && f.type === type);
      if (target) {
        return this.removeLocalFavorite(target.id);
      }
      return false;
    } else {
      // 远程模式：调用API根据sourceId删除
      try {
        const response = await this.apiService.post(API_ENDPOINTS.FAVORITES + '/remove-by-source', {
          sourceId,
          type
        });
        return response.success;
      } catch (error) {
        console.error('[FavoriteService] Remove favorite by source failed:', error);
        return false;
      }
    }
  }

  /**
   * 检查是否已收藏
   * @param sourceId 原始内容ID
   * @param type 收藏类型
   * @returns 是否已收藏
   */
  async isFavorited(sourceId: string, type: FavoriteType): Promise<boolean> {
    if (this.useLocalStorage) {
      const favorites = this.getAllLocalFavorites();
      return favorites.some(f => f.sourceId === sourceId && f.type === type);
    } else {
      try {
        const response = await this.apiService.get<boolean>(
          `${API_ENDPOINTS.FAVORITES}/check?sourceId=${sourceId}&type=${type}`
        );
        return response.data || false;
      } catch (error) {
        console.error('[FavoriteService] Check favorite status failed:', error);
        return false;
      }
    }
  }

  /**
   * 切换收藏状态（收藏/取消收藏）
   * @param item 收藏项
   * @returns 当前是否已收藏
   */
  async toggleFavorite(item: Omit<FavoriteItem, 'id' | 'createTime' | 'updateTime'>): Promise<boolean> {
    const isFav = await this.isFavorited(item.sourceId, item.type);
    if (isFav) {
      await this.removeFavoriteBySource(item.sourceId, item.type);
      return false;
    } else {
      await this.addFavorite(item);
      return true;
    }
  }

  /**
   * 清空所有收藏
   * @returns 是否成功
   */
  async clearAllFavorites(): Promise<boolean> {
    if (this.useLocalStorage) {
      try {
        AppStorage.setOrCreate(this.STORAGE_KEY, JSON.stringify([]));
        return true;
      } catch (error) {
        console.error('[FavoriteService] Clear favorites failed:', error);
        return false;
      }
    } else {
      try {
        const response = await this.apiService.post(API_ENDPOINTS.FAVORITES + '/clear');
        return response.success;
      } catch (error) {
        console.error('[FavoriteService] Clear remote favorites failed:', error);
        return false;
      }
    }
  }

  /**
   * 获取收藏数量
   * @param type 可选，按类型筛选
   * @returns 收藏数量
   */
  async getFavoriteCount(type?: FavoriteType): Promise<number> {
    const favorites = await this.getFavorites(type);
    return favorites.length;
  }

  // ==================== 本地存储方法 ====================

  private getAllLocalFavorites(): FavoriteItem[] {
    try {
      const data = AppStorage.get<string>(this.STORAGE_KEY);
      if (data) {
        return JSON.parse(data);
      }
    } catch (error) {
      console.error('[FavoriteService] Parse local favorites failed:', error);
    }
    return [];
  }

  private getLocalFavorites(type?: FavoriteType): FavoriteItem[] {
    const favorites = this.getAllLocalFavorites();
    if (type) {
      return favorites.filter(f => f.type === type).sort((a, b) => b.createTime - a.createTime);
    }
    return favorites.sort((a, b) => b.createTime - a.createTime);
  }

  private addLocalFavorite(item: FavoriteItem): Promise<FavoriteItem> {
    return new Promise((resolve, reject) => {
      try {
        // 检查是否已存在
        const favorites = this.getAllLocalFavorites();
        const exists = favorites.some(f => f.sourceId === item.sourceId && f.type === item.type);
        if (exists) {
          reject(new Error('该内容已收藏'));
          return;
        }

        favorites.push(item);
        AppStorage.setOrCreate(this.STORAGE_KEY, JSON.stringify(favorites));
        resolve(item);
      } catch (error) {
        console.error('[FavoriteService] Add local favorite failed:', error);
        reject(error);
      }
    });
  }

  private removeLocalFavorite(id: string): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        const favorites = this.getAllLocalFavorites();
        const filtered = favorites.filter(f => f.id !== id);
        AppStorage.setOrCreate(this.STORAGE_KEY, JSON.stringify(filtered));
        resolve(filtered.length < favorites.length);
      } catch (error) {
        console.error('[FavoriteService] Remove local favorite failed:', error);
        resolve(false);
      }
    });
  }

  // ==================== 远程API方法 ====================

  private async getRemoteFavorites(type?: FavoriteType): Promise<FavoriteItem[]> {
    try {
      const url = type
        ? `${API_ENDPOINTS.FAVORITES}?type=${type}`
        : API_ENDPOINTS.FAVORITES;
      const response = await this.apiService.get<FavoriteItem[]>(url);
      return response.data || [];
    } catch (error) {
      console.error('[FavoriteService] Get remote favorites failed:', error);
      return [];
    }
  }

  private async addRemoteFavorite(item: FavoriteItem): Promise<FavoriteItem> {
    const response = await this.apiService.post<FavoriteItem>(API_ENDPOINTS.FAVORITES, item);
    if (!response.success || !response.data) {
      throw new Error(response.error || '添加收藏失败');
    }
    return response.data;
  }

  private async removeRemoteFavorite(id: string): Promise<boolean> {
    try {
      const response = await this.apiService.delete(API_ENDPOINTS.FAVORITES + '/' + id);
      return response.success;
    } catch (error) {
      console.error('[FavoriteService] Remove remote favorite failed:', error);
      return false;
    }
  }

  // ==================== 工具方法 ====================

  private generateId(): string {
    return 'fav_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
}

export default FavoriteService.getInstance();
