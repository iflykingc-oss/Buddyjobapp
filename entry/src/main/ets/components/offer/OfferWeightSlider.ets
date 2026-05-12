/**
 * Offer 权重调节滑块组件
 *
 * 提供 5 个分析维度的权重调节滑块，实时显示权重百分比，支持重置默认权重。
 * 使用 WEIGHT_LABELS 生成 5 行，每行包含标签+描述、Slider、百分比 Text。
 * 使用 design-tokens 的颜色和间距常量。
 */

import {
  BrandColors,
  SemanticColors,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
} from '../../constants/design-tokens';
import {
  WeightConfig,
  DEFAULT_WEIGHTS,
  WEIGHT_LABELS,
} from '../../models/OfferAnalysis';

@Component
export struct OfferWeightSlider {
  /** 当前权重配置（双向绑定） */
  @Link weights: WeightConfig;

  /** 权重维度 key 列表 */
  private weightKeys: (keyof WeightConfig)[] = ['salary', 'balance', 'benefit', 'commute', 'growth'];

  /** 计算总权重 */
  private getTotalWeight(): number {
    return this.weights.salary + this.weights.balance +
      this.weights.benefit + this.weights.commute + this.weights.growth;
  }

  /** 获取某个维度的百分比 */
  private getPercentage(key: keyof WeightConfig): string {
    const total = this.getTotalWeight();
    if (total === 0) return '0%';
    return `${Math.round((this.weights[key] / total) * 100)}%`;
  }

  /** 更新某个维度的权重 */
  private updateWeight(key: keyof WeightConfig, value: number) {
    this.weights[key] = Math.round(value);
  }

  /** 重置为默认权重 */
  private resetWeights() {
    this.weights = { ...DEFAULT_WEIGHTS };
  }

  /** 判断是否为默认权重 */
  private isDefault(): boolean {
    return this.weights.salary === DEFAULT_WEIGHTS.salary &&
      this.weights.balance === DEFAULT_WEIGHTS.balance &&
      this.weights.benefit === DEFAULT_WEIGHTS.benefit &&
      this.weights.commute === DEFAULT_WEIGHTS.commute &&
      this.weights.growth === DEFAULT_WEIGHTS.growth;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('权重调节')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Semibold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)

        // 恢复默认按钮
        Text('恢复默认')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDefault() ? SemanticColors.Text4 : BrandColors.Brand500)
          .onClick(() => {
            if (!this.isDefault()) {
              this.resetWeights();
            }
          })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Lg })

      // ForEach WEIGHT_LABELS 生成 5 行
      ForEach(this.weightKeys, (key: keyof WeightConfig) => {
        Column() {
          // 标签 + 描述
          Row() {
            Column() {
              Text(WEIGHT_LABELS[key].name)
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text1)
              Text(WEIGHT_LABELS[key].description)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text3)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 百分比 Text
            Text(this.getPercentage(key))
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Semibold)
              .fontColor(BrandColors.Brand500)
              .width(45)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Xs })

          // Slider(value=权重, min=0, max=100, step=5)
          Slider({
            value: this.weights[key],
            min: 0,
            max: 100,
            step: 5,
            style: SliderStyle.OutSet,
          })
            .width('100%')
            .blockColor(BrandColors.Brand500)
            .trackColor(SemanticColors.Surface2)
            .selectedColor(BrandColors.Brand500)
            .showSteps(false)
            .showTips(false)
            .onChange((value: number) => {
              this.updateWeight(key, value);
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: SemanticSpacing.Lg })
      }, (key: keyof WeightConfig) => key)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }
}
