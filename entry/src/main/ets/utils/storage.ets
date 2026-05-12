import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

/**
 * 本地存储工具
 */
export class Storage {
  private static instance: Storage;
  private preferences: dataPreferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  // 内存缓存，用于支持同步读取
  private cache: Map<string, string> = new Map();

  private constructor() {}

  static getInstance(): Storage {
    if (!Storage.instance) {
      Storage.instance = new Storage();
    }
    return Storage.instance;
  }

  /**
   * 初始化存储
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.context = context;
      this.preferences = await dataPreferences.Preferences.getPreferences(context, {
        name: 'buddyjob_preferences'
      });
      // 将preferences数据预加载到cache
      if (this.preferences) {
        const allEntries = await this.preferences.getAll();
        if (allEntries) {
          Object.keys(allEntries).forEach((key) => {
            const value = allEntries[key];
            if (typeof value === 'string') {
              this.cache.set(key, value);
            }
          });
        }
      }
    } catch (error) {
      console.error('[Storage] Init failed:', error);
    }
  }

  /**
   * 保存数据（异步）
   */
  async set(key: string, value: string): Promise<void> {
    try {
      // 先更新缓存
      this.cache.set(key, value);
      if (this.preferences) {
        await this.preferences.put(key, value);
        await this.preferences.flush();
      }
    } catch (error) {
      console.error(`[Storage] Set ${key} failed:`, error);
    }
  }

  /**
   * 获取数据（异步）
   */
  async get(key: string, defaultValue: string = ''): Promise<string> {
    try {
      if (this.preferences) {
        return await this.preferences.get(key, defaultValue);
      }
      return defaultValue;
    } catch (error) {
      console.error(`[Storage] Get ${key} failed:`, error);
      return defaultValue;
    }
  }

  /**
   * 保存数据（同步，仅更新缓存，异步持久化）
   */
  setSync(key: string, value: string): void {
    // 更新缓存
    this.cache.set(key, value);
    // 异步持久化
    this.set(key, value).catch(err => {
      console.error(`[Storage] setSync failed for ${key}:`, err);
    });
  }

  /**
   * 获取数据（同步，从缓存读取）
   */
  getSync<T = string>(key: string, defaultValue: T | string = ''): T | string {
    // 先从缓存读取
    if (this.cache.has(key)) {
      return this.cache.get(key) as T;
    }
    return defaultValue;
  }

  /**
   * 删除数据（异步）
   */
  async delete(key: string): Promise<void> {
    try {
      // 先删除缓存
      this.cache.delete(key);
      if (this.preferences) {
        await this.preferences.delete(key);
        await this.preferences.flush();
      }
    } catch (error) {
      console.error(`[Storage] Delete ${key} failed:`, error);
    }
  }

  /**
   * 删除数据（同步）
   */
  deleteSync(key: string): void {
    // 删除缓存
    this.cache.delete(key);
    // 异步持久化
    this.delete(key).catch(err => {
      console.error(`[Storage] deleteSync failed for ${key}:`, err);
    });
  }

  /**
   * 移除数据（同步，delete 的别名）
   */
  remove(key: string): void {
    this.deleteSync(key);
  }

  /**
   * 检查 key 是否存在（异步）
   */
  async has(key: string): Promise<boolean> {
    try {
      // 先检查缓存
      if (this.cache.has(key)) {
        return true;
      }
      if (this.preferences) {
        return await this.preferences.has(key);
      }
      return false;
    } catch (error) {
      console.error(`[Storage] Has ${key} failed:`, error);
      return false;
    }
  }

  /**
   * 清除所有数据（异步）
   */
  async clear(): Promise<void> {
    try {
      // 清除缓存
      this.cache.clear();
      if (this.preferences) {
        await this.preferences.clear();
        await this.preferences.flush();
      }
    } catch (error) {
      console.error('[Storage] Clear failed:', error);
    }
  }

  // 便捷方法 - JSON 存储
  async setObject(key: string, value: object): Promise<void> {
    await this.set(key, JSON.stringify(value));
  }

  async getObject<T>(key: string): Promise<T | null> {
    const str = await this.get(key);
    if (str) {
      try {
        return JSON.parse(str) as T;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /**
   * 获取所有key（异步）
   */
  async getAllKeys(): Promise<string[]> {
    try {
      if (this.preferences) {
        const allEntries = await this.preferences.getAll();
        if (allEntries) {
          return Object.keys(allEntries);
        }
      }
      return Array.from(this.cache.keys());
    } catch (error) {
      console.error('[Storage] getAllKeys failed:', error);
      return Array.from(this.cache.keys());
    }
  }
}

export const storage = Storage.getInstance();
