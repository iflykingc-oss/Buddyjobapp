@Component
export struct LoadingSpinner {
  @Prop size: number = 32;
  @Prop color: string = '#8B5CF6';
  @Prop text: string = '';

  build() {
    Column() {
      LoadingProgress()
        .width(this.size)
        .height(this.size)
        .color(this.color)

      if (this.text) {
        Text(this.text)
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
