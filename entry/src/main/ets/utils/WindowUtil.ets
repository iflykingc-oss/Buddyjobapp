/**
 * WindowUtil - 窗口工具类
 *
 * 提供窗口尺寸监听、断点判断和响应式布局辅助方法。
 * 配合鸿蒙 GridRow/GridCol 栅格组件和断点系统使用。
 *
 * 断点定义（与鸿蒙官方一致）：
 * - sm: >= 320vp（手机竖屏）
 * - md: >= 520vp（手机横屏/小平板）
 * - lg: >= 840vp（平板）
 * - xl: >= 1240vp（大屏/桌面）
 * - xxl: >= 1880vp（超大屏）
 */

import window from '@ohos.window';

/**
 * 断点枚举
 */
export enum BreakpointType {
  SM = 'sm',   // >= 320vp
  MD = 'md',   // >= 520vp
  LG = 'lg',   // >= 840vp
  XL = 'xl',   // >= 1240vp
  XXL = 'xxl', // >= 1880vp
}

/**
 * 断点阈值（单位：vp）
 */
const BREAKPOINT_VALUES: Record<BreakpointType, number> = {
  [BreakpointType.SM]: 320,
  [BreakpointType.MD]: 520,
  [BreakpointType.LG]: 840,
  [BreakpointType.XL]: 1240,
  [BreakpointType.XXL]: 1880,
};

export class WindowUtil {
  private currentBreakpoint: BreakpointType = BreakpointType.SM;
  private windowWidth: number = 0;
  private windowHeight: number = 0;
  private listenerId: number = -1;

  /**
   * 初始化窗口监听
   * 应在 EntryAbility.onWindowStageCreate 或页面 aboutToAppear 中调用
   */
  async init(): Promise<void> {
    try {
      const windowInstance = await window.getLastWindow(getContext());
      const windowProperties = windowInstance.getWindowProperties();
      this.windowWidth = windowProperties.windowRect.width;
      this.windowHeight = windowProperties.windowRect.height;
      this.updateBreakpoint();

      // 监听窗口尺寸变化
      this.listenerId = windowInstance.on('windowSizeChange', (windowSize) => {
        this.windowWidth = windowSize.width;
        this.windowHeight = windowSize.height;
        this.updateBreakpoint();
      });

      // 初始化存入 AppStorage
      AppStorage.setOrCreate('windowUtil', this);
      AppStorage.setOrCreate('currentBreakpoint', this.currentBreakpoint);
    } catch (error) {
      console.error('[WindowUtil] Init failed:', error);
      // 默认设置为 sm 断点
      this.currentBreakpoint = BreakpointType.SM;
      AppStorage.setOrCreate('windowUtil', this);
      AppStorage.setOrCreate('currentBreakpoint', this.currentBreakpoint);
    }
  }

  /**
   * 根据窗口宽度更新断点
   */
  private updateBreakpoint(): void {
    const oldBreakpoint = this.currentBreakpoint;

    if (this.windowWidth >= BREAKPOINT_VALUES[BreakpointType.XXL]) {
      this.currentBreakpoint = BreakpointType.XXL;
    } else if (this.windowWidth >= BREAKPOINT_VALUES[BreakpointType.XL]) {
      this.currentBreakpoint = BreakpointType.XL;
    } else if (this.windowWidth >= BREAKPOINT_VALUES[BreakpointType.LG]) {
      this.currentBreakpoint = BreakpointType.LG;
    } else if (this.windowWidth >= BREAKPOINT_VALUES[BreakpointType.MD]) {
      this.currentBreakpoint = BreakpointType.MD;
    } else {
      this.currentBreakpoint = BreakpointType.SM;
    }

    if (oldBreakpoint !== this.currentBreakpoint) {
      AppStorage.setOrCreate('currentBreakpoint', this.currentBreakpoint);
    }
  }

  /**
   * 获取当前断点
   */
  getCurrentBreakpoint(): BreakpointType {
    return this.currentBreakpoint;
  }

  /**
   * 获取窗口宽度
   */
  getWindowWidth(): number {
    return this.windowWidth;
  }

  /**
   * 获取窗口高度
   */
  getWindowHeight(): number {
    return this.windowHeight;
  }

  /**
   * 是否为手机竖屏（sm 断点）
   */
  isPhone(): boolean {
    return this.currentBreakpoint === BreakpointType.SM;
  }

  /**
   * 是否为中等屏幕（md 断点，手机横屏/小平板）
   */
  isMedium(): boolean {
    return this.currentBreakpoint === BreakpointType.MD;
  }

  /**
   * 是否为平板（lg 断点）
   */
  isTablet(): boolean {
    return this.currentBreakpoint === BreakpointType.LG;
  }

  /**
   * 是否为宽屏（lg 及以上，平板/大屏/桌面）
   */
  isWideScreen(): boolean {
    return this.currentBreakpoint === BreakpointType.LG ||
      this.currentBreakpoint === BreakpointType.XL ||
      this.currentBreakpoint === BreakpointType.XXL;
  }

  /**
   * 是否为超大屏（xl 及以上）
   */
  isLargeScreen(): boolean {
    return this.currentBreakpoint === BreakpointType.XL ||
      this.currentBreakpoint === BreakpointType.XXL;
  }

  /**
   * 获取内容区域最大宽度（宽屏时限制内容宽度，提升阅读体验）
   */
  getContentMaxWidth(): string {
    switch (this.currentBreakpoint) {
      case BreakpointType.XXL:
        return '1200vp';
      case BreakpointType.XL:
        return '1000vp';
      case BreakpointType.LG:
        return '840vp';
      default:
        return '100%';
    }
  }

  /**
   * 获取内容区域水平内边距（宽屏时增加内边距）
   */
  getContentPaddingH(): number {
    switch (this.currentBreakpoint) {
      case BreakpointType.XXL:
        return 64;
      case BreakpointType.XL:
        return 48;
      case BreakpointType.LG:
        return 32;
      default:
        return 16;
    }
  }

  /**
   * 获取列表列数（根据屏幕宽度）
   */
  getListLanes(defaultLanes: number = 1): number {
    switch (this.currentBreakpoint) {
      case BreakpointType.XXL:
        return Math.max(defaultLanes, 3);
      case BreakpointType.XL:
        return Math.max(defaultLanes, 3);
      case BreakpointType.LG:
        return Math.max(defaultLanes, 2);
      default:
        return defaultLanes;
    }
  }

  /**
   * 清理监听
   */
  async destroy(): Promise<void> {
    if (this.listenerId !== -1) {
      try {
        const windowInstance = await window.getLastWindow(getContext());
        windowInstance.off('windowSizeChange', this.listenerId);
      } catch (error) {
        console.error('[WindowUtil] Destroy failed:', error);
      }
      this.listenerId = -1;
    }
  }
}
