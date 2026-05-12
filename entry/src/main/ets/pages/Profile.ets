import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { User } from '../models/User';
import { MemberService, MemberStatus, Benefit } from '../services/MemberService';
import { MemberCard } from '../components/profile/MemberCard';
import { BenefitGrid } from '../components/profile/BenefitGrid';
import { PurchaseSheet } from '../components/profile/PurchaseSheet';
import { MemberDetailSheet } from '../components/profile/MemberDetailSheet';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { WindowUtil } from '../utils/WindowUtil';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
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
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;

  // 弹窗控制
  @State showPurchaseSheet: boolean = false;
  @State showDetailSheet: boolean = false;
  @State showEditProfileSheet: boolean = false;
  @State editNickname: string = '';
  @State isLoading: boolean = false;

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
    this.isLoading = true;

    // 异步加载会员状态
    this.memberService.getMemberStatus().then((status) => {
      this.memberStatus = status;
      this.isVip = status.isMember;
    });

    // 加载权益列表
    this.memberService.getBenefits().then((benefits) => {
      this.benefits = benefits;
      this.isLoading = false;
    }).catch(() => {
      this.isLoading = false;
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
        if (this.isLoading) {
          // 骨架屏加载状态
          this.buildSkeletonView()
        } else {
          // 会员状态卡片 - 替换原有的用户信息卡片
          MemberCard({
            userInfo: this.userInfo,
            memberStatus: this.memberStatus,
            isVip: this.isVip,
            onUpgradeClick: () => {
              // 审核期间隐藏支付入口，显示即将上线提示
              promptAction.showToast({
                message: '支付功能即将上线，敬请期待',
                duration: 2000
              });
            },
            onDetailClick: () => {
              this.showDetailSheet = true;
            }
          })
          .onClick(() => {
            // 点击用户信息区域打开编辑弹窗
            this.editNickname = this.userInfo?.username || '';
            this.showEditProfileSheet = true;
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
                // 审核期间隐藏支付入口，显示即将上线提示
                promptAction.showToast({
                  message: '支付功能即将上线，敬请期待',
                  duration: 2000
                });
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
              router.pushUrl({
                url: 'pages/profile/OrderHistory',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })

            Divider()
              .margin({ left: 56 })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            this.MenuItem({
            icon: $r('app.media.ic_favorite'),
            title: '我的收藏',
            showBadge: false,
            onClick: () => {
              router.pushUrl({
                url: 'pages/profile/Favorites',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })

            Divider()
              .margin({ left: 56 })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            this.MenuItem({
            icon: $r('app.media.ic_history'),
            title: '历史记录',
            showBadge: false,
            onClick: () => {
              router.pushUrl({
                url: 'pages/profile/History',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })

            Divider()
              .margin({ left: 56 })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            this.MenuItem({
            icon: $r('app.media.ic_help'),
            title: '帮助与反馈',
            showBadge: false,
            onClick: () => {
              router.pushUrl({
                url: 'pages/profile/HelpFeedback',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })

            Divider()
              .margin({ left: 56 })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            this.MenuItem({
            icon: $r('app.media.ic_settings'),
            title: '设置',
            showBadge: false,
            onClick: () => {
              router.pushUrl({
                url: 'pages/profile/SettingsPage',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })

            Divider()
              .margin({ left: 56 })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            this.MenuItem({
            icon: $r('app.media.ic_about'),
            title: '关于我们',
            showBadge: false,
            onClick: () => {
              router.pushUrl({
                url: 'pages/profile/AboutPage',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            }
          })
          }
          .layoutWeight(1)
          .constraintSize({ maxWidth: this.windowUtil?.isWideScreen() ? 600 : undefined })
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 版本信息
        Text('一职搭子 v' + (AppStorage.get('appVersion') as string || '1.0.1'))
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
          .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)

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
            // 审核期间隐藏支付入口，显示即将上线提示
            promptAction.showToast({
              message: '支付功能即将上线，敬请期待',
              duration: 2000
            });
          }
        })
      }

      // 编辑个人资料弹窗
      if (this.showEditProfileSheet) {
        this.EditProfileSheet()
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
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)

      Text(params.title)
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
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
        .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
    }
    .width('100%')
    .height(52)
    .padding({ left: Spacing.Space4, right: SemanticSpacing.Lg })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
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

  /**
   * 编辑个人资料弹窗
   */
  @Builder
  EditProfileSheet() {
    Column() {
      // 弹窗标题栏
      Row() {
        Text('取消')
          .fontSize(FontSize.Base)
          .fontColor(SemanticColors.Text2)
          .onClick(() => {
            this.showEditProfileSheet = false;
          })

        Text('编辑资料')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('保存')
          .fontSize(FontSize.Base)
          .fontColor(BrandColors.Brand500)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.saveNickname();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

      Divider()
        .color(SemanticColors.Border)

      // 编辑内容
      Column() {
        // 头像区域
        Row() {
          Text('头像')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .layoutWeight(1)

          Column() {
            if (this.userInfo?.avatar) {
              Image(this.userInfo.avatar)
                .width(48)
                .height(48)
                .borderRadius(24)
            } else {
              Column() {
                Text(this.getAvatarText())
                  .fontSize(FontSize.Lg)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(NeutralColors.Neutral0)
              }
              .width(48)
              .height(48)
              .borderRadius(24)
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
        }
        .width('100%')
        .height(64)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .alignItems(VerticalAlign.Center)

        Divider()
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          .color(SemanticColors.Border)

        // 昵称编辑
        Row() {
          Text('昵称')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)

          TextInput({ text: this.editNickname, placeholder: '请输入昵称' })
            .layoutWeight(1)
            .height(40)
            .textAlign(TextAlign.End)
            .backgroundColor('transparent')
            .placeholderColor(SemanticColors.Text4)
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .maxLength(20)
            .onChange((value: string) => {
              this.editNickname = value;
            })
        }
        .width('100%')
        .height(64)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .alignItems(VerticalAlign.Center)

        Divider()
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          .color(SemanticColors.Border)

        // 手机号（只读）
        Row() {
          Text('手机号')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .layoutWeight(1)

          Text(this.userInfo?.phone || '未绑定')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text3)
        }
        .width('100%')
        .height(64)
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .alignItems(VerticalAlign.Center)

        // 提示文字
        Text('昵称长度2-20个字符，修改后即时生效')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text4)
          .width('100%')
          .margin({ top: Spacing.Space4 })
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .padding({ top: SemanticSpacing.Lg })
    }
    .width('100%')
    .height('50%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetY: -4
    })
    .position({ x: 0, y: '50%' })
  }

  /**
   * 保存昵称
   */
  private saveNickname(): void {
    const nickname = this.editNickname.trim();
    if (!nickname || nickname.length < 2) {
      promptAction.showToast({
        message: '昵称至少2个字符'
      });
      return;
    }

    if (nickname.length > 20) {
      promptAction.showToast({
        message: '昵称最多20个字符'
      });
      return;
    }

    // 更新本地用户信息
    if (this.userInfo) {
      const updatedUser: User = {
        ...this.userInfo,
        username: nickname,
        updatedAt: Date.now()
      };
      this.userInfo = updatedUser;

      // 保存到 AppStorage
      AppStorage.setOrCreate('userInfo', JSON.stringify(updatedUser));
    }

    this.showEditProfileSheet = false;
    promptAction.showToast({
      message: '资料已更新'
    });
  }

  /**
   * 骨架屏视图
   */
  @Builder
  buildSkeletonView() {
    Column() {
      // 会员卡片骨架
      Column() {
        // 头像和用户名区域骨架
        Row() {
          // 头像骨架
          Column()
            .width(64)
            .height(64)
            .borderRadius(32)
            .backgroundColor(NeutralColors.Neutral200)

          Column() {
            // 用户名骨架
            Row()
              .width(120)
              .height(20)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)

            // 手机号骨架
            Row()
              .width(100)
              .height(16)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)
              .margin({ top: Spacing.Space3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: SemanticSpacing.Lg })
        }
        .width('100%')

        // 会员状态骨架
        Row() {
          Row()
            .width(80)
            .height(24)
            .borderRadius(12)
            .backgroundColor(NeutralColors.Neutral200)
        }
        .width('100%')
        .margin({ top: SemanticSpacing.Lg })
      }
      .width('100%')
      .padding(SemanticSpacing.Xl)
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius(SemanticRadius.Component)
      .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 权益宫格骨架
      Row() {
        ForEach([1, 2, 3], (item: number) => {
          Column() {
            Column()
              .width(48)
              .height(48)
              .borderRadius(24)
              .backgroundColor(NeutralColors.Neutral200)

            Row()
              .width(60)
              .height(16)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)
              .margin({ top: Spacing.Space3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        })
      }
      .width('100%')
      .padding(SemanticSpacing.Lg)
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius(SemanticRadius.Component)
      .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 功能菜单骨架
      Column() {
        ForEach([1, 2, 3, 4, 5, 6], (item: number) => {
          Row() {
            // 图标骨架
            Column()
              .width(24)
              .height(24)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)

            // 标题骨架
            Row()
              .width(80)
              .height(16)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)
              .margin({ left: Spacing.Space4 })

            Blank()

            // 箭头骨架
            Column()
              .width(16)
              .height(16)
              .borderRadius(4)
              .backgroundColor(NeutralColors.Neutral200)
          }
          .width('100%')
          .height(52)
          .padding({ left: Spacing.Space4, right: SemanticSpacing.Lg })

          if (item < 6) {
            Divider()
              .margin({ left: 56 })
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
    }
    .width('100%')
    .height('100%')
  }
}
