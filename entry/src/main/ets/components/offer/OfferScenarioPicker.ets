/**
 * Offer 场景模板选择组件
 *
 * 以 2x2 Grid 展示 SCENARIO_TEMPLATES，每个模板包含图标区域、标题、描述。
 * 选中态：border 2px Brand500 + 浅紫背景 Brand50。
 * 使用 design-tokens 的颜色和间距常量。
 */

import {
  BrandColors,
  SemanticColors,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes,
} from '../../constants/design-tokens';
import {
  ScenarioTemplate,
  SCENARIO_TEMPLATES,
} from '../../models/OfferAnalysis';

@Component
export struct OfferScenarioPicker {
  /** 当前选中的模板 ID */
  @Prop selectedId: string = '';
  /** 模板选择回调 */
  onSelect: (template: ScenarioTemplate) => void = () => {};

  build() {
    Column() {
      // 标题
      Text('场景模板')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xs })

      Text('选择一个与你需求最匹配的场景，快速开始对比分析')
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text3)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      // 2x2 Grid 展示 SCENARIO_TEMPLATES
      Grid() {
        ForEach(SCENARIO_TEMPLATES, (template: ScenarioTemplate) => {
          GridItem() {
            Column() {
              // 图标区域
              Text(template.icon)
                .fontSize(ComponentSizes.Icon.Xxl)
                .margin({ bottom: SemanticSpacing.Sm })

              // 标题
              Text(template.title)
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Semibold)
                .fontColor(this.selectedId === template.id ?
                  BrandColors.Brand500 : SemanticColors.Text1)
                .margin({ bottom: SemanticSpacing.Xs })

              // 描述
              Text(template.description)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text3)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .lineHeight(18)
            }
            .width('100%')
            .height('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.selectedId === template.id ?
              BrandColors.Brand50 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Container)
            .border({
              width: this.selectedId === template.id ? 2 : 1,
              color: this.selectedId === template.id ?
                BrandColors.Brand500 : SemanticColors.Border,
              radius: SemanticRadius.Container,
            })
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Start)
            .onClick(() => {
              this.onSelect(template);
            })
          }
        }, (template: ScenarioTemplate) => template.id)
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .columnsGap(SemanticSpacing.Md)
      .rowsGap(SemanticSpacing.Md)
      .width('100%')
      .height(280)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }
}
