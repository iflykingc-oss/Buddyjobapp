/**
 * 横向断点类型工具类
 * 根据鸿蒙官方断点规范: xs(0,320) sm[320,600) md[600,840) lg[840,1440) xl[1440,+∞)
 */
export class WidthBreakpointType<T> {
  sm: T;
  md: T;
  lg: T;
  xl: T;

  constructor(sm: T, md: T, lg: T, xl: T) {
    this.sm = sm;
    this.md = md;
    this.lg = lg;
    this.xl = xl;
  }

  getValue(widthBp: string): T {
    switch (widthBp) {
      case 'xs':
      case 'sm':
        return this.sm;
      case 'md':
        return this.md;
      case 'lg':
        return this.lg;
      case 'xl':
      default:
        return this.xl;
    }
  }
}

/**
 * 纵向断点类型工具类
 * 根据鸿蒙官方断点规范: sm(0,0.8) md[0.8,1.2) lg[1.2,+∞)
 */
export class HeightBreakpointType<T> {
  sm: T;
  md: T;
  lg: T;

  constructor(sm: T, md: T, lg: T) {
    this.sm = sm;
    this.md = md;
    this.lg = lg;
  }

  getValue(heightBp: string): T {
    switch (heightBp) {
      case 'sm':
        return this.sm;
      case 'md':
        return this.md;
      case 'lg':
      default:
        return this.lg;
    }
  }
}

// 预定义的常用断点值
export class BreakpointValues {
  // 栅格列数
  static readonly GridColumns = new WidthBreakpointType(4, 8, 12, 12);
  // 栅格间距
  static readonly GridGutter = new WidthBreakpointType(12, 16, 24, 24);
  // 栅格边距
  static readonly GridMargin = new WidthBreakpointType(16, 24, 32, 48);
  // 页面内边距
  static readonly PagePadding = new WidthBreakpointType(16, 20, 32, 48);
  // 卡片圆角
  static readonly CardRadius = new WidthBreakpointType(12, 16, 20, 24);
  // 标题字号
  static readonly TitleFontSize = new WidthBreakpointType(18, 20, 24, 28);
  // 正文字号
  static readonly BodyFontSize = new WidthBreakpointType(14, 14, 16, 16);
  // 列表列数
  static readonly ListColumns = new WidthBreakpointType(1, 1, 2, 3);
  // Tab栏高度
  static readonly TabBarHeight = new WidthBreakpointType(56, 56, 64, 64);
  // 导航栏高度
  static readonly NavBarHeight = new WidthBreakpointType(56, 56, 64, 64);
  // 侧边栏宽度
  static readonly SideBarWidth = new WidthBreakpointType(0, 0, 240, 280);
}
