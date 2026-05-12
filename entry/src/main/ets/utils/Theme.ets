import { AppStorage } from '@kit.ArkUI';
import uiAppearance from '@ohos.uiAppearance';

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
    this.onSystemThemeChange();
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
      try {
        const colorMode = uiAppearance.getColorMode();
        isDark = colorMode === uiAppearance.ColorMode.DARK;
      } catch (e) {
        isDark = false;
      }
    }
    AppStorage.setOrCreate('isDarkMode', isDark);
  }

  // 监听系统主题变化
  onSystemThemeChange(): void {
    try {
      uiAppearance.on('colorModeChange', (colorMode: uiAppearance.ColorMode) => {
        const currentMode = AppStorage.get<string>('themeMode');
        if (currentMode === ThemeMode.SYSTEM) {
          const isDark = colorMode === uiAppearance.ColorMode.DARK;
          AppStorage.setOrCreate('isDarkMode', isDark);
        }
      });
    } catch (e) {
      console.error('[ThemeManager] Failed to register color mode change listener');
    }
  }

  // 获取当前是否暗黑模式
  isDark(): boolean {
    return AppStorage.get<boolean>('isDarkMode') || false;
  }
}

export default ThemeManager;
