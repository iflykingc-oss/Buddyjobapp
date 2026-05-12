/**
 * 一职搭子 设计系统 - 鸿蒙端常量
 *
 * 本文件定义了一职搭子应用的设计令牌（Design Tokens），
 * 与 Web 端保持一致，确保跨平台视觉统一。
 */

// ============================================
// 品牌色 (Brand Colors) - 温暖紫
// ============================================
export const BrandColors = {
  /** 最浅背景 */
  Brand50: '#F5F3FF',
  /** 浅色背景 */
  Brand100: '#EDE9FE',
  /** 边框、分隔 */
  Brand200: '#DDD6FE',
  /** 禁用状态 */
  Brand300: '#C4B5FD',
  /** 悬停状态 */
  Brand400: '#A78BFA',
  /** 主色 */
  Brand500: '#8B5CF6',
  /** 按下状态 */
  Brand600: '#7C3AED',
  /** 深色强调 */
  Brand700: '#6D28D9',
  /** 深色背景 */
  Brand800: '#5B21B6',
  /** 最深背景 */
  Brand900: '#4C1D95',
  /** 极深背景 */
  Brand950: '#2E1065',
} as const;

// ============================================
// 中性色 (Neutral Colors) - 暖灰
// ============================================
export const NeutralColors = {
  /** 纯白 */
  Neutral0: '#FFFFFF',
  /** 页面背景 */
  Neutral50: '#FAFAF9',
  /** 卡片背景 */
  Neutral100: '#F5F5F4',
  /** 边框、分隔线 */
  Neutral200: '#E7E5E4',
  /** 强边框 */
  Neutral300: '#D6D3D1',
  /** 禁用文字 */
  Neutral400: '#A8A29E',
  /** 三级文字 */
  Neutral500: '#78716C',
  /** 二级文字 */
  Neutral600: '#57534E',
  /** 深色文字 */
  Neutral700: '#44403C',
  /** 深色背景 */
  Neutral800: '#292524',
  /** 更深背景 */
  Neutral900: '#1C1917',
  /** 最深背景/主文字 */
  Neutral950: '#0C0A09',
} as const;

// ============================================
// 功能色 (Functional Colors)
// ============================================
export const SuccessColors = {
  /** 成功背景 */
  Success50: '#F0FDF4',
  /** 主色 */
  Success500: '#22C55E',
  /** 深色成功 */
  Success900: '#14532D',
} as const;

export const WarningColors = {
  /** 警告背景 */
  Warning50: '#FFFBEB',
  /** 主色 */
  Warning500: '#F59E0B',
  /** 深色警告 */
  Warning900: '#78350F',
} as const;

export const ErrorColors = {
  /** 错误背景 */
  Error50: '#FEF2F2',
  /** 主色 */
  Error500: '#EF4444',
  /** 深色错误 */
  Error900: '#7F1D1D',
} as const;

// ============================================
// 语义色 - Light Mode (Semantic Colors)
// ============================================
export const SemanticColors = {
  // 背景色
  /** 页面背景 */
  Background: NeutralColors.Neutral0,
  /** 卡片表面 */
  Surface1: NeutralColors.Neutral50,
  /** 二级表面 */
  Surface2: NeutralColors.Neutral100,
  /** 输入框背景 */
  Surface3: NeutralColors.Neutral200,

  // 边框色
  /** 微妙边框 */
  Border: NeutralColors.Neutral200,
  /** 明显边框 */
  BorderStrong: NeutralColors.Neutral300,

  // 文本色
  /** 主文本 */
  Text1: NeutralColors.Neutral950,
  /** 二级文本 */
  Text2: NeutralColors.Neutral600,
  /** 三级文本 */
  Text3: NeutralColors.Neutral500,
  /** 禁用文本 */
  Text4: NeutralColors.Neutral400,

  // 强调色
  /** 强调色 */
  Accent: BrandColors.Brand500,
  /** 强调色背景 */
  AccentSubtle: BrandColors.Brand50,

  // 功能色
  /** 成功色 */
  Success: SuccessColors.Success500,
  /** 警告色 */
  Warning: WarningColors.Warning500,
  /** 错误色 */
  Error: ErrorColors.Error500,
} as const;

