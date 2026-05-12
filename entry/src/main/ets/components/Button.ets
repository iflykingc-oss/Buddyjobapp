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

  private getBackgroundColor(): string {
    if (this.disabled) {
      return '#CCCCCC';
    }
    switch (this.type) {
      case 'primary':
        return '#8B5CF6';
      case 'secondary':
        return '#F5F5F5';
      case 'outline':
        return 'transparent';
      case 'text':
        return 'transparent';
      default:
        return '#8B5CF6';
    }
  }

  private getTextColor(): string {
    if (this.disabled) {
      return '#FFFFFF';
    }
    switch (this.type) {
      case 'primary':
        return '#FFFFFF';
      case 'secondary':
        return '#333333';
      case 'outline':
        return '#8B5CF6';
      case 'text':
        return '#8B5CF6';
      default:
        return '#FFFFFF';
    }
  }

  private getHeight(): number {
    switch (this.size) {
      case 'small':
        return 32;
      case 'medium':
        return 44;
      case 'large':
        return 52;
      default:
        return 44;
    }
  }

  private getFontSize(): number {
    switch (this.size) {
      case 'small':
        return 12;
      case 'medium':
        return 14;
      case 'large':
        return 16;
      default:
        return 14;
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
            .margin({ right: 8 })
        } else if (this.icon) {
          Image(this.icon)
            .width(this.getFontSize())
            .height(this.getFontSize())
            .fillColor(this.getTextColor())
            .margin({ right: 8 })
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
      color: this.type === 'outline' ? '#8B5CF6' : 'transparent'
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
