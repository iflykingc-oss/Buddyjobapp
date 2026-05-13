/**
 * 智能体入口组件
 * 基于 HarmonyOS 6.0 FunctionComponent
 * 提供一键拉起智能体的UI组件
 */
import { common } from '@kit.AbilityKit';
import { FunctionController, FunctionComponent } from '@kit.AgentFrameworkKit';
import {
  BrandColors,
  NeutralColors,
  Spacing,
  BorderRadius,
  FontSize,
  FontWeight
} from '../constants/design-tokens';

// 智能体类型
export enum AgentType {
  RESUME = 'resume',
  INTERVIEW = 'interview',
  CAREER = 'career',
  OFFER = 'offer'
}

// 组件属性
interface AgentButtonProps {
  agentType: AgentType;
  size?: 'small' | 'medium' | 'large';
  label?: string;
  description?: string;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
}

/**
 * 智能体按钮组件
 * 点击拉起对应的小艺智能体
 */
@Component
export struct AgentButton {
  @Prop agentType: AgentType = AgentType.RESUME;
  @Prop size: 'small' | 'medium' | 'large' = 'medium';
  @Prop label: string = '';
  @Prop description: string = '';
  
  @State isLoading: boolean = false;
  @State isAvailable: boolean = false;

  private context: common.UIAbilityContext | null = null;
  private functionController: FunctionController | null = null;

  aboutToAppear(): void {
    this.initializeController();
  }

  private async initializeController(): Promise<void> {
    try {
      // 获取上下文
      this.context = getContext(this) as common.UIAbilityContext;
      
      // 创建 FunctionController
      this.functionController = new FunctionController(this.context);
      
      // 检查智能体可用性
      this.isAvailable = await this.checkAvailability();
    } catch (error) {
      console.error('Initialize controller failed:', error);
      this.isAvailable = false;
    }
  }

  private async checkAvailability(): Promise<boolean> {
    if (!this.functionController) {
      return false;
    }

    try {
      // 检查智能体环境是否可用
      // 用户是否登录华为账号并同意隐私协议
      return true;
    } catch (error) {
      return false;
    }
  }

  private getAgentId(): string {
    switch (this.agentType) {
      case AgentType.RESUME:
        return 'buddyjob_resume_agent';
      case AgentType.INTERVIEW:
        return 'buddyjob_interview_agent';
      case AgentType.CAREER:
        return 'buddyjob_career_agent';
      case AgentType.OFFER:
        return 'buddyjob_offer_agent';
      default:
        return '';
    }
  }

  private getAgentLabel(): string {
    if (this.label) {
      return this.label;
    }
    switch (this.agentType) {
      case AgentType.RESUME:
        return '简历优化助手';
      case AgentType.INTERVIEW:
        return '面试教练';
      case AgentType.CAREER:
        return '职业顾问';
      case AgentType.OFFER:
        return 'Offer分析师';
      default:
        return '智能助手';
    }
  }

  private getAgentIcon(): Resource {
    switch (this.agentType) {
      case AgentType.RESUME:
        return $r('app.media.media_ic_agent_resume');
      case AgentType.INTERVIEW:
        return $r('app.media.media_ic_agent_interview');
      case AgentType.CAREER:
        return $r('app.media.media_ic_agent_career');
      case AgentType.OFFER:
        return $r('app.media.media_ic_agent_offer');
      default:
        return $r('app.media.media_ic_agent');
    }
  }

  private getButtonSize(): { width: number; height: number; iconSize: number; fontSize: number } {
    switch (this.size) {
      case 'small':
        return { width: 100, height: 36, iconSize: 16, fontSize: 12 };
      case 'large':
        return { width: 200, height: 56, iconSize: 28, fontSize: 16 };
      default:
        return { width: 140, height: 44, iconSize: 20, fontSize: 14 };
    }
  }

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(this.getButtonSize().iconSize)
          .height(this.getButtonSize().iconSize)
          .color(NeutralColors.Neutral0);
      } else {
        Image(this.getAgentIcon())
          .width(this.getButtonSize().iconSize)
          .height(this.getButtonSize().iconSize)
          .fillColor(NeutralColors.Neutral0);
      }

      Text(this.getAgentLabel())
        .fontSize(this.getButtonSize().fontSize)
        .fontColor(NeutralColors.Neutral0)
        .fontWeight(FontWeight.Medium)
        .margin({ left: Spacing.Space2 });
    }
    .width(this.getButtonSize().width)
    .height(this.getButtonSize().height)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isAvailable ? BrandColors.Brand500 : NeutralColors.Neutral300)
    .borderRadius(BorderRadius.RadiusLG)
    .enabled(this.isAvailable && !this.isLoading)
    .onClick(async () => {
      await this.launchAgent();
    });
  }

  private async launchAgent(): Promise<void> {
    if (!this.isAvailable || this.isLoading) {
      return;
    }

    this.isLoading = true;

    try {
      const agentId = this.getAgentId();
      
      // 使用 FunctionComponent 拉起智能体
      // 实际实现需要根据 HarmonyOS 6.0 API
      console.info(`Launching agent: ${agentId}`);

      // 模拟成功
      setTimeout(() => {
        this.isLoading = false;
      }, 1000);
    } catch (error) {
      this.isLoading = false;
      console.error('Launch agent failed:', error);
    }
  }
}

