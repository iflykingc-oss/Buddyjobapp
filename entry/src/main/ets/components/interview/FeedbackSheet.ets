/**
 * AI点评底部弹出面板
 *
 * 使用 BindSheet 实现底部弹出效果
 * 展示优点、改进点、参考答案和STAR分析
 * 遵循鸿蒙设计规范
 */
import { InterviewFeedback, StarAnalysis } from '../../services/InterviewService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight
} from '../../constants/design-tokens';

@Component
export struct FeedbackSheet {
  // 点评数据
  @Prop feedback: InterviewFeedback | null = null;
  @Prop isExpanded: boolean = true;

  // 回调
  onNextQuestion: () => void = () => {};
  onRetryQuestion: () => void = () => {};
  onClose: () => void = () => {};

  // 内部状态
  @State private showReferenceAnswer: boolean = false;
  @State private showStarAnalysis: boolean = false;

  build() {
    if (!this.feedback) {
      Column() {
        Text('暂无点评数据')
          .fontSize(FontSize.Md)
          .fontColor(SemanticColors.Text3)
          .padding(40)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(NeutralColors.Neutral0)
      return;
    }

    Column() {
      // 拖拽指示器
      Row()
        .width(36)
        .height(4)
        .backgroundColor(NeutralColors.Neutral300)
        .borderRadius(2)
        .margin({ top: Spacing.Space3, bottom: Spacing.Space3 })

      // 标题栏
      Row() {
        Text('AI点评')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)

        Blank()

        // 关闭按钮
        Column() {
          Image($r('app.media.media_ic_close'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text2)
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor(NeutralColors.Neutral100)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

      // 内容区域
      Scroll() {
        Column() {
          if (this.feedback) {
            // 评分卡片
            this.ScoreCard()

            // 优点
            this.StrengthsSection()

            // 改进点
            this.ImprovementsSection()

            // STAR分析
            if (this.feedback.starAnalysis) {
              this.StarAnalysisSection()
            }

            // 参考答案
            this.ReferenceAnswerSection()

            // 建议
            this.SuggestionsSection()
          }
        }
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部操作按钮
      this.ActionButtons()
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
    .shadow({
      radius: 32,
      color: 'rgba(0, 0, 0, 0.12)',
      offsetY: -8
    })
  }

  /**
   * 评分卡片
   */
  @Builder
  ScoreCard() {
    Column() {
      Row() {
        Column() {
          Text('本次得分')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)

          Text(this.feedback!.score.toString())
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.feedback!.score))
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 评分等级
        Column() {
          Text(this.getScoreLabel(this.feedback!.score))
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getScoreColor(this.feedback!.score))

          Text(this.getScoreDescription(this.feedback!.score))
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space1 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      // 进度条
      Stack() {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor(NeutralColors.Neutral200)
          .borderRadius(4)

        Row()
          .width(`${this.feedback!.score}%`)
          .height(8)
          .backgroundColor(this.getScoreColor(this.feedback!.score))
          .borderRadius(4)
      }
      .width('100%')
      .height(8)
      .margin({ top: Spacing.Space4 })
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
  }

  /**
   * 优点部分
   */
  @Builder
  StrengthsSection() {
    Column() {
      Row() {
        Image($r('app.media.media_ic_check'))
          .width(16)
          .height(16)
          .fillColor(SuccessColors.Success500)

        Text('优点')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
          .margin({ left: Spacing.Space3 })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space3 })

      ForEach(this.feedback!.strengths, (strength: string, index: number) => {
        Row() {
          Text('•')
            .fontSize(FontSize.Sm)
            .fontColor(SuccessColors.Success500)
            .width(16)

          Text(strength)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text1)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: index === 0 ? 0 : Spacing.Space2 })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(SuccessColors.Success50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 改进点部分
   */
  @Builder
  ImprovementsSection() {
    Column() {
      Row() {
        Image($r('app.media.media_ic_info'))
          .width(16)
          .height(16)
          .fillColor(WarningColors.Warning500)

        Text('改进建议')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
          .margin({ left: Spacing.Space3 })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space3 })

      ForEach(this.feedback!.improvements, (improvement: string, index: number) => {
        Row() {
          Text('•')
            .fontSize(FontSize.Sm)
            .fontColor(WarningColors.Warning500)
            .width(16)

          Text(improvement)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text1)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: index === 0 ? 0 : Spacing.Space2 })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(WarningColors.Warning50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * STAR分析部分
   */
  @Builder
  StarAnalysisSection() {
    Column() {
      // 标题行（可展开）
      Row() {
        Text('STAR分析')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)

        Blank()

        Row() {
          Text(this.showStarAnalysis ? '收起' : '展开')
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)

          Image($r('app.media.media_ic_arrow_down'))
            .width(12)
            .height(12)
            .fillColor(BrandColors.Brand500)
            .rotate({ angle: this.showStarAnalysis ? 180 : 0 })
            .margin({ left: Spacing.Space1 })
        }
      }
      .width('100%')
      .onClick(() => {
        this.showStarAnalysis = !this.showStarAnalysis;
      })

      // STAR分析详情
      if (this.showStarAnalysis) {
        Column() {
          this.StarItem('S - 情境', this.feedback!.starAnalysis!.situation.score, this.feedback!.starAnalysis!.situation.comment)
          this.StarItem('T - 任务', this.feedback!.starAnalysis!.task.score, this.feedback!.starAnalysis!.task.comment)
          this.StarItem('A - 行动', this.feedback!.starAnalysis!.action.score, this.feedback!.starAnalysis!.action.comment)
          this.StarItem('R - 结果', this.feedback!.starAnalysis!.result.score, this.feedback!.starAnalysis!.result.comment)
        }
        .margin({ top: Spacing.Space4 })
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(BrandColors.Brand50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * STAR单项
   */
  @Builder
  StarItem(title: string, score: number, comment: string) {
    Row() {
      Text(title)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .width(80)

      Stack() {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor(NeutralColors.Neutral200)
          .borderRadius(3)

        Row()
          .width(`${score}%`)
          .height(6)
          .backgroundColor(this.getScoreColor(score))
          .borderRadius(3)
      }
      .layoutWeight(1)
      .height(6)

      Text(score.toString())
        .fontSize(FontSize.Xs)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getScoreColor(data.score))
        .width(28)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: Spacing.Space3 })

    Text(data.comment)
      .fontSize(FontSize.Xs)
      .fontColor(SemanticColors.Text3)
      .margin({ top: Spacing.Space1, left: 80 })
      .width('100%')
  }

  /**
   * 参考答案部分
   */
  @Builder
  ReferenceAnswerSection() {
    Column() {
      // 标题行（可展开）
      Row() {
        Text('参考答案')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)

        Blank()

        Row() {
          Text(this.showReferenceAnswer ? '收起' : '查看')
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)

          Image($r('app.media.media_ic_arrow_down'))
            .width(12)
            .height(12)
            .fillColor(BrandColors.Brand500)
            .rotate({ angle: this.showReferenceAnswer ? 180 : 0 })
            .margin({ left: Spacing.Space1 })
        }
      }
      .width('100%')
      .onClick(() => {
        this.showReferenceAnswer = !this.showReferenceAnswer;
      })

      // 参考答案内容
      if (this.showReferenceAnswer) {
        Text(this.feedback!.referenceAnswer)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text1)
          .lineHeight(22)
          .margin({ top: Spacing.Space4 })
          .width('100%')
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 建议部分
   */
  @Builder
  SuggestionsSection() {
    Column() {
      Text('面试技巧')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: Spacing.Space3 })

      ForEach(this.feedback!.suggestions, (suggestion: string, index: number) => {
        Row() {
          Text((index + 1).toString())
            .fontSize(FontSize.Xs)
            .fontColor(NeutralColors.Neutral0)
            .width(20)
            .height(20)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(10)
            .textAlign(TextAlign.Center)

          Text(suggestion)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text1)
            .margin({ left: Spacing.Space3 })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: index === 0 ? 0 : Spacing.Space3 })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space4 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 底部操作按钮
   */
  @Builder
  ActionButtons() {
    Row() {
      // 重新回答按钮
      Button() {
        Row() {
          Image($r('app.media.media_ic_refresh'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)

          Text('重新回答')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .margin({ left: Spacing.Space2 })
        }
      }
      .height(44)
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius(SemanticRadius.Pill)
      .border({ width: 1, color: BrandColors.Brand500 })
      .layoutWeight(1)
      .onClick(() => this.onRetryQuestion())

      // 下一题按钮
      Button() {
        Row() {
          Text('下一题')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)

          Image($r('app.media.media_ic_arrow_right'))
            .width(16)
            .height(16)
            .fillColor(NeutralColors.Neutral0)
            .margin({ left: Spacing.Space2 })
        }
      }
      .height(44)
      .backgroundColor(BrandColors.Brand500)
      .borderRadius(SemanticRadius.Pill)
      .layoutWeight(1)
      .margin({ left: Spacing.Space3 })
      .onClick(() => this.onNextQuestion())
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space9 })
    .backgroundColor(NeutralColors.Neutral0)
  }

  /**
   * 获取分数颜色
   */
  private getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /**
   * 获取分数标签
   */
  private getScoreLabel(score: number): string {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 70) return '中等';
    if (score >= 60) return '及格';
    return '需改进';
  }

  /**
   * 获取分数描述
   */
  private getScoreDescription(score: number): string {
    if (score >= 90) return '回答非常出色';
    if (score >= 80) return '回答质量良好';
    if (score >= 70) return '回答基本合格';
    if (score >= 60) return '回答需要提升';
    return '回答存在明显不足';
  }
}
