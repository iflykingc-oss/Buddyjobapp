import { Config, Environment } from '../constants/config';
import { NetworkUtil, ConnectionType, NetworkChangeCallback } from '../utils/NetworkUtil';

/**
 * 应用生命周期状态
 */
export type AppLifecycleState = 'FOREGROUND' | 'BACKGROUND' | 'INACTIVE';

/**
 * 应用配置接口
 */
export interface AppConfig {
  apiBaseUrl: string;
  env: 'development' | 'testing' | 'production';
  enableLogging: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}

/**
 * 功能开关接口
 */
export interface FeatureFlag {
  key: string;
  enabled: boolean;
  description: string;
}

/**
 * 网络状态信息接口
 */
export interface NetworkState {
  isOnline: boolean;
  connectionType: ConnectionType;
  lastNetworkChange: number;
}

/**
 * 全局应用状态管理
 * 包含网络状态监控、功能开关、应用配置等
 */
export class AppStore {
  private static instance: AppStore;
  private networkUtil: NetworkUtil;
  private networkChangeCallback: NetworkChangeCallback | null = null;
  private networkCheckTimer: number | null = null;

  private constructor() {
    this.networkUtil = NetworkUtil.getInstance();
  }

  static getInstance(): AppStore {
    if (!AppStore.instance) {
      AppStore.instance = new AppStore();
    }
    return AppStore.instance;
  }

  // ============================================
  // 应用初始化状态
  // ============================================
  isInitialized(): boolean {
    return AppStorage.get<boolean>('appInitialized') ?? false;
  }

  setInitialized(value: boolean): void {
    AppStorage.setOrCreate('appInitialized', value);
  }

  // ============================================
  // 主题模式
  // ============================================
  getTheme(): 'light' | 'dark' {
    return AppStorage.get<'light' | 'dark'>('theme') ?? 'light';
  }

  setTheme(theme: 'light' | 'dark'): void {
    AppStorage.setOrCreate('theme', theme);
  }

  // ============================================
  // 通知开关
  // ============================================
  isNotificationEnabled(): boolean {
    return AppStorage.get<boolean>('notificationEnabled') ?? true;
  }

  setNotificationEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('notificationEnabled', enabled);
  }

  // ============================================
  // 声音开关
  // ============================================
  isSoundEnabled(): boolean {
    return AppStorage.get<boolean>('soundEnabled') ?? true;
  }

  setSoundEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('soundEnabled', enabled);
  }

  // ============================================
  // 获取应用版本
  // ============================================
  getAppVersion(): string {
    return AppStorage.get<string>('appVersion') ?? '1.0.1';
  }

  // ============================================
  // 获取语言设置
  // ============================================
  getLanguage(): string {
    return AppStorage.get<string>('language') ?? 'zh-CN';
  }

  setLanguage(lang: string): void {
    AppStorage.setOrCreate('language', lang);
  }

  // ============================================
  // 网络状态管理
  // ============================================

  /**
   * 获取网络状态
   */
  getNetworkState(): NetworkState {
    return {
      isOnline: AppStorage.get<boolean>('isOnline') ?? true,
      connectionType: AppStorage.get<string>('connectionType') as ConnectionType ?? ConnectionType.UNKNOWN,
      lastNetworkChange: AppStorage.get<number>('lastNetworkChange') ?? 0
    };
  }

  /**
   * 获取网络是否在线
   */
  isOnline(): boolean {
    return AppStorage.get<boolean>('isOnline') ?? true;
  }

  /**
   * 获取连接类型
   */
  getConnectionType(): ConnectionType {
    return AppStorage.get<string>('connectionType') as ConnectionType ?? ConnectionType.UNKNOWN;
  }

  /**
   * 检查网络状态
   */
  async checkNetworkStatus(): Promise<void> {
    try {
      const isAvailable = await this.networkUtil.isNetworkAvailable();
      const connectionType = await this.networkUtil.getConnectionType();

      AppStorage.setOrCreate('isOnline', isAvailable);
      AppStorage.setOrCreate('connectionType', connectionType);
      AppStorage.setOrCreate('lastNetworkChange', Date.now());

      console.info(`[AppStore] Network status: online=${isAvailable}, type=${connectionType}`);
    } catch (error) {
      console.error('[AppStore] Failed to check network status:', JSON.stringify(error));
      AppStorage.setOrCreate('isOnline', false);
      AppStorage.setOrCreate('connectionType', ConnectionType.NONE);
    }
  }

  /**
   * 开始网络状态监控
   */
  startNetworkMonitoring(): void {
    if (this.networkChangeCallback) {
      console.info('[AppStore] Network monitoring already started');
      return;
    }

    // 初始检查
    this.checkNetworkStatus();

    // 注册网络变化监听
    this.networkChangeCallback = (type: ConnectionType) => {
      const isOnline = type !== ConnectionType.NONE && type !== ConnectionType.UNKNOWN;
      AppStorage.setOrCreate('isOnline', isOnline);
      AppStorage.setOrCreate('connectionType', type);
      AppStorage.setOrCreate('lastNetworkChange', Date.now());
      console.info(`[AppStore] Network changed: type=${type}, isOnline=${isOnline}`);
    };

    this.networkUtil.onNetworkChange(this.networkChangeCallback);
    console.info('[AppStore] Network monitoring started');
  }

  /**
   * 停止网络状态监控
   */
  stopNetworkMonitoring(): void {
    if (this.networkChangeCallback) {
      this.networkUtil.offNetworkChange(this.networkChangeCallback);
      this.networkChangeCallback = null;
      console.info('[AppStore] Network monitoring stopped');
    }

    if (this.networkCheckTimer !== null) {
      clearInterval(this.networkCheckTimer);
      this.networkCheckTimer = null;
    }
  }

  /**
   * 获取网络类型
   */
  getNetworkType(): ConnectionType {
    return AppStorage.get<string>('connectionType') as ConnectionType ?? ConnectionType.UNKNOWN;
  }

  /**
   * 获取网络类型描述
   */
  getNetworkTypeDesc(): string {
    const type = this.getNetworkType();
    const descMap: Record<ConnectionType, string> = {
      [ConnectionType.WIFI]: 'WiFi',
      [ConnectionType.CELLULAR]: '移动数据',
      [ConnectionType.ETHERNET]: '以太网',
      [ConnectionType.NONE]: '无网络',
      [ConnectionType.UNKNOWN]: '未知'
    };
    return descMap[type] || '未知';
  }

  // ============================================
  // 功能开关管理
  // ============================================

  /**
   * 获取所有功能开关
   */
  getFeatureFlags(): Record<string, boolean> {
    const stored = AppStorage.get<string>('featureFlags');
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch (e) {
        return this.getDefaultFeatureFlags();
      }
    }
    return this.getDefaultFeatureFlags();
  }

  /**
   * 获取默认功能开关
   */
  private getDefaultFeatureFlags(): Record<string, boolean> {
    return {
      enableAIChat: true,
      enableVoiceInterview: true,
      enableResumeAnalysis: true,
      enableAssessment: true,
      enableOfferAnalysis: true,
      enableKanban: true,
      enableResumeOptimization: true,
      enableCrossDevice: true,
      enableDistributed: true,
      enableXiaoyiAgent: true,
      enableContinuation: true,
      enableNewFeatureX: false
    };
  }

  /**
   * 保存功能开关
   */
  private saveFeatureFlags(flags: Record<string, boolean>): void {
    AppStorage.setOrCreate('featureFlags', JSON.stringify(flags));
  }

  /**
   * 检查功能是否启用
   */
  isFeatureEnabled(key: string): boolean {
    const flags = this.getFeatureFlags();
    return flags[key] ?? false;
  }

  /**
   * 启用功能
   */
  enableFeature(key: string): void {
    const flags = this.getFeatureFlags();
    flags[key] = true;
    this.saveFeatureFlags(flags);
    console.info(`[AppStore] Feature enabled: ${key}`);
  }

  /**
   * 禁用功能
   */
  disableFeature(key: string): void {
    const flags = this.getFeatureFlags();
    flags[key] = false;
    this.saveFeatureFlags(flags);
    console.info(`[AppStore] Feature disabled: ${key}`);
  }

  /**
   * 切换功能状态
   */
  toggleFeature(key: string): boolean {
    const current = this.isFeatureEnabled(key);
    if (current) {
      this.disableFeature(key);
    } else {
      this.enableFeature(key);
    }
    return !current;
  }

  /**
   * 加载功能开关
   */
  async loadFeatureFlags(): Promise<void> {
    // 如果存储中没有功能开关，使用默认值
    const stored = AppStorage.get<string>('featureFlags');
    if (!stored) {
      const defaults = this.getDefaultFeatureFlags();
      // 合并配置中的功能开关
      const configFlags = Config.featureFlags || {};
      const mergedFlags = { ...defaults, ...configFlags };
      this.saveFeatureFlags(mergedFlags);
      console.info('[AppStore] Feature flags loaded with defaults');
    } else {
      console.info('[AppStore] Feature flags loaded from storage');
    }
  }

  /**
   * 重置功能开关到默认值
   */
  resetFeatureFlags(): void {
    const defaults = this.getDefaultFeatureFlags();
    this.saveFeatureFlags(defaults);
    console.info('[AppStore] Feature flags reset to defaults');
  }

  // ============================================
  // 应用生命周期状态
  // ============================================

  /**
   * 获取应用状态
   */
  getAppState(): AppLifecycleState {
    return AppStorage.get<string>('appState') as AppLifecycleState ?? 'FOREGROUND';
  }

  /**
   * 获取应用是否活跃
   */
  isAppActive(): boolean {
    return AppStorage.get<boolean>('isActive') ?? true;
  }

  /**
   * 设置应用状态
   */
  setAppState(state: AppLifecycleState): void {
    const isActive = state === 'FOREGROUND';
    AppStorage.setOrCreate('appState', state);
    AppStorage.setOrCreate('isActive', isActive);
    if (isActive) {
      AppStorage.setOrCreate('lastActiveTime', Date.now());
    }
    console.info(`[AppStore] App state changed: ${state}, isActive=${isActive}`);
  }

  /**
   * 获取应用运行时长（毫秒）
   */
  getAppUptime(): number {
    const startTime = AppStorage.get<number>('appStartTime');
    if (startTime) {
      return Date.now() - startTime;
    }
    return 0;
  }

  /**
   * 获取应用启动时间戳
   */
  getAppStartTime(): number {
    let startTime = AppStorage.get<number>('appStartTime');
    if (!startTime) {
      startTime = Date.now();
      AppStorage.setOrCreate('appStartTime', startTime);
    }
    return startTime;
  }

  /**
   * 获取上次活跃时间
   */
  getLastActiveTime(): number {
    return AppStorage.get<number>('lastActiveTime') ?? 0;
  }

  // ============================================
  // 应用配置管理
  // ============================================

  /**
   * 获取应用配置
   */
  getConfig(): AppConfig {
    const stored = AppStorage.get<string>('appConfig');
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch (e) {
        return this.getDefaultConfig();
      }
    }
    return this.getDefaultConfig();
  }

  /**
   * 获取默认配置
   */
  private getDefaultConfig(): AppConfig {
    return {
      apiBaseUrl: Config.API_BASE_URL,
      env: 'production',
      enableLogging: true,
      logLevel: 'info'
    };
  }

  /**
   * 保存应用配置
   */
  private saveConfig(config: AppConfig): void {
    AppStorage.setOrCreate('appConfig', JSON.stringify(config));
  }

  /**
   * 更新应用配置
   */
  updateConfig(updates: Partial<AppConfig>): void {
    const current = this.getConfig();
    const updated = { ...current, ...updates };
    this.saveConfig(updated);
    console.info('[AppStore] App config updated:', JSON.stringify(updates));
  }

  /**
   * 加载应用配置
   */
  async loadConfig(): Promise<void> {
    const stored = AppStorage.get<string>('appConfig');
    if (!stored) {
      // 根据环境设置默认配置
      const env = Config.environment;
      const defaultConfig = this.getDefaultConfig();
      defaultConfig.env = env;
      defaultConfig.apiBaseUrl = Config.API_BASE_URL;
      this.saveConfig(defaultConfig);
      console.info(`[AppStore] Config loaded for environment: ${env}`);
    } else {
      console.info('[AppStore] Config loaded from storage');
    }
  }

  /**
   * 获取当前环境
   */
  getEnvironment(): 'development' | 'testing' | 'production' {
    return this.getConfig().env;
  }

  /**
   * 是否是生产环境
   */
  isProduction(): boolean {
    return this.getEnvironment() === 'production';
  }

  /**
   * 是否启用日志
   */
  isLoggingEnabled(): boolean {
    return this.getConfig().enableLogging;
  }

  // ============================================
  // 清除所有应用状态
  // ============================================
  clearAll(): void {
    AppStorage.delete('appInitialized');
    AppStorage.delete('theme');
    AppStorage.delete('notificationEnabled');
    AppStorage.delete('soundEnabled');
    AppStorage.delete('language');
    // 网络状态保留
    // 功能开关保留
    // 应用配置保留
    // 清除认证和聊天数据
    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('userInfo', null);
    AppStorage.setOrCreate('chatHistory', '[]');
    AppStorage.setOrCreate('chatSessions', '[]');
    console.info('[AppStore] All app state cleared');
  }

  // ============================================
  // 初始化
  // ============================================

  /**
   * 完整初始化
   */
  async initialize(): Promise<void> {
    console.info('[AppStore] Initializing...');

    // 记录启动时间
    this.getAppStartTime();

    // 加载配置
    await this.loadConfig();

    // 加载功能开关
    await this.loadFeatureFlags();

    // 开始网络监控
    this.startNetworkMonitoring();

    // 初始网络检查
    await this.checkNetworkStatus();

    this.setInitialized(true);
    console.info('[AppStore] Initialization complete');
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.stopNetworkMonitoring();
    console.info('[AppStore] Resources cleaned up');
  }
}

// ============================================
// 全局状态观察者
// ============================================

/**
 * 观察网络状态
 */
export function useNetworkState(): NetworkState {
  const isOnline = AppStorage.get<boolean>('isOnline') ?? true;
  const connectionType = AppStorage.get<string>('connectionType') as ConnectionType ?? ConnectionType.UNKNOWN;
  const lastNetworkChange = AppStorage.get<number>('lastNetworkChange') ?? 0;

  return {
    isOnline,
    connectionType,
    lastNetworkChange
  };
}

/**
 * 观察应用状态
 */
export function useAppState(): AppLifecycleState {
  return AppStorage.get<string>('appState') as AppLifecycleState ?? 'FOREGROUND';
}

/**
 * 观察功能开关
 */
export function useFeatureFlag(key: string): boolean {
  const flags = AppStore.getInstance().getFeatureFlags();
  return flags[key] ?? false;
}

/**
 * 获取 AppStore 单例快捷方法
 */
export const appStore = AppStore.getInstance();
