/**
 * 简历分析结果 Swiper 组件
 * 多维度结果滑动展示，配合底部指示器
 * 
 * 设计规范：
 * - 使用 Swiper 组件展示各维度评分卡片
 * - 底部指示器显示当前位置
 * - 支持手势滑动切换
 * - 卡片切换动画
 */

import { ResumeAnalysisResult, Dimension, Suggestion } from '../../models/Resume';
import { ResumeAnalysisCard } from './ResumeAnalysisCard';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration
} from '../../constants/design-tokens';

// Swiper 控制器
import { SwiperController } from '@kit.ArkUI';

@Component
export struct ResumeResultSwiper {
  // 分析结果数据
  @Prop analysisResult: ResumeAnalysisResult | null = null;
  // 当前 Swiper 索引
  @State currentIndex: number = 0;
  // Swiper 控制器
  private swiperController: SwiperController = new SwiperController();
  // 指示器动画状态
  @State private indicatorScale: number = 1.0;

  // 计算总页数：维度卡片 + 总分卡片 + 建议卡片
  private get totalPages(): number {
    if (!this.analysisResult) return 0;
    // 维度数量 + 总分页 + 建议页
    return this.analysisResult.dimensions.length + 2;
  }

  build() {
    if (!this.analysisResult) {
      return;
    }

    Column() {
      // Swiper 内容区
      Swiper(this.swiperController) {
        // 第一页：ATS 总分卡片
        this.buildOverallScoreCard();

        // 中间页：各维度分析卡片
        ForEach(this.analysisResult.dimensions, (dimension: Dimension, index: number) => {
          ResumeAnalysisCard({
            dimension: dimension,
            index: index,
            showSuggestion: true,
            isActive: this.currentIndex === index + 1
          });
        });

        // 最后一页：优化建议汇总卡片
        this.buildSuggestionsCard();
      }
      .width('100%')
      .layoutWeight(1)
      .loop(false)
      .autoPlay(false)
      .indicator(false) // 使用自定义指示器
      .duration(Duration.Normal)
      .curve(Curve.EaseInOut)
      .onChange((index: number) => {
        this.onSwiperChange(index);
      })
      .margin({ top: SemanticSpacing.Lg })

      // 底部指示器
      this.buildIndicator();

      // 底部操作栏
      this.buildActionBar();
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 构建总分卡片
   */
  @Builder
  buildOverallScoreCard() {
    Column() {
      // 标题
      Text('简历综合评分')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .margin({ bottom: SemanticSpacing.Xl })

      // 大号环形进度
      Stack() {
        // 背景圆环
        Circle()
          .width(160)
          .height(160)
          .fill('transparent')
          .stroke(NeutralColors.Neutral200)
          .strokeWidth(12)

        // 进度圆环
        Circle()
          .width(160)
          .height(160)
          .fill('transparent')
          .stroke(this.getOverallScoreColor())
          .strokeWidth(12)
          .strokeDashArray([this.analysisResult!.atsScore / 100 * 502, 502]) // 502 = 2 * PI * 80
          .rotate({ angle: -90, centerX: '50%', centerY: '50%' })

        // 中心内容
        Column() {
          Text(this.analysisResult!.atsScore.toString())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getOverallScoreColor())

          Text('分')
            .fontSize(FontSize.Lg)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space1 })
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(160)
      .height(160)
      .margin({ bottom: SemanticSpacing.Xl })

      // 评分等级
      Row() {
        Text(this.getOverallScoreLabel())
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)
      }
      .padding({ left: Spacing.Space6, right: Spacing.Space6, top: Spacing.Space3, bottom: Spacing.Space3 })
      .backgroundColor(this.getOverallScoreColor())
      .borderRadius(SemanticRadius.Pill)

      // 总结
      Text(this.analysisResult!.summary)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
        .width('90%')
        .margin({ top: SemanticSpacing.Xl })

      // 关键词标签
      this.buildKeywordTags();
    }
    .width('100%')
    .height('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: 16,
      color: 'rgba(139, 92, 246, 0.15)',
      offsetY: 8
    })
    .justifyContent(FlexAlign.Start)
  }

  /**
   * 构建关键词标签
   */
  @Builder
  buildKeywordTags() {
    if (!this.analysisResult || !this.analysisResult.keywords.length) {
      return;
    }

    Column() {
      Text('简历关键词')
        .fontSize(FontSize.Sm)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: Spacing.Space3 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.analysisResult.keywords.slice(0, 8), (keyword: string) => {
          Text(keyword)
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(SemanticRadius.Pill)
            .margin({ right: Spacing.Space2, bottom: Spacing.Space2 })
        });
      }
    }
    .width('100%')
    .margin({ top: SemanticSpacing.Xl })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 构建优化建议汇总卡片
   */
  @Builder
  buildSuggestionsCard() {
    Column() {
      // 标题
      Row() {
        Image($r('app.media.media_ic_tip'))
          .width(20)
          .height(20)
          .fillColor(BrandColors.Brand500)

        Text('优化建议汇总')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .margin({ left: Spacing.Space3 })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Lg })

      // 建议列表
      Scroll() {
        Column() {
          ForEach(this.analysisResult!.suggestions, (suggestion: Suggestion, index: number) => {
            this.buildSuggestionItem(suggestion, index);
          });
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: 16,
      color: 'rgba(139, 92, 246, 0.15)',
      offsetY: 8
    })
  }

  /**
   * 构建单个建议项
   */
  @Builder
  buildSuggestionItem(suggestion: Suggestion, index: number) {
    Row() {
      // 序号
      Column() {
        Text(`${index + 1}`)
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(NeutralColors.Neutral0)
      }
      .width(28)
      .height(28)
      .backgroundColor(this.getSuggestionColor(suggestion.type))
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)

      // 内容
      Column() {
        Row() {
          Text(suggestion.title)
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)

          // 优先级标签
          Text(this.getPriorityLabel(suggestion.priority))
            .fontSize(FontSize.Xs)
            .fontColor(this.getPriorityColor(suggestion.priority))
            .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
            .backgroundColor(this.getPriorityColor(suggestion.priority) + '20')
            .borderRadius(4)
            .margin({ left: Spacing.Space2 })
        }
        .width('100%')

        Text(suggestion.description)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text2)
          .margin({ top: Spacing.Space2 })
          .lineHeight(18)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: Spacing.Space4 })
    }
    .width('100%')
    .padding(Spacing.Space4)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Control)
    .margin({ bottom: Spacing.Space3 })
  }

  /**
   * 构建底部指示器
   */
  @Builder
  buildIndicator() {
    Row() {
      ForEach(Array.from({ length: this.totalPages }), (_: unknown, index: number) => {
        Column()
          .width(this.currentIndex === index ? 24 : 8)
          .height(8)
          .backgroundColor(this.currentIndex === index ? BrandColors.Brand500 : NeutralColors.Neutral300)
          .borderRadius(4)
          .margin({ left: index === 0 ? 0 : Spacing.Space2 })
          .animation({
            duration: Duration.Fast,
            curve: Curve.EaseOut
          })
          .onClick(() => {
            this.swiperController.changeIndex(index);
          });
      });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
  }

  /**
   * 构建底部操作栏
   */
  @Builder
  buildActionBar() {
    Row() {
      // 导出 PDF
      Button() {
        Row() {
          Image($r('app.media.media_ic_download'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)

          Text('导出PDF')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .margin({ left: Spacing.Space2 })
        }
      }
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(SemanticRadius.Control)
      .height(40)
      .layoutWeight(1)
      .onClick(() => {
        this.onExportPdf();
      })

      Blank().width(Spacing.Space3)

      // 重新分析
      Button() {
        Row() {
          Image($r('app.media.media_ic_refresh'))
            .width(16)
            .height(16)
            .fillColor(NeutralColors.Neutral0)

          Text('重新分析')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .margin({ left: Spacing.Space2 })
        }
      }
      .backgroundColor(BrandColors.Brand500)
      .borderRadius(SemanticRadius.Control)
      .height(40)
      .layoutWeight(1)
      .onClick(() => {
        this.onReanalyze();
      })

      Blank().width(Spacing.Space3)

      // 优化建议
      Button() {
        Row() {
          Image($r('app.media.media_ic_optimize'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)

          Text('优化建议')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .margin({ left: Spacing.Space2 })
        }
      }
      .backgroundColor(BrandColors.Brand50)
      .borderRadius(SemanticRadius.Control)
      .height(40)
      .layoutWeight(1)
      .onClick(() => {
        this.onViewSuggestions();
      })
    }
    .width('100%')
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetY: -4
    })
  }

  /**
   * Swiper 切换事件
   */
  private onSwiperChange(index: number): void {
    animateTo({
      duration: Duration.Fast,
      curve: Curve.EaseOut
    }, () => {
      this.currentIndex = index;
    });
  }

  /**
   * 导出 PDF
   */
  private onExportPdf(): void {
    // 触发父组件的导出事件
    console.log('[ResumeResultSwiper] Export PDF clicked');
  }

  /**
   * 重新分析
   */
  private onReanalyze(): void {
    // 触发父组件的重新分析事件
    console.log('[ResumeResultSwiper] Reanalyze clicked');
  }

  /**
   * 查看优化建议
   */
  private onViewSuggestions(): void {
    // 跳转到建议页
    if (this.analysisResult && this.analysisResult.suggestions.length > 0) {
      this.swiperController.changeIndex(this.totalPages - 1);
    }
  }

  /**
   * 获取总分颜色
   */
  private getOverallScoreColor(): string {
    const score = this.analysisResult?.atsScore || 0;
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /**
   * 获取总分标签
   */
  private getOverallScoreLabel(): string {
    const score = this.analysisResult?.atsScore || 0;
    if (score >= 90) return '优秀简历';
    if (score >= 80) return '良好简历';
    if (score >= 60) return '合格简历';
    if (score >= 40) return '待改进简历';
    return '需优化简历';
  }

  /**
   * 获取建议类型颜色
   */
  private getSuggestionColor(type: string): string {
    switch (type) {
      case 'add':
        return SuccessColors.Success500;
      case 'modify':
        return WarningColors.Warning500;
      case 'delete':
        return ErrorColors.Error500;
      default:
        return BrandColors.Brand500;
    }
  }

  /**
   * 获取优先级颜色
   */
  private getPriorityColor(priority: string): string {
    switch (priority) {
      case 'high':
        return ErrorColors.Error500;
      case 'medium':
        return WarningColors.Warning500;
      case 'low':
        return SuccessColors.Success500;
      default:
        return BrandColors.Brand500;
    }
  }

  /**
   * 获取优先级标签
   */
  private getPriorityLabel(priority: string): string {
    switch (priority) {
      case 'high':
        return '高优先';
      case 'medium':
        return '中优先';
      case 'low':
        return '低优先';
      default:
        return '';
    }
  }
}

export default ResumeResultSwiper;
