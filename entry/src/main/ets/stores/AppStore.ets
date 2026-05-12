import { Config } from '../constants/config';

/**
 * 全局应用状态管理
 */
export class AppStore {
  private static instance: AppStore;

  private constructor() {}

  static getInstance(): AppStore {
    if (!AppStore.instance) {
      AppStore.instance = new AppStore();
    }
    return AppStore.instance;
  }

  // 应用初始化状态
  isInitialized(): boolean {
    return AppStorage.get<boolean>('appInitialized') ?? false;
  }

  setInitialized(value: boolean): void {
    AppStorage.setOrCreate('appInitialized', value);
  }

  // 主题模式
  getTheme(): 'light' | 'dark' {
    return AppStorage.get<'light' | 'dark'>('theme') ?? 'light';
  }

  setTheme(theme: 'light' | 'dark'): void {
    AppStorage.setOrCreate('theme', theme);
  }

  // 通知开关
  isNotificationEnabled(): boolean {
    return AppStorage.get<boolean>('notificationEnabled') ?? true;
  }

  setNotificationEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('notificationEnabled', enabled);
  }

  // 声音开关
  isSoundEnabled(): boolean {
    return AppStorage.get<boolean>('soundEnabled') ?? true;
  }

  setSoundEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('soundEnabled', enabled);
  }

  // 获取应用版本
  getAppVersion(): string {
    return AppStorage.get<string>('appVersion') ?? '1.0.1';
  }

  // 获取语言设置
  getLanguage(): string {
    return AppStorage.get<string>('language') ?? 'zh-CN';
  }

  setLanguage(lang: string): void {
    AppStorage.setOrCreate('language', lang);
  }

  // 清除所有应用状态
  clearAll(): void {
    AppStorage.delete('appInitialized');
    AppStorage.delete('theme');
    AppStorage.delete('notificationEnabled');
    AppStorage.delete('soundEnabled');
    AppStorage.delete('language');
    // 清除认证和聊天数据
    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('userInfo', null);
    AppStorage.setOrCreate('chatHistory', '[]');
    AppStorage.setOrCreate('chatSessions', '[]');
  }
}
