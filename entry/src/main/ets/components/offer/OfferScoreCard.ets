/**
 * Offer 评分展示卡片组件
 *
 * 展示综合评分圆环（Stack + Progress(Ring) + Text 叠加，直径 120vp）、
 * 各维度评分条、市场对比信息。
 * 颜色编码：>=85 Success500, >=70 Info500, >=55 Warning500, <55 Error500。
 * 使用 design-tokens 的颜色和间距常量。
 */

import {
  BrandColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  InfoColors,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
} from '../../constants/design-tokens';
import {
  OfferAnalysisResult,
  DimensionScore,
} from '../../models/OfferAnalysis';

@Component
export struct OfferScoreCard {
  /** 分析结果 */
  @Prop result: OfferAnalysisResult;

  /** 获取评分对应颜色 */
  private getScoreColor(score: number): ResourceColor {
    if (score >= 85) return SuccessColors.Success500;
    if (score >= 70) return InfoColors.Info500;
    if (score >= 55) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /** 获取评分背景色 */
  private getScoreBgColor(score: number): string {
    if (score >= 85) return SuccessColors.Success50;
    if (score >= 70) return InfoColors.Info50;
    if (score >= 55) return WarningColors.Warning50;
    return ErrorColors.Error50;
  }

  /** 获取评分标签 */
  private getScoreLabel(score: number): string {
    if (score >= 90) return '卓越';
    if (score >= 85) return '优秀';
    if (score >= 70) return '良好';
    if (score >= 55) return '一般';
    return '较差';
  }

  /** 综合评分圆环区域 - Stack + Progress(Ring) + Text 叠加，直径 120vp */
  @Builder
  buildOverallScore() {
    Column() {
      Text('综合评分')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      Row() {
        // 圆形评分 - 使用 Stack + Progress(Ring) + Text 叠加，直径 120vp
        Stack() {
          // 背景圆环
          Progress({
            value: 100,
            total: 100,
            type: ProgressBarType.Ring,
          })
            .width(120)
            .height(120)
            .color(SemanticColors.Surface2)
            .style({ strokeWidth: 8 })

          // 进度圆环
          Progress({
            value: this.result.overallScore,
            total: 100,
            type: ProgressBarType.Ring,
          })
            .width(120)
            .height(120)
            .color(this.getScoreColor(this.result.overallScore))
            .style({ strokeWidth: 8 })

          // 分数文字
          Text(`${this.result.overallScore}`)
            .fontSize(FontSize.Xxxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.result.overallScore))
        }
        .width(120)
        .height(120)

        Column() {
          Text(this.getScoreLabel(this.result.overallScore))
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Semibold)
            .fontColor(SemanticColors.Text1)
          Text('综合评估')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ top: SemanticSpacing.Xs })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: SemanticSpacing.Xxl })
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 各维度评分 - ForEach dimensions，每行名称+Progress(Linear)+分数 */
  @Builder
  buildDimensionScores() {
    Column() {
      Text('维度评分')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      ForEach(this.result.dimensions, (dim: DimensionScore) => {
        Column() {
          Row() {
            Text(dim.name)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .width(90)

            Progress({ value: dim.score, total: 100, type: ProgressBarType.Linear })
              .layoutWeight(1)
              .height(8)
              .color(this.getScoreColor(dim.score))
              .backgroundColor(SemanticColors.Surface2)
              .style({ strokeWidth: 8 })

            Text(`${dim.score}`)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Semibold)
              .fontColor(this.getScoreColor(dim.score))
              .width(30)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Xs })

          Row() {
            Text(dim.description)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .layoutWeight(1)
            Text(dim.label)
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getScoreColor(dim.score))
              .padding({
                left: SemanticSpacing.Sm,
                right: SemanticSpacing.Sm,
                top: 2,
                bottom: 2,
              })
              .backgroundColor(this.getScoreBgColor(dim.score))
              .borderRadius(SemanticRadius.Pill)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Md })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (dim: DimensionScore) => dim.name)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 市场对比 - 薪资范围条 + 百分位文字 */
  @Builder
  buildMarketComparison() {
    const mc = this.result.marketComparison;

    Column() {
      Text('市场对比')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      Text(mc.description)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 薪资范围条
      Column() {
        Row() {
          Text(`低位 ${mc.salaryRange.low.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
          Text(`中位 ${mc.salaryRange.median.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
          Text(`高位 ${mc.salaryRange.high.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: SemanticSpacing.Xs })

        // 薪资范围进度条
        Stack() {
          Row()
            .width('100%')
            .height(8)
            .backgroundColor(SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Pill)

          Row()
            .width(`${mc.salaryPercentile}%`)
            .height(8)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
        }
        .width('100%')
        .alignContent(Alignment.Start)

        // 百分位文字
        Text(`超过市场 ${mc.salaryPercentile}% 的水平`)
          .fontSize(FontSize.Xs)
          .fontColor(BrandColors.Brand500)
          .margin({ top: SemanticSpacing.Xs })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  build() {
    Column() {
      // 综合评分圆环
      this.buildOverallScore()

      // 各维度评分条
      this.buildDimensionScores()

      // 市场对比信息
      this.buildMarketComparison()
    }
    .width('100%')
  }
}
