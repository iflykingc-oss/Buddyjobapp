import { BrandColors, SemanticColors, FontSize, Spacing } from '../constants/design-tokens';

@Component
export struct LoadingSpinner {
  @Prop size: number = 32;
  @Prop color: ResourceColor = BrandColors.Brand500;
  @Prop text: string = '';

  build() {
    Column() {
      LoadingProgress()
        .width(this.size)
        .height(this.size)
        .color(this.color)

      if (this.text) {
        Text(this.text)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .margin({ top: Spacing.Space3 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
