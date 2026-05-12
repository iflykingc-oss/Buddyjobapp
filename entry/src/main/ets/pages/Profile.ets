import router from '@ohos.router';
import { User } from '../models/User';
import { HuaweiPayService } from '../utils/huaweiPay';
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
  @State showVipDialog: boolean = false;
  @State memberBenefits: string[] = [
    '无限次简历分析',
    '无限次岗位测评',
    'AI对话优先响应',
    '专属职业规划报告',
    '简历AI智能润色'
  ];

  aboutToAppear() {
    this.loadUserInfo();
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
    Column() {
      // 用户信息卡片
      Column() {
        Row() {
          Column() {
            if (this.userInfo?.avatar) {
              Image(this.userInfo.avatar)
                .width(64)
                .height(64)
                .borderRadius(32)
            } else {
              Column() {
                Text(this.getAvatarText())
                  .fontSize(FontSize.Xxl)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(NeutralColors.Neutral0)
              }
              .width(64)
              .height(64)
              .borderRadius(32)
              .linearGradient({
                direction: GradientDirection.BottomRight,
                colors: [
                  [BrandColors.Brand400, 0],
                  [BrandColors.Brand600, 1]
                ]
              })
              .justifyContent(FlexAlign.Center)
            }
          }
          .width(64)
          .height(64)
          .margin({ right: SemanticSpacing.Lg })

          Column() {
            Row() {
              Text(this.userInfo?.username || '未登录')
                .fontSize(FontSize.Lg)
                .fontWeight(FontWeight.Medium)
                .fontColor(SemanticColors.Text1)

              if (this.isVip) {
                Text('VIP')
                  .fontSize(FontSize.Xs)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(NeutralColors.Neutral0)
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
            }

            Text(this.userInfo?.phone || '点击登录')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .margin({ top: Spacing.Space3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (!this.isVip) {
            Button('开通VIP')
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .linearGradient({
                direction: GradientDirection.Right,
                colors: [
                  [WarningColors.Warning500, 0],
                  ['#F97316', 1]
                ]
              })
              .borderRadius(SemanticRadius.Pill)
              .height(32)
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .onClick(() => {
                this.showVipDialog = true;
              })
          }
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
        .backgroundColor(NeutralColors.Neutral0)
      }
      .backgroundColor(NeutralColors.Neutral0)
      .margin({ top: Spacing.Space9 })

      // VIP 权益说明
      if (!this.isVip) {
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
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4 })

          Row() {
            ForEach(this.memberBenefits.slice(0, 3), (benefit: string) => {
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
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
        }
        .width('100%')
        .backgroundColor('#FFF8E6')
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3 })
        .borderRadius(SemanticRadius.Control)
      }

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
            console.info('Navigate to favorites');
          }
        })

        Divider()
          .margin({ left: 56 })

        this.MenuItem({
          icon: $r('app.media.ic_history'),
          title: '历史记录',
          showBadge: false,
          onClick: () => {
            console.info('Navigate to history');
          }
        })

        Divider()
          .margin({ left: 56 })

        this.MenuItem({
          icon: $r('app.media.ic_help'),
          title: '帮助与反馈',
          showBadge: false,
          onClick: () => {
            console.info('Navigate to help');
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

      // VIP 弹窗
      if (this.showVipDialog) {
        this.VipDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
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
    const vipExpireTime = this.userInfo?.vipExpireTime || '';
    if (vipLevel <= 0) return false;
    if (!vipExpireTime) return false;
    return new Date(vipExpireTime).getTime() > Date.now();
  }

  @Builder
  VipDialog() {
    Column() {
      Column() {
        Text('开通VIP会员')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })
        
        Text('享受更多专属权益')
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ bottom: 24 })
        
        Row() {
          Button('取消')
            .backgroundColor('#F1F5F9')
            .fontColor('#64748B')
            .onClick(() => {
              this.showVipDialog = false;
            })
          
          Button('立即开通')
            .backgroundColor($r('app.color.primary'))
            .fontColor(Color.White)
            .margin({ left: 12 })
            .onClick(() => {
              this.showVipDialog = false;
              // TODO: 调用支付服务
            })
        }
      }
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(24)
      .width('80%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showVipDialog = false;
    })
  }
}
