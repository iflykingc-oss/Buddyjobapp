/**
 * 看板列组件
 * 每一列包含标题 + 卡片列表
 */
import { KanbanColumn, JobCard, KanbanColumnStatus } from '../../models/Kanban';
import { JobCardItem } from './JobCardItem';
import { Colors } from '../../constants/colors';

@Component
export struct KanbanColumnItem {
  @Prop column: KanbanColumn = {} as KanbanColumn;
  @Prop cards: JobCard[] = [];
  onCardEdit?: (card: JobCard) => void;
  onCardDelete?: (cardId: string) => void;
  onCardMove?: (cardId: string) => void;

  build() {
    Column() {
      // 列头
      Row() {
        // 色点
        Circle()
          .width(8)
          .height(8)
          .fill(this.column.color)

        Text(this.column.title)
          .fontSize(14)
          .fontColor(Colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 6 })

        // 计数
        Text(`${this.cards.length}`)
          .fontSize(12)
          .fontColor(Colors.textMuted)
          .backgroundColor(Colors.backgroundSecondary)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 1, bottom: 1 })
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })

      // 卡片列表
      List() {
        ForEach(this.cards, (card: JobCard) => {
          ListItem() {
            JobCardItem({
              card: card,
              columnColor: this.column.color,
              onEdit: (c) => this.onCardEdit?.(c),
              onDelete: (id) => this.onCardDelete?.(id),
              onMove: (id) => this.onCardMove?.(id)
            })
          }
          .margin({ bottom: 8 })
        }, (card: JobCard) => card.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .divider({ strokeWidth: 0 })
    }
    .width(280)
    .height('100%')
    .backgroundColor(Colors.backgroundSecondary)
    .borderRadius(12)
    .clip(true)
  }
}