// ============================================
// 语义色 - Dark Mode
// ============================================
export const DarkSemanticColors = {
  // 背景色
  Background: NeutralColors.Neutral950,
  Surface1: NeutralColors.Neutral900,
  Surface2: NeutralColors.Neutral800,
  Surface3: NeutralColors.Neutral700,

  // 边框色
  Border: NeutralColors.Neutral800,
  BorderStrong: NeutralColors.Neutral700,

  // 文本色
  Text1: NeutralColors.Neutral50,
  Text2: NeutralColors.Neutral400,
  Text3: NeutralColors.Neutral500,
  Text4: NeutralColors.Neutral600,

  // 强调色
  Accent: BrandColors.Brand400,
  AccentSubtle: BrandColors.Brand950,

  // 功能色
  Success: SuccessColors.Success500,
  Warning: WarningColors.Warning500,
  Error: ErrorColors.Error500,
} as const;

// ============================================
// 间距系统 (Spacing) - 8px 网格
// ============================================
export const Spacing = {
  /** 无间距 */
  Space0: 0,
  /** 光学微调 2px */
  Space1: 2,
  /** 紧凑间距 4px */
  Space2: 4,
  /** 小间距 8px */
  Space3: 8,
  /** 中小间距 12px */
  Space4: 12,
  /** 标准间距 16px */
  Space5: 16,
  /** 中等间距 20px */
  Space6: 20,
  /** 大间距 24px */
  Space7: 24,
  /** 区块间距 32px */
  Space8: 32,
  /** 主要区块分隔 48px */
  Space9: 48,
  /** 屏幕区块划分 64px */
  Space10: 64,
  /** 大型区块分隔 96px */
  Space11: 96,
} as const;

// 语义化间距
export const SemanticSpacing = {
  /** 光学微调 */
  Xs: Spacing.Space1,
  /** 图标与标签间隙 */
  Sm: Spacing.Space2,
  /** 组件内部间距 */
  Md: Spacing.Space3,
  /** 标准间距 */
  Lg: Spacing.Space5,
  /** 卡片内边距 */
  Xl: Spacing.Space7,
  /** 区块间距 */
  Xxl: Spacing.Space8,
  /** 主要区块分隔 */
  Xxl2: Spacing.Space9,
  /** 屏幕区块划分 */
  Xxl3: Spacing.Space10,
} as const;

// ============================================
// 圆角系统 (Border Radius)
// ============================================
export const BorderRadius = {
  /** 无圆角 */
  RadiusNone: 0,
  /** 小圆角 4px */
  RadiusSm: 4,
  /** 中圆角 8px */
  RadiusMd: 8,
  /** 大圆角 12px */
  RadiusLg: 12,
  /** 更大圆角 16px */
  RadiusXl: 16,
  /** 超大圆角 24px */
  Radius2xl: 24,
  /** 全圆角 */
  RadiusFull: 999,
} as const;

// 语义化圆角
export const SemanticRadius = {
  /** 小控件、复选框 */
  Element: BorderRadius.RadiusSm,
  /** 按钮、输入框 */
  Control: BorderRadius.RadiusMd,
  /** 卡片、面板 */
  Component: BorderRadius.RadiusLg,
  /** 模态框 */
  Container: BorderRadius.RadiusXl,
  /** 胶囊、标签 */
  Pill: BorderRadius.RadiusFull,
} as const;

// ============================================
// 字体系统 (Typography)
// ============================================
export const FontSize = {
  /** 辅助信息、标签 */
  Xs: 12,
  /** 正文小号 */
  Sm: 14,
  /** 正文基准 */
  Base: 16,
  /** 小标题 */
  Lg: 18,
  /** 标题 */
  Xl: 20,
  /** 大标题 */
  Xxl: 24,
  /** 页面标题 */
  Xxxl: 30,
  /** 展示标题 */
  Xxxxl: 36,
  /** 大型展示 */
  Xxxxxl: 48,
} as const;

export const FontWeight = {
  /** 正文 */
  Normal: 400,
  /** 强调正文 */
  Medium: 500,
  /** 小标题 */
  Semibold: 600,
  /** 标题 */
  Bold: 700,
} as const;

