import router from '@ohos.router';
import { User } from '../models/User';
import { MemberService, MemberStatus, Benefit } from '../services/MemberService';
import { MemberCard } from '../components/profile/MemberCard';
import { BenefitGrid } from '../components/profile/BenefitGrid';
import { PurchaseSheet } from '../components/profile/PurchaseSheet';
import { MemberDetailSheet } from '../components/profile/MemberDetailSheet';
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
} from '../constants/design-tokens';

@Component
export struct ProfilePage {
  @State userInfo: User | null = null;
  @State isVip: boolean = false;
  @State memberStatus: MemberStatus | null = null;
  @State benefits: Benefit[] = [];
  
  // 弹窗控制
  @State showPurchaseSheet: boolean = false;
  @State showDetailSheet: boolean = false;
  
  private memberService: MemberService = MemberService.getInstance();

  aboutToAppear() {
    this.loadUserInfo();
    this.loadMemberStatus();
  }

  loadUserInfo() {
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        this.userInfo = JSON.parse(userStr);
        this.isVip = this.checkVipStatus();
      } catch (e) {
        this.initDemoUser();
      }
    } else {
      this.initDemoUser();
    }
  }

  loadMemberStatus() {
    // 异步加载会员状态
    this.memberService.getMemberStatus().then((status) => {
      this.memberStatus = status;
      this.isVip = status.isMember;
    });
    
    // 加载权益列表
    this.memberService.getBenefits().then((benefits) => {
      this.benefits = benefits;
    });
  }

  initDemoUser() {
    this.userInfo = {
      id: '10001',
      username: '求职者',
      phone: '138****8888',
      avatar: '',
      vipLevel: 0,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    this.isVip = false;
  }

  build() {
    Stack() {
      Column() {
        // 会员状态卡片 - 替换原有的用户信息卡片
        MemberCard({
          userInfo: this.userInfo,
          memberStatus: this.memberStatus,
          isVip: this.isVip,
          onUpgradeClick: () => {
            this.showPurchaseSheet = true;
          },
          onDetailClick: () => {
            this.showDetailSheet = true;
          }
        })

        // 权益宫格展示
        BenefitGrid({
          benefits: this.benefits,
          isMember: this.isVip,
          columns: 3,
          onBenefitClick: (benefit: Benefit) => {
            // 点击权益项
            if (this.isVip) {
              // 已是会员，显示详情
              this.showDetailSheet = true;
            } else {
              // 非会员，引导开通
              this.showPurchaseSheet = true;
            }
          }
        })
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })

        // 功能菜单
        Column() {
          this.MenuItem({
            icon: $r('app.media.ic_order'),
            title: '订单记录',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/OrderHistory' });
            }
          })

          Divider()
            .margin({ left: 56 })

          this.MenuItem({
            icon: $r('app.media.ic_favorite'),
            title: '我的收藏',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/Favorites' });
            }
          })

          Divider()
            .margin({ left: 56 })

          this.MenuItem({
            icon: $r('app.media.ic_history'),
            title: '历史记录',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/History' });
            }
          })

          Divider()
            .margin({ left: 56 })

          this.MenuItem({
            icon: $r('app.media.ic_help'),
            title: '帮助与反馈',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/HelpFeedback' });
            }
          })

          Divider()
            .margin({ left: 56 })

          this.MenuItem({
            icon: $r('app.media.ic_settings'),
            title: '设置',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/SettingsPage' });
            }
          })

          Divider()
            .margin({ left: 56 })

          this.MenuItem({
            icon: $r('app.media.ic_about'),
            title: '关于我们',
            showBadge: false,
            onClick: () => {
              router.pushUrl({ url: 'pages/profile/AboutPage' });
            }
          })
        }
        .layoutWeight(1)
        .backgroundColor(NeutralColors.Neutral0)
        .borderRadius(SemanticRadius.Component)
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
        .shadow({
          radius: 8,
          color: 'rgba(0, 0, 0, 0.04)',
          offsetY: 2
        })

        // 版本信息
        Text('一职搭子 v' + (AppStorage.get('appVersion') as string || '1.0.1'))
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text4)
          .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(NeutralColors.Neutral50)

      // 购买面板
      if (this.showPurchaseSheet) {
        PurchaseSheet({
          onClose: () => {
            this.showPurchaseSheet = false;
          },
          onSuccess: () => {
            // 购买成功，刷新状态
            this.refreshMemberStatus();
          }
        })
      }

      // 会员详情面板
      if (this.showDetailSheet) {
        MemberDetailSheet({
          memberStatus: this.memberStatus,
          onClose: () => {
            this.showDetailSheet = false;
          },
          onRenewClick: () => {
            this.showDetailSheet = false;
            this.showPurchaseSheet = true;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MenuItem(params: { icon: Resource; title: string; showBadge: boolean; onClick?: () => void }) {
    Row() {
      Column() {
        Image(params.icon)
          .width(ComponentSizes.Icon.Lg)
          .height(ComponentSizes.Icon.Lg)
          .fillColor(SemanticColors.Text3)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)

      Text(params.title)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text1)
        .margin({ left: Spacing.Space4 })

      Blank()

      if (params.showBadge) {
        Circle()
          .width(8)
          .height(8)
          .fill(BrandColors.Brand500)
          .margin({ right: Spacing.Space3 })
      }

      Image($r('app.media.ic_arrow_right'))
        .width(16)
        .height(16)
        .fillColor(SemanticColors.Text4)
    }
    .width('100%')
    .height(52)
    .padding({ left: Spacing.Space4, right: SemanticSpacing.Lg })
    .backgroundColor(NeutralColors.Neutral0)
    .onClick(() => {
      if (params.onClick) {
        params.onClick();
      }
    })
  }

  getAvatarText(): string {
    const name = this.userInfo?.username || '未';
    return name.substring(0, 1);
  }

  checkVipStatus(): boolean {
    const vipLevel = this.userInfo?.vipLevel || 0;
    const vipExpireTime = this.userInfo?.vipExpireTime || 0;
    if (vipLevel <= 0) return false;
    if (!vipExpireTime) return false;
    return vipExpireTime > Date.now();
  }

  /**
   * 刷新会员状态
   */
  private async refreshMemberStatus() {
    const status = await this.memberService.refreshStatus();
    this.memberStatus = status;
    this.isVip = status.isMember;
    
    // 刷新权益列表
    const benefits = await this.memberService.getBenefits();
    this.benefits = benefits;
  }
}
