import { Message } from '../models/Message';
import { Colors } from '../constants/colors';

@Component
export struct ChatBubble {
  @Prop message: Message;

  build() {
    if (this.message.role === 'user') {
      this.userBubble()
    } else if (this.message.role === 'assistant') {
      this.assistantBubble()
    }
  }

  @Builder
  userBubble() {
    Row() {
      Blank()
      Column() {
        Text(this.message.content)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      }
      .alignItems(HorizontalAlign.End)
      .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
  }

  @Builder
  assistantBubble() {
    Row() {
      Column() {
        Text(this.message.content)
          .fontSize(15)
          .fontColor('#1A1A2E')
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
  }
}
