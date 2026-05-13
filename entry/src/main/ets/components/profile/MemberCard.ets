/**
 * MemberCard - 会员状态卡片组件
 * 
 * 鸿蒙典型设计：个人中心顶部卡片
 * - 会员状态：头像 + 会员等级 + 到期时间
 * - 非会员：升级按钮 + 权益预览
 */

import { User } from '../../models/User';
import { MemberService, MemberStatus, MemberLevel } from '../../services/MemberService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  WarningColors,
  SuccessColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

/**
 * 会员卡片参数
 */
export interface MemberCardParams {
  userInfo: User | null;
  memberStatus: MemberStatus | null;
  onUpgradeClick?: () => void;
  onDetailClick?: () => void;
}

@Component
export struct MemberCard {
  @Prop userInfo: User | null = null;
  @Prop memberStatus: MemberStatus | null = null;
  @Prop isVip: boolean = false;
  
  // 事件回调
  onUpgradeClick?: () => void;
  onDetailClick?: () => void;
  
  // 权益预览列表
  private benefitPreviews: string[] = [
    '无限次简历分析',
    '无限次岗位测评',
    'AI对话优先响应'
  ];

  build() {
    Column() {
      if (this.isVip && this.memberStatus?.isMember) {
        // 会员卡片
        this.MemberContent()
      } else {
        // 非会员卡片 - 升级入口
        this.NonMemberContent()
      }
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ top: Spacing.Space9 })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  /**
   * 会员内容
   */
  @Builder
  MemberContent() {
    Column() {
      // 顶部：头像 + 用户信息
      Row() {
        // 头像
        this.AvatarSection()
        
        // 用户信息
        Column() {
          Row() {
            Text(this.userInfo?.username || '会员用户')
              .fontSize(FontSize.Lg)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)
            
            // VIP 标签
            this.VipTag()
          }
          
          // 会员等级 + 到期时间
          Row() {
            Text(this.getLevelName())
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
            
            Text('·')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
              .margin({ left: Spacing.Space2, right: Spacing.Space2 })
            
            Text(this.getExpireText())
              .fontSize(FontSize.Sm)
              .fontColor(this.getExpireTextColor())
          }
          .margin({ top: Spacing.Space3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        
        // 查看详情箭头
        Column() {
          Image($r('app.media.media_ic_arrow_right'))
            .width(16)
            .height(16)
            .fillColor(SemanticColors.Text3)
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: Spacing.Space4, top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
      .onClick(() => {
        if (this.onDetailClick) {
          this.onDetailClick();
        }
      })
      
      // 分割线
      Divider()
        .margin({ left: SemanticSpacing.Xxl })
      
      // 底部：权益快捷入口
      Row() {
        Row() {
          Text('查看全部权益')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
          
          Image($r('app.media.media_ic_arrow_right'))
            .width(14)
            .height(14)
            .fillColor(BrandColors.Brand500)
            .margin({ left: Spacing.Space2 })
        }
        .onClick(() => {
          if (this.onDetailClick) {
            this.onDetailClick();
          }
        })
        
        Blank()
        
        // 自动续费状态
        if (this.memberStatus?.autoRenewing) {
          Row() {
            Text('自动续费')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
            
            Text('已开启')
              .fontSize(FontSize.Xs)
              .fontColor(SuccessColors.Success500)
              .margin({ left: Spacing.Space2 })
          }
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl, top: Spacing.Space4, bottom: Spacing.Space4 })
    }
  }

  /**
   * 非会员内容 - 升级入口
   */
  @Builder
  NonMemberContent() {
    Column() {
      // 顶部：头像 + 用户信息 + 升级按钮
      Row() {
        // 头像
        this.AvatarSection()
        
        // 用户信息
        Column() {
          Text(this.userInfo?.username || '求职者')
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
          
          Text(this.userInfo?.phone || '开通会员享更多权益')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ top: Spacing.Space3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        
        // 升级按钮
        Button() {
          Row() {
            Text('开通VIP')
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
          }
        }
        .height(32)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            [WarningColors.Warning500, 0],
            ['#F97316', 1]
          ]
        })
        .borderRadius(SemanticRadius.Pill)
        .onClick(() => {
          if (this.onUpgradeClick) {
            this.onUpgradeClick();
          }
        })
      }
      .width('100%')
      .padding(SemanticSpacing.Xl)
      
      // 权益预览区域
      Column() {
        Row() {
          Text('开通VIP解锁全部功能')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
          
          Blank()
          
          Text('限时优惠中')
            .fontSize(FontSize.Xs)
            .fontColor(WarningColors.Warning500)
        }
        .width('100%')
        
        // 权益列表
        Row() {
          ForEach(this.benefitPreviews, (benefit: string) => {
            Row() {
              Text('✓')
                .fontSize(FontSize.Xs)
                .fontColor(SuccessColors.Success500)
              
              Text(benefit)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text2)
                .margin({ left: Spacing.Space2 })
            }
            .margin({ right: SemanticSpacing.Lg })
          })
        }
        .width('100%')
        .margin({ top: Spacing.Space3 })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl, bottom: SemanticSpacing.Lg })
      .backgroundColor('#FFF8E6')
      .borderRadius({ bottomLeft: SemanticRadius.Control, bottomRight: SemanticRadius.Control })
    }
  }