export const LineHeight = {
  /** 标题 */
  Tight: 1.25,
  /** 正文 */
  Normal: 1.5,
  /** 长文本 */
  Relaxed: 1.75,
} as const;

// ============================================
// 阴影系统 (Shadows)
// ============================================
export const Shadows = {
  /** 微妙阴影 */
  Sm: '0 1px 2px rgba(0, 0, 0, 0.05)',
  /** 标准阴影 */
  Md: '0 2px 4px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1)',
  /** 卡片阴影 */
  Lg: '0 4px 8px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1)',
  /** 弹出层阴影 */
  Xl: '0 8px 16px rgba(0, 0, 0, 0.1), 0 4px 8px rgba(0, 0, 0, 0.1)',
} as const;

// 深色模式阴影
export const DarkShadows = {
  Sm: '0 1px 2px rgba(0, 0, 0, 0.2)',
  Md: '0 2px 4px rgba(0, 0, 0, 0.2), 0 1px 2px rgba(0, 0, 0, 0.3)',
  Lg: '0 4px 8px rgba(0, 0, 0, 0.2), 0 2px 4px rgba(0, 0, 0, 0.3)',
  Xl: '0 8px 16px rgba(0, 0, 0, 0.3), 0 4px 8px rgba(0, 0, 0, 0.3)',
} as const;

// ============================================
// 动效系统 (Motion)
// ============================================
export const Duration = {
  /** hover、focus 等微交互 */
  Fast: 150,
  /** 标准过渡 */
  Normal: 200,
  /** 页面区块入场 */
  Slow: 300,
  /** 模态框、抽屉 */
  Slower: 400,
} as const;

export const Easing = {
  /** 默认缓动 */
  Default: 'cubic-bezier(0.4, 0, 0.2, 1)',
  /** 进入缓动 */
  In: 'cubic-bezier(0.4, 0, 1, 1)',
  /** 退出缓动 */
  Out: 'cubic-bezier(0, 0, 0.2, 1)',
  /** 弹性缓动 */
  Bounce: 'cubic-bezier(0.68, -0.55, 0.265, 1.55)',
} as const;

// ============================================
// 层级系统 (Z-Index)
// ============================================
export const ZIndex = {
  /** 下拉菜单 */
  Dropdown: 1000,
  /** 粘性元素 */
  Sticky: 1020,
  /** 固定元素 */
  Fixed: 1030,
  /** 模态框背景 */
  ModalBackdrop: 1040,
  /** 模态框 */
  Modal: 1050,
  /** 弹出框 */
  Popover: 1060,
  /** 提示框 */
  Tooltip: 1070,
  /** Toast */
  Toast: 1080,
} as const;

// ============================================
// 组件尺寸规范
// ============================================
export const ComponentSizes = {
  // 按钮尺寸
  Button: {
    Sm: {
      height: 32,
      paddingH: 12,
      fontSize: FontSize.Sm,
    },
    Md: {
      height: 40,
      paddingH: 16,
      fontSize: FontSize.Sm,
    },
    Lg: {
      height: 48,
      paddingH: 24,
      fontSize: FontSize.Base,
    },
  },
  // 输入框尺寸
  Input: {
    Sm: {
      height: 32,
      paddingH: 12,
      fontSize: FontSize.Sm,
    },
    Md: {
      height: 40,
      paddingH: 12,
      fontSize: FontSize.Base,
    },
    Lg: {
      height: 48,
      paddingH: 16,
      fontSize: FontSize.Base,
    },
  },
  // 图标尺寸
  Icon: {
    Xs: 12,
    Sm: 16,
    Md: 20,
    Lg: 24,
    Xl: 32,
    Xxl: 48,
  },
} as const;

// ============================================
// 导出类型
// ============================================
export type BrandColorKey = keyof typeof BrandColors;
export type NeutralColorKey = keyof typeof NeutralColors;
export type SpacingKey = keyof typeof Spacing;
export type RadiusKey = keyof typeof BorderRadius;
export type FontSizeKey = keyof typeof FontSize;
export type FontWeightKey = keyof typeof FontWeight;
export type DurationKey = keyof typeof Duration;
