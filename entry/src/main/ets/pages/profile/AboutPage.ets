import router from '@ohos.router';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

@Entry
@Component
struct AboutPage {
  @State appVersion: string = '1.0.1';
  @State buildTime: string = '2025.01.15';

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.media_ic_arrow_right'))
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

        Text('关于我们')
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

      Scroll() {
        Column() {
          // Logo 区域
          Column() {
            Column() {
              Text('BJ')
                .fontSize(FontSize.Xxl)
                .fontWeight(FontWeight.Bold)
                .fontColor(NeutralColors.Neutral0)
            }
            .width(80)
            .height(80)
            .borderRadius(20)
            .linearGradient({
              direction: GradientDirection.BottomRight,
              colors: [
                [BrandColors.Brand400, 0],
                [BrandColors.Brand600, 1]
              ]
            })
            .justifyContent(FlexAlign.Center)
            .margin({ top: SemanticSpacing.Xxl })

            Text('一职搭子')
              .fontSize(FontSize.Xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.Text1)
              .margin({ top: SemanticSpacing.Lg })

            Text('你的智能求职伙伴')
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text2)
              .margin({ top: Spacing.Space3 })

            Text('v' + this.appVersion)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
              .margin({ top: Spacing.Space4 })
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space2, bottom: Spacing.Space2 })
              .backgroundColor(NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Pill)
          }
          .width('100%')
          .padding({ bottom: SemanticSpacing.Xxl })

          // 应用介绍
          Column() {
            Text('应用介绍')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            Text('一职搭子是一款基于 AI 技术的智能求职助手应用。我们致力于帮助求职者提升求职竞争力，通过 AI 简历分析、智能对话、岗位测评等功能，为用户提供全方位的求职支持。')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .lineHeight(24)
          }
          .width('100%')
          .padding(SemanticSpacing.Xl)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 核心功能
          Column() {
            Text('核心功能')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            ForEach([
              { icon: '\u{1F4DD}', name: 'AI 简历分析', desc: '智能分析简历，提供优化建议' },
              { icon: '\u{1F4AC}', name: '智能求职对话', desc: 'AI 助手实时解答求职疑问' },
              { icon: '\u{1F3AF}', name: '岗位测评', desc: '多维度测评，精准匹配岗位' },
              { icon: '\u{1F4DA}', name: '求职知识库', desc: '丰富的求职攻略和行业资讯' }
            ], (item: { icon: string; name: string; desc: string }) => {
              Row() {
                Text(item.icon)
                  .fontSize(FontSize.Xxl)

                Column() {
                  Text(item.name)
                    .fontSize(FontSize.Base)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(SemanticColors.Text1)

                  Text(item.desc)
                    .fontSize(FontSize.Xs)
                    .fontColor(SemanticColors.Text3)
                    .margin({ top: Spacing.Space2 })
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: SemanticSpacing.Lg })
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
            })
          }
          .width('100%')
          .padding(SemanticSpacing.Xl)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 版权信息
          Column() {
            Text('一职搭子 Harmony')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)

            Text('Copyright \u00A9 2025 一职搭子 Team')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
              .margin({ top: Spacing.Space3 })

            Text('All Rights Reserved')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
              .margin({ top: Spacing.Space2 })
          }
          .width('100%')
          .padding({ top: SemanticSpacing.Xxl, bottom: Spacing.Space9 })
          .alignItems(HorizontalAlign.Center)
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }
}
