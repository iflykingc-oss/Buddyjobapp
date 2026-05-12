import { router } from '@kit.ArkUI';
import { HMSUtils, HMSServiceType, HMSConfig } from '../utils/hms';
import { AuthService } from '../services/AuthService';
import { PushService } from '../services/PushService';
import { PaymentService } from '../services/PaymentService';
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
  Duration
} from '../constants/design-tokens';

/**
 * 启动页状态
 */
enum SplashStatus {
  INITIALIZING = 'initializing',     // 初始化中
  CHECKING_HMS = 'checking_hms',     // 检查 HMS Core
  AUTO_LOGIN = 'auto_login',         // 自动登录中
  FIRST_LAUNCH = 'first_launch',     // 首次启动引导
  COMPLETED = 'completed',           // 完成
  ERROR = 'error',                   // 错误
}

/**
 * 启动页 - HMS Core 初始化检查、自动登录检测、引导页逻辑
 */
@Entry
@Component
struct Splash {
  @State private status: SplashStatus = SplashStatus.INITIALIZING;
  @State private statusMessage: string = '正在初始化...';
  @State private progress: number = 0;
  @State private errorMessage: string = '';
  @State private isFirstLaunch: boolean = false;
  @State private showGuide: boolean = false;
  @State private currentGuidePage: number = 0;
  @State private logoScale: number = 0.8;
  @State private logoOpacity: number = 0;

  private hmsUtils: HMSUtils = HMSUtils.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private pushService: PushService = PushService.getInstance();
  private paymentService: PaymentService = PaymentService.getInstance();

  // 引导页数据
  private guidePages = [
    {
      title: 'AI 求职助手',
      desc: '智能简历优化、面试辅导、职业规划，让求职更轻松',
      icon: $r('app.media.ic_guide_ai'),
      color: BrandColors.Brand500
    },
    {
      title: '实时聊天咨询',
      desc: '7x24小时在线，随时解答你的求职疑惑',
      icon: $r('app.media.ic_guide_chat'),
      color: BrandColors.Brand400
    },
    {
      title: '专业测评分析',
      desc: '职业能力测评、性格测试，发现更适合你的职业方向',
      icon: $r('app.media.ic_guide_assessment'),
      color: BrandColors.Brand600
    },
    {
      title: 'VIP 专属权益',
      desc: '解锁无限对话、高级简历模板、专属职业顾问',
      icon: $r('app.media.ic_guide_vip'),
      color: BrandColors.Brand700
    }
  ];

  aboutToAppear() {
    // 启动 Logo 动画
    this.startLogoAnimation();
    this.initialize();
  }

  /**
   * Logo 入场动画
   */
  private startLogoAnimation(): void {
    setTimeout(() => {
      this.logoScale = 1;
      this.logoOpacity = 1;
    }, 100);
  }

  /**
   * 初始化流程
   */
  private async initialize(): Promise<void> {
    try {
      // 步骤1: 检查是否是首次启动
      this.updateStatus(SplashStatus.INITIALIZING, '正在初始化...', 10);
      await this.checkFirstLaunch();

      // 步骤2: 检查 HMS Core 可用性
      this.updateStatus(SplashStatus.CHECKING_HMS, '检查 HMS Core 服务...', 30);
      const hmsAvailable = await this.checkHMSCore();

      if (!hmsAvailable) {
        console.warn('[Splash] HMS Core not fully available, continuing with limited features');
      }

      // 步骤3: 初始化 HMS 服务
      this.updateStatus(SplashStatus.INITIALIZING, '初始化服务...', 50);
      await this.initializeHMSServices();

      // 步骤4: 尝试自动登录
      this.updateStatus(SplashStatus.AUTO_LOGIN, '检查登录状态...', 70);
      const autoLoginSuccess = await this.tryAutoLogin();

      if (autoLoginSuccess) {
        this.updateStatus(SplashStatus.COMPLETED, '准备就绪', 100);
        this.navigateToMain();
        return;
      }

      // 步骤5: 判断是否显示引导页
      if (this.isFirstLaunch) {
        this.updateStatus(SplashStatus.FIRST_LAUNCH, '', 100);
        this.showGuide = true;
      } else {
        this.updateStatus(SplashStatus.COMPLETED, '准备就绪', 100);
        this.navigateToLogin();
      }

    } catch (error) {
      console.error('[Splash] Initialization failed:', error);
      this.updateStatus(SplashStatus.ERROR, '初始化失败', 0);
      this.errorMessage = '应用初始化失败，请稍后重试';
    }
  }

  /**
   * 更新状态
   */
  private updateStatus(status: SplashStatus, message: string, progress: number): void {
    this.status = status;
    this.statusMessage = message;
    this.progress = progress;
  }

