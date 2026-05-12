/**
 * 一职搭子 设计系统 - 鸿蒙端常量
 *
 * 本文件定义了一职搭子应用的设计令牌（Design Tokens），
 * 对齐华为 HarmonyOS 设计规范：
 *   - One（万物归一）：以人为本，文字清晰易读，图标精确，色彩协调，动效流畅
 *   - Harmonious（和谐）：光影材质映射，物理世界体验记忆
 *   - Universe（万物演化）：自适应能力，多设备一致性
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
// 中性色 (Neutral Colors) - HarmonyOS 灰阶
// ============================================
export const NeutralColors = {
  /** 纯白 */
  Neutral0: '#FFFFFF',
  /** 页面背景 */
  Neutral50: '#F1F3F5',
  /** 卡片背景 */
  Neutral100: '#E3E5E8',
  /** 边框、分隔线 */
  Neutral200: '#C4C7CC',
  /** 强边框 */
  Neutral300: '#99A0A6',
  /** 禁用文字 */
  Neutral400: '#66707A',
  /** 三级文字 */
  Neutral500: '#4A5058',
  /** 二级文字 */
  Neutral600: '#3D4654',
  /** 深色文字 */
  Neutral700: '#2C323A',
  /** 深色背景 */
  Neutral800: '#1C2028',
  /** 更深背景 */
  Neutral900: '#141820',
  /** 最深背景/主文字 */
  Neutral950: '#0C0E14',
} as const;

// ============================================
// 功能色 (Functional Colors) - HarmonyOS 规范
// ============================================
export const SuccessColors = {
  /** 成功背景 */
  Success50: '#E8F5E6',
  /** 主色 - HarmonyOS 成功绿 */
  Success500: '#64BB5C',
  /** 深色成功 */
  Success900: '#2E5A2A',
} as const;

export const WarningColors = {
  /** 警告背景 */
  Warning50: '#FFF3E0',
  /** 主色 - HarmonyOS 警告橙 */
  Warning500: '#FF9800',
  /** 深色警告 */
  Warning900: '#6D3E00',
} as const;

export const ErrorColors = {
  /** 错误背景 */
  Error50: '#FDECEB',
  /** 主色 - HarmonyOS 错误红 */
  Error500: '#E84026',
  /** 深色错误 */
  Error900: '#6B1D12',
} as const;

export const InfoColors = {
  /** 信息背景 */
  Info50: '#E5F2FF',
  /** 主色 - HarmonyOS 信息蓝 */
  Info500: '#007DFF',
  /** 深色信息 */
  Info900: '#003A7A',
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
  Text3: NeutralColors.Neutral400,
  /** 禁用文本 */
  Text4: NeutralColors.Neutral300,

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
  /** 信息色 */
  Info: InfoColors.Info500,
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
  Info: InfoColors.Info500,
} as const;

// ============================================
// 间距系统 (Spacing) - 4px 基准网格 (HarmonyOS)
// ============================================
export const Spacing = {
  /** 无间距 */
  Space0: 0,
  /** 4px - 最小间距单元 */
  Space1: 4,
  /** 8px - 紧凑间距 */
  Space2: 8,
  /** 12px - 小间距 */
  Space3: 12,
  /** 16px - 标准间距 */
  Space4: 16,
  /** 20px - 中等间距 */
  Space5: 20,
  /** 24px - 大间距 */
  Space6: 24,
  /** 32px - 区块间距 */
  Space7: 32,
  /** 40px - 主要区块分隔 */
  Space8: 40,
  /** 48px - 屏幕区块划分 */
  Space9: 48,
} as const;

// 语义化间距
export const SemanticSpacing = {
  /** 最小间距 */
  Xs: Spacing.Space1,
  /** 图标与标签间隙 */
  Sm: Spacing.Space2,
  /** 组件内部间距 */
  Md: Spacing.Space3,
  /** 标准间距 */
  Lg: Spacing.Space4,
  /** 中等间距 */
  Xl: Spacing.Space5,
  /** 卡片内边距 */
  Xxl: Spacing.Space6,
  /** 区块间距 */
  Xxl2: Spacing.Space7,
  /** 主要区块分隔 */
  Xxl3: Spacing.Space8,
  /** 屏幕区块划分 */
  Xxl4: Spacing.Space9,
} as const;

