@Component
export struct ChatInput {
  @Link inputText: string;
  onSend: () => void = () => {};

  build() {
    Row() {
      TextInput({ placeholder: '输入您的问题...', text: this.inputText })
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .fontSize(14)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          if (this.inputText.trim()) {
            this.onSend();
          }
        })

      Button() {
        Text('发送')
          .fontColor('#FFFFFF')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
      }
      .width(60)
      .height(40)
      .backgroundColor(this.inputText.trim() ? '#8B5CF6' : '#CCCCCC')
      .borderRadius(20)
      .margin({ left: 8 })
      .enabled(!!this.inputText.trim())
      .onClick(() => {
        if (this.inputText.trim()) {
          this.onSend();
        }
      })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }
}