  /**
   * 头像区域
   */
  @Builder
  AvatarSection() {
    Column() {
      if (this.userInfo?.avatar) {
        Image(this.userInfo.avatar)
          .width(56)
          .height(56)
          .borderRadius(28)
      } else {
        Column() {
          Text(this.getAvatarText())
            .fontSize(FontSize.Xl)
            .fontWeight(FontWeight.Bold)
            .fontColor(NeutralColors.Neutral0)
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .linearGradient({
          direction: GradientDirection.BottomRight,
          colors: [
            [BrandColors.Brand400, 0],
            [BrandColors.Brand600, 1]
          ]
        })
        .justifyContent(FlexAlign.Center)
      }
      
      // 会员角标
      if (this.isVip) {
        Row() {
          Image($r('app.media.media_ic_vip_crown'))
            .width(12)
            .height(12)
            .fillColor(WarningColors.Warning500)
        }
        .width(20)
        .height(20)
        .backgroundColor(NeutralColors.Neutral0)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center)
        .margin({ top: -10 })
        .shadow({
          radius: 4,
          color: 'rgba(0, 0, 0, 0.1)',
          offsetY: 1
        })
      }
    }
    .width(56)
    .margin({ right: SemanticSpacing.Lg })
  }

  /**
   * VIP 标签
   */
  @Builder
  VipTag() {
    Row() {
      Text('VIP')
        .fontSize(FontSize.Xs)
        .fontWeight(FontWeight.Medium)
        .fontColor(NeutralColors.Neutral0)
    }
    .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [
        [WarningColors.Warning500, 0],
        ['#F97316', 1]
      ]
    })
    .borderRadius(SemanticRadius.Pill)
    .margin({ left: Spacing.Space3 })
  }

  /**
   * 获取头像文字
   */
  private getAvatarText(): string {
    const name = this.userInfo?.username || '未';
    return name.substring(0, 1);
  }

  /**
   * 获取会员等级名称
   */
  private getLevelName(): string {
    if (!this.memberStatus) return '会员';
    return this.memberStatus.levelName || '会员';
  }

  /**
   * 获取到期文案
   */
  private getExpireText(): string {
    if (!this.memberStatus || !this.memberStatus.expireTime) return '';
    
    const remaining = this.memberStatus.remainingDays;
    if (remaining <= 0) {
      return '已过期';
    } else if (remaining <= 7) {
      return `${remaining}天后到期`;
    } else {
      const date = new Date(this.memberStatus.expireTime);
      const month = date.getMonth() + 1;
      const day = date.getDate();
      return `${month}月${day}日到期`;
    }
  }

  /**
   * 获取到期时间颜色
   */
  private getExpireTextColor(): string {
    if (!this.memberStatus) return SemanticColors.Text2;
    
    const remaining = this.memberStatus.remainingDays;
    if (remaining <= 3) {
      return ErrorColors.Error500;
    } else if (remaining <= 7) {
      return WarningColors.Warning500;
    }
    return SemanticColors.Text2;
  }
}
