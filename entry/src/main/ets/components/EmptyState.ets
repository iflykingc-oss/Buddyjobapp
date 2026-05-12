import { BrandColors, NeutralColors, SemanticColors, Spacing, BorderRadius, FontSize } from '../constants/design-tokens';

@Component
export struct EmptyState {
  @Prop icon: Resource;
  @Prop title: string;
  @Prop description: string = '';
  @Prop buttonText: string = '';
  onButtonClick: () => void = () => {};

  build() {
    Column() {
      Image(this.icon)
        .width(100)
        .height(100)
        .opacity(0.4)

      Text(this.title)
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .margin({ top: Spacing.Space4 })

      if (this.description) {
        Text(this.description)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .margin({ top: Spacing.Space2 })
          .textAlign(TextAlign.Center)
      }

      if (this.buttonText) {
        Button(this.buttonText)
          .fontSize(FontSize.Sm)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(BorderRadius.RadiusXl)
          .height(40)
          .padding({ left: Spacing.Space8, right: Spacing.Space8 })
          .margin({ top: Spacing.Space6 })
          .onClick(() => {
            this.onButtonClick();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: Spacing.Space8, right: Spacing.Space8 })
  }
}
