/**
 * LazyDataLoader - 懒加载服务
 *
 * 针对大型 rawfile JSON 文件（10,000+ 条目，~12MB）进行分批加载，
 * 避免启动时一次性加载所有数据导致阻塞。
 *
 * 核心策略：
 *   1. 启动时仅加载元数据（分类、统计信息），不加载全部数据
 *   2. 按需分批加载，每批默认 100 条
 *   3. 支持预加载下一批（用户浏览当前批时后台加载）
 *   4. 内存中缓存已加载数据，避免重复 IO
 *
 * @example
 * const loader = LazyDataLoader.getInstance();
 * await loader.initializeMetadata('interviews', 'data/interview_questions_v2.json');
 * const batch = await loader.loadBatch('interviews', 1, 100);
 *
 * @since 1.0.0
 */
import resourceManager from '@ohos.resourceManager';

const TAG = 'LazyDataLoader';
const DOMAIN = 0xFF00;

/**
 * 数据元信息 - 启动时快速加载，用于 UI 展示分类/统计
 */
export interface DataMetadata {
  /** 数据源标识 */
  key: string;
  /** 数据总条数 */
  totalItems: number;
  /** 分类列表（从数据中提取的唯一分类） */
  categories: string[];
  /** 职位列表（可选，面试题等按职位分类的数据） */
  positions?: string[];
  /** 难度级别（可选） */
  difficulties?: string[];
  /** 元数据是否已加载 */
  loaded: boolean;
  /** rawfile 文件路径 */
  filePath: string;
}

/**
 * 单个数据源的加载状态
 */
export interface DataLoadState {
  /** 元数据是否已加载 */
  metadataLoaded: boolean;
  /** 全量数据是否已加载到内存 */
  fullyLoaded: boolean;
  /** 是否正在加载 */
  loading: boolean;
  /** 已加载的数据项 */
  items: Object[];
  /** 数据总条数 */
  totalItems: number;
  /** 元数据信息 */
  metadata: DataMetadata | null;
  /** 预加载的下一批数据 */
  preloadedBatch: Object[] | null;
  /** 预加载的批次号 */
  preloadedBatchPage: number;
  /** 加载错误信息 */
  lastError: string | null;
}

export interface DataLoadStateView {
  metadataLoaded: boolean;
  fullyLoaded: boolean;
  loading: boolean;
  loadedCount: number;
  totalCount: number;
  hasError: boolean;
  errorMessage: string | null;
}

export class LazyDataLoader {
  private static instance: LazyDataLoader;

  /** 分批加载配置 - 每批加载条数 */
  readonly BATCH_SIZE: number = 100;

  /** 最大内存缓存条数，超过后淘汰最早批次 */
  readonly MAX_CACHED_ITEMS: number = 500;

