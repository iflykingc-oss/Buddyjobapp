import router from '@ohos.router';
import { AuthService } from '../../services/AuthService';
import { AppReviewService } from '../../services/AppReviewService';
import { promptAction } from '@kit.ArkUI';
import { ThemeManager, ThemeMode } from '../../utils/Theme';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../../constants/design-tokens';

@Entry
@Component
struct SettingsPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @State isNotificationEnabled: boolean = true;
  @State isSoundEnabled: boolean = true;
  @State isVibrationEnabled: boolean = true;
  @State fontSize: number = 16;
  @State cacheSize: string = '0 MB';
  @State appVersion: string = '1.0.0';
  @State isLoading: boolean = false;

  private authService: AuthService = AuthService.getInstance();

  /**
   * 显示退出登录确认对话框
   */
  private showLogoutConfirmDialog(): void {
    AlertDialog.show({
      title: '确认退出',
      message: '确定要退出登录吗？',
      primaryButton: {
        value: '取消',
        action: () => {
          console.info('[SettingsPage] User cancelled logout');
        }
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          this.handleLogout();
        }
      }
    });
  }

  /**
   * 处理退出登录
   */
  private async handleLogout(): Promise<void> {
    try {
      // 1. 调用 AuthService.logout() 清除 HMS 登录态
      await this.authService.logout();

      // 2. 清除 AppStorage 中的用户信息
      AppStorage.delete('userInfo');
      AppStorage.delete('huaweiAccountInfo');
      AppStorage.delete('token');

      // 3. 清除 AppStorage 中的 token（已在上方执行）
      // AppStorage.delete('token');

      // 4. 显示退出成功提示
      promptAction.showToast({ message: '已退出登录' });

      // 5. 跳转到登录页
      router.replaceUrl({
        url: 'pages/Login',
        params: {},
        transition: {
          type: router.TransitionType.Push,
          duration: 300,
          curve: Curve.EaseInOut
        }
      });
    } catch (error) {
      console.error('[SettingsPage] Logout failed:', error);
      promptAction.showToast({ message: '退出登录失败，请重试' });
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('设置')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      Scroll() {
        Column() {
          // 通用设置分组
          Column() {
            Text('通用设置')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            // 暗黑模式
            Row() {
              Text('暗黑模式')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .selectedColor(BrandColors.Brand500)
                .onChange((isOn: boolean) => {
                  this.isDarkMode = isOn;
                  ThemeManager.setTheme(isOn ? ThemeMode.DARK : ThemeMode.LIGHT);
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 通知开关
            Row() {
              Text('消息通知')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.isNotificationEnabled })
                .selectedColor(BrandColors.Brand500)
                .onChange((isOn: boolean) => {
                  this.isNotificationEnabled = isOn;
                  promptAction.showToast({
                    message: isOn ? '已开启消息通知' : '已关闭消息通知'
                  });
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 声音设置
            Row() {
              Text('声音')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.isSoundEnabled })
                .selectedColor(BrandColors.Brand500)
                .onChange((isOn: boolean) => {
                  this.isSoundEnabled = isOn;
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 震动设置
            Row() {
              Text('震动')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.isVibrationEnabled })
                .selectedColor(BrandColors.Brand500)
                .onChange((isOn: boolean) => {
                  this.isVibrationEnabled = isOn;
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          }
          .width('100%')
          .padding(Spacing.Space4)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 存储设置分组
          Column() {
            Text('存储')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            // 清除缓存
            Row() {
              Text('清除缓存')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Text(this.cacheSize)
                .fontSize(FontSize.Sm)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                .margin({ right: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              this.cacheSize = '0 MB';
              promptAction.showToast({ message: '缓存已清除' });
            })
          }
          .width('100%')
          .padding(Spacing.Space4)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 其他设置分组
          Column() {
            Text('其他')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            // 给我们评分
            Row() {
              Text('给我们评分')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              AppReviewService.getInstance().openComment();
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 关于我们
            Row() {
              Text('关于我们')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/profile/AboutPage',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 用户协议
            Row() {
              Text('用户协议')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/profile/UserAgreement',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
              .color(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)

            // 隐私政策
            Row() {
              Text('隐私政策')
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/profile/PrivacyPolicy',
                params: {},
                transition: {
                  type: router.TransitionType.Push,
                  duration: 300,
                  curve: Curve.EaseInOut
                }
              });
            })
          }
          .width('100%')
          .padding(Spacing.Space4)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 退出登录按钮
          Button('退出登录')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Pill)
            .width('calc(100% - 32px)')
            .height(48)
            .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Xxl, bottom: Spacing.Space9 })
            .onClick(() => {
              this.showLogoutConfirmDialog();
            })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }

  @Builder
  SettingItem(params: {
    icon: Resource;
    title: string;
    subtitle?: string;
    showArrow?: boolean;
    onClick?: () => void;
    customRight?: () => void;
  }) {
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

      if (params.subtitle) {
        Text(params.subtitle)
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ right: Spacing.Space3 })
      }

      if (params.customRight) {
        params.customRight()
      } else if (params.showArrow !== false) {
        Image($r('app.media.ic_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
      }
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
}
