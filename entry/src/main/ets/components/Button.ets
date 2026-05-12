import { BrandColors, NeutralColors, SemanticColors, FontSize, ComponentSizes, Spacing } from '../constants/design-tokens';

/**
 * BuddyButton - 自定义按钮组件
 */
@Component
export struct BuddyButton {
  @Prop text: string;
  @Prop type: ButtonType = 'primary'; // primary, secondary, outline, text
  @Prop size: ButtonSize = 'medium'; // small, medium, large
  @Prop disabled: boolean = false;
  @Prop loading: boolean = false;
  @Prop icon: Resource | null = null;
  onClick: () => void = () => {};

  private getBackgroundColor(): ResourceColor {
    if (this.disabled) {
      return NeutralColors.Neutral300;
    }
    switch (this.type) {
      case 'primary':
        return BrandColors.Brand500;
      case 'secondary':
        return NeutralColors.Neutral100;
      case 'outline':
        return 'transparent';
      case 'text':
        return 'transparent';
      default:
        return BrandColors.Brand500;
    }
  }

  private getTextColor(): ResourceColor {
    if (this.disabled) {
      return NeutralColors.Neutral0;
    }
    switch (this.type) {
      case 'primary':
        return NeutralColors.Neutral0;
      case 'secondary':
        return NeutralColors.Neutral900;
      case 'outline':
        return BrandColors.Brand500;
      case 'text':
        return BrandColors.Brand500;
      default:
        return NeutralColors.Neutral0;
    }
  }

  private getHeight(): number {
    switch (this.size) {
      case 'small':
        return ComponentSizes.Button.Sm.height;
      case 'medium':
        return ComponentSizes.Button.Md.height;
      case 'large':
        return ComponentSizes.Button.Lg.height;
      default:
        return ComponentSizes.Button.Md.height;
    }
  }

  private getFontSize(): number {
    switch (this.size) {
      case 'small':
        return FontSize.Xs;
      case 'medium':
        return FontSize.Sm;
      case 'large':
        return FontSize.Base;
      default:
        return FontSize.Sm;
    }
  }

  build() {
    Button() {
      Row() {
        if (this.loading) {
          LoadingProgress()
            .width(this.getFontSize())
            .height(this.getFontSize())
            .color(this.getTextColor())
            .margin({ right: Spacing.Space2 })
        } else if (this.icon) {
          Image(this.icon)
            .width(this.getFontSize())
            .height(this.getFontSize())
            .fillColor(this.getTextColor())
            .margin({ right: Spacing.Space2 })
        }

        Text(this.text)
          .fontSize(this.getFontSize())
          .fontColor(this.getTextColor())
          .fontWeight(FontWeight.Medium)
      }
    }
    .height(this.getHeight())
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(this.getHeight() / 2)
    .border({
      width: this.type === 'outline' ? 1 : 0,
      color: this.type === 'outline' ? BrandColors.Brand500 : 'transparent'
    })
    .enabled(!this.disabled && !this.loading)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onClick();
      }
    })
  }
}

type ButtonType = 'primary' | 'secondary' | 'outline' | 'text';
type ButtonSize = 'small' | 'medium' | 'large';