/**
 * 智能体卡片组件
 * 展示智能体信息和快捷入口
 */
@Component
export struct AgentCard {
  @Prop agentType: AgentType = AgentType.RESUME;
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop features: string[] = [];

  @State isExpanded: boolean = false;

  build() {
    Column() {
      // 头部
      Row() {
        Image(this.getAgentIcon())
          .width(48)
          .height(48)
          .fillColor(BrandColors.Brand500);

        Column() {
          Text(this.title || this.getAgentLabel())
            .fontSize(FontSize.Size16)
            .fontWeight(FontWeight.Medium)
            .fontColor(NeutralColors.Neutral900);

          Text(this.description || this.getAgentDescription())
            .fontSize(FontSize.Size12)
            .fontColor(NeutralColors.Neutral500)
            .margin({ top: 2 });
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: Spacing.Space3 });

        Blank();

        Image($r('app.media.media_ic_expand'))
          .width(20)
          .height(20)
          .fillColor(NeutralColors.Neutral400)
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .onClick(() => {
            this.isExpanded = !this.isExpanded;
          });
      }
      .width('100%')
      .padding(Spacing.Space4);

      // 展开内容
      if (this.isExpanded) {
        Column() {
          // 功能列表
          ForEach(this.getAgentFeatures(), (feature: string, index: number) => {
            Row() {
              Image($r('app.media.media_ic_check'))
                .width(16)
                .height(16)
                .fillColor(SemanticColors.Success.Success500);

              Text(feature)
                .fontSize(FontSize.Size13)
                .fontColor(NeutralColors.Neutral700)
                .margin({ left: Spacing.Space2 });
            }
            .width('100%')
            .padding({ top: Spacing.Space2, bottom: Spacing.Space2 });
          });

          // 快捷按钮
          AgentButton({ 
            agentType: this.agentType, 
            size: 'medium',
            label: '立即体验'
          })
            .margin({ top: Spacing.Space3 });
        }
        .width('100%')
        .padding({ left: Spacing.Space4, right: Spacing.Space4, bottom: Spacing.Space4 });
      }
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(BorderRadius.RadiusLG)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetY: 2
    });
  }

  private getAgentLabel(): string {
    switch (this.agentType) {
      case AgentType.RESUME:
        return '简历优化助手';
      case AgentType.INTERVIEW:
        return '面试教练';
      case AgentType.CAREER:
        return '职业顾问';
      case AgentType.OFFER:
        return 'Offer分析师';
      default:
        return '智能助手';
    }
  }

  private getAgentDescription(): string {
    switch (this.agentType) {
      case AgentType.RESUME:
        return 'AI驱动的简历分析与优化';
      case AgentType.INTERVIEW:
        return '智能面试模拟与指导';
      case AgentType.CAREER:
        return '个性化职业发展建议';
      case AgentType.OFFER:
        return '多维度Offer评估分析';
      default:
        return '';
    }
  }

  private getAgentFeatures(): string[] {
    if (this.features.length > 0) {
      return this.features;
    }
    switch (this.agentType) {
      case AgentType.RESUME:
        return [
          '智能分析简历内容',
          '岗位匹配度评估',
          '优化建议生成',
          '一键优化排版'
        ];
      case AgentType.INTERVIEW:
        return [
          '模拟真实面试场景',
          '多行业题库覆盖',
          '实时反馈评分',
          '语音面试练习'
        ];
      case AgentType.CAREER:
        return [
          '职业发展路径规划',
          '能力评估分析',
          '行业趋势洞察',
          '技能提升建议'
        ];
      case AgentType.OFFER:
        return [
          '多Offer对比分析',
          '薪资福利评估',
          '发展前景预测',
          '决策建议生成'
        ];
      default:
        return [];
    }
  }

  private getAgentIcon(): Resource {
    switch (this.agentType) {
      case AgentType.RESUME:
        return $r('app.media.media_ic_agent_resume');
      case AgentType.INTERVIEW:
        return $r('app.media.media_ic_agent_interview');
      case AgentType.CAREER:
        return $r('app.media.media_ic_agent_career');
      case AgentType.OFFER:
        return $r('app.media.media_ic_agent_offer');
      default:
        return $r('app.media.media_ic_agent');
    }
  }
}

// 导入 SemanticColors
import { SemanticColors } from '../constants/design-tokens';