  private resMgr: resourceManager.ResourceManager | null = null;
  private loadStates: Map<string, DataLoadState> = new Map();

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): LazyDataLoader {
    if (!LazyDataLoader.instance) {
      LazyDataLoader.instance = new LazyDataLoader();
    }
    return LazyDataLoader.instance;
  }

  // ==================== 初始化 ====================

  /**
   * 初始化 ResourceManager
   * @param context 应用上下文
   */
  initializeResourceManager(context: Context): void {
    try {
      this.resMgr = context.resourceManager;
      this.log('ResourceManager 初始化成功');
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`ResourceManager 初始化失败: ${errMsg}`);
    }
  }

  // ==================== 元数据加载 ====================

  /**
   * 初始化数据元信息
   * 仅读取 JSON 文件的元数据（分类、统计），不加载全部数据内容
   * 启动时调用，耗时极低
   *
   * @param dataKey 数据源标识，如 'assessments'、'interviews'、'knowledge'
   * @param filePath rawfile 文件路径，如 'data/interview_questions_v2.json'
   * @returns 数据元信息
   */
  async initializeMetadata(dataKey: string, filePath: string): Promise<DataMetadata> {
    const state = this.getOrCreateState(dataKey, filePath);

    // 如果已经加载过元数据，直接返回
    if (state.metadataLoaded && state.metadata) {
      this.log(`元数据已缓存，直接返回: ${dataKey}`);
      return state.metadata;
    }

    state.loading = true;
    state.lastError = null;

    try {
      if (!this.resMgr) {
        throw new Error('ResourceManager 未初始化，请先调用 initializeResourceManager()');
      }

      this.log(`开始加载元数据: ${dataKey} -> ${filePath}`);
      const startTime = Date.now();

      // 读取文件内容
      const rawContent = await this.resMgr.getRawFileContent(filePath);
      const contentStr = this.uint8ArrayToString(rawContent);
      const parsedData: Record<string, Object> = JSON.parse(contentStr) as Record<string, Object>;

      // 提取数组数据
      const dataArray: Object[] = Array.isArray(parsedData) ? parsedData as Object[] :
        (parsedData['data'] && Array.isArray(parsedData['data'])) ? parsedData['data'] as Object[] :
          (parsedData['questions'] && Array.isArray(parsedData['questions'])) ? parsedData['questions'] as Object[] :
            (parsedData['articles'] && Array.isArray(parsedData['articles'])) ? parsedData['articles'] as Object[] : [];

      const totalItems = dataArray.length;

      // 提取分类信息
      const categories = this.extractUniqueValues(dataArray, 'category');
      const positions = this.extractUniqueValues(dataArray, 'position');
      const difficulties = this.extractUniqueValues(dataArray, 'difficulty');

      // 构建元数据
      const metadata: DataMetadata = {
        key: dataKey,
        totalItems: totalItems,
        categories: categories,
        positions: positions.length > 0 ? positions : undefined,
        difficulties: difficulties.length > 0 ? difficulties : undefined,
        loaded: true,
        filePath: filePath,
      };

      // 更新状态
      state.metadataLoaded = true;
      state.metadata = metadata;
      state.totalItems = totalItems;
      state.loading = false;

      const elapsed = Date.now() - startTime;
      this.log(`元数据加载完成: ${dataKey}, 共 ${totalItems} 条, ${categories.length} 个分类, 耗时 ${elapsed}ms`);

      return metadata;
    } catch (error) {
      state.loading = false;
      const errMsg = error instanceof Error ? error.message : String(error);
      state.lastError = errMsg;
      this.logError(`元数据加载失败 [${dataKey}]: ${errMsg}`);

      // 返回空元数据，不阻塞启动
      return {
        key: dataKey,
        totalItems: 0,
        categories: [],
        loaded: false,
        filePath: filePath,
      };
    }
  }

  // ==================== 分批加载 ====================

  /**
   * 按需加载一批数据
   * 如果数据已全量加载到内存，直接从内存分页返回
   * 否则从 rawfile 读取并解析对应批次
   *
   * @param dataKey 数据源标识
   * @param page 页码（从 1 开始）
   * @param pageSize 每页条数，默认 BATCH_SIZE
   * @returns 当前批次的数据
   */
  async loadBatch(dataKey: string, page: number, pageSize?: number): Promise<Object[]> {
    const size = pageSize || this.BATCH_SIZE;
    const state = this.loadStates.get(dataKey);

    if (!state) {
      this.logError(`数据源未初始化: ${dataKey}，请先调用 initializeMetadata()`);
      return [];
    }

    // 如果数据已全量加载，直接分页
    if (state.fullyLoaded) {
      const startIndex = (page - 1) * size;
      const endIndex = startIndex + size;
      return state.items.slice(startIndex, endIndex);
    }

    // 检查是否有预加载数据
    if (state.preloadedBatch !== null && state.preloadedBatchPage === page) {
      const batch = state.preloadedBatch;
      state.preloadedBatch = null;
      state.preloadedBatchPage = 0;
      // 将预加载数据合并到已加载列表
      state.items.push(...batch);
      return batch;
    }

    // 需要从文件加载
    state.loading = true;
    state.lastError = null;

    try {
      if (!state.metadata) {
        this.logError(`元数据未加载: ${dataKey}`);
        state.loading = false;
        return [];
      }

      const startTime = Date.now();
      const filePath = state.metadata.filePath;

      // 读取全量数据（rawfile 不支持随机读取，需要读取全文件后分批）
      const rawContent = await this.resMgr!.getRawFileContent(filePath);
      const contentStr = this.uint8ArrayToString(rawContent);
      const parsedData: Record<string, Object> = JSON.parse(contentStr) as Record<string, Object>;

      const dataArray: Object[] = Array.isArray(parsedData) ? parsedData as Object[] :
        (parsedData['data'] && Array.isArray(parsedData['data'])) ? parsedData['data'] as Object[] :
          (parsedData['questions'] && Array.isArray(parsedData['questions'])) ? parsedData['questions'] as Object[] :
            (parsedData['articles'] && Array.isArray(parsedData['articles'])) ? parsedData['articles'] as Object[] : [];

      // 如果数据量不大（< MAX_CACHED_ITEMS），直接全量缓存
      if (dataArray.length <= this.MAX_CACHED_ITEMS) {
        state.items = dataArray;
        state.fullyLoaded = true;
        state.loading = false;

        const startIndex = (page - 1) * size;
        const endIndex = startIndex + size;
        const batch = dataArray.slice(startIndex, endIndex);

        this.log(`数据量较小，已全量缓存: ${dataKey}, 共 ${dataArray.length} 条, 耗时 ${Date.now() - startTime}ms`);
        return batch;
      }

      // 大数据量：只返回当前批次，并缓存
      const startIndex = (page - 1) * size;
      const endIndex = startIndex + size;
      const batch = dataArray.slice(startIndex, endIndex);

      // 缓存已加载的批次
      state.items.push(...batch);

      // 控制内存缓存大小
      if (state.items.length > this.MAX_CACHED_ITEMS) {
        state.items = state.items.slice(state.items.length - this.MAX_CACHED_ITEMS);
      }

      state.loading = false;
      this.log(`批次加载完成: ${dataKey}, 第 ${page} 页, ${batch.length} 条, 耗时 ${Date.now() - startTime}ms`);

      return batch;
    } catch (error) {
      state.loading = false;
      const errMsg = error instanceof Error ? error.message : String(error);
      state.lastError = errMsg;
      this.logError(`批次加载失败 [${dataKey}]: ${errMsg}`);
      return [];
    }
  }

  /**
   * 预加载下一批数据
   * 在用户浏览当前批时后台调用，减少等待时间
   *
   * @param dataKey 数据源标识
   * @param nextPage 下一页页码（可选，自动推断当前页 +1）
   */
  async preloadNextBatch(dataKey: string, nextPage?: number): Promise<void> {
    const state = this.loadStates.get(dataKey);

    if (!state || state.fullyLoaded || state.loading) {
      return;
    }

    // 自动推断下一页
    const currentPage = Math.ceil(state.items.length / this.BATCH_SIZE);
    const targetPage = nextPage || (currentPage + 1);

    // 如果已经预加载了该页，跳过
    if (state.preloadedBatch !== null && state.preloadedBatchPage === targetPage) {
      return;
    }

    try {
      const batch = await this.loadBatch(dataKey, targetPage);
      if (batch.length > 0) {
        state.preloadedBatch = batch;
        state.preloadedBatchPage = targetPage;
        this.log(`预加载完成: ${dataKey}, 第 ${targetPage} 页`);
      }
    } catch (error) {
      // 预加载失败不影响用户体验
      this.logError(`预加载失败 [${dataKey}]: ${error}`);
    }
  }

  // ==================== 数据访问 ====================

  /**
   * 获取已加载的数据
   * @param dataKey 数据源标识
   * @returns 已加载到内存中的数据项
   */
  getLoadedItems(dataKey: string): Object[] {
    const state = this.loadStates.get(dataKey);
    return state ? state.items : [];
  }

  /**
   * 获取数据元信息
   * @param dataKey 数据源标识
   * @returns 元信息，未初始化返回 null
   */
  getMetadata(dataKey: string): DataMetadata | null {
    const state = this.loadStates.get(dataKey);
    return state ? state.metadata : null;
  }

  /**
   * 检查数据是否已全量加载
   * @param dataKey 数据源标识
   */
  isFullyLoaded(dataKey: string): boolean {
    const state = this.loadStates.get(dataKey);
    return state ? state.fullyLoaded : false;
  }

  /**
   * 搜索已加载数据
   * 仅在已加载到内存的数据中搜索，未加载的数据不会被搜索到
   *
   * @param dataKey 数据源标识
   * @param keyword 搜索关键字
   * @param field 搜索字段名
   * @returns 匹配的数据列表
   */
  searchLoaded(dataKey: string, keyword: string, field: string): Object[] {
    const state = this.loadStates.get(dataKey);
    if (!state || !keyword || keyword.length === 0) {
      return state ? state.items : [];
    }

    const lowerKeyword = keyword.toLowerCase();
    return state.items.filter((item: Object) => {
      const val = (item as Record<string, Object>)[field];
      if (typeof val === 'string') {
        return (val as string).toLowerCase().includes(lowerKeyword);
      }
      return false;
    });
  }

  /**
   * 在已加载数据中按分类筛选
   * @param dataKey 数据源标识
   * @param category 分类名称
   * @returns 匹配的数据列表
   */
  filterByCategory(dataKey: string, category: string): Object[] {
    const state = this.loadStates.get(dataKey);
    if (!state || !category) {
      return state ? state.items : [];
    }

    return state.items.filter((item: Object) => {
      return (item as Record<string, Object>)['category'] === category;
    });
  }

  /**
   * 获取数据源加载状态
   * @param dataKey 数据源标识
   */
  getLoadState(dataKey: string): DataLoadStateView {
    const state = this.loadStates.get(dataKey);
    if (!state) {
      const emptyState: DataLoadState = {
        metadataLoaded: false,
        fullyLoaded: false,
        loading: false,
        items: [],
        totalItems: 0,
        metadata: null,
        preloadedBatch: null,
        preloadedBatchPage: 0,
        lastError: '数据源未初始化',
      };
      return emptyState;
    }
    return state;
  }

  // ==================== 缓存管理 ====================

  /**
   * 释放指定数据源的内存缓存
   * @param dataKey 数据源标识
   */
  releaseCache(dataKey: string): void {
    const state = this.loadStates.get(dataKey);
    if (state) {
      state.items = [];
      state.preloadedBatch = null;
      state.preloadedBatchPage = 0;
      this.log(`内存缓存已释放: ${dataKey}`);
    }
  }

  /**
   * 释放所有数据源的内存缓存（保留元数据）
   */
  releaseAllCaches(): void {
    this.loadStates.forEach((state, key) => {
      state.items = [];
      state.preloadedBatch = null;
      state.preloadedBatchPage = 0;
      this.log(`内存缓存已释放: ${key}`);
    });
  }

  /**
   * 重置指定数据源（包括元数据）
   * @param dataKey 数据源标识
   */
  reset(dataKey: string): void {
    this.loadStates.delete(dataKey);
    this.log(`数据源已重置: ${dataKey}`);
  }

  // ==================== 私有方法 ====================

  /**
   * 获取或创建数据加载状态
   */
  private getOrCreateState(dataKey: string, filePath: string): DataLoadState {
    let state = this.loadStates.get(dataKey);
    if (!state) {
      state = {
        metadataLoaded: false,
        fullyLoaded: false,
        loading: false,
        items: [],
        totalItems: 0,
        metadata: null,
        preloadedBatch: null,
        preloadedBatchPage: 0,
        lastError: null,
      };
      this.loadStates.set(dataKey, state);
    }
    return state;
  }

  /**
   * 从数据数组中提取指定字段的唯一值
   */
  private extractUniqueValues(dataArray: Object[], field: string): string[] {
    const valueSet = new Set<string>();
    for (let i = 0; i < dataArray.length; i++) {
      const val = (dataArray[i] as Record<string, Object>)[field];
      if (val && typeof val === 'string' && (val as string).length > 0) {
        valueSet.add(val as string);
      }
    }
    return Array.from(valueSet);
  }

  /**
   * Uint8Array 转字符串
   * 使用循环拼接避免展开运算符可能导致的栈溢出
   */
  private uint8ArrayToString(array: Uint8Array): string {
    let str = '';
    for (let i = 0; i < array.length; i++) {
      str += String.fromCharCode(array[i]);
    }
    return str;
  }

  // ==================== 日志 ====================

  private log(message: string): void {
    console.info(`[${TAG}] ${message}`);
  }

  private logError(message: string): void {
    console.error(`[${TAG}] ${message}`);
  }
}
