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
        .fontSize(16)
        .fontColor('#1A1A2E')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16 })

      if (this.description) {
        Text(this.description)
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ top: 8 })
          .textAlign(TextAlign.Center)
      }

      if (this.buttonText) {
        Button(this.buttonText)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#8B5CF6')
          .borderRadius(20)
          .height(40)
          .padding({ left: 32, right: 32 })
          .margin({ top: 24 })
          .onClick(() => {
            this.onButtonClick();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 32, right: 32 })
  }
}
