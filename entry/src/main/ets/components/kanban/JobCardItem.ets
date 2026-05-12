/**
 * 求职看板卡片组件
 * Kanban 中每一张求职卡片
 */
import { Router } from '../../utils/Router';
import { JobCard, CardPriority, KanbanColumnStatus } from '../../models/Kanban';
import { Colors } from '../../constants/colors';

@Component
export struct JobCardItem {
  @Prop card: JobCard = {} as JobCard;
  @Prop columnColor: string = '#8B5CF6';
  @Prop columnStatus: KanbanColumnStatus = KanbanColumnStatus.WISH;
  onEdit?: (card: JobCard) => void;
  onDelete?: (cardId: string) => void;
  onMove?: (cardId: string) => void;

  // 拖拽相关
  @State isDragging: boolean = false;

  build() {
    Column() {
      // 顶部色条
      Row()
        .width('100%')
        .height(3)
        .backgroundColor(this.columnColor)

      // 卡片内容
      Column() {
        // 公司名 + 优先级
        Row() {
          // 公司首字头像
          Text(this.card.company.charAt(0))
            .fontSize(18)
            .fontColor('#FFFFFF')
            .width(36)
            .height(36)
            .backgroundColor(this.columnColor)
            .borderRadius(8)
            .textAlign(TextAlign.Center)

          Column() {
            Text(this.card.company)
              .fontSize(15)
              .fontColor(Colors.textPrimary)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '70%' })

            Text(this.card.position)
              .fontSize(12)
              .fontColor(Colors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10 })

          // 优先级标记
          if (this.card.priority === CardPriority.HIGH) {
            Text('急')
              .fontSize(10)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF4D4F')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 标签行
        if (this.card.tags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.card.tags.slice(0, 3), (tag: string) => {
              Text(tag)
                .fontSize(10)
                .fontColor(Colors.textSecondary)
                .backgroundColor(Colors.backgroundSecondary)
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .margin({ right: 4, top: 4 })
            })

            if (this.card.tags.length > 3) {
              Text(`+${this.card.tags.length - 3}`)
                .fontSize(10)
                .fontColor(Colors.textMuted)
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .margin({ top: 8 })
        }

        // 底部信息
        Row() {
          if (this.card.location) {
            Row() {
              Text('📍')
                .fontSize(10)
              Text(this.card.location)
                .fontSize(11)
                .fontColor(Colors.textMuted)
            }
          }

          if (this.card.salary) {
            Row() {
              Text('💰')
                .fontSize(10)
              Text(this.card.salary)
                .fontSize(11)
                .fontColor(Colors.textMuted)
            }
            .margin({ left: 12 })
          }

          Blank()

          // 来源
          if (this.card.source) {
            Text(this.card.source)
              .fontSize(10)
              .fontColor(Colors.textMuted)
          }
        }
        .width('100%')
        .margin({ top: 8 })

        // 备注预览
        if (this.card.note) {
          Text(this.card.note)
            .fontSize(11)
            .fontColor(Colors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
            .padding(8)
            .backgroundColor(Colors.backgroundSecondary)
            .borderRadius(6)
        }

        // Offer 分析入口（仅已录用列显示）
        if (this.columnStatus === KanbanColumnStatus.OFFER) {
          Row() {
            Text('📊 分析 Offer')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .backgroundColor('#8B5CF6')
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 8 })
          .onClick(() => {
            Router.push('pages/OfferAnalysis', {
              company: this.card.company,
              position: this.card.position,
              salary: this.card.salary,
              location: this.card.location,
            });
          })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    }
    .width('100%')
    .backgroundColor(Colors.white)
    .borderRadius(12)
    .shadow({
      radius: this.isDragging ? 16 : 8,
      color: this.isDragging ? 'rgba(0,0,0,0.15)' : 'rgba(0,0,0,0.06)',
      offsetY: this.isDragging ? 8 : 2
    })
    .scale({ x: this.isDragging ? 1.03 : 1, y: this.isDragging ? 1.03 : 1 })
    .opacity(this.isDragging ? 0.9 : 1)
    .animation({ duration: 200, curve: Curve.EaseOut })
    .gesture(
      // 长按触发拖拽
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          this.isDragging = true;
        })
        .onActionEnd(() => {
          this.isDragging = false;
        })
    )
    .onClick(() => {
      this.onEdit?.(this.card);
    })
  }
}