// ============================================
// 圆角系统 (Border Radius) - HarmonyOS 规范
// ============================================
export const BorderRadius = {
  /** 无圆角 */
  RadiusNone: 0,
  /** 小圆角 4px - 小控件 */
  RadiusSm: 4,
  /** 中圆角 8px - 按钮 */
  RadiusMd: 8,
  /** 大圆角 12px - 卡片 */
  RadiusLg: 12,
  /** 更大圆角 16px - 弹窗 */
  RadiusXl: 16,
  /** 超大圆角 24px - 底部弹窗 */
  Radius2xl: 24,
  /** 全圆角 */
  RadiusFull: 999,
} as const;

// 语义化圆角 - HarmonyOS 对齐
export const SemanticRadius = {
  /** 小控件、复选框 */
  Element: BorderRadius.RadiusSm,
  /** 按钮、输入框 - 8px */
  Control: BorderRadius.RadiusMd,
  /** 卡片、面板 - 12px */
  Component: BorderRadius.RadiusLg,
  /** 弹窗 - 16px */
  Container: BorderRadius.RadiusXl,
  /** 底部弹窗 - 24px */
  BottomSheet: BorderRadius.Radius2xl,
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
// 阴影系统 (Shadows) - HarmonyOS 光影设计
// ============================================
export const Shadows = {
  /** 微妙阴影 - 贴合表面 */
  Sm: { radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetY: 1 },
  /** 标准阴影 - 轻微悬浮 */
  Md: { radius: 16, color: 'rgba(0, 0, 0, 0.06)', offsetY: 2 },
  /** 卡片阴影 - 柔和悬浮 */
  Lg: { radius: 24, color: 'rgba(0, 0, 0, 0.08)', offsetY: 4 },
  /** 弹出层阴影 - 明显悬浮 */
  Xl: { radius: 32, color: 'rgba(0, 0, 0, 0.12)', offsetY: 8 },
} as const;

// 深色模式阴影 - HarmonyOS 深色光影
export const DarkShadows = {
  Sm: { radius: 8, color: 'rgba(0, 0, 0, 0.16)', offsetY: 1 },
  Md: { radius: 16, color: 'rgba(0, 0, 0, 0.20)', offsetY: 2 },
  Lg: { radius: 24, color: 'rgba(0, 0, 0, 0.24)', offsetY: 4 },
  Xl: { radius: 32, color: 'rgba(0, 0, 0, 0.32)', offsetY: 8 },
} as const;

// ============================================
// 动效系统 (Motion) - HarmonyOS 规范
// ============================================
export const Duration = {
  /** 快速 - 微交互、hover、focus */
  Fast: 150,
  /** 标准 - 常规过渡 */
  Normal: 300,
  /** 慢速 - 模态框、抽屉、页面切换 */
  Slow: 500,
} as const;

export const Easing = {
  /** 标准缓动 - easeInOut */
  Default: 'cubic-bezier(0.4, 0, 0.2, 1)',
  /** 进入缓动 */
  In: 'cubic-bezier(0.4, 0, 1, 1)',
  /** 退出缓动 */
  Out: 'cubic-bezier(0, 0, 0.2, 1)',
  /** 弹性缓动 - spring */
  Spring: 'cubic-bezier(0.175, 0.885, 0.32, 1.275)',
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
// HarmonyOS 设计规范常量
// ============================================
export const HarmonyDesign = {
  /** 4px 基准网格 */
  BaseGrid: 4,
  /** 标准安全区域内边距 */
  SafePadding: 16,
  /** 列表项标准高度 */
  ListItemHeight: 56,
  /** 底部导航栏高度 */
  TabBarHeight: 56,
  /** 导航栏高度 */
  NavBarHeight: 56,
  /** 标准分割线粗细 */
  DividerThickness: 0.5,
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
