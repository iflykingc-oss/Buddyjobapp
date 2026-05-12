/**
 * 一职搭子 颜色常量
 *
 * 基于设计系统 design-tokens.ets 导出的颜色
 * 保持与 Web 端一致的视觉体验
 */

import {
  BrandColors,
  NeutralColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  SemanticColors,
  DarkSemanticColors,
} from './design-tokens';

// ============================================
// 主题色 - 兼容旧代码
// ============================================
export const Colors = {
  // 品牌色（主色）
  primary: BrandColors.Brand500,
  primaryLight: BrandColors.Brand400,
  primaryDark: BrandColors.Brand600,

  // 状态色
  success: SuccessColors.Success500,
  warning: WarningColors.Warning500,
  error: ErrorColors.Error500,

  // 背景色
  background: SemanticColors.Background,
  backgroundSecondary: SemanticColors.Surface1,
  backgroundTertiary: SemanticColors.Surface2,

  // 文字色
  textPrimary: SemanticColors.Text1,
  textSecondary: SemanticColors.Text2,
  textMuted: SemanticColors.Text3,
  textPlaceholder: SemanticColors.Text4,

  // 边框色
  border: SemanticColors.Border,
  divider: SemanticColors.Border,

  // 其他
  white: NeutralColors.Neutral0,
  black: NeutralColors.Neutral950,
  transparent: 'transparent',

  // Tab 未选中
  tabInactive: NeutralColors.Neutral400,
} as const;

// ============================================
// 深色模式颜色
// ============================================
export const DarkColors = {
  // 品牌色（主色）
  primary: DarkSemanticColors.Accent,
  primaryLight: BrandColors.Brand300,
  primaryDark: BrandColors.Brand500,

  // 状态色
  success: DarkSemanticColors.Success,
  warning: DarkSemanticColors.Warning,
  error: DarkSemanticColors.Error,

  // 背景色
  background: DarkSemanticColors.Background,
  backgroundSecondary: DarkSemanticColors.Surface1,
  backgroundTertiary: DarkSemanticColors.Surface2,

  // 文字色
  textPrimary: DarkSemanticColors.Text1,
  textSecondary: DarkSemanticColors.Text2,
  textMuted: DarkSemanticColors.Text3,
  textPlaceholder: DarkSemanticColors.Text4,

  // 边框色
  border: DarkSemanticColors.Border,
  divider: DarkSemanticColors.Border,

  // Tab 未选中
  tabInactive: NeutralColors.Neutral500,
} as const;

// ============================================
// 完整色板导出
// ============================================
export {
  BrandColors,
  NeutralColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  SemanticColors,
  DarkSemanticColors,
};

export type ColorName = keyof typeof Colors;
