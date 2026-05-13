/**
 * PurchaseSheet - 底部弹出购买面板
 * 
 * 鸿蒙设计规范：
 * - 使用 BindSheet 半屏弹窗
 * - 套餐选择：月卡/季卡/年卡
 * - 价格对比标签（推荐/最划算）
 * - 支付按钮：华为支付
 * - 购买成功动画
 */

import promptAction from '@ohos.promptAction';
import { MemberService, Package, Benefit } from '../../services/MemberService';
import { PurchaseResult } from '../../services/PaymentService';
import { CompactBenefitGrid } from './BenefitGrid';
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
 * 购买面板参数
 */
export interface PurchaseSheetParams {
  onClose?: () => void;
  onSuccess?: () => void;
}

@Component
export struct PurchaseSheet {
  @State isShow: boolean = false;
  @State selectedPackageId: string = 'quarterly'; // 默认选中季度
  @State isPurchasing: boolean = false;
  @State showSuccess: boolean = false;
  
  // 套餐列表
  @State packages: Package[] = [];
  
  // 事件回调
  onClose?: () => void;
  onSuccess?: () => void;
  
  private memberService: MemberService = MemberService.getInstance();

  aboutToAppear() {
    this.packages = this.memberService.getPackages();
  }

  /**
   * 显示面板
   */
  show() {
    this.isShow = true;
  }

