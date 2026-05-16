import { OfferAnalysisService } from '../services/OfferAnalysisService';
import { MemberService } from '../services/MemberService';
import { HistoryService } from '../services/HistoryService';
import { OfferItem } from '../models/Offer';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct OfferAnalysis {
  @State private offers: OfferItem[] = [];
  @State private isLoading: boolean = false;
  @State private analysisResult: string = '';
  @State private showAnalysis: boolean = false;
  private offerAnalysisService: OfferAnalysisService = OfferAnalysisService.getInstance();
  private memberService: MemberService = MemberService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();

  private async analyzeOffers(): Promise<void> {
    if (this.offers.length < 2) {
      promptAction.showToast({ message: '请至少添加两个 Offer 进行对比' });
      return;
    }
    this.isLoading = true;
    try {
      this.analysisResult = await this.offerAnalysisService.analyzeOffers(this.offers);
      this.showAnalysis = true;
    } catch (err) {
      promptAction.showToast({ message: 'Offer 分析失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private addOffer(): void {
    const newOffer: OfferItem = {
      id: Date.now().toString(),
      company: '',
      position: '',
      salary: 0,
      city: '',
      benefits: [],
      score: 0
    };
    this.offers = [...this.offers, newOffer];
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('Offer 分析')
          .fontSize(FontSize.LG)
          .fontWeight(FontWeight.SEMIBOLD)
          .fontColor(NeutralColors.GRAY_900)
          .layoutWeight(1)

        if (!this.showAnalysis) {
          Button('+ 添加 Offer')
            .height(32)
            .backgroundColor(BrandColors.PRIMARY)
            .fontColor(NeutralColors.WHITE)
            .fontSize(FontSize.SM)
            .borderRadius(SemanticRadius.BTN)
            .onClick(() => this.addOffer())
        }
      }
      .width('100%')
      .height(ComponentSizes.NAV_BAR)
      .padding({ left: SemanticSpacing.PAGE_H, right: SemanticSpacing.PAGE_H })

      if (this.showAnalysis) {
        // 分析结果
        Scroll() {
          Column() {
            Text('AI 分析结果')
              .fontSize(FontSize.LG)
              .fontWeight(FontWeight.SEMIBOLD)
              .fontColor(NeutralColors.GRAY_900)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: Spacing.MD })

            Text(this.analysisResult)
              .fontSize(FontSize.MD)
              .fontColor(NeutralColors.GRAY_700)
              .lineHeight(24)
              .width('100%')

            Button('重新分析')
              .width('100%')
              .height(ComponentSizes.BTN_LG)
              .backgroundColor(NeutralColors.GRAY_200)
              .fontColor(NeutralColors.GRAY_700)
              .borderRadius(SemanticRadius.BTN)
              .margin({ top: Spacing.LG })
              .onClick(() => { this.showAnalysis = false; })
          }
          .width('100%')
          .padding(SemanticSpacing.PAGE_H)
        }
        .layoutWeight(1)
      } else {
        // Offer 列表
        Scroll() {
          Column() {
            if (this.offers.length === 0) {
              Column() {
                Text('暂无 Offer')
                  .fontSize(FontSize.MD)
                  .fontColor(NeutralColors.GRAY_400)
                Text('点击右上角添加 Offer 进行对比分析')
                  .fontSize(FontSize.SM)
                  .fontColor(NeutralColors.GRAY_400)
                  .margin({ top: Spacing.SM })
              }
              .width('100%')
              .padding({ top: 80 })
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.offers, (offer: OfferItem, idx: number) => {
                Column() {
                  Text(offer.company.length > 0 ? offer.company : `Offer ${idx + 1}`)
                    .fontSize(FontSize.MD)
                    .fontWeight(FontWeight.SEMIBOLD)
                    .fontColor(NeutralColors.GRAY_900)
                    .margin({ bottom: Spacing.XS })

                  if (offer.position.length > 0) {
                    Text(offer.position)
                      .fontSize(FontSize.SM)
                      .fontColor(NeutralColors.GRAY_500)
                  }

                  if (offer.salary > 0) {
                    Text(`月薪：${offer.salary}k`)
                      .fontSize(FontSize.SM)
                      .fontColor(BrandColors.PRIMARY)
                      .margin({ top: Spacing.XS })
                  }
                }
                .width('100%')
                .padding(SemanticSpacing.CARD)
                .backgroundColor(NeutralColors.WHITE)
                .borderRadius(SemanticRadius.CARD)
                .margin({ bottom: Spacing.MD, left: SemanticSpacing.PAGE_H, right: SemanticSpacing.PAGE_H })
                .alignItems(HorizontalAlign.Start)
              })
            }
          }
          .padding({ bottom: 100 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        // 底部操作区
        Column() {
          Button(this.isLoading ? '分析中...' : 'AI 智能分析')
            .width('90%')
            .height(ComponentSizes.BTN_LG)
            .backgroundColor(this.offers.length >= 2 ? BrandColors.PRIMARY : NeutralColors.GRAY_300)
            .fontColor(NeutralColors.WHITE)
            .fontSize(FontSize.MD)
            .borderRadius(SemanticRadius.BTN)
            .enabled(this.offers.length >= 2 && !this.isLoading)
            .onClick(() => this.analyzeOffers())
        }
        .width('100%')
        .padding({ top: Spacing.MD, bottom: Spacing.XL })
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(NeutralColors.WHITE)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.GRAY_50)
  }
}
