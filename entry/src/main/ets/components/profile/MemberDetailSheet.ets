/**
 * MemberDetailSheet - 会员详情半屏弹窗
 * 
 * 鸿蒙设计规范：
 * - 半屏弹窗展示会员详情
 * - 权益列表
 * - 使用记录
 * - 续费/取消自动续费
 */

import promptAction from '@ohos.promptAction';
import { MemberService, MemberStatus, Benefit, UsageRecord } from '../../services/MemberService';
import { BenefitGrid } from './BenefitGrid';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  WarningColors,
  SuccessColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration
} from '../../constants/design-tokens';

/**
 * 会员详情面板参数
 */
export interface MemberDetailSheetParams {
  memberStatus: MemberStatus | null;
  onClose?: () => void;
  onRenewClick?: () => void;
}

@Component
export struct MemberDetailSheet {
  @State isShow: boolean = false;
  @State memberStatus: MemberStatus | null = null;
  @State benefits: Benefit[] = [];
  @State usageRecords: UsageRecord[] = [];
  @State isLoading: boolean = false;
  @State showCancelConfirm: boolean = false;
  @State activeTab: number = 0; // 0: 权益, 1: 使用记录
  
  // 事件回调
  onClose?: () => void;
  onRenewClick?: () => void;
  
  private memberService: MemberService = MemberService.getInstance();

  aboutToAppear() {
    this.loadData();
  }

  /**
   * 加载数据
   */
  private async loadData() {
    this.isLoading = true;
    
    try {
      // 并行加载权益和使用记录
      const [benefits, records] = await Promise.all([
        this.memberService.getBenefits(),
        this.memberService.getUsageRecords(10)
      ]);
      
      this.benefits = benefits;
      this.usageRecords = records;
    } catch (error) {
      console.error('[MemberDetailSheet] Load data failed:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 显示面板
   */
  show(status: MemberStatus | null) {
    this.memberStatus = status;
    this.isShow = true;
    this.loadData();
  }

  /**
   * 隐藏面板
   */
  hide() {
    this.isShow = false;
    this.showCancelConfirm = false;
    if (this.onClose) {
      this.onClose();
    }
  }

  build() {
    if (!this.isShow) {
      return;
    }
    
    Column() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          if (!this.showCancelConfirm) {
            this.hide();
          }
        })
      
      // 底部面板
      Column() {
        if (this.showCancelConfirm) {
          this.CancelConfirmContent()
        } else {
          this.DetailContent()
        }
      }
      .width('100%')
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1000)
  }

