/**
 * Offer 分析页面（重构版）
 *
 * 智能体驱动的 Offer 分析体验：
 * 1. 场景模板引导 → 快速开始
 * 2. 对话式录入 → AI 引导填写
 * 3. 多维度分析 → 雷达图 + 评分卡
 * 4. 权重自定义 → 滑块调节
 * 5. What-if 分析 → 实时调参
 * 6. 多 Offer 对比 → 并排雷达图
 */

import router from '@ohos.router';
import {
  OfferInput, OfferAnalysisResult, ComparisonResult,
  BenefitType, OvertimeFrequency,
  WeightConfig, DEFAULT_WEIGHTS, WEIGHT_LABELS,
  ScenarioTemplate, SCENARIO_TEMPLATES,
  createEmptyOfferInput,
} from '../models/OfferAnalysis';
import { OfferAnalysisService } from '../services/OfferAnalysisService';
import { OfferRadarChart } from '../components/offer/OfferRadarChart';
import { OfferFormCard } from '../components/offer/OfferFormCard';
import { OfferScoreCard } from '../components/offer/OfferScoreCard';
import { OfferWeightSlider } from '../components/offer/OfferWeightSlider';
import { OfferScenarioPicker } from '../components/offer/OfferScenarioPicker';
import { OfferWhatIfPanel } from '../components/offer/OfferWhatIfPanel';
import {
  BrandColors, NeutralColors, SemanticColors,
  SuccessColors, WarningColors, ErrorColors, InfoColors,
  SemanticSpacing, SemanticRadius, FontSize, FontWeight,
  ComponentSizes, Duration, Easing, Shadows, HarmonyDesign,
} from '../constants/design-tokens';

// 页面阶段
type PagePhase = 'scenario' | 'input' | 'result' | 'compare' | 'whatif';

@Entry
@Component
struct OfferAnalysisPage {
  // Offer 数据
  @State offers: OfferInput[] = [];
  @State currentOfferIndex: number = 0;
  @State phase: PagePhase = 'scenario';

  // 分析结果
  @State analysisResult: OfferAnalysisResult | null = null;
  @State comparisonResult: ComparisonResult | null = null;

  // 权重
  @State weights: WeightConfig = { ...DEFAULT_WEIGHTS };

  // 场景
  @State selectedScenarioId: string = '';

  // UI 状态
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showWeightSheet: boolean = false;
  @State showOvertimePicker: boolean = false;
  @State showAddConfirm: boolean = false;

  private offerService: OfferAnalysisService = OfferAnalysisService.getInstance();

  aboutToAppear() {
    // 如果从看板跳转过来，检查路由参数
    const params = router.getParams() as Record<string, string>;
    if (params?.company && params?.position) {
      const offer = createEmptyOfferInput();
      offer.company = params.company;
      offer.position = params.position;
      if (params.salary) {
        offer.monthlySalary = parseInt(params.salary) || 0;
      }
      if (params.location) {
        offer.note = `城市：${params.location}`;
      }
      this.offers = [offer];
      this.phase = 'input';
      this.selectedScenarioId = 'custom';
    }
  }

