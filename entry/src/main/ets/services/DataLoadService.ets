/**
 * DataLoadService - 统一数据加载服务
 *
 * 提供从本地 rawfile JSON 文件和远程 API 加载结构化数据的能力，
 * 支持多种加载策略、内存缓存、分页查询和关键字搜索。
 * 被 AssessmentService、InterviewService、KnowledgeService 共同使用。
 *
 * @example
 * const service = DataLoadService.getInstance();
 * await service.initialize(this.context);
 * const data = await service.loadJson<MyType>(config);
 *
 * @since 1.0.0
 */
import resourceManager from '@ohos.resourceManager';
import { ApiService } from './ApiService';

const TAG = 'DataLoadService';
const DOMAIN = 0xFF00;

/**
 * 数据加载策略
 */
export enum DataLoadStrategy {
  LOCAL_FIRST = 'local_first',     // 优先本地，本地无数据时请求API
  API_FIRST = 'api_first',         // 优先API，失败时回退本地
  LOCAL_ONLY = 'local_only',       // 仅本地
  API_ONLY = 'api_only'            // 仅API
}

/**
 * 数据加载配置
 */
export interface DataLoadConfig {
  strategy: DataLoadStrategy;
  localPath: string;          // rawfile中的文件路径，如 'data/interview_questions.json'
  apiEndpoint: string;        // API端点，如 '/interview/questions'
  cacheKey: string;           // 本地缓存key
  cacheExpiry: number;        // 缓存过期时间（毫秒），默认24小时
}

/**
 * 分页参数
 */
export interface PaginationParams {
  page: number;
  pageSize: number;
}

/**
 * 分页结果
 */
export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/**
 * 筛选参数
 */
export interface FilterParams {
  keyword?: string;
  category?: string;
  position?: string;
  difficulty?: string;
  tags?: string[];
  [key: string]: string | string[] | undefined;
}

interface CacheEntry {
  data: Object;
  timestamp: number;
}

export class DataLoadService {
  private static instance: DataLoadService;
  private resMgr: resourceManager.ResourceManager | null = null;
  private cache: Map<string, CacheEntry> = new Map();

  private constructor() {
  }

  /**
   * 获取 DataLoadService 单例实例
   * @returns DataLoadService 实例
   */
  static getInstance(): DataLoadService {
    if (!DataLoadService.instance) {
      DataLoadService.instance = new DataLoadService();
    }
    return DataLoadService.instance;
  }

  // ==================== 初始化 ====================