  /**
   * 详情内容
   */
  @Builder
  DetailContent() {
    Column() {
      // 顶部拖动条
      Row() {
        Column()
          .width(36)
          .height(4)
          .backgroundColor(NeutralColors.Neutral200)
          .borderRadius(2)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
      
      // 标题栏
      Row() {
        Text('会员详情')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
        
        Blank()
        
        Column() {
          Image($r('app.media.media_ic_close'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text3)
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.hide();
        })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Lg })
      
      // 会员状态卡片
      this.MemberStatusCard()
      
      // Tab 切换
      Row() {
        Column() {
          Text('会员权益')
            .fontSize(FontSize.Sm)
            .fontWeight(this.activeTab === 0 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.activeTab === 0 ? BrandColors.Brand500 : SemanticColors.Text2)
          
          if (this.activeTab === 0) {
            Column()
              .width(24)
              .height(2)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(1)
              .margin({ top: Spacing.Space2 })
          }
        }
        .layoutWeight(1)
        .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
        .onClick(() => {
          this.activeTab = 0;
        })
        
        Column() {
          Text('使用记录')
            .fontSize(FontSize.Sm)
            .fontWeight(this.activeTab === 1 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.activeTab === 1 ? BrandColors.Brand500 : SemanticColors.Text2)
          
          if (this.activeTab === 1) {
            Column()
              .width(24)
              .height(2)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(1)
              .margin({ top: Spacing.Space2 })
          }
        }
        .layoutWeight(1)
        .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
        .onClick(() => {
          this.activeTab = 1;
        })
      }
      .width('100%')
      .margin({ top: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral50)
      
      // 内容区域
      if (this.activeTab === 0) {
        this.BenefitsContent()
      } else {
        this.UsageRecordsContent()
      }
      
      // 底部操作区
      this.BottomActions()
    }
    .width('100%')
    .height('85%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
  }

  /**
   * 会员状态卡片
   */
  @Builder
  MemberStatusCard() {
    Column() {
      Row() {
        // 会员等级
        Column() {
          Row() {
            Text(this.memberStatus?.levelName || '会员')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)
            
            // VIP 标签
            Row() {
              Text('VIP')
                .fontSize(FontSize.Xs)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
            }
            .padding({ left: Spacing.Space3, right: Spacing.Space3, top: 2, bottom: 2 })
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
          
          Text(this.getExpireText())
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        
        // 剩余天数
        Column() {
          Text(this.getRemainingDays())
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(WarningColors.Warning500)
          
          Text('剩余天数')
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(SemanticSpacing.Lg)
    }
    .width('100%')
    .backgroundColor('#FFF8E6')
    .borderRadius(SemanticRadius.Control)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4 })
  }

  /**
   * 权益内容
   */
  @Builder
  BenefitsContent() {
    Scroll() {
      Column() {
        ForEach(this.benefits, (benefit: Benefit) => {
          this.BenefitItem(benefit)
        })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  /**
   * 权益项
   */
  @Builder
  BenefitItem(benefit: Benefit) {
    Row() {
      // 图标
      Column() {
        Image(this.getBenefitIcon(benefit.icon))
          .width(24)
          .height(24)
          .fillColor(BrandColors.Brand500)
      }
      .width(40)
      .height(40)
      .borderRadius(SemanticRadius.Control)
      .backgroundColor(BrandColors.Brand50)
      .justifyContent(FlexAlign.Center)
      
      // 名称和描述
      Column() {
        Text(benefit.name)
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)
        
        Text(benefit.description)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: Spacing.Space4 })
      
      // 状态
      Column() {
        Text('已开通')
          .fontSize(FontSize.Xs)
          .fontColor(SuccessColors.Success500)
      }
      .padding({ left: Spacing.Space3, right: Spacing.Space3, top: 2, bottom: 2 })
      .backgroundColor(SuccessColors.Success50)
      .borderRadius(SemanticRadius.Pill)
    }
    .width('100%')
    .padding(Spacing.Space4)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Control)
    .margin({ bottom: Spacing.Space3 })
  }

  /**
   * 使用记录内容
   */
  @Builder
  UsageRecordsContent() {
    Scroll() {
      Column() {
        if (this.usageRecords.length === 0) {
          Column() {
            Image($r('app.media.media_ic_history'))
              .width(48)
              .height(48)
              .fillColor(SemanticColors.Text3)
            
            Text('暂无使用记录')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
              .margin({ top: Spacing.Space4 })
          }
          .width('100%')
          .padding(SemanticSpacing.Xxl3)
        } else {
          ForEach(this.usageRecords, (record: UsageRecord) => {
            this.UsageRecordItem(record)
          })
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  /**
   * 使用记录项
   */
  @Builder
  UsageRecordItem(record: UsageRecord) {
    Row() {
      Column() {
        Text(record.benefitName)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text1)
        
        Text(record.detail)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
          .margin({ top: Spacing.Space2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      Text(this.formatTime(record.usedAt))
        .fontSize(FontSize.Xs)
        .fontColor(SemanticColors.Text3)
    }
    .width('100%')
    .padding(Spacing.Space4)
    .backgroundColor(NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Control)
    .margin({ bottom: Spacing.Space3 })
  }

  /**
   * 底部操作区
   */
  @Builder
  BottomActions() {
    Column() {
      // 自动续费状态
      Row() {
        Text('自动续费')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text1)
        
        Blank()
        
        if (this.memberStatus?.autoRenewing) {
          Row() {
            Text('已开启')
              .fontSize(FontSize.Sm)
              .fontColor(SuccessColors.Success500)
            
            Text(' | ')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
            
            Text('取消')
              .fontSize(FontSize.Sm)
              .fontColor(ErrorColors.Error500)
              .onClick(() => {
                this.showCancelConfirm = true;
              })
          }
        } else {
          Row() {
            Text('已关闭')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
            
            Text(' | ')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text3)
            
            Text('开启')
              .fontSize(FontSize.Sm)
              .fontColor(BrandColors.Brand500)
              .onClick(() => {
                if (this.onRenewClick) {
                  this.onRenewClick();
                }
              })
          }
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl, top: Spacing.Space4, bottom: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral50)
      
      // 续费按钮
      Button() {
        Text('续费会员')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)
      }
      .width('100%')
      .height(44)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [
          [WarningColors.Warning500, 0],
          ['#F97316', 1]
        ]
      })
      .borderRadius(SemanticRadius.Control)
      .margin({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl, top: Spacing.Space4, bottom: SemanticSpacing.Lg })
      .onClick(() => {
        if (this.onRenewClick) {
          this.onRenewClick();
        }
      })
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
  }

  /**
   * 取消确认内容
   */
  @Builder
  CancelConfirmContent() {
    Column() {
      Column() {
        Text('取消自动续费')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
        
        Text('取消后，会员权益将在到期日失效。确定要取消自动续费吗？')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .margin({ top: Spacing.Space4 })
          .textAlign(TextAlign.Center)
        
        Row() {
          Button() {
            Text('再想想')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(NeutralColors.Neutral100)
          .borderRadius(SemanticRadius.Control)
          .onClick(() => {
            this.showCancelConfirm = false;
          })
          
          Button() {
            Text('确认取消')
              .fontSize(FontSize.Sm)
              .fontColor(NeutralColors.Neutral0)
          }
          .layoutWeight(1)
          .height(44)
          .backgroundColor(ErrorColors.Error500)
          .borderRadius(SemanticRadius.Control)
          .margin({ left: Spacing.Space4 })
          .onClick(() => {
            this.handleCancelAutoRenew();
          })
        }
        .width('100%')
        .margin({ top: Spacing.Space6 })
      }
      .width('100%')
      .padding(SemanticSpacing.Xxl3)
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius(SemanticRadius.Component)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(SemanticSpacing.Xxl)
  }

  /**
   * 获取权益图标
   */
  private getBenefitIcon(iconName: string): Resource {
    switch (iconName) {
      case 'ic_resume':
        return $r('app.media.media_ic_resume');
      case 'ic_assessment':
        return $r('app.media.media_ic_assessment');
      case 'ic_chat':
        return $r('app.media.media_ic_chat');
      case 'ic_knowledge':
        return $r('app.media.media_ic_knowledge');
      case 'ic_favorite':
        return $r('app.media.media_ic_favorite');
      case 'ic_help':
        return $r('app.media.media_ic_help');
      default:
        return $r('app.media.media_ic_resume');
    }
  }

  /**
   * 获取到期文案
   */
  private getExpireText(): string {
    if (!this.memberStatus || !this.memberStatus.expireTime) return '';
    
    const date = new Date(this.memberStatus.expireTime);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    
    return `${year}-${month}-${day} 到期`;
  }

  /**
   * 获取剩余天数
   */
  private getRemainingDays(): string {
    if (!this.memberStatus) return '0';
    return String(this.memberStatus.remainingDays || 0);
  }

  /**
   * 格式化时间
   */
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hour = String(date.getHours()).padStart(2, '0');
    const minute = String(date.getMinutes()).padStart(2, '0');
    
    return `${month}/${day} ${hour}:${minute}`;
  }

  /**
   * 处理取消自动续费
   */
  private async handleCancelAutoRenew() {
    try {
      const result = await this.memberService.cancelAutoRenew();
      
      if (result) {
        promptAction.showToast({
          message: '已取消自动续费',
          duration: 2000
        });
        
        // 更新状态
        if (this.memberStatus) {
          this.memberStatus = {
            ...this.memberStatus,
            autoRenewing: false
          };
        }
        
        this.showCancelConfirm = false;
      } else {
        promptAction.showToast({
          message: '取消失败，请重试',
          duration: 2000
        });
      }
    } catch (error) {
      console.error('[MemberDetailSheet] Cancel auto renew failed:', error);
      promptAction.showToast({
        message: '操作失败，请重试',
        duration: 2000
      });
    }
  }
}