  /**
   * 检查是否首次启动
   */
  private async checkFirstLaunch(): Promise<void> {
    const hasLaunched = AppStorage.get<boolean>('hasLaunched');
    this.isFirstLaunch = !hasLaunched;
    
    // 模拟初始化耗时
    await this.delay(500);
  }

  /**
   * 检查 HMS Core
   */
  private async checkHMSCore(): Promise<boolean> {
    try {
      // 检查 HMS Core 是否可用
      const hmsCoreAvailable = await this.hmsUtils.checkHMSCoreAvailability();
      
      if (hmsCoreAvailable) {
        // 检查各服务可用性
        const services = [HMSServiceType.ACCOUNT, HMSServiceType.PUSH, HMSServiceType.IAP];
        const results = await this.hmsUtils.checkMultipleServices(services);
        
        const availableServices = Array.from(results.entries())
          .filter(([, available]) => available)
          .map(([type]) => type);
        
        console.info('[Splash] HMS services available:', availableServices);
        return true;
      }
      
      return false;
    } catch (error) {
      console.error('[Splash] Check HMS Core failed:', error);
      return false;
    }
  }

  /**
   * 初始化 HMS 服务
   */
  private async initializeHMSServices(): Promise<void> {
    try {
      // 并行初始化各个服务
      const initTasks = [];

      // 初始化推送服务
      if (this.hmsUtils.isServiceAvailable(HMSServiceType.PUSH)) {
        initTasks.push(
          this.pushService.init({
            autoGetToken: true,
            showNotification: true,
          })
        );
      }

      // 初始化支付服务
      if (this.hmsUtils.isServiceAvailable(HMSServiceType.IAP)) {
        initTasks.push(this.paymentService.init());
      }

      // 等待所有初始化完成
      await Promise.all(initTasks);
      
    } catch (error) {
      console.error('[Splash] Initialize HMS services failed:', error);
    }
  }

  /**
   * 尝试自动登录
   */
  private async tryAutoLogin(): Promise<boolean> {
    try {
      // 检查是否有本地登录态
      if (!this.authService.isLoggedIn()) {
        console.info('[Splash] No local login session');
        return false;
      }

      // 尝试华为账号静默登录
      if (this.authService.isHuaweiLoginAvailable()) {
        const result = await this.authService.silentLoginWithHuawei();
        if (result) {
          console.info('[Splash] Huawei silent login success');
          return true;
        }
      }

      // 尝试刷新登录态
      const userInfo = await this.authService.getUserInfo();
      if (userInfo) {
        console.info('[Splash] Token valid, auto login success');
        return true;
      }

      return false;
    } catch (error) {
      console.error('[Splash] Auto login failed:', error);
      return false;
    }
  }

