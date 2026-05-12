import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { AuthService } from '../../services/AuthService';
import { Storage } from '../../utils/storage';
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
  ComponentSizes
} from '../../constants/design-tokens';

@Entry
@Component
struct SettingsPage {
  @State currentLanguage: string = '简体中文';
  @State isNotificationEnabled: boolean = true;
  @State isMessagePushEnabled: boolean = true;
  @State cacheSize: string = '12.5 MB';
  private authService: AuthService = AuthService.getInstance();
  private storage: Storage = Storage.getInstance();

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

      // 3. 清除 LocalStorage 中的 token
      this.storage.deleteSync('token');

      // 4. 显示退出成功提示
      promptAction.showToast({ message: '已退出登录' });

      // 5. 跳转到登录页
      router.replaceUrl({ url: 'pages/Login' });
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
            .fillColor(SemanticColors.Text1)
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
          .fontColor(SemanticColors.Text1)
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
      .backgroundColor(NeutralColors.Neutral0)
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

            // 语言切换
            Row() {
              Text('语言')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Text(this.currentLanguage)
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text3)
                .margin({ right: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              // 切换语言
              if (this.currentLanguage === '简体中文') {
                this.currentLanguage = 'English';
              } else {
                this.currentLanguage = '简体中文';
              }
              promptAction.showToast({ message: '语言已切换为 ' + this.currentLanguage });
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            // 通知开关
            Row() {
              Text('消息通知')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
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

            // 推送开关
            Row() {
              Text('推送通知')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.isMessagePushEnabled })
                .selectedColor(BrandColors.Brand500)
                .onChange((isOn: boolean) => {
                  this.isMessagePushEnabled = isOn;
                  promptAction.showToast({
                    message: isOn ? '已开启推送通知' : '已关闭推送通知'
                  });
                })
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          }
          .width('100%')
          .padding(Spacing.Space4)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.04)',
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
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Text(this.cacheSize)
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text3)
                .margin({ right: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Text4)
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
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.04)',
            offsetY: 2
          })

          // 其他设置分组
          Column() {
            Text('其他')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .width('100%')
              .margin({ bottom: Spacing.Space3 })

            // 关于我们
            Row() {
              Text('关于我们')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({ url: 'pages/profile/AboutPage' });
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            // 用户协议
            Row() {
              Text('用户协议')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({ url: 'pages/profile/UserAgreement' });
            })

            Divider()
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })

            // 隐私政策
            Row() {
              Text('隐私政策')
                .fontSize(FontSize.Base)
                .fontColor(SemanticColors.Text1)
                .layoutWeight(1)

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Text4)
            }
            .width('100%')
            .height(52)
            .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
            .onClick(() => {
              router.pushUrl({ url: 'pages/profile/PrivacyPolicy' });
            })
          }
          .width('100%')
          .padding(Spacing.Space4)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.04)',
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
    .backgroundColor(NeutralColors.Neutral50)
  }
}
