import router from '@ohos.router';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

interface OrderItem {
  id: string;
  orderNo: string;
  title: string;
  amount: string;
  status: string;
  createTime: string;
}

@Entry
@Component
struct OrderHistory {
  @State orderList: OrderItem[] = [];

  aboutToAppear() {
    this.orderList = this.getDefaultOrders();
  }

  private getDefaultOrders(): OrderItem[] {
    return [
      { id: '1', orderNo: 'BJ20250115001', title: 'VIP会员 - 月度', amount: '29.90', status: '已完成', createTime: '2025-01-15 14:30' },
      { id: '2', orderNo: 'BJ20250110002', title: '简历AI智能润色', amount: '9.90', status: '已完成', createTime: '2025-01-10 09:15' },
      { id: '3', orderNo: 'BJ20250105003', title: 'VIP会员 - 年度', amount: '199.00', status: '已退款', createTime: '2025-01-05 18:42' },
      { id: '4', orderNo: 'BJ20241228004', title: '职业性格测试', amount: '0.00', status: '已完成', createTime: '2024-12-28 11:20' },
      { id: '5', orderNo: 'BJ20241220005', title: '简历AI智能润色', amount: '9.90', status: '已完成', createTime: '2024-12-20 16:55' },
    ];
  }

  getStatusColor(status: string): string {
    if (status === '已完成') {
      return SuccessColors.Success500;
    } else if (status === '已退款') {
      return SemanticColors.Text4;
    } else if (status === '待支付') {
      return WarningColors.Warning500;
    }
    return SemanticColors.Text3;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('订单记录')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 订单列表
      List() {
        ForEach(this.orderList, (item: OrderItem) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.title)
                  .fontSize(FontSize.Base)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(SemanticColors.Text1)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(item.status)
                  .fontSize(FontSize.Xs)
                  .fontColor(this.getStatusColor(item.status))
                  .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                  .backgroundColor(this.getStatusColor(item.status) === SuccessColors.Success500 ? SuccessColors.Success50 :
                    this.getStatusColor(item.status) === WarningColors.Warning500 ? WarningColors.Warning50 :
                      NeutralColors.Neutral100)
                  .borderRadius(SemanticRadius.Pill)
              }

              Row() {
                Text('订单号: ' + item.orderNo)
                  .fontSize(FontSize.Xs)
                  .fontColor(SemanticColors.Text3)

                Blank()

                Text(item.createTime)
                  .fontSize(FontSize.Xs)
                  .fontColor(SemanticColors.Text4)
              }
              .margin({ top: Spacing.Space3 })

              Divider()
                .margin({ top: SemanticSpacing.Lg })

              Row() {
                Text('实付金额')
                  .fontSize(FontSize.Xs)
                  .fontColor(SemanticColors.Text3)

                Blank()

                Text(item.amount === '0.00' ? '免费' : '\u00A5' + item.amount)
                  .fontSize(FontSize.Base)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(item.amount === '0.00' ? SuccessColors.Success500 : SemanticColors.Text1)
              }
              .margin({ top: Spacing.Space4 })
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Component)
            .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space4 })
            .shadow({
              radius: 8,
              color: 'rgba(0, 0, 0, 0.04)',
              offsetY: 2
            })
          }
        })
      }
      .layoutWeight(1)
      .padding({ top: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral50)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }
}