  /**
   * 跳转到主页面
   */
  private navigateToMain(): void {
    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' });
    }, 500);
  }

  /**
   * 跳转到登录页面
   */
  private navigateToLogin(): void {
    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Login' });
    }, 500);
  }

  /**
   * 完成引导页
   */
  private completeGuide(): void {
    AppStorage.setOrCreate('hasLaunched', true);
    this.showGuide = false;
    this.navigateToLogin();
  }

  /**
   * 跳过引导页
   */
  private skipGuide(): void {
    AppStorage.setOrCreate('hasLaunched', true);
    this.showGuide = false;
    this.navigateToLogin();
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 渐变背景
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [BrandColors.Brand600, 0],
            [BrandColors.Brand800, 0.5],
            [BrandColors.Brand950, 1]
          ]
        })

      if (this.showGuide) {
        // 引导页内容
        this.GuideBuilder()
      } else {
        // 启动页内容
        this.SplashBuilder()
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 启动页构建器
   */
  @Builder
  SplashBuilder() {
    Column({ space: SemanticSpacing.Lg }) {
      // Logo 容器
      Column() {
        // Logo 外圈光晕
        Column() {
          Image($r('app.media.icon'))
            .width(100)
            .height(100)
            .borderRadius(SemanticRadius.Component)
            .shadow({
              radius: 30,
              color: 'rgba(139, 92, 246, 0.5)',
              offsetX: 0,
              offsetY: 0
            })
        }
        .width(120)
        .height(120)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.1)')
        .borderRadius(60)
        .backdropBlur(20)
      }
      .width(140)
      .height(140)
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.logoScale, y: this.logoScale })
      .opacity(this.logoOpacity)
      .animation({
        duration: Duration.Slow,
        curve: Curve.SpringMotion,
        iterations: 1
      })

      // 应用名称
      Text('一职搭子')
        .fontSize(FontSize.Xxxxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(NeutralColors.Neutral0)
        .margin({ top: SemanticSpacing.Xl })
        .opacity(this.logoOpacity)
        .animation({
          duration: Duration.Slow,
          curve: Curve.EaseOut,
          delay: 200
        })

      // 副标题
      Text('AI 求职助手')
        .fontSize(FontSize.Base)
        .fontColor('rgba(255, 255, 255, 0.8)')
        .opacity(this.logoOpacity)
        .animation({
          duration: Duration.Slow,
          curve: Curve.EaseOut,
          delay: 300
        })

      // 状态信息
      if (this.status !== SplashStatus.ERROR) {
        Column({ space: SemanticSpacing.Md }) {
          Text(this.statusMessage)
            .fontSize(FontSize.Xs)
            .fontColor('rgba(255, 255, 255, 0.7)')

          // 进度条
          Stack() {
            // 背景轨道
            Row()
              .width(200)
              .height(4)
              .backgroundColor('rgba(255, 255, 255, 0.2)')
              .borderRadius(2)
            
            // 进度
            Row()
              .width(`${this.progress}%`)
              .height(4)
              .backgroundColor(NeutralColors.Neutral0)
              .borderRadius(2)
          }
          .width(200)
          .height(4)
        }
        .margin({ top: Spacing.Space9 })
        .opacity(this.logoOpacity)
        .animation({
          duration: Duration.Slow,
          curve: Curve.EaseOut,
          delay: 400
        })
      }

      // 错误提示
      if (this.status === SplashStatus.ERROR) {
        Column({ space: SemanticSpacing.Lg }) {
          Text(this.errorMessage)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Error)
            .textAlign(TextAlign.Center)

          Button('重试')
            .width(120)
            .height(40)
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand600)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Pill)
            .onClick(() => {
              this.errorMessage = '';
              this.initialize();
            })
        }
        .margin({ top: Spacing.Space9 })
      }

      // 底部版权
      Column() {
        Text('Powered by HMS Core')
          .fontSize(FontSize.Xs)
          .fontColor('rgba(255, 255, 255, 0.5)')

        Text(`© ${new Date().getFullYear()} 一职搭子. All rights reserved.`)
          .fontSize(10)
          .fontColor('rgba(255, 255, 255, 0.4)')
          .margin({ top: Spacing.Space2 })
      }
      .position({ x: 0, y: '90%' })
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 引导页构建器
   */
  @Builder
  GuideBuilder() {
    Column() {
      // 跳过按钮
      Row() {
        Text('跳过')
          .fontSize(FontSize.Sm)
          .fontColor('rgba(255, 255, 255, 0.8)')
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
          .backgroundColor('rgba(255, 255, 255, 0.15)')
          .borderRadius(SemanticRadius.Pill)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ top: Spacing.Space10, right: SemanticSpacing.Lg })
      .onClick(() => this.skipGuide())

      // 引导内容
      Swiper() {
        ForEach(this.guidePages, (page: typeof this.guidePages[0], index: number) => {
          Column({ space: SemanticSpacing.Xl }) {
            // 图标容器
            Column() {
              Image(page.icon)
                .width(160)
                .height(160)
                .objectFit(ImageFit.Contain)
            }
            .width(200)
            .height(200)
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(100)
            .justifyContent(FlexAlign.Center)
            .backdropBlur(10)

            // 标题
            Text(page.title)
              .fontSize(FontSize.Xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(NeutralColors.Neutral0)

            // 描述
            Text(page.desc)
              .fontSize(FontSize.Base)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .textAlign(TextAlign.Center)
              .padding({ left: Spacing.Space9, right: Spacing.Space9 })
              .lineHeight(24)
          }
          .width('100%')
          .height('60%')
          .justifyContent(FlexAlign.Center)
        })
      }
      .index(this.currentGuidePage)
      .autoPlay(false)
      .indicator(
        new DotIndicator()
          .itemWidth(8)
          .itemHeight(8)
          .selectedItemWidth(24)
          .selectedItemHeight(8)
          .color('rgba(255, 255, 255, 0.3)')
          .selectedColor(NeutralColors.Neutral0)
      )
      .loop(false)
      .onChange((index: number) => {
        this.currentGuidePage = index;
      })

      // 底部按钮
      Column({ space: SemanticSpacing.Lg }) {
        if (this.currentGuidePage < this.guidePages.length - 1) {
          Button('下一步')
            .width(280)
            .height(50)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(BrandColors.Brand600)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Pill)
            .onClick(() => {
              this.currentGuidePage++;
            })
        } else {
          Button('立即体验')
            .width(280)
            .height(50)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(BrandColors.Brand600)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Pill)
            .onClick(() => this.completeGuide())
        }

        // 指示器
        Row({ space: Spacing.Space3 }) {
          ForEach(this.guidePages, (_, index: number) => {
            Row()
              .width(this.currentGuidePage === index ? 24 : 8)
              .height(8)
              .backgroundColor(this.currentGuidePage === index ? NeutralColors.Neutral0 : 'rgba(255, 255, 255, 0.3)')
              .borderRadius(4)
              .animation({ duration: Duration.Normal })
          })
        }
        .margin({ top: SemanticSpacing.Lg })
      }
      .margin({ bottom: Spacing.Space10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }
}

export default Splash;
