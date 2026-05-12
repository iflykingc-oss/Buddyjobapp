import router from '@ohos.router';
import { AuthService } from '../services/AuthService';
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
} from '../constants/design-tokens';

@Entry
@Component
struct Login {
  @State phone: string = '';
  @State code: string = '';
  @State countdown: number = 0;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State agreeTerms: boolean = false;
  @State headerOpacity: number = 0;
  private authService: AuthService = AuthService.getInstance();
  private countdownTimer: number = -1;

  aboutToAppear() {
    // 启动头部动画
    setTimeout(() => {
      this.headerOpacity = 1;
    }, 100);
  }

  build() {
    Column() {
      // 顶部品牌区域
      Column() {
        // 品牌背景渐变
        Column() {
          // Logo
          Column() {
            Image($r('app.media.ic_logo'))
              .width(64)
              .height(64)
              .objectFit(ImageFit.Contain)
          }
          .width(88)
          .height(88)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(255, 255, 255, 0.15)')
          .borderRadius(44)
          .backdropBlur(10)

          Text('一职搭子')
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(NeutralColors.Neutral0)
            .margin({ top: SemanticSpacing.Lg })

          Text('智能求职助手')
            .fontSize(FontSize.Sm)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .margin({ top: Spacing.Space3 })
        }
        .width('100%')
        .padding({ top: Spacing.Space10, bottom: Spacing.Space9 })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [BrandColors.Brand500, 0],
          [BrandColors.Brand600, 1]
        ]
      })
      .opacity(this.headerOpacity)
      .animation({
        duration: 400,
        curve: Curve.EaseOut
      })

      // 登录表单卡片
      Column() {
        // 手机号输入
        Column() {
          Text('手机号')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text2)
            .width('100%')
            .margin({ bottom: Spacing.Space3 })

          Row() {
            Text('+86')
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text1)
              .margin({ right: SemanticSpacing.Md })

            TextInput({ placeholder: '请输入手机号', text: this.phone })
              .layoutWeight(1)
              .height(ComponentSizes.Input.Lg.height)
              .backgroundColor(NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Control)
              .padding({ left: SemanticSpacing.Md })
              .type(InputType.PhoneNumber)
              .placeholderColor(SemanticColors.Text4)
              .placeholderFont({ size: FontSize.Base })
              .fontColor(SemanticColors.Text1)
              .onChange((value: string) => {
                this.phone = value;
              })
          }
          .width('100%')
          .padding(SemanticSpacing.Md)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .border({
            width: 1,
            color: NeutralColors.Neutral200
          })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xl })

        // 验证码输入
        Column() {
          Text('验证码')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text2)
            .width('100%')
            .margin({ bottom: Spacing.Space3 })

          Row() {
            TextInput({ placeholder: '请输入验证码', text: this.code })
              .layoutWeight(1)
              .height(ComponentSizes.Input.Lg.height)
              .backgroundColor(NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Control)
              .padding({ left: SemanticSpacing.Md })
              .type(InputType.Number)
              .placeholderColor(SemanticColors.Text4)
              .placeholderFont({ size: FontSize.Base })
              .fontColor(SemanticColors.Text1)
              .onChange((value: string) => {
                this.code = value;
              })

            Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
              .fontSize(FontSize.Sm)
              .fontColor(this.countdown > 0 ? SemanticColors.Text4 : BrandColors.Brand500)
              .backgroundColor(this.countdown > 0 ? NeutralColors.Neutral100 : BrandColors.Brand50)
              .borderRadius(SemanticRadius.Control)
              .width(110)
              .height(ComponentSizes.Input.Lg.height)
              .margin({ left: SemanticSpacing.Md })
              .enabled(this.countdown === 0 && this.phone.length === 11)
              .onClick(() => {
                this.sendCode();
              })
          }
          .width('100%')
          .padding(SemanticSpacing.Md)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .border({
            width: 1,
            color: NeutralColors.Neutral200
          })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xl })

        // 协议勾选
        Row() {
          Checkbox()
            .select(this.agreeTerms)
            .shape(CheckBoxShape.CIRCLE)
            .width(18)
            .height(18)
            .selectedColor(BrandColors.Brand500)
            .onChange((value: boolean) => {
              this.agreeTerms = value;
            })

          Text('我已阅读并同意')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text2)
            .margin({ left: Spacing.Space3 })

          Text('《用户协议》')
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .onClick(() => {
              // TODO: 打开用户协议页面
              console.info('Open user agreement');
            })

          Text('和')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text2)

          Text('《隐私政策》')
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .onClick(() => {
              // TODO: 打开隐私政策页面
              console.info('Open privacy policy');
            })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xl })

        // 错误提示
        if (this.errorMessage) {
          Row() {
            Text('!')
              .fontSize(FontSize.Xs)
              .fontColor(NeutralColors.Neutral0)
              .width(16)
              .height(16)
              .backgroundColor(SemanticColors.Error)
              .borderRadius(8)
              .textAlign(TextAlign.Center)

            Text(this.errorMessage)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Error)
              .margin({ left: Spacing.Space3 })
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Lg })
        }

        // 登录按钮
        Button('登录')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(this.canLogin() ? BrandColors.Brand500 : NeutralColors.Neutral300)
          .width('100%')
          .height(ComponentSizes.Button.Lg.height)
          .borderRadius(SemanticRadius.Pill)
          .enabled(this.canLogin())
          .loading(this.isLoading)
          .shadow(this.canLogin() ? {
            radius: 16,
            color: 'rgba(139, 92, 246, 0.3)',
            offsetX: 0,
            offsetY: 4
          } : undefined)
          .onClick(() => {
            this.doLogin();
          })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, top: Spacing.Space9 })
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius({ topLeft: SemanticRadius.Container, topRight: SemanticRadius.Container })
      .margin({ top: -SemanticSpacing.Xl })
      .layoutWeight(1)

      // 底部品牌信息
      Column() {
        Text('一职搭子 出品')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text4)
      }
      .width('100%')
      .padding({ bottom: Spacing.Space9 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  canLogin(): boolean {
    return this.phone.length === 11 &&
           this.code.length === 4 &&
           this.agreeTerms;
  }

  async sendCode() {
    if (this.phone.length !== 11) {
      this.errorMessage = '请输入正确的手机号';
      return;
    }

    try {
      await this.authService.sendCode(this.phone);
      this.countdown = 60;
      this.errorMessage = '';

      this.countdownTimer = setInterval(() => {
        this.countdown--;
        if (this.countdown <= 0) {
          clearInterval(this.countdownTimer);
        }
      }, 1000);
    } catch (error) {
      this.errorMessage = '发送验证码失败，请稍后重试';
    }
  }

  async doLogin() {
    if (!this.canLogin()) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const result = await this.authService.loginWithCode(this.phone, this.code);

      // token 和 userInfo 已在 AuthService.loginWithCode() 内部写入 AppStorage，此处不再重复

      // 登录成功，跳转到主页
      hilog.info(0x0001, 'Login', 'Login success');
      setTimeout(() => {
        router.replaceUrl({ url: 'pages/Index' });
      }, 500);
    } catch (error) {
      this.errorMessage = '验证码错误或已过期';
    } finally {
      this.isLoading = false;
    }
  }

  aboutToDisappear() {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
    }
  }
}

import hilog from '@ohos.hilog';
