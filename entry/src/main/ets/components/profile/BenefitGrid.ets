/**
 * BenefitGrid - 权益宫格展示组件
 * 
 * 鸿蒙设计规范：
 * - 2x3 宫格展示核心权益
 * - 每个权益：图标 + 名称 + 状态（已开通/未开通）
 * - 点击查看权益详情
 */

import { Benefit } from '../../services/MemberService';
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

/**
 * 权益宫格参数
 */
export interface BenefitGridParams {
  benefits: Benefit[];
  isMember: boolean;
  onBenefitClick?: (benefit: Benefit) => void;
}

@Component
export struct BenefitGrid {
  @Prop benefits: Benefit[] = [];
  @Prop isMember: boolean = false;
  @Prop columns: number = 3; // 默认3列
  
  // 事件回调
  onBenefitClick?: (benefit: Benefit) => void;
  
  // 默认权益（当没有传入数据时使用）
  private defaultBenefits: Benefit[] = [
    { id: 'resume_analyze', name: '简历分析', icon: 'ic_resume', description: '无限次AI简历分析', isActive: false },
    { id: 'job_assess', name: '岗位测评', icon: 'ic_assessment', description: '无限次岗位匹配测评', isActive: false },
    { id: 'ai_chat', name: 'AI对话', icon: 'ic_chat', description: 'AI对话优先响应', isActive: false },
    { id: 'career_report', name: '职业规划', icon: 'ic_knowledge', description: '专属职业规划报告', isActive: false },
    { id: 'resume_polish', name: '简历润色', icon: 'ic_favorite', description: 'AI智能润色简历', isActive: false },
    { id: 'priority_support', name: '专属客服', icon: 'ic_help', description: '优先客服支持', isActive: false }
  ];

  build() {
    Column() {
      // 标题
      Row() {
        Text('会员权益')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
        
        Blank()
        
        if (this.isMember) {
          Text('已开通')
            .fontSize(FontSize.Xs)
            .fontColor(SuccessColors.Success500)
        } else {
          Text('开通后可用')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space4 })
      
      // 权益宫格
      this.BenefitGridLayout()
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .padding({ top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
  }

  /**
   * 权益宫格布局
   */
  @Builder
  BenefitGridLayout() {
    // 使用 Flex 实现宫格布局
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.getDisplayBenefits(), (benefit: Benefit, index: number) => {
        this.BenefitItem(benefit, index)
      })
    }
    .width('100%')
    .padding({ left: Spacing.Space4, right: Spacing.Space4 })
  }

  /**
   * 单个权益项
   */
  @Builder
  BenefitItem(benefit: Benefit, index: number) {
    Column() {
      // 图标
      Column() {
        Image(this.getBenefitIcon(benefit.icon))
          .width(28)
          .height(28)
          .fillColor(this.getIconColor(benefit.isActive))
      }
      .width(48)
      .height(48)
      .borderRadius(SemanticRadius.Control)
      .backgroundColor(this.getIconBgColor(benefit.isActive))
      .justifyContent(FlexAlign.Center)
      
      // 名称
      Text(benefit.name)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text1)
        .margin({ top: Spacing.Space3 })
      
      // 状态标签
      Text(this.getStatusText(benefit.isActive))
        .fontSize(FontSize.Xs)
        .fontColor(this.getStatusColor(benefit.isActive))
        .margin({ top: Spacing.Space2 })
    }
    .width(`${100 / this.columns}%`)
    .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
    .onClick(() => {
      if (this.onBenefitClick) {
        this.onBenefitClick(benefit);
      }
    })
  }

  /**
   * 获取显示的权益列表
   */
  private getDisplayBenefits(): Benefit[] {
    if (this.benefits && this.benefits.length > 0) {
      return this.benefits.map(b => ({
        ...b,
        isActive: this.isMember || b.isActive
      }));
    }
    return this.defaultBenefits.map(b => ({
      ...b,
      isActive: this.isMember
    }));
  }

  /**
   * 获取权益图标
   */
  private getBenefitIcon(iconName: string): Resource {
    switch (iconName) {
      case 'ic_resume':
        return $r('app.media.media_ic_resume');
      case 'ic_assessment':
        return $r('app.media.media_ic_assessment');
      case 'ic_chat':
        return $r('app.media.media_ic_chat');
      case 'ic_knowledge':
        return $r('app.media.media_ic_knowledge');
      case 'ic_favorite':
        return $r('app.media.media_ic_favorite');
      case 'ic_help':
        return $r('app.media.media_ic_help');
      default:
        return $r('app.media.media_ic_resume');
    }
  }

  /**
   * 获取图标颜色
   */
  private getIconColor(isActive: boolean): string {
    return isActive ? BrandColors.Brand500 : NeutralColors.Neutral400;
  }

  /**
   * 获取图标背景颜色
   */
  private getIconBgColor(isActive: boolean): string {
    return isActive ? BrandColors.Brand50 : NeutralColors.Neutral100;
  }

  /**
   * 获取状态文案
   */
  private getStatusText(isActive: boolean): string {
    return isActive ? '已开通' : '未开通';
  }

  /**
   * 获取状态颜色
   */
  private getStatusColor(isActive: boolean): string {
    return isActive ? SuccessColors.Success500 : SemanticColors.Text3;
  }
}

/**
 * 紧凑型权益宫格（用于弹窗等场景）
 */
@Component
export struct CompactBenefitGrid {
  @Prop benefits: Benefit[] = [];
  @Prop isMember: boolean = false;
  
  build() {
    Column() {
      // 标题
      Row() {
        Text('会员权益')
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .margin({ bottom: Spacing.Space4 })
      
      // 权益列表（紧凑布局）
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.getDisplayBenefits(), (benefit: Benefit) => {
          Row() {
            // 图标
            Image(this.getBenefitIcon(benefit.icon))
              .width(16)
              .height(16)
              .fillColor(this.isMember ? BrandColors.Brand500 : NeutralColors.Neutral400)
            
            // 名称
            Text(benefit.name)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text2)
              .margin({ left: Spacing.Space2 })
          }
          .width('50%')
          .padding({ top: Spacing.Space2, bottom: Spacing.Space2 })
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Control)
  }

  private getDisplayBenefits(): Benefit[] {
    const defaults: Benefit[] = [
      { id: 'resume_analyze', name: '简历分析', icon: 'ic_resume', description: '', isActive: false },
      { id: 'job_assess', name: '岗位测评', icon: 'ic_assessment', description: '', isActive: false },
      { id: 'ai_chat', name: 'AI对话', icon: 'ic_chat', description: '', isActive: false },
      { id: 'career_report', name: '职业规划', icon: 'ic_knowledge', description: '', isActive: false },
      { id: 'resume_polish', name: '简历润色', icon: 'ic_favorite', description: '', isActive: false },
      { id: 'priority_support', name: '专属客服', icon: 'ic_help', description: '', isActive: false }
    ];
    
    if (this.benefits && this.benefits.length > 0) {
      return this.benefits;
    }
    return defaults;
  }

  private getBenefitIcon(iconName: string): Resource {
    switch (iconName) {
      case 'ic_resume':
        return $r('app.media.media_ic_resume');
      case 'ic_assessment':
        return $r('app.media.media_ic_assessment');
      case 'ic_chat':
        return $r('app.media.media_ic_chat');
      case 'ic_knowledge':
        return $r('app.media.media_ic_knowledge');
      case 'ic_favorite':
        return $r('app.media.media_ic_favorite');
      case 'ic_help':
        return $r('app.media.media_ic_help');
      default:
        return $r('app.media.media_ic_resume');
    }
  }
}
