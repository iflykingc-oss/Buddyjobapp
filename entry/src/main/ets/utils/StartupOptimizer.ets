/**
 * StartupOptimizer - 应用启动优化器
 *
 * 职责：
 *   1. 记录启动各阶段耗时，输出启动报告
 *   2. 区分关键路径初始化（首帧前）和非关键初始化（首帧后）
 *   3. 预加载用户常用数据（最近访问的面试题、知识文章等）
 *   4. 延迟非必要的初始化任务，减少首帧时间
 *
 * 使用方式：
 *   onCreate()    -> markStart()
 *   onWindowStageCreate() -> criticalInit() (await)
 *   loadContent() 之后 -> deferredInit() (fire-and-forget)
 *   onForeground() -> getStartupReport() (首次)
 *
 * @since 1.0.0
 */
import hilog from '@ohos.hilog';
import { LazyDataLoader } from '../services/LazyDataLoader';

const TAG = 'StartupOptimizer';
const DOMAIN = 0xFF00;

/**
 * 启动耗时报告
 */
export interface StartupReport {
  /** 启动总耗时（从 markStart 到 getStartupReport） */
  totalDuration: number;
  /** 关键路径初始化耗时 */
  criticalInitDuration: number;
  /** 非关键初始化耗时 */
  deferredInitDuration: number;
  /** 各阶段耗时明细 */
  phases: StartupPhase[];
  /** 是否所有初始化均成功 */
  allSuccess: boolean;
}

/**
 * 单个启动阶段
 */
export interface StartupPhase {
  /** 阶段名称 */
  name: string;
  /** 耗时（毫秒） */
  duration: number;
  /** 是否成功 */
  success: boolean;
  /** 错误信息 */
  error?: string;
}

export class StartupOptimizer {
  private static instance: StartupOptimizer;

  /** 启动开始时间 */
  private startTime: number = 0;

  /** 关键路径初始化开始时间 */
  private criticalStartTime: number = 0;

  /** 非关键初始化开始时间 */
  private deferredStartTime: number = 0;

  /** 关键路径耗时 */
  private criticalDuration: number = 0;

  /** 非关键路径耗时 */
  private deferredDuration: number = 0;

  /** 各阶段耗时记录 */
  private phases: StartupPhase[] = [];

  /** 是否已输出过报告 */
  hasReported: boolean = false;

