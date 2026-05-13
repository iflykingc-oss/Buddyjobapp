/**
 * STAR法则悬浮提示组件
 *
 * 实时显示STAR法则引导，帮助用户组织回答
 * 支持展开查看完整说明
 * 遵循鸿蒙设计规范
 */
import { StarGuide as StarGuideType } from '../../services/InterviewService';
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
  Shadows
} from '../../constants/design-tokens';

@Component
export struct StarGuide {
  // STAR引导数据
  @Prop starGuide: StarGuideType | null = null;
  @Prop isAnswering: boolean = false;

  // 内部状态
  @State private isExpanded: boolean = false;
  @State private currentStep: 'S' | 'T' | 'A' | 'R' = 'S';

  // STAR步骤定义
  private starSteps: Array<{ key: 'S' | 'T' | 'A' | 'R'; title: string; icon: string }> = [
    { key: 'S', title: '情境', icon: 'S' },
    { key: 'T', title: '任务', icon: 'T' },
    { key: 'A', title: '行动', icon: 'A' },
    { key: 'R', title: '结果', icon: 'R' }
  ];

  build() {
    if (!this.starGuide) {
      // 默认STAR提示
      this.DefaultGuide()
    } else {
      // 完整STAR引导
      this.FullGuide()
    }
  }

  /**
   * 默认STAR提示（无具体引导数据时）
   */
  @Builder
  DefaultGuide() {
    Column() {
      // 标题行
      Row() {
        Text('STAR法则')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(BrandColors.Brand500)

        Blank()

        // 展开/收起按钮
        Image($r('app.media.media_ic_arrow_down'))
          .width(12)
          .height(12)
          .fillColor(BrandColors.Brand400)
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .onClick(() => {
            this.isExpanded = !this.isExpanded;
          })
      }
      .width('100%')

      // 简要提示
      if (!this.isExpanded) {
        Text('用STAR法则组织回答')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space2 })
          .width('100%')
      }

      // 展开内容
      if (this.isExpanded) {
        Column() {
          this.StepItem('S', '情境', '描述当时的背景和情况')
          this.StepItem('T', '任务', '说明你的目标和责任')
          this.StepItem('A', '行动', '详述你采取的行动')
          this.StepItem('R', '结果', '展示取得的成果')
        }
        .margin({ top: Spacing.Space3 })
      }
    }
    .width(160)
    .padding(SemanticSpacing.Md)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetY: 4
    })
    .border({
      width: 1,
      color: BrandColors.Brand200
    })
  }

  /**
   * 完整STAR引导
   */
  @Builder
  FullGuide() {
    Column() {
      // 标题行
      Row() {
        Row() {
          Text('STAR')
            .fontSize(FontSize.Xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(BrandColors.Brand500)

          Text('引导')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text2)
            .margin({ left: Spacing.Space1 })
        }

        Blank()

        // 展开/收起按钮
        Image($r('app.media.media_ic_arrow_down'))
          .width(12)
          .height(12)
          .fillColor(BrandColors.Brand400)
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .onClick(() => {
            this.isExpanded = !this.isExpanded;
          })
      }
      .width('100%')

      // 当前步骤指示器
      Row() {
        ForEach(this.starSteps, (step: { key: 'S' | 'T' | 'A' | 'R'; title: string; icon: string }) => {
          Column() {
            Text(step.icon)
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentStep === step.key ? NeutralColors.Neutral0 : BrandColors.Brand500)
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor(this.currentStep === step.key ? BrandColors.Brand500 : BrandColors.Brand50)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.currentStep = step.key;
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: Spacing.Space3 })

      // 当前步骤内容
      Column() {
        Text(this.getCurrentStepTitle())
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
          .width('100%')

        Text(this.getCurrentStepContent())
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text2)
          .margin({ top: Spacing.Space2 })
          .width('100%')
          .maxLines(this.isExpanded ? 10 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ top: Spacing.Space3 })
      .alignItems(HorizontalAlign.Start)

      // 展开查看完整内容
      if (this.isExpanded) {
        Column() {
          // 分隔线
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(NeutralColors.Neutral200)
            .margin({ top: Spacing.Space3, bottom: Spacing.Space3 })

          // 完整STAR内容
          this.FullStarContent()
        }
      }
    }
    .width(180)
    .padding(SemanticSpacing.Md)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetY: 4
    })
    .border({
      width: 1,
      color: BrandColors.Brand200
    })
  }

  /**
   * 步骤项
   */
  @Builder
  StepItem(key: string, title: string, description: string) {
    Row() {
      Text(key)
        .fontSize(FontSize.Xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(BrandColors.Brand500)
        .width(16)

      Column() {
        Text(title)
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)

        Text(description)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space1 })
      }
      .layoutWeight(1)
      .margin({ left: Spacing.Space2 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .margin({ top: Spacing.Space2 })
  }

  /**
   * 完整STAR内容
   */
  @Builder
  FullStarContent() {
    Column() {
      // 情境
      Row() {
        Text('S')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(BrandColors.Brand500)
          .width(16)

        Text('情境')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')

      Text(this.starGuide!.situation)
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text2)
        .margin({ top: Spacing.Space1, left: 16 })
        .width('100%')

      // 任务
      Row() {
        Text('T')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(BrandColors.Brand500)
          .width(16)

        Text('任务')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .margin({ top: Spacing.Space3 })

      Text(this.starGuide!.task)
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text2)
        .margin({ top: Spacing.Space1, left: 16 })
        .width('100%')

      // 行动
      Row() {
        Text('A')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(BrandColors.Brand500)
          .width(16)

        Text('行动')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .margin({ top: Spacing.Space3 })

      Text(this.starGuide!.action)
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text2)
        .margin({ top: Spacing.Space1, left: 16 })
        .width('100%')

      // 结果
      Row() {
        Text('R')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(BrandColors.Brand500)
          .width(16)

        Text('结果')
          .fontSize(FontSize.Xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .margin({ top: Spacing.Space3 })

      Text(this.starGuide!.result)
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text2)
        .margin({ top: Spacing.Space1, left: 16 })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 获取当前步骤标题
   */
  private getCurrentStepTitle(): string {
    switch (this.currentStep) {
      case 'S':
        return '描述情境 (Situation)';
      case 'T':
        return '说明任务 (Task)';
      case 'A':
        return '详述行动 (Action)';
      case 'R':
        return '展示结果 (Result)';
      default:
        return '';
    }
  }

  /**
   * 获取当前步骤内容
   */
  private getCurrentStepContent(): string {
    if (!this.starGuide) return '';

    switch (this.currentStep) {
      case 'S':
        return this.starGuide.situation;
      case 'T':
        return this.starGuide.task;
      case 'A':
        return this.starGuide.action;
      case 'R':
        return this.starGuide.result;
      default:
        return '';
    }
  }

  /**
   * 切换到下一个步骤
   */
  public nextStep(): void {
    switch (this.currentStep) {
      case 'S':
        this.currentStep = 'T';
        break;
      case 'T':
        this.currentStep = 'A';
        break;
      case 'A':
        this.currentStep = 'R';
        break;
      case 'R':
        this.currentStep = 'S';
        break;
    }
  }
}