  build() {
    Column() {
      // 顶部导航
      this.TopBar()

      // 主内容区
      if (this.isLoading) {
        this.LoadingView()
      } else if (this.errorMessage) {
        this.ErrorView()
      } else {
        switch (this.phase) {
          case 'scenario':
            this.ScenarioView()
            break
          case 'input':
            this.InputView()
            break
          case 'result':
            this.ResultView()
            break
          case 'compare':
            this.CompareView()
            break
          case 'whatif':
            this.WhatIfView()
            break
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.Background)
    .bindSheet($$this.showWeightSheet, this.WeightSheet(), {
      height: '60%',
      dragBar: true,
      backgroundColor: SemanticColors.Surface1,
    })
    .bindSheet($$this.showOvertimePicker, this.OvertimeSheet(), {
      height: '35%',
      dragBar: true,
      backgroundColor: SemanticColors.Surface1,
    })
  }

  // ============================================
  // 顶部导航
  // ============================================
  @Builder
  TopBar() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(ComponentSizes.Icon.Lg)
        .height(ComponentSizes.Icon.Lg)
        .fillColor(SemanticColors.Text1)
        .onClick(() => router.back())

      Text(this.getPhaseTitle())
        .fontSize(FontSize.Lg)
        .fontColor(SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .margin({ left: SemanticSpacing.Sm })

      Blank()

      // 权重按钮（结果页显示）
      if (this.phase === 'result' || this.phase === 'whatif') {
        Text('权重')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .padding({
            left: SemanticSpacing.Sm, right: SemanticSpacing.Sm,
            top: SemanticSpacing.Xs, bottom: SemanticSpacing.Xs
          })
          .borderRadius(SemanticRadius.Pill)
          .backgroundColor(BrandColors.Brand50)
          .onClick(() => { this.showWeightSheet = true })
          .margin({ right: SemanticSpacing.Sm })
      }
    }
    .width('100%')
    .height(HarmonyDesign.NavBarHeight)
    .padding({ left: HarmonyDesign.SafePadding, right: HarmonyDesign.SafePadding })
    .backgroundColor(SemanticColors.Surface1)
  }

  // ============================================
  // 场景选择页
  // ============================================
  @Builder
  ScenarioView() {
    Scroll() {
      Column() {
        // 标题区
        Column() {
          Text('选择你的求职场景')
            .fontSize(FontSize.Xxl)
            .fontColor(SemanticColors.Text1)
            .fontWeight(FontWeight.Bold)

          Text('我们为你准备了常见场景模板，也可以自由录入')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
            .margin({ top: SemanticSpacing.Sm })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, top: SemanticSpacing.Xxl })

        // 场景选择器
        OfferScenarioPicker({
          selectedId: this.selectedScenarioId,
          onSelect: (template: ScenarioTemplate) => {
            this.selectedScenarioId = template.id;
            if (template.id === 'custom') {
              this.offers = [createEmptyOfferInput()];
            } else {
              this.offers = template.presetOffers.map(preset => ({
                ...createEmptyOfferInput(),
                ...preset,
                monthlySalary: preset.monthlySalary || 0,
                annualBonus: preset.annualBonus || 0,
                workHours: preset.workHours || 40,
                commuteMinutes: preset.commuteMinutes || 30,
                socialInsurance: preset.socialInsurance || 0.2,
                overtimeFrequency: preset.overtimeFrequency || 'sometimes' as OvertimeFrequency,
                benefits: preset.benefits || [],
              }));
            }
            // 延迟跳转到录入页
            setTimeout(() => {
              this.phase = 'input';
            }, 300);
          }
        })
        .margin({ top: SemanticSpacing.Lg, left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // ============================================
  // 录入页
  // ============================================
  @Builder
  InputView() {
    Column() {
      // Offer 切换器
      if (this.offers.length > 1) {
        Scroll() {
          Row() {
            ForEach(this.offers, (offer: OfferInput, index: number) => {
              Text(`Offer ${index + 1}`)
                .fontSize(FontSize.Sm)
                .fontColor(this.currentOfferIndex === index ? NeutralColors.Neutral0 : SemanticColors.Text2)
                .backgroundColor(this.currentOfferIndex === index ? BrandColors.Brand500 : SemanticColors.Surface2)
                .borderRadius(SemanticRadius.Pill)
                .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md, top: SemanticSpacing.Xs, bottom: SemanticSpacing.Xs })
                .margin({ right: SemanticSpacing.Sm })
                .onClick(() => { this.currentOfferIndex = index })
            }, (_: OfferInput, index: number) => index.toString())
          }
          .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ top: SemanticSpacing.Sm, bottom: SemanticSpacing.Sm })
      }

      // 表单
      if (this.offers.length > 0) {
        Scroll() {
          Column() {
            OfferFormCard({ offer: this.offers[this.currentOfferIndex] })
          }
          .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, bottom: SemanticSpacing.Xxl })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 底部操作栏
      Row() {
        if (this.offers.length < 5) {
          Button('添加 Offer')
            .height(ComponentSizes.Button.Md.height)
            .fontSize(FontSize.Md)
            .fontColor(SemanticColors.Text2)
            .backgroundColor(SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Control)
            .layoutWeight(1)
            .onClick(() => {
              this.offers.push(createEmptyOfferInput());
              this.currentOfferIndex = this.offers.length - 1;
            })
        }

        if (this.offers.length >= 2) {
          Button('对比分析')
            .height(ComponentSizes.Button.Md.height)
            .fontSize(FontSize.Md)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Control)
            .layoutWeight(1)
            .margin({ left: SemanticSpacing.Sm })
            .onClick(() => this.doCompare())
        }

        Button('分析当前')
          .height(ComponentSizes.Button.Md.height)
          .fontSize(FontSize.Md)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Control)
          .layoutWeight(1)
          .margin({ left: SemanticSpacing.Sm })
          .onClick(() => this.doAnalyze())
      }
      .width('100%')
      .padding({
        left: SemanticSpacing.Xl, right: SemanticSpacing.Xl,
        top: SemanticSpacing.Sm, bottom: HarmonyDesign.SafePadding
      })
      .backgroundColor(SemanticColors.Surface1)
    }
    .width('100%')
    .height('100%')
  }

