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
  Duration,
  ZIndex
} from '../constants/design-tokens';

/**
 * 引导步骤数据
 */
interface OnboardingStep {
  title: string;
  description: string;
  icon: string;
  targetTab: number;
}

/**
 * 登录后引导组件 - 新用户功能引导
 *
 * 在新用户首次登录后展示，引导用户了解5个核心功能。
 * 全屏半透明遮罩 + 底部卡片式引导。
 */
@Component
export struct OnboardingGuide {
  @State currentStep: number = 0;
  @State cardOpacity: number = 1;
  @State cardTranslate: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  onComplete?: () => void;
  onSkip?: () => void;

  // 引导步骤数据
  private steps: OnboardingStep[] = [
    {
      title: 'AI求职助手',
      description: '随时向AI提问求职相关问题，获取专业建议',
      icon: '💬',
      targetTab: 0
    },
    {
      title: '智能简历分析',
      description: '上传简历，AI帮你分析优劣势并给出优化建议',
      icon: '📄',
      targetTab: 1
    },
    {
      title: '职业能力测评',
      description: '通过专业测评了解自己的职业性格和能力',
      icon: '🎯',
      targetTab: 2
    },
    {
      title: '求职知识库',
      description: '浏览精选求职攻略和行业知识',
      icon: '📚',
      targetTab: 3
    },
    {
      title: '开始你的求职之旅',
      description: '以上功能都可以在底部导航栏快速访问',
      icon: '🚀',
      targetTab: -1
    }
  ];

  aboutToAppear() {
    // 检查是否已完成引导
    const hasCompleted = AppStorage.get<boolean>('hasCompletedOnboarding');
    if (hasCompleted) {
      this.onSkip?.();
    }
  }

  /**
   * 切换到下一步
   */
  private nextStep(): void {
    if (this.currentStep < this.steps.length - 1) {
      // 播放退出动画
      this.cardOpacity = 0;
      this.cardTranslate = 20;

      setTimeout(() => {
        this.currentStep++;
        // 重置为进入动画起始状态
        this.cardTranslate = -20;
        this.cardOpacity = 0;

        // 触发进入动画
        setTimeout(() => {
          this.cardOpacity = 1;
          this.cardTranslate = 0;
        }, 50);
      }, Duration.Normal);
    } else {
      this.completeOnboarding();
    }
  }

  /**
   * 跳过引导
   */
  private skipOnboarding(): void {
    AppStorage.setOrCreate('hasCompletedOnboarding', true);
    this.onSkip?.();
  }

  /**
   * 完成引导
   */
  private completeOnboarding(): void {
    AppStorage.setOrCreate('hasCompletedOnboarding', true);
    this.onComplete?.();
  }

  build() {
    Stack() {
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDarkMode ? 'rgba(0, 0, 0, 0.75)' : 'rgba(0, 0, 0, 0.6)')
        .onClick(() => {
          // 点击遮罩不执行任何操作，防止误触
        })

      // 引导内容
      Column() {
        // 顶部区域：步骤标题 + 跳过按钮
        Row() {
          // 步骤计数
          Text(`${this.currentStep + 1} / ${this.steps.length}`)
            .fontSize(FontSize.Sm)
            .fontColor('rgba(255, 255, 255, 0.7)')
            .padding({
              left: SemanticSpacing.Lg,
              right: SemanticSpacing.Lg,
              top: Spacing.Space2,
              bottom: Spacing.Space2
            })
            .backgroundColor('rgba(255, 255, 255, 0.15)')
            .borderRadius(SemanticRadius.Pill)

          Blank()

          // 跳过按钮
          Text('跳过')
            .fontSize(FontSize.Sm)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .padding({
              left: SemanticSpacing.Lg,
              right: SemanticSpacing.Lg,
              top: Spacing.Space2,
              bottom: Spacing.Space2
            })
            .backgroundColor('rgba(255, 255, 255, 0.15)')
            .borderRadius(SemanticRadius.Pill)
            .onClick(() => this.skipOnboarding())
        }
        .width('100%')
        .padding({
          left: SemanticSpacing.Lg,
          right: SemanticSpacing.Lg,
          top: SemanticSpacing.Xxl,
          bottom: SemanticSpacing.Md
        })

        Blank()

        // 中间图标区域
        Column() {
          Text(this.steps[this.currentStep].icon)
            .fontSize(64)
        }
        .width(120)
        .height(120)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.1)')
        .borderRadius(60)
        .backdropBlur(10)
        .opacity(this.cardOpacity)
        .translate({ y: this.cardTranslate })
        .animation({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        })

        Blank()

        // 底部引导卡片
        Column({ space: SemanticSpacing.Lg }) {
          // 步骤标题
          Text(this.steps[this.currentStep].title)
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .textAlign(TextAlign.Center)
            .width('100%')

          // 步骤描述
          Text(this.steps[this.currentStep].description)
            .fontSize(FontSize.Base)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
            .textAlign(TextAlign.Center)
            .width('100%')
            .lineHeight(24)

          // 步骤指示器
          Row({ space: Spacing.Space2 }) {
            ForEach(this.steps, (_: OnboardingStep, index: number) => {
              Row()
                .width(this.currentStep === index ? 24 : 8)
                .height(8)
                .backgroundColor(this.currentStep === index
                  ? BrandColors.Brand500
                  : (this.isDarkMode ? DarkSemanticColors.Surface3 : SemanticColors.Surface3))
                .borderRadius(4)
                .animation({ duration: Duration.Normal, curve: Curve.EaseInOut })
            }, (_: OnboardingStep, index: number) => `dot_${index}`)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')

          // 操作按钮
          Row({ space: SemanticSpacing.Md }) {
            // 跳过按钮（文字按钮）
            if (this.currentStep < this.steps.length - 1) {
              Button('跳过')
                .height(ComponentSizes.Button.Lg.height)
                .fontSize(FontSize.Base)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
                .backgroundColor(Color.Transparent)
                .borderRadius(SemanticRadius.Pill)
                .borderWidth(1)
                .borderColor(this.isDarkMode ? DarkSemanticColors.Border : SemanticColors.Border)
                .layoutWeight(1)
                .onClick(() => this.skipOnboarding())
            }

            // 下一步 / 开始使用 按钮
            Button(this.currentStep < this.steps.length - 1 ? '下一步' : '开始使用')
              .height(ComponentSizes.Button.Lg.height)
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(SemanticRadius.Pill)
              .layoutWeight(1)
              .onClick(() => this.nextStep())
          }
          .width('100%')
        }
        .width('100%')
        .padding({
          left: SemanticSpacing.Xxl,
          right: SemanticSpacing.Xxl,
          top: SemanticSpacing.Xxl,
          bottom: SemanticSpacing.Xxl2
        })
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius({
          topLeft: SemanticRadius.Container,
          topRight: SemanticRadius.Container
        })
        .shadow({
          radius: 24,
          color: 'rgba(0, 0, 0, 0.2)',
          offsetY: -4
        })
        .opacity(this.cardOpacity)
        .translate({ y: this.cardTranslate })
        .animation({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .zIndex(ZIndex.Modal)
  }
}