  /**
   * 隐藏面板
   */
  hide() {
    this.isShow = false;
    this.showSuccess = false;
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
          if (!this.isPurchasing) {
            this.hide();
          }
        })
      
      // 底部面板
      Column() {
        // 成功动画
        if (this.showSuccess) {
          this.SuccessContent()
        } else {
          // 正常购买内容
          this.PurchaseContent()
        }
      }
      .width('100%')
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
      .position({ x: 0, y: this.showSuccess ? '30%' : '0' })
      .animation({
        duration: Duration.Normal,
        curve: Curve.EaseOut
      })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1000)
  }

  /**
   * 购买内容
   */
  @Builder
  PurchaseContent() {
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
      
      // 标题
      Row() {
        Text('开通VIP会员')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
        
        Blank()
        
        // 关闭按钮
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
      
      // 权益预览
      Column() {
        Row() {
          Text('开通即享以下权益')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
        }
        .width('100%')
        .margin({ bottom: Spacing.Space3 })
        
        CompactBenefitGrid({ benefits: [], isMember: true })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl })
      .margin({ top: Spacing.Space4 })
      
      // 套餐选择
      Column() {
        Row() {
          Text('选择套餐')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
        }
        .width('100%')
        .margin({ bottom: Spacing.Space4 })
        
        // 套餐列表
        Row() {
          ForEach(this.packages, (pkg: Package) => {
            this.PackageItem(pkg)
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl })
      .margin({ top: SemanticSpacing.Lg })
      
      // 底部支付区域
      Column() {
        // 价格展示
        Row() {
          Text('¥')
            .fontSize(FontSize.Base)
            .fontColor(WarningColors.Warning500)
          
          Text(this.getSelectedPrice())
            .fontSize(FontSize.Xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(WarningColors.Warning500)
          
          // 原价
          Text(`¥${this.getSelectedOriginalPrice()}`)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
            .decoration({ type: TextDecorationType.LineThrough })
            .margin({ left: Spacing.Space3 })
        }
        
        Blank()
        
        // 支付按钮
        Button() {
          Row() {
            if (this.isPurchasing) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color(NeutralColors.Neutral0)
                .margin({ right: Spacing.Space3 })
            }
            
            Text(this.isPurchasing ? '支付中...' : '立即开通')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
          }
        }
        .width(140)
        .height(44)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            [WarningColors.Warning500, 0],
            ['#F97316', 1]
          ]
        })
        .borderRadius(SemanticRadius.Control)
        .enabled(!this.isPurchasing)
        .onClick(() => {
          this.handlePurchase();
        })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl, top: SemanticSpacing.Lg, bottom: SemanticSpacing.Xxl })
      .margin({ top: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral50)
      
      // 协议提示
      Row() {
        Text('开通即表示同意')
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
        
        Text('《会员服务协议》')
          .fontSize(FontSize.Xs)
          .fontColor(BrandColors.Brand500)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: SemanticSpacing.Lg })
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
  }

  /**
   * 套餐项
   */
  @Builder
  PackageItem(pkg: Package) {
    Column() {
      // 标签
      if (pkg.tag) {
        Row() {
          Text(pkg.tag)
            .fontSize(10)
            .fontColor(NeutralColors.Neutral0)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor(this.getTagColor(pkg.tag))
        .borderRadius({ topLeft: 4, topRight: 4 })
        .position({ x: 0, y: -18 })
      }
      
      // 套餐名称
      Text(pkg.name)
        .fontSize(FontSize.Sm)
        .fontWeight(this.selectedPackageId === pkg.id ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedPackageId === pkg.id ? SemanticColors.Text1 : SemanticColors.Text2)
      
      // 价格
      Row() {
        Text('¥')
          .fontSize(FontSize.Xs)
          .fontColor(this.selectedPackageId === pkg.id ? WarningColors.Warning500 : SemanticColors.Text2)
        
        Text(pkg.price.toFixed(1))
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedPackageId === pkg.id ? WarningColors.Warning500 : SemanticColors.Text2)
      }
      .margin({ top: Spacing.Space2 })
      
      // 原价/折扣
      if (pkg.discount) {
        Text(pkg.discount)
          .fontSize(FontSize.Xs)
          .fontColor(this.selectedPackageId === pkg.id ? SuccessColors.Success500 : SemanticColors.Text3)
          .margin({ top: Spacing.Space2 })
      }
    }
    .width('30%')
    .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
    .backgroundColor(this.selectedPackageId === pkg.id ? '#FFF8E6' : NeutralColors.Neutral50)
    .borderRadius(SemanticRadius.Control)
    .border({
      width: this.selectedPackageId === pkg.id ? 2 : 1,
      color: this.selectedPackageId === pkg.id ? WarningColors.Warning500 : NeutralColors.Neutral200
    })
    .onClick(() => {
      this.selectedPackageId = pkg.id;
    })
  }

  /**
   * 成功内容
   */
  @Builder
  SuccessContent() {
    Column() {
      // 成功图标动画
      Column() {
        Column() {
          Text('✓')
            .fontSize(40)
            .fontColor(NeutralColors.Neutral0)
        }
        .width(80)
        .height(80)
        .borderRadius(40)
        .backgroundColor(SuccessColors.Success500)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 16,
          color: 'rgba(100, 187, 92, 0.3)',
          offsetY: 4
        })
      }
      .margin({ top: 40, bottom: Spacing.Space6 })
      
      // 成功文案
      Text('开通成功')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
      
      Text('已为您开通会员权益')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .margin({ top: Spacing.Space3 })
      
      // 确认按钮
      Button() {
        Text('开始体验')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral0)
      }
      .width(200)
      .height(44)
      .backgroundColor(BrandColors.Brand500)
      .borderRadius(SemanticRadius.Control)
      .margin({ top: Spacing.Space8 })
      .onClick(() => {
        this.hide();
        if (this.onSuccess) {
          this.onSuccess();
        }
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl3)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
  }

  /**
   * 获取标签颜色
   */
  private getTagColor(tag: string): string {
    switch (tag) {
      case '推荐':
        return BrandColors.Brand500;
      case '最划算':
        return ErrorColors.Error500;
      default:
        return WarningColors.Warning500;
    }
  }

  /**
   * 获取选中套餐价格
   */
  private getSelectedPrice(): string {
    const pkg = this.packages.find(p => p.id === this.selectedPackageId);
    return pkg ? pkg.price.toFixed(1) : '0';
  }

  /**
   * 获取选中套餐原价
   */
  private getSelectedOriginalPrice(): string {
    const pkg = this.packages.find(p => p.id === this.selectedPackageId);
    return pkg ? pkg.originalPrice.toFixed(1) : '0';
  }

  /**
   * 处理购买
   * 审核期间禁用 mock 支付流程，点击时显示即将上线提示
   */
  private async handlePurchase() {
    // 审核期间隐藏支付入口，显示即将上线提示
    promptAction.showToast({
      message: '支付功能即将上线，敬请期待',
      duration: 2000
    });
    return;

    // 以下为原支付流程，审核通过后恢复
    /*
    if (this.isPurchasing) return;
    
    this.isPurchasing = true;
    
    try {
      const result = await this.memberService.purchaseMember(
        this.selectedPackageId,
        (purchaseResult: PurchaseResult) => {
          // 购买成功
          this.isPurchasing = false;
          this.showSuccess = true;
        },
        (error: { code: string; message: string }) => {
          // 购买失败
          this.isPurchasing = false;
          if (error.code !== 'CANCELLED') {
            promptAction.showToast({
              message: error.message || '购买失败，请重试',
              duration: 2000
            });
          }
        }
      );
      
      // 处理返回结果
      if (!result.success && result.errorCode !== 'CANCELLED') {
        // 错误已在回调中处理
      }
    } catch (error) {
      this.isPurchasing = false;
      promptAction.showToast({
        message: '购买异常，请重试',
        duration: 2000
      });
    }
    */
  }
}