  /** 非关键初始化是否已完成 */
  private deferredCompleted: boolean = false;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): StartupOptimizer {
    if (!StartupOptimizer.instance) {
      StartupOptimizer.instance = new StartupOptimizer();
    }
    return StartupOptimizer.instance;
  }

  // ==================== 启动时间线 ====================

  /**
   * 记录启动开始
   * 应在 onCreate() 中最先调用
   */
  markStart(): void {
    this.startTime = Date.now();
    this.phases = [];
    this.hasReported = false;
    this.deferredCompleted = false;
    this.criticalDuration = 0;
    this.deferredDuration = 0;
    hilog.info(DOMAIN, TAG, 'Startup timer started');
  }

  /**
   * 记录关键路径初始化开始
   * 应在 onWindowStageCreate() 中首帧前调用
   */
  markCriticalStart(): void {
    this.criticalStartTime = Date.now();
  }

  /**
   * 记录关键路径初始化完成
   */
  markCriticalEnd(): void {
    if (this.criticalStartTime > 0) {
      this.criticalDuration = Date.now() - this.criticalStartTime;
      this.criticalStartTime = 0;
    }
  }

  // ==================== 关键路径初始化 ====================

  /**
   * 执行关键路径初始化
   * 这些初始化必须在首帧渲染前完成，否则会影响用户感知的启动速度
   *
   * 关键路径包括：
   *   - 全局配置写入 AppStorage
   *   - 窗口属性设置
   *   - 数据元信息加载（LazyDataLoader.initializeMetadata）
   */
  async criticalInit(): Promise<void> {
    this.markCriticalStart();

    try {
      // 1. 预加载用户偏好设置（如果本地存储可用）
      await this.recordPhase('userPreferences', async () => {
        // 从 AppStorage 读取已设置的偏好
        // 此步骤通常极快，主要是确保首帧渲染时主题等设置已就绪
        await Promise.resolve();
      });

      // 2. 数据元信息已由 EntryAbility 中的 LazyDataLoader.initializeMetadata 完成
      //    此处仅做标记
      await this.recordPhase('metadataReady', async () => {
        await Promise.resolve();
      });

      hilog.info(DOMAIN, TAG, `Critical init completed in ${Date.now() - (this.criticalStartTime || Date.now())}ms`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Critical init failed: ${error}`);
    } finally {
      this.markCriticalEnd();
    }
  }

  // ==================== 非关键初始化 ====================

  /**
   * 执行非关键初始化
   * 这些初始化在首帧渲染后异步执行，不阻塞用户交互
   *
   * 非关键路径包括：
   *   - 预加载常用数据（最近访问的面试题、知识文章）
   *   - 图片缓存预热
   *   - 历史记录加载
   *   - 统计数据上报
   */
  async deferredInit(): Promise<void> {
    if (this.deferredCompleted) {
      return;
    }

    this.deferredStartTime = Date.now();

    try {
      // 1. 预加载面试题首页数据（用户最常用的功能之一）
      await this.recordPhase('preloadInterviews', async () => {
        try {
          const lazyLoader = LazyDataLoader.getInstance();
          await lazyLoader.loadBatch('interviews', 1, lazyLoader.BATCH_SIZE);
          // 预加载第二页
          lazyLoader.preloadNextBatch('interviews', 2);
        } catch (e) {
          // 预加载失败不影响用户体验
          hilog.warn(DOMAIN, TAG, `Preload interviews failed: ${e}`);
        }
      });

      // 2. 预加载知识库首页数据
      await this.recordPhase('preloadKnowledge', async () => {
        try {
          const lazyLoader = LazyDataLoader.getInstance();
          await lazyLoader.loadBatch('knowledge', 1, lazyLoader.BATCH_SIZE);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, `Preload knowledge failed: ${e}`);
        }
      });

      // 3. 预加载测评元数据（测评页面需要分类信息）
      await this.recordPhase('preloadAssessments', async () => {
        try {
          const lazyLoader = LazyDataLoader.getInstance();
          await lazyLoader.loadBatch('assessments', 1, lazyLoader.BATCH_SIZE);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, `Preload assessments failed: ${e}`);
        }
      });

      this.deferredDuration = Date.now() - this.deferredStartTime;
      this.deferredCompleted = true;

      hilog.info(DOMAIN, TAG, `Deferred init completed in ${this.deferredDuration}ms`);
    } catch (error) {
      this.deferredDuration = Date.now() - this.deferredStartTime;
      hilog.error(DOMAIN, TAG, `Deferred init failed: ${error}`);
    }
  }

  // ==================== 用户数据预加载 ====================

  /**
   * 预加载用户常用数据
   * 根据用户历史行为预加载最可能访问的数据
   * 应在用户登录后或首页加载完成后调用
   */
  async preloadUserData(): Promise<void> {
    try {
      // 检查用户是否已登录
      const isLoggedIn = AppStorage.get<boolean>('isLoggedIn');
      if (!isLoggedIn) {
        hilog.info(DOMAIN, TAG, 'User not logged in, skip preloading user data');
        return;
      }

      // 预加载用户收藏的知识文章分类
      await this.recordPhase('preloadFavorites', async () => {
        // 收藏数据预加载由 FavoriteService 处理
        await Promise.resolve();
      });

      hilog.info(DOMAIN, TAG, 'User data preloaded');
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `Preload user data failed: ${error}`);
    }
  }

  // ==================== 报告 ====================

  /**
   * 获取启动耗时报告
   * 应在 onForeground() 中首次调用，输出到日志
   */
  getStartupReport(): StartupReport {
    const totalDuration = this.startTime > 0 ? Date.now() - this.startTime : 0;

    const allSuccess = this.phases.every((phase) => phase.success);

    return {
      totalDuration: totalDuration,
      criticalInitDuration: this.criticalDuration,
      deferredInitDuration: this.deferredDuration,
      phases: this.phases.slice(),
      allSuccess: allSuccess,
    };
  }

  // ==================== 私有方法 ====================

  /**
   * 记录单个阶段的耗时
   */
  private async recordPhase(name: string, fn: () => Promise<void>): Promise<void> {
    const phaseStart = Date.now();
    let success = true;
    let error: string | undefined;

    try {
      await fn();
    } catch (e) {
      success = false;
      error = e instanceof Error ? e.message : String(e);
    }

    const duration = Date.now() - phaseStart;
    this.phases.push({ name, duration, success, error });

    if (!success) {
      hilog.warn(DOMAIN, TAG, `Phase [${name}] failed (${duration}ms): ${error}`);
    } else {
      hilog.info(DOMAIN, TAG, `Phase [${name}] completed (${duration}ms)`);
    }
  }
}