  // ============================================
  // 分析结果页
  // ============================================
  @Builder
  ResultView() {
    Scroll() {
      Column() {
        if (this.analysisResult) {
          // 综合评分 + 雷达图
          Row() {
            // 左侧评分
            Column() {
              Text('综合评分')
                .fontSize(FontSize.Sm)
                .fontColor(SemanticColors.Text3)

              Stack() {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                  .width(120)
                  .height(120)
                  .color(SemanticColors.Surface2)

                Progress({ value: this.analysisResult.overallScore, total: 100, type: ProgressType.Ring })
                  .width(120)
                  .height(120)
                  .color(this.getScoreColor(this.analysisResult.overallScore))
                  .style({ strokeWidth: 10 })

                Column() {
                  Text(this.analysisResult.overallScore.toString())
                    .fontSize(FontSize.Xxxl)
                    .fontColor(SemanticColors.Text1)
                    .fontWeight(FontWeight.Bold)

                  Text(this.getScoreLabel(this.analysisResult.overallScore))
                    .fontSize(FontSize.Xs)
                    .fontColor(this.getScoreColor(this.analysisResult.overallScore))
                }
              }
              .margin({ top: SemanticSpacing.Sm })
            }
            .width('40%')
            .justifyContent(FlexAlign.Center)

            // 右侧雷达图
            Column() {
              OfferRadarChart({
                scores: [this.analysisResult.dimensions.map(d => d.score)],
                labels: this.analysisResult.dimensions.map(d => d.name),
              })
            }
            .width('60%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .margin({ top: SemanticSpacing.Md })

          // 评分卡片
          OfferScoreCard({ result: this.analysisResult })
            .margin({ top: SemanticSpacing.Sm })

          // AI 建议
          this.SuggestionSection('💡 AI 分析建议', this.analysisResult.suggestions)

          // 谈判建议
          this.SuggestionSection('🎯 谈判建议', this.analysisResult.negotiationTips)

          // What-if 入口
          Row() {
            Column() {
              Text('🔍 What-if 分析')
                .fontSize(FontSize.Md)
                .fontColor(SemanticColors.Text1)
                .fontWeight(FontWeight.Medium)

              Text('调整参数，实时查看评分变化')
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text3)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.ic_arrow_right'))
              .width(ComponentSizes.Icon.Md)
              .height(ComponentSizes.Icon.Md)
              .fillColor(SemanticColors.Text3)
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .margin({ top: SemanticSpacing.Md })
          .backgroundColor(SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Container)
          .onClick(() => { this.phase = 'whatif' })
        }
      }
      .padding({ bottom: SemanticSpacing.Xxl })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // ============================================
  // 对比页
  // ============================================
  @Builder
  CompareView() {
    Scroll() {
      Column() {
        if (this.comparisonResult) {
          // 推荐横幅
          Row() {
            Text('🏆 推荐')
              .fontSize(FontSize.Sm)
              .fontColor(NeutralColors.Neutral0)
              .backgroundColor(SuccessColors.Success500)
              .borderRadius(SemanticRadius.Pill)
              .padding({ left: SemanticSpacing.Sm, right: SemanticSpacing.Sm, top: 2, bottom: 2 })

            Text(this.comparisonResult.summary)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .margin({ left: SemanticSpacing.Sm })
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Container)
          .margin({ top: SemanticSpacing.Md })

          // 对比雷达图
          Column() {
            OfferRadarChart({
              scores: this.comparisonResult.dimensionComparison.map(d => d.scores),
              labels: this.comparisonResult.dimensionComparison.map(d => d.name),
            })
          }
          .padding(SemanticSpacing.Lg)
          .margin({ top: SemanticSpacing.Md })

          // 各 Offer 概览
          ForEach(this.comparisonResult.offers, (item, index: number) => {
            Column() {
              Row() {
                Text(`${item.company} - ${item.position}`)
                  .fontSize(FontSize.Md)
                  .fontColor(SemanticColors.Text1)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)

                if (index === this.comparisonResult!.recommendedIndex) {
                  Text('推荐')
                    .fontSize(FontSize.Xs)
                    .fontColor(NeutralColors.Neutral0)
                    .backgroundColor(SuccessColors.Success500)
                    .borderRadius(SemanticRadius.Pill)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                }

                Text(`${item.overallScore}分`)
                  .fontSize(FontSize.Md)
                  .fontColor(BrandColors.Brand500)
                  .fontWeight(FontWeight.Bold)
                  .margin({ left: SemanticSpacing.Sm })
              }
              .width('100%')

              // 优势
              if (item.advantages.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(item.advantages, (adv: string) => {
                    Text(adv)
                      .fontSize(FontSize.Xs)
                      .fontColor(SuccessColors.Success500)
                      .backgroundColor(SuccessColors.Success50)
                      .borderRadius(SemanticRadius.Element)
                      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                      .margin({ right: 4, top: 4 })
                  })
                }
                .margin({ top: SemanticSpacing.Sm })
              }

              // 劣势
              if (item.disadvantages.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(item.disadvantages, (dis: string) => {
                    Text(dis)
                      .fontSize(FontSize.Xs)
                      .fontColor(WarningColors.Warning500)
                      .backgroundColor(WarningColors.Warning50)
                      .borderRadius(SemanticRadius.Element)
                      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                      .margin({ right: 4, top: 4 })
                  })
                }
                .margin({ top: SemanticSpacing.Xs })
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Container)
            .margin({ top: SemanticSpacing.Sm })
          }, (_: any, index: number) => index.toString())
        }
      }
      .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, bottom: SemanticSpacing.Xxl })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  // ============================================
  // What-if 页
  // ============================================
  @Builder
  WhatIfView() {
    Column() {
      if (this.offers.length > 0) {
        OfferWhatIfPanel({
          offer: this.offers[this.currentOfferIndex],
          weights: this.weights,
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ============================================
  // 加载/错误状态
  // ============================================
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(BrandColors.Brand500)

      Text('AI 正在分析中...')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Md })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ErrorView() {
    Column() {
      Text('分析失败')
        .fontSize(FontSize.Lg)
        .fontColor(SemanticColors.Text1)

      Text(this.errorMessage)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Sm })
        .textAlign(TextAlign.Center)
        .padding({ left: SemanticSpacing.Xxl, right: SemanticSpacing.Xxl })

      Button('重试')
        .height(ComponentSizes.Button.Md.height)
        .fontSize(FontSize.Md)
        .fontColor(NeutralColors.Neutral0)
        .backgroundColor(BrandColors.Brand500)
        .borderRadius(SemanticRadius.Control)
        .margin({ top: SemanticSpacing.Xxl })
        .onClick(() => {
          this.errorMessage = '';
          this.phase = 'input';
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ============================================
  // 建议列表
  // ============================================
  @Builder
  SuggestionSection(title: string, items: string[]) {
    Column() {
      Text(title)
        .fontSize(FontSize.Md)
        .fontColor(SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      ForEach(items, (item: string) => {
        Row() {
          Text('•')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)

          Text(item)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ left: SemanticSpacing.Xs })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: SemanticSpacing.Sm })
      }, (item: string, index: number) => `${title}_${index}`)
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .margin({ top: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Container)
    .alignItems(HorizontalAlign.Start)
  }

  // ============================================
  // 权重弹窗
  // ============================================
  @Builder
  WeightSheet() {
    Column() {
      Text('自定义分析权重')
        .fontSize(FontSize.Lg)
        .fontColor(SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: SemanticSpacing.Xl, bottom: SemanticSpacing.Lg })

      OfferWeightSlider({
        weights: this.weights,
        onWeightChange: (w: WeightConfig) => {
          this.weights = w;
        }
      })

      // 重新分析按钮
      Button('使用新权重重新分析')
        .width('90%')
        .height(ComponentSizes.Button.Md.height)
        .fontSize(FontSize.Md)
        .fontColor(NeutralColors.Neutral0)
        .backgroundColor(BrandColors.Brand500)
        .borderRadius(SemanticRadius.Control)
        .margin({ top: SemanticSpacing.Xl, bottom: HarmonyDesign.SafePadding })
        .onClick(async () => {
          this.showWeightSheet = false;
          await this.doAnalyze();
        })
    }
    .width('100%')
    .height('100%')
  }

  // ============================================
  // 加班频率弹窗
  // ============================================
  @Builder
  OvertimeSheet() {
    Column() {
      Text('选择加班频率')
        .fontSize(FontSize.Lg)
        .fontColor(SemanticColors.Text1)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: SemanticSpacing.Xl, bottom: SemanticSpacing.Lg })

      List() {
        ForEach(['never', 'rarely', 'sometimes', 'often', 'always'] as OvertimeFrequency[], (freq: OvertimeFrequency) => {
          ListItem() {
            Row() {
              Text(this.getOvertimeLabel(freq))
                .fontSize(FontSize.Md)
                .fontColor(this.offers[this.currentOfferIndex]?.overtimeFrequency === freq ? BrandColors.Brand500 : SemanticColors.Text1)

              Blank()

              if (this.offers[this.currentOfferIndex]?.overtimeFrequency === freq) {
                Image($r('app.media.ic_check'))
                  .width(ComponentSizes.Icon.Md)
                  .height(ComponentSizes.Icon.Md)
                  .fillColor(BrandColors.Brand500)
              }
            }
            .width('100%')
            .padding({ left: SemanticSpacing.Xl, right: SemanticSpacing.Xl, top: SemanticSpacing.Md, bottom: SemanticSpacing.Md })
            .onClick(() => {
              if (this.offers.length > 0) {
                this.offers[this.currentOfferIndex].overtimeFrequency = freq;
              }
              this.showOvertimePicker = false;
            })
          }
        }, (freq: OvertimeFrequency) => freq)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  // ============================================
  // 业务方法
  // ============================================
  private async doAnalyze(): Promise<void> {
    if (this.offers.length === 0 || this.currentOfferIndex >= this.offers.length) {
      this.errorMessage = '请先填写 Offer 信息';
      return;
    }

    const offer = this.offers[this.currentOfferIndex];
    if (!offer.company || !offer.position) {
      this.errorMessage = '请至少填写公司名称和职位';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.analysisResult = await this.offerService.analyzeWithWeights(offer, this.weights);
      this.phase = 'result';
    } catch (error) {
      this.errorMessage = '分析失败，请检查网络后重试';
    } finally {
      this.isLoading = false;
    }
  }

  private async doCompare(): Promise<void> {
    if (this.offers.length < 2) {
      this.errorMessage = '至少需要 2 个 Offer 才能对比';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.comparisonResult = await this.offerService.compareOffers(this.offers);
      this.phase = 'compare';
    } catch (error) {
      this.errorMessage = '对比失败，请检查网络后重试';
    } finally {
      this.isLoading = false;
    }
  }

  // ============================================
  // 辅助方法
  // ============================================
  private getPhaseTitle(): string {
    switch (this.phase) {
      case 'scenario': return 'Offer 分析';
      case 'input': return '填写 Offer';
      case 'result': return '分析结果';
      case 'compare': return 'Offer 对比';
      case 'whatif': return 'What-if 分析';
      default: return 'Offer 分析';
    }
  }

  private getScoreLabel(score: number): string {
    if (score >= 85) return '优秀';
    if (score >= 70) return '良好';
    if (score >= 55) return '一般';
    if (score >= 40) return '较差';
    return '很差';
  }

  private getScoreColor(score: number): string {
    if (score >= 85) return SuccessColors.Success500;
    if (score >= 70) return InfoColors.Info500;
    if (score >= 55) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  private getOvertimeLabel(freq: OvertimeFrequency): string {
    const labels: Record<OvertimeFrequency, string> = {
      never: '几乎不加班',
      rarely: '偶尔加班',
      sometimes: '有时加班',
      often: '经常加班',
      always: '频繁加班',
    };
    return labels[freq] || freq;
  }
}
