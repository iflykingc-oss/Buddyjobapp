import { AppStorage } from '@kit.ArkUI';

// 主题模式
export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  SYSTEM = 'system'
}

// 主题管理器
export class ThemeManager {
  private static instance: ThemeManager;

  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  // 初始化主题
  init(): void {
    // 从本地存储读取用户设置，默认跟随系统
    const savedMode = AppStorage.get<string>('themeMode') || ThemeMode.SYSTEM;
    AppStorage.setOrCreate('themeMode', savedMode);
    this.applyTheme(savedMode);
  }

  // 设置主题模式
  setThemeMode(mode: ThemeMode): void {
    AppStorage.setOrCreate('themeMode', mode);
    this.applyTheme(mode);
  }

  // 应用主题
  private applyTheme(mode: ThemeMode): void {
    let isDark = false;
    if (mode === ThemeMode.DARK) {
      isDark = true;
    } else if (mode === ThemeMode.SYSTEM) {
      // 跟随系统主题
      isDark = false; // 默认浅色，实际应读取系统设置
    }
    AppStorage.setOrCreate('isDarkMode', isDark);
  }

  // 获取当前是否暗黑模式
  isDark(): boolean {
    return AppStorage.get<boolean>('isDarkMode') || false;
  }
}

export default ThemeManager;
