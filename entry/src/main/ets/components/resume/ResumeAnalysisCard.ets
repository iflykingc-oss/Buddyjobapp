/**
 * 简历分析维度卡片组件
 * 展示单个维度的评分、环形进度和具体建议
 * 
 * 设计规范：
 * - 环形进度条显示评分（0-100）
 * - 维度图标和名称
 * - 评分等级标签
 * - 具体建议内容
 */

import { Dimension } from '../../models/Resume';
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
  FontWeight
} from '../../constants/design-tokens';

// 维度图标映射
const DimensionIconMap: Record<string, string> = {
  '基本信息': 'ic_user',
  '工作经历': 'ic_work',
  '教育背景': 'ic_education',
  '技能特长': 'ic_skill',
  '项目经验': 'ic_project',
  '自我评价': 'ic_evaluation',
  '语言能力': 'ic_language',
  '证书资质': 'ic_certificate'
};

// 维度颜色映射
const DimensionColorMap: Record<string, string> = {
  '基本信息': BrandColors.Brand500,
  '工作经历': '#3B82F6',
  '教育背景': '#10B981',
  '技能特长': '#F59E0B',
  '项目经验': '#8B5CF6',
  '自我评价': '#EC4899',
  '语言能力': '#06B6D4',
  '证书资质': '#EF4444'
};

@Component
export struct ResumeAnalysisCard {
  // 维度数据
  @Prop dimension: Dimension | null = null;
  // 卡片索引（用于动画延迟）
  @Prop index: number = 0;
  // 是否显示详细建议
  @Prop showSuggestion: boolean = true;
  // 是否激活状态（Swiper 当前项）
  @Prop isActive: boolean = false;
  
  // 动画状态
  @State private progressValue: number = 0;
  @State private cardScale: number = 0.95;
  @State private cardOpacity: number = 0;

  aboutToAppear() {
    // 入场动画
    this.playEnterAnimation();
  }

  aboutToDisappear() {
    // 清理动画
  }

  /**
   * 播放入场动画
   */
  private playEnterAnimation(): void {
    // 延迟启动，实现交错效果
    const delay = this.index * 100;
    
    // 缩放和透明度动画
    animateTo({
      duration: 400,
      delay: delay,
      curve: Curve.EaseOut
    }, () => {
      this.cardScale = 1.0;
      this.cardOpacity = 1.0;
    });

    // 进度条动画
    setTimeout(() => {
      this.animateProgress();
    }, delay + 200);
  }

  /**
   * 进度条动画
   */
  private animateProgress(): void {
    const targetProgress = this.dimension?.score || 0;
    const duration = 800;
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      
      // 使用 easeOut 缓动
      const easeOut = 1 - Math.pow(1 - progress, 3);
      this.progressValue = Math.floor(targetProgress * easeOut);
      
      if (progress < 1) {
        setTimeout(animate, 16);
      }
    };
    
    animate();
  }

  build() {
    if (!this.dimension) {
      return;
    }

    Column() {
      // 顶部：维度图标和名称
      this.buildHeader();

      // 中部：环形进度条
      this.buildProgressRing();

      // 底部：建议内容
      if (this.showSuggestion) {
        this.buildSuggestion();
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: this.isActive ? 16 : 8,
      color: this.isActive ? 'rgba(139, 92, 246, 0.15)' : 'rgba(0, 0, 0, 0.06)',
      offsetY: this.isActive ? 8 : 2
    })
    .scale({ x: this.cardScale, y: this.cardScale })
    .opacity(this.cardOpacity)
    .animation({
      duration: 300,
      curve: Curve.EaseOut
    })
  }

  /**
   * 构建头部：维度图标和名称
   */
  @Builder
  buildHeader() {
    Row() {
      // 维度图标
      Column() {
        Image($r(`app.media.${this.getDimensionIcon()}`))
          .width(24)
          .height(24)
          .fillColor(this.getDimensionColor())
      }
      .width(48)
      .height(48)
      .backgroundColor(this.getDimensionColor() + '15') // 15% 透明度
      .borderRadius(24)
      .justifyContent(FlexAlign.Center)

      // 维度名称
      Column() {
        Text(this.dimension!.name)
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)

        Text(this.getScoreLabel())
          .fontSize(FontSize.Xs)
          .fontColor(this.getScoreColor())
          .margin({ top: Spacing.Space1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: SemanticSpacing.Lg })
      .layoutWeight(1)

      // 评分标签
      Column() {
        Text(`${this.dimension!.score}分`)
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor())
      }
      .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
      .backgroundColor(this.getScoreColor() + '15')
      .borderRadius(SemanticRadius.Pill)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 构建环形进度条
   */
  @Builder
  buildProgressRing() {
    Column() {
      Stack() {
        // 背景圆环
        Circle()
          .width(120)
          .height(120)
          .fill('transparent')
          .stroke(NeutralColors.Neutral200)
          .strokeWidth(8)

        // 进度圆环
        Circle()
          .width(120)
          .height(120)
          .fill('transparent')
          .stroke(this.getScoreColor())
          .strokeWidth(8)
          .strokeDashArray([this.progressValue / 100 * 377, 377]) // 377 = 2 * PI * 60
          .rotate({ angle: -90, centerX: '50%', centerY: '50%' })

        // 中心内容
        Column() {
          Text(`${this.progressValue}%`)
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor())

          Text(this.getScoreLabel())
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space1 })
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(120)
      .height(120)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: SemanticSpacing.Xl, bottom: SemanticSpacing.Xl })
  }

  /**
   * 构建建议内容
   */
  @Builder
  buildSuggestion() {
    Column() {
      // 分隔线
      Divider()
        .width('100%')
        .height(1)
        .color(NeutralColors.Neutral200)
        .margin({ bottom: SemanticSpacing.Lg })

      // 建议标题
      Row() {
        Image($r('app.media.media_ic_tip'))
          .width(16)
          .height(16)
          .fillColor(BrandColors.Brand500)

        Text('优化建议')
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(BrandColors.Brand500)
          .margin({ left: Spacing.Space2 })
      }
      .width('100%')
      .margin({ bottom: Spacing.Space4 })

      // 建议内容
      Text(this.dimension!.description)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 获取维度图标
   */
  private getDimensionIcon(): string {
    return DimensionIconMap[this.dimension!.name] || 'ic_analysis';
  }

  /**
   * 获取维度颜色
   */
  private getDimensionColor(): string {
    return DimensionColorMap[this.dimension!.name] || BrandColors.Brand500;
  }

  /**
   * 获取评分颜色
   */
  private getScoreColor(): string {
    const score = this.dimension!.score;
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /**
   * 获取评分标签
   */
  private getScoreLabel(): string {
    const score = this.dimension!.score;
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 60) return '合格';
    if (score >= 40) return '待改进';
    return '需优化';
  }
}

export default ResumeAnalysisCard;