  /**
   * 初始化 ResourceManager
   * @param context 应用上下文（UIAbilityContext 或 AbilityContext）
   */
  async initialize(context: Context): Promise<void> {
    try {
      this.resMgr = context.resourceManager;
      this.log('ResourceManager 初始化成功');
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`ResourceManager 初始化失败: ${errMsg}`);
      throw error;
    }
  }

  // ==================== 核心加载方法 ====================

  /**
   * 加载JSON数据（根据策略）
   * @param config 数据加载配置
   * @returns 解析后的JSON数据
   */
  async loadJson<T>(config: DataLoadConfig): Promise<T> {
    const expiry = config.cacheExpiry || 24 * 60 * 60 * 1000; // 默认24小时

    // 检查缓存
    if (!this.isCacheExpired(config.cacheKey)) {
      const cached = this.getCache<T>(config.cacheKey);
      if (cached !== null) {
        this.log(`从缓存加载数据: ${config.cacheKey}`);
        return cached;
      }
    }

    let data: T | null = null;

    switch (config.strategy) {
      case DataLoadStrategy.LOCAL_FIRST:
        data = await this.tryLoadLocal<T>(config.localPath);
        if (data === null) {
          this.log(`本地无数据，尝试API加载: ${config.apiEndpoint}`);
          data = await this.tryLoadApi<T>(config.apiEndpoint);
        }
        break;

      case DataLoadStrategy.API_FIRST:
        data = await this.tryLoadApi<T>(config.apiEndpoint);
        if (data === null) {
          this.log(`API加载失败，回退本地: ${config.localPath}`);
          data = await this.tryLoadLocal<T>(config.localPath);
        }
        break;

      case DataLoadStrategy.LOCAL_ONLY:
        data = await this.tryLoadLocal<T>(config.localPath);
        break;

      case DataLoadStrategy.API_ONLY:
        data = await this.tryLoadApi<T>(config.apiEndpoint);
        break;

      default:
        this.logError(`未知的加载策略: ${config.strategy}`);
        break;
    }

    if (data !== null) {
      this.setCache(config.cacheKey, data, expiry);
    }

    return data as T;
  }

  /**
   * 从本地rawfile加载JSON
   * @param filePath rawfile中的文件路径
   * @returns 解析后的JSON数据，失败返回null
   */
  async loadLocalJson<T>(filePath: string): Promise<T> {
    try {
      if (!this.resMgr) {
        this.logError('ResourceManager 未初始化，请先调用 initialize()');
        return null as T;
      }

      const rawContent = await this.resMgr.getRawFileContent(filePath);
      const contentStr = this.uint8ArrayToString(rawContent);
      const parsed: T = JSON.parse(contentStr) as T;
      this.log(`本地JSON加载成功: ${filePath}`);
      return parsed;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`本地JSON加载失败 [${filePath}]: ${errMsg}`);
      return null as T;
    }
  }

  /**
   * 从API加载JSON
   * @param endpoint API端点
   * @returns 解析后的JSON数据，失败返回null
   */
  async loadApiJson<T>(endpoint: string): Promise<T> {
    try {
      const apiService = ApiService.getInstance();
      const response = await apiService.get<T>(endpoint);

      if (response.success && response.data !== null && response.data !== undefined) {
        this.log(`API JSON加载成功: ${endpoint}`);
        return response.data as T;
      } else {
        this.logError(`API JSON加载失败 [${endpoint}]: ${response.error}`);
        return null as T;
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`API JSON加载异常 [${endpoint}]: ${errMsg}`);
      return null as T;
    }
  }

  // ==================== 分页与搜索 ====================

  /**
   * 获取 rawfile 文件大小（字节），用于懒加载决策
   * @param filePath rawfile中的文件路径
   * @returns 文件大小（字节），获取失败返回 -1
   */
  async getRawFileSize(filePath: string): Promise<number> {
    try {
      if (!this.resMgr) {
        this.logError('ResourceManager 未初始化，请先调用 initialize()');
        return -1;
      }

      const rawFileDescriptor = await this.resMgr.getRawFileDescriptor(filePath);
      const fileSize = rawFileDescriptor.length;
      await rawFileDescriptor.close();
      this.log(`文件大小获取成功: ${filePath}, ${fileSize} 字节`);
      return fileSize;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`获取文件大小失败 [${filePath}]: ${errMsg}`);
      return -1;
    }
  }

  /**
   * 分块加载大型JSON数组文件
   * 仅解析数组的前 N 个元素，适用于初始快速展示，后续可在后台加载完整数据
   * @param config 数据加载配置
   * @param maxItems 最多加载的条目数，默认 100
   * @returns 截断后的数组数据
   */
  async loadJsonChunked<T>(config: DataLoadConfig, maxItems?: number): Promise<T[]> {
    try {
      const limit = maxItems || 100;

      // 检查缓存
      if (!this.isCacheExpired(config.cacheKey)) {
        const cached = this.getCache<T[]>(config.cacheKey);
        if (cached !== null) {
          this.log(`从缓存加载分块数据: ${config.cacheKey}`);
          return cached;
        }
      }

      // 从本地加载完整内容
      let rawContent: Uint8Array | null = null;
      if (config.strategy === DataLoadStrategy.LOCAL_FIRST ||
          config.strategy === DataLoadStrategy.LOCAL_ONLY) {
        try {
          if (!this.resMgr) {
            this.logError('ResourceManager 未初始化，请先调用 initialize()');
            return [];
          }
          rawContent = await this.resMgr.getRawFileContent(config.localPath);
        } catch (error) {
          const errMsg = error instanceof Error ? error.message : String(error);
          this.logError(`本地文件加载失败 [${config.localPath}]: ${errMsg}`);
        }
      }

      if (rawContent === null && config.strategy !== DataLoadStrategy.LOCAL_ONLY) {
        // 尝试从API加载
        try {
          const apiData = await this.tryLoadApi<Object>(config.apiEndpoint);
          if (apiData !== null) {
            let rawList: Object[];
            if (Array.isArray(apiData)) {
              rawList = apiData as Object[];
            } else {
              const apiObj = apiData as Record<string, Object>;
              rawList = ((apiObj['data'] as Object[]) || (apiObj['items'] as Object[]) ||
                (apiObj['questions'] as Object[]) || (apiObj['articles'] as Object[]) || []) as Object[];
            }
            const chunked = rawList.slice(0, limit) as T[];
            this.setCache(config.cacheKey, chunked, config.cacheExpiry || 24 * 60 * 60 * 1000);
            this.log(`API分块加载成功: ${config.cacheKey}, 返回 ${chunked.length}/${rawList.length} 条`);
            return chunked;
          }
        } catch (error) {
          const errMsg = error instanceof Error ? error.message : String(error);
          this.logError(`API分块加载失败: ${errMsg}`);
        }
        return [];
      }

      if (rawContent === null) {
        return [];
      }

      // 解析JSON并截取前N条
      const contentStr = this.uint8ArrayToString(rawContent);
      const parsed: Object = JSON.parse(contentStr);

      // 兼容多种顶层结构
      let rawList: Object[] = [];
      if (Array.isArray(parsed)) {
        rawList = parsed as Object[];
      } else if (parsed) {
        const parsedObj = parsed as Record<string, Object>;
        rawList = ((parsedObj['questions'] as Object[]) || (parsedObj['articles'] as Object[]) ||
          (parsedObj['assessments'] as Object[]) || (parsedObj['data'] as Object[]) ||
          (parsedObj['items'] as Object[]) || (parsedObj['list'] as Object[]) || []) as Object[];
      }

      const chunked = rawList.slice(0, limit) as T[];
      this.setCache(config.cacheKey, chunked, config.cacheExpiry || 24 * 60 * 60 * 1000);
      this.log(`本地分块加载成功: ${config.localPath}, 返回 ${chunked.length}/${rawList.length} 条`);
      return chunked;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`分块加载失败: ${errMsg}`);
      return [];
    }
  }

  /**
   * 分页查询
   * 加载全部数据 -> 按筛选条件过滤 -> 分页返回
   * @param config 数据加载配置
   * @param params 分页参数
   * @param filters 筛选参数（可选）
   * @returns 分页结果
   */
  async loadPaginated<T extends Record<string, Object>>(
    config: DataLoadConfig,
    params: PaginationParams,
    filters?: FilterParams
  ): Promise<PaginatedResult<T>> {
    try {
      const allData = await this.loadJson<T[]>(config);

      if (allData === null || !Array.isArray(allData)) {
        return {
          items: [],
          total: 0,
          page: params.page,
          pageSize: params.pageSize,
          hasMore: false
        };
      }

      // 应用筛选
      let filtered = allData;

      if (filters) {
        // 关键字搜索
        if (filters.keyword && filters.keyword.length > 0) {
          const keyword = filters.keyword.toLowerCase();
          filtered = filtered.filter((item: T) => {
            let found = false;
            for (const key in item) {
              const val = (item as Record<string, Object>)[key];
              if (typeof val === 'string' && (val as string).toLowerCase().includes(keyword)) {
                found = true;
                break;
              }
            }
            return found;
          });
        }

        // 分类筛选
        if (filters.category && filters.category.length > 0) {
          filtered = filtered.filter((item: T) => {
            return item['category'] === filters.category;
          });
        }

        // 职位筛选
        if (filters.position && filters.position.length > 0) {
          filtered = filtered.filter((item: T) => {
            return item['position'] === filters.position;
          });
        }

        // 难度筛选
        if (filters.difficulty && filters.difficulty.length > 0) {
          filtered = filtered.filter((item: T) => {
            return item['difficulty'] === filters.difficulty;
          });
        }

        // 标签筛选
        if (filters.tags && filters.tags.length > 0) {
          filtered = filtered.filter((item: T) => {
            const itemTags = item['tags'];
            if (!Array.isArray(itemTags)) {
              return false;
            }
            for (let i = 0; i < filters.tags!.length; i++) {
              if (itemTags.indexOf(filters.tags![i]) >= 0) {
                return true;
              }
            }
            return false;
          });
        }
      }

      // 分页
      return this.paginate(filtered, params.page, params.pageSize);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`分页查询失败: ${errMsg}`);
      return {
        items: [],
        total: 0,
        page: params.page,
        pageSize: params.pageSize,
        hasMore: false
      };
    }
  }

  /**
   * 搜索
   * 加载全部数据 -> 在指定字段中搜索关键字
   * @param config 数据加载配置
   * @param keyword 搜索关键字
   * @param field 搜索字段名
   * @returns 匹配的数据列表
   */
  async search<T extends Record<string, Object>>(
    config: DataLoadConfig,
    keyword: string,
    field: string
  ): Promise<T[]> {
    try {
      const allData = await this.loadJson<T[]>(config);

      if (allData === null || !Array.isArray(allData)) {
        return [];
      }

      if (!keyword || keyword.length === 0) {
        return allData;
      }

      const lowerKeyword = keyword.toLowerCase();
      return allData.filter((item: T) => {
        const val = item[field];
        if (typeof val === 'string') {
          return (val as string).toLowerCase().includes(lowerKeyword);
        }
        return false;
      });
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`搜索失败: ${errMsg}`);
      return [];
    }
  }

  /**
   * 按ID获取
   * @param config 数据加载配置
   * @param id 目标ID
   * @param idField ID字段名，默认 'id'
   * @returns 匹配的数据项，未找到返回null
   */
  async getById<T extends Record<string, Object>>(
    config: DataLoadConfig,
    id: string,
    idField?: string
  ): Promise<T | null> {
    try {
      const allData = await this.loadJson<T[]>(config);

      if (allData === null || !Array.isArray(allData)) {
        return null;
      }

      const field = idField || 'id';
      for (let i = 0; i < allData.length; i++) {
        if (allData[i][field] === id) {
          return allData[i];
        }
      }

      this.log(`未找到ID为 ${id} 的数据 (字段: ${field})`);
      return null;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`按ID获取失败: ${errMsg}`);
      return null;
    }
  }

  // ==================== 缓存管理 ====================

  /**
   * 设置缓存
   * @param key 缓存key
   * @param data 缓存数据
   * @param expiry 过期时间（毫秒），默认24小时
   */
  setCache(key: string, data: Object, expiry?: number): void {
    const ttl = expiry || 24 * 60 * 60 * 1000;
    this.cache.set(key, {
      data: data,
      timestamp: Date.now() + ttl
    });
    this.log(`缓存已设置: ${key}, 过期时间: ${ttl}ms`);
  }

  /**
   * 获取缓存
   * @param key 缓存key
   * @returns 缓存数据，未命中或已过期返回null
   */
  getCache<T>(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) {
      return null;
    }
    if (this.isCacheExpired(key)) {
      this.cache.delete(key);
      return null;
    }
    return entry.data as T;
  }

  /**
   * 清除缓存
   * @param key 指定key清除，不传则清除全部缓存
   */
  clearCache(key?: string): void {
    if (key) {
      this.cache.delete(key);
      this.log(`缓存已清除: ${key}`);
    } else {
      this.cache.clear();
      this.log('全部缓存已清除');
    }
  }

  /**
   * 检查缓存是否过期
   * @param key 缓存key
   * @returns 是否已过期
   */
  isCacheExpired(key: string): boolean {
    const entry = this.cache.get(key);
    if (!entry) {
      return true;
    }
    return Date.now() > entry.timestamp;
  }

  // ==================== 数据过滤工具方法 ====================

  /**
   * 按关键字过滤（多字段搜索）
   * @param items 数据列表
   * @param keyword 搜索关键字
   * @param fields 搜索字段列表
   * @returns 匹配的数据列表
   */
  filterByKeyword<T extends Record<string, Object>>(items: T[], keyword: string, fields: string[]): T[] {
    if (!keyword || keyword.length === 0) {
      return items;
    }

    const lowerKeyword = keyword.toLowerCase();
    return items.filter((item: T) => {
      for (let i = 0; i < fields.length; i++) {
        const val = item[fields[i]];
        if (typeof val === 'string' && (val as string).toLowerCase().includes(lowerKeyword)) {
          return true;
        }
      }
      return false;
    });
  }

  /**
   * 按字段值过滤
   * @param items 数据列表
   * @param field 字段名
   * @param value 目标值
   * @returns 匹配的数据列表
   */
  filterByField<T extends Record<string, Object>>(items: T[], field: string, value: string): T[] {
    return items.filter((item: T) => {
      return item[field] === value;
    });
  }

  /**
   * 分页工具
   * @param items 数据列表
   * @param page 页码（从1开始）
   * @param pageSize 每页数量
   * @returns 分页结果
   */
  paginate<T>(items: T[], page: number, pageSize: number): PaginatedResult<T> {
    const total = items.length;
    const startIndex = (page - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    const pagedItems = items.slice(startIndex, endIndex);

    return {
      items: pagedItems,
      total: total,
      page: page,
      pageSize: pageSize,
      hasMore: endIndex < total
    };
  }

  /**
   * 按字段排序
   * @param items 数据列表
   * @param field 排序字段
   * @param ascending 是否升序，默认true
   * @returns 排序后的数据列表
   */
  sortByField<T extends Record<string, Object>>(items: T[], field: string, ascending?: boolean): T[] {
    const isAsc = ascending !== false;
    const sorted = items.slice(); // 浅拷贝避免修改原数组
    sorted.sort((a: T, b: T) => {
      const valA = a[field];
      const valB = b[field];

      if (valA === valB) {
        return 0;
      }

      // 处理数字类型
      if (typeof valA === 'number' && typeof valB === 'number') {
        return isAsc ? ((valA as number) - (valB as number)) : ((valB as number) - (valA as number));
      }

      // 处理字符串类型
      const strA = String(valA);
      const strB = String(valB);
      const compare = strA.localeCompare(strB);
      return isAsc ? compare : -compare;
    });
    return sorted;
  }

  // ==================== 私有辅助方法 ====================

  /**
   * 尝试从本地加载（封装错误处理）
   * @param filePath rawfile路径
   * @returns 数据或null
   */
  private async tryLoadLocal<T>(filePath: string): Promise<T | null> {
    try {
      return await this.loadLocalJson<T>(filePath);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`本地加载异常 [${filePath}]: ${errMsg}`);
      return null;
    }
  }

  /**
   * 尝试从API加载（封装错误处理）
   * @param endpoint API端点
   * @returns 数据或null
   */
  private async tryLoadApi<T>(endpoint: string): Promise<T | null> {
    try {
      return await this.loadApiJson<T>(endpoint);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`API加载异常 [${endpoint}]: ${errMsg}`);
      return null;
    }
  }

  /**
   * Uint8Array 转字符串
   * 使用循环拼接避免展开运算符可能导致的栈溢出
   * @param array Uint8Array数据
   * @returns 字符串
   */
  private uint8ArrayToString(array: Uint8Array): string {
    let str = '';
    for (let i = 0; i < array.length; i++) {
      str += String.fromCharCode(array[i]);
    }
    return str;
  }

  // ==================== 日志方法 ====================

  private log(message: string): void {
    console.info(`[${TAG}] ${message}`);
  }

  private logError(message: string): void {
    console.error(`[${TAG}] ${message}`);
  }
}
