/**
 * Offer What-if 分析面板组件
 *
 * 提供 4 个可调参数（月薪、年终奖、工时、通勤）的滑块，
 * 实时计算各参数调整后的分数变化。
 * 使用 OfferAnalysisService.getInstance().whatIfAnalysis() 计算分数变化。
 * 使用 design-tokens 的颜色和间距常量。
 */

import {
  BrandColors,
  SemanticColors,
  SuccessColors,
  ErrorColors,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
} from '../../constants/design-tokens';
import {
  OfferInput,
  WeightConfig,
} from '../../models/OfferAnalysis';
import { OfferAnalysisService } from '../../services/OfferAnalysisService';

/** What-if 单项结果 */
interface WhatIfItem {
  field: keyof OfferInput;
  label: string;
  unit: string;
  currentValue: number;
  min: number;
  max: number;
  step: number;
  scoreChange: number;
  newScore: number;
}

@Component
export struct OfferWhatIfPanel {
  /** 当前 Offer 数据 */
  @Prop offer: OfferInput;
  /** 当前权重配置 */
  @Prop weights: WeightConfig;

  /** 各参数的变化结果 */
  @State private whatIfResults: WhatIfItem[] = [];

  private service: OfferAnalysisService = OfferAnalysisService.getInstance();

  aboutToAppear() {
    this.initWhatIfParams();
    this.calculateAllChanges();
  }

  /** 初始化 What-if 参数 */
  private initWhatIfParams() {
    this.whatIfResults = [
      {
        field: 'monthlySalary',
        label: '月薪',
        unit: 'k',
        currentValue: Math.round((this.offer.monthlySalary || 0) / 1000),
        min: 5,
        max: 80,
        step: 1,
        scoreChange: 0,
        newScore: 0,
      },
      {
        field: 'annualBonus',
        label: '年终奖',
        unit: '月',
        currentValue: this.offer.annualBonus || 0,
        min: 0,
        max: 12,
        step: 1,
        scoreChange: 0,
        newScore: 0,
      },
      {
        field: 'workHours',
        label: '工时',
        unit: 'h/周',
        currentValue: this.offer.workHours || 40,
        min: 30,
        max: 60,
        step: 1,
        scoreChange: 0,
        newScore: 0,
      },
      {
        field: 'commuteMinutes',
        label: '通勤',
        unit: 'min',
        currentValue: this.offer.commuteMinutes || 30,
        min: 5,
        max: 120,
        step: 5,
        scoreChange: 0,
        newScore: 0,
      },
    ];
  }

  /** 计算所有参数的分数变化 */
  private calculateAllChanges() {
    this.whatIfResults = this.whatIfResults.map(item => {
      let actualNewValue: number;
      if (item.field === 'monthlySalary') {
        actualNewValue = item.currentValue * 1000;
      } else {
        actualNewValue = item.currentValue;
      }

      const result = this.service.whatIfAnalysis(
        this.offer,
        item.field,
        actualNewValue,
        this.weights
      );

      return {
        ...item,
        scoreChange: result.scoreChange,
        newScore: result.newScore,
      };
    });
  }

  /** 更新单个参数值并重新计算 */
  private updateParam(index: number, newValue: number) {
    this.whatIfResults[index].currentValue = newValue;
    this.calculateAllChanges();
  }

  /** 格式化分数变化文本 */
  private formatScoreChange(change: number): string {
    if (change > 0) {
      return `+${change}`;
    }
    return `${change}`;
  }

  build() {
    Column() {
      // 标题
      Text('What-if 分析')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xs })

      Text('调整参数，查看对评分的影响')
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text3)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      // 4 个可调参数
      ForEach(this.whatIfResults, (item: WhatIfItem, index?: number) => {
        Column() {
          // 标签 + 当前值 + 分数变化
          Row() {
            Text(item.label)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)

            Text(`${item.currentValue}${item.unit}`)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Semibold)
              .fontColor(SemanticColors.Text1)
              .margin({ left: SemanticSpacing.Xs })

            Blank()

            // 分数变化（绿色上升 或 红色下降）
            if (item.scoreChange !== 0) {
              Row() {
                Text(item.scoreChange > 0 ? '\u2191' : '\u2193')
                  .fontSize(FontSize.Xs)
                  .fontColor(item.scoreChange > 0 ? SuccessColors.Success500 : ErrorColors.Error500)
                Text(this.formatScoreChange(item.scoreChange))
                  .fontSize(FontSize.Xs)
                  .fontWeight(FontWeight.Semibold)
                  .fontColor(item.scoreChange > 0 ? SuccessColors.Success500 : ErrorColors.Error500)
              }
              .margin({ right: SemanticSpacing.Xs })
            }
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Xs })

          // Slider
          Slider({
            value: item.currentValue,
            min: item.min,
            max: item.max,
            step: item.step,
            style: SliderStyle.OutSet,
          })
            .width('100%')
            .blockColor(BrandColors.Brand500)
            .trackColor(SemanticColors.Surface2)
            .selectedColor(BrandColors.Brand500)
            .showSteps(false)
            .showTips(false)
            .onChange((value: number) => {
              if (index !== undefined) {
                this.updateParam(index, Math.round(value));
              }
            })

          // 范围提示
          Row() {
            Text(`${item.min}${item.unit}`)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
            Blank()
            Text(`${item.max}${item.unit}`)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
          }
          .width('100%')
          .margin({ top: 2 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: SemanticSpacing.Lg })
      }, (item: WhatIfItem, index?: number) => `${index}_${item.field}`)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }
}
