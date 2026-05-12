/**
 * Offer 分析页面
 *
 * 提供 Offer 信息录入、AI 分析、多 Offer 对比功能。
 * 使用 Canvas 2D 绘制雷达图，BindSheet 弹窗新增 Offer。
 */

import {
  OfferInput,
  OfferAnalysisResult,
  ComparisonResult,
  BenefitType,
  BenefitTypeLabels,
  OvertimeFrequency,
  OvertimeFrequencyLabels,
  DimensionScore,
  createEmptyOfferInput,
} from '../models/OfferAnalysis';
import { OfferAnalysisService } from '../services/OfferAnalysisService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  InfoColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes,
  HarmonyDesign,
} from '../constants/design-tokens';
import { Colors } from '../constants/colors';

// ============================================
// 页面 Tab 类型
// ============================================
type PageTab = 'input' | 'result' | 'compare';

@Entry
@Component
struct OfferAnalysisPage {
  // Offer 列表
  @State offers: OfferInput[] = [];
  @State currentOfferIndex: number = 0;
  @State currentTab: PageTab = 'input';

  // 表单状态
  @State formCompany: string = '';
  @State formPosition: string = '';
  @State formSalary: string = '';
  @State formBonus: string = '';
  @State formEquity: string = '';
  @State formInsurance: string = '0.2';
  @State formWorkHours: string = '40';
  @State formOvertime: OvertimeFrequency = 'sometimes';
  @State formCommute: string = '30';
  @State formNote: string = '';
  @State selectedBenefits: BenefitType[] = [...[BenefitType.SUPPLEMENTAL_MEDICAL, BenefitType.MEAL_ALLOWANCE,
    BenefitType.TRANSPORT_ALLOWANCE, BenefitType.HEALTH_CHECKUP]];

  // 分析结果
  @State analysisResult: OfferAnalysisResult | null = null;
  @State comparisonResult: ComparisonResult | null = null;

  // UI 状态
  @State isLoading: boolean = false;
  @State showAddSheet: boolean = false;
  @State showBenefitPicker: boolean = false;
  @State showOvertimePicker: boolean = false;
  @State errorMessage: string = '';

  // 雷达图设置
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private radarContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 对比雷达图设置
  private compareSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private compareRadarContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.compareSettings);

  private offerService: OfferAnalysisService = OfferAnalysisService.getInstance();

  // 所有福利类型列表
  private allBenefits: BenefitType[] = [
    BenefitType.SUPPLEMENTAL_MEDICAL,
    BenefitType.EXTRA_LEAVE,
    BenefitType.MEAL_ALLOWANCE,
    BenefitType.TRANSPORT_ALLOWANCE,
    BenefitType.HOUSING_ALLOWANCE,
    BenefitType.HEALTH_CHECKUP,
    BenefitType.OTHER,
  ];

  // 所有加班频率列表
  private overtimeOptions: OvertimeFrequency[] = ['never', 'rarely', 'sometimes', 'often', 'always'];

  aboutToAppear() {
    AppStorage.setOrCreate('currentPage', 'pages/OfferAnalysis');
    // 初始化一个空白 Offer
    if (this.offers.length === 0) {
      this.offers.push(createEmptyOfferInput());
    }
    this.loadFormFromOffer(0);
  }

  // ============================================
  // 表单操作
  // ============================================

  /** 从 Offer 数据加载表单 */
  loadFormFromOffer(index: number) {
    if (index < 0 || index >= this.offers.length) return;
    const offer = this.offers[index];
    this.formCompany = offer.company;
    this.formPosition = offer.position;
    this.formSalary = offer.monthlySalary > 0 ? offer.monthlySalary.toString() : '';
    this.formBonus = offer.annualBonus > 0 ? offer.annualBonus.toString() : '';
    this.formEquity = offer.equity;
    this.formInsurance = offer.socialInsurance > 0 ? offer.socialInsurance.toString() : '0.2';
    this.formWorkHours = offer.workHours > 0 ? offer.workHours.toString() : '40';
    this.formOvertime = offer.overtimeFrequency;
    this.formCommute = offer.commuteMinutes > 0 ? offer.commuteMinutes.toString() : '30';
    this.formNote = offer.note;
    this.selectedBenefits = [...offer.benefits];
    this.currentOfferIndex = index;
    this.analysisResult = null;
    this.errorMessage = '';
  }

  /** 从表单收集数据到 Offer */
  collectFormToOffer(): OfferInput | null {
    if (!this.validateForm()) return null;

    return {
      company: this.formCompany.trim(),
      position: this.formPosition.trim(),
      monthlySalary: parseFloat(this.formSalary) || 0,
      annualBonus: parseFloat(this.formBonus) || 0,
      equity: this.formEquity.trim(),
      socialInsurance: parseFloat(this.formInsurance) || 0.2,
      benefits: [...this.selectedBenefits],
      workHours: parseFloat(this.formWorkHours) || 40,
      overtimeFrequency: this.formOvertime,
      commuteMinutes: parseFloat(this.formCommute) || 30,
      note: this.formNote.trim(),
    };
  }

  /** 表单验证 */
  validateForm(): boolean {
    if (!this.formCompany.trim()) {
      this.errorMessage = '请输入公司名称';
      return false;
    }
    if (!this.formPosition.trim()) {
      this.errorMessage = '请输入职位名称';
      return false;
    }
    if (!this.formSalary || parseFloat(this.formSalary) <= 0) {
      this.errorMessage = '请输入有效的月薪';
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  /** 保存当前 Offer 到列表 */
  saveCurrentOffer() {
    const offer = this.collectFormToOffer();
    if (!offer) return;

    if (this.currentOfferIndex < this.offers.length) {
      this.offers[this.currentOfferIndex] = offer;
    } else {
      this.offers.push(offer);
    }
  }

  /** 切换福利选择 */
  toggleBenefit(type: BenefitType) {
    const idx = this.selectedBenefits.indexOf(type);
    if (idx >= 0) {
      this.selectedBenefits.splice(idx, 1);
    } else {
      this.selectedBenefits.push(type);
    }
  }

  // ============================================
  // 分析操作
  // ============================================

  /** 开始分析当前 Offer */
  async startAnalysis() {
    this.saveCurrentOffer();
    const offer = this.offers[this.currentOfferIndex];
    if (!offer) return;

    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.analysisResult = await this.offerService.analyzeOffer(offer);
      this.currentTab = 'result';
    } catch (error) {
      this.errorMessage = '分析失败，请稍后重试';
    } finally {
      this.isLoading = false;
    }
  }

  /** 开始对比所有 Offer */
  async startComparison() {
    // 先保存当前表单
    this.saveCurrentOffer();

    const validOffers = this.offers.filter(o => o.company && o.position && o.monthlySalary > 0);
    if (validOffers.length < 2) {
      this.errorMessage = '至少需要 2 份完整 Offer 才能对比';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      this.comparisonResult = await this.offerService.compareOffers(validOffers);
      this.currentTab = 'compare';
    } catch (error) {
      this.errorMessage = '对比失败，请稍后重试';
    } finally {
      this.isLoading = false;
    }
  }

  /** 添加新 Offer */
  addNewOffer() {
    this.saveCurrentOffer();
    const newOffer = createEmptyOfferInput();
    this.offers.push(newOffer);
    this.currentOfferIndex = this.offers.length - 1;
    this.loadFormFromOffer(this.currentOfferIndex);
    this.showAddSheet = false;
    this.currentTab = 'input';
    this.analysisResult = null;
  }

  /** 删除指定 Offer */
  removeOffer(index: number) {
    if (this.offers.length <= 1) {
      this.errorMessage = '至少保留一份 Offer';
      return;
    }
    this.offers.splice(index, 1);
    if (this.currentOfferIndex >= this.offers.length) {
      this.currentOfferIndex = this.offers.length - 1;
    }
    this.loadFormFromOffer(this.currentOfferIndex);
  }

  // ============================================
  // 雷达图绘制
  // ============================================

  /** 绘制单个 Offer 雷达图 */
  drawRadarChart() {
    if (!this.analysisResult) return;

    const ctx = this.radarContext;
    const width = 300;
    const height = 300;
    const centerX = width / 2;
    const centerY = height / 2;
    const maxRadius = 110;
    const dimensions = this.analysisResult.dimensions;
    const count = dimensions.length;
    const angleStep = (Math.PI * 2) / count;

    ctx.clearRect(0, 0, width, height);

    // 绘制背景网格
    const levels = 5;
    for (let level = 1; level <= levels; level++) {
      const r = (maxRadius / levels) * level;
      ctx.beginPath();
      for (let i = 0; i <= count; i++) {
        const angle = angleStep * i - Math.PI / 2;
        const x = centerX + r * Math.cos(angle);
        const y = centerY + r * Math.sin(angle);
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.closePath();
      ctx.strokeStyle = level === levels ? NeutralColors.Neutral300 : NeutralColors.Neutral200;
      ctx.lineWidth = level === levels ? 1.5 : 0.8;
      ctx.stroke();
    }

    // 绘制轴线
    for (let i = 0; i < count; i++) {
      const angle = angleStep * i - Math.PI / 2;
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(centerX + maxRadius * Math.cos(angle), centerY + maxRadius * Math.sin(angle));
      ctx.strokeStyle = NeutralColors.Neutral200;
      ctx.lineWidth = 0.8;
      ctx.stroke();
    }

    // 绘制数据区域
    ctx.beginPath();
    for (let i = 0; i <= count; i++) {
      const idx = i % count;
      const angle = angleStep * idx - Math.PI / 2;
      const r = (dimensions[idx].score / 100) * maxRadius;
      const x = centerX + r * Math.cos(angle);
      const y = centerY + r * Math.sin(angle);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(139, 92, 246, 0.2)';
    ctx.fill();
    ctx.strokeStyle = BrandColors.Brand500;
    ctx.lineWidth = 2;
    ctx.stroke();

    // 绘制数据点
    for (let i = 0; i < count; i++) {
      const angle = angleStep * i - Math.PI / 2;
      const r = (dimensions[i].score / 100) * maxRadius;
      const x = centerX + r * Math.cos(angle);
      const y = centerY + r * Math.sin(angle);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = BrandColors.Brand500;
      ctx.fill();
      ctx.strokeStyle = NeutralColors.Neutral0;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // 绘制标签
    ctx.font = '12px sans-serif';
    ctx.fillStyle = NeutralColors.Neutral700;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < count; i++) {
      const angle = angleStep * i - Math.PI / 2;
      const labelR = maxRadius + 22;
      const x = centerX + labelR * Math.cos(angle);
      const y = centerY + labelR * Math.sin(angle);
      ctx.fillText(dimensions[i].name, x, y);
    }
  }

  /** 绘制对比雷达图 */
  drawComparisonRadar() {
    if (!this.comparisonResult) return;

    const ctx = this.compareRadarContext;
    const width = 320;
    const height = 320;
    const centerX = width / 2;
    const centerY = height / 2;
    const maxRadius = 110;
    const dimComp = this.comparisonResult.dimensionComparison;
    const count = dimComp.length;
    const angleStep = (Math.PI * 2) / count;

    // 对比颜色
    const compareColors = [
      { fill: 'rgba(139, 92, 246, 0.15)', stroke: BrandColors.Brand500 },
      { fill: 'rgba(0, 125, 255, 0.15)', stroke: InfoColors.Info500 },
      { fill: 'rgba(255, 152, 0, 0.15)', stroke: WarningColors.Warning500 },
    ];

    ctx.clearRect(0, 0, width, height);

    // 绘制背景网格
    const levels = 5;
    for (let level = 1; level <= levels; level++) {
      const r = (maxRadius / levels) * level;
      ctx.beginPath();
      for (let i = 0; i <= count; i++) {
        const angle = angleStep * i - Math.PI / 2;
        const x = centerX + r * Math.cos(angle);
        const y = centerY + r * Math.sin(angle);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.strokeStyle = level === levels ? NeutralColors.Neutral300 : NeutralColors.Neutral200;
      ctx.lineWidth = level === levels ? 1.5 : 0.8;
      ctx.stroke();
    }

    // 绘制轴线
    for (let i = 0; i < count; i++) {
      const angle = angleStep * i - Math.PI / 2;
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.lineTo(centerX + maxRadius * Math.cos(angle), centerY + maxRadius * Math.sin(angle));
      ctx.strokeStyle = NeutralColors.Neutral200;
      ctx.lineWidth = 0.8;
      ctx.stroke();
    }

    // 绘制每个 Offer 的数据区域
    const offerCount = this.comparisonResult.offers.length;
    for (let o = 0; o < offerCount; o++) {
      const color = compareColors[o % compareColors.length];
      ctx.beginPath();
      for (let i = 0; i <= count; i++) {
        const idx = i % count;
        const angle = angleStep * idx - Math.PI / 2;
        const score = dimComp[idx].scores[o] || 0;
        const r = (score / 100) * maxRadius;
        const x = centerX + r * Math.cos(angle);
        const y = centerY + r * Math.sin(angle);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.fillStyle = color.fill;
      ctx.fill();
      ctx.strokeStyle = color.stroke;
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // 绘制标签
    ctx.font = '12px sans-serif';
    ctx.fillStyle = NeutralColors.Neutral700;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < count; i++) {
      const angle = angleStep * i - Math.PI / 2;
      const labelR = maxRadius + 22;
      const x = centerX + labelR * Math.cos(angle);
      const y = centerY + labelR * Math.sin(angle);
      ctx.fillText(dimComp[i].name, x, y);
    }
  }

  // ============================================
  // 辅助方法
  // ============================================

  /** 获取评分对应颜色 */
  getScoreColor(score: number): string {
    if (score >= 85) return SuccessColors.Success500;
    if (score >= 70) return InfoColors.Info500;
    if (score >= 55) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /** 获取评分进度条颜色 */
  getProgressColor(score: number): ResourceColor {
    if (score >= 85) return SuccessColors.Success500;
    if (score >= 70) return InfoColors.Info500;
    if (score >= 55) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  // ============================================
  // 构建页面
  // ============================================

  build() {
    Column() {
      // 顶部导航栏
      this.buildNavBar();

      // Tab 切换栏
      this.buildTabBar();

      // 内容区域
      if (this.isLoading) {
        this.buildLoadingView();
      } else {
        if (this.currentTab === 'input') {
          this.buildInputTab();
        } else if (this.currentTab === 'result') {
          this.buildResultTab();
        } else if (this.currentTab === 'compare') {
          this.buildCompareTab();
        }
      }

      // 错误提示
      if (this.errorMessage) {
        this.buildErrorToast();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SemanticColors.Background)
    .bindSheet($$this.showAddSheet, this.buildAddSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      backgroundColor: SemanticColors.Background,
      borderRadius: { topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet },
    })
    .bindSheet($$this.showOvertimePicker, this.buildOvertimeSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      showClose: true,
      dragBar: true,
      backgroundColor: SemanticColors.Background,
      borderRadius: { topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet },
    })
  }

  // ============================================
  // 导航栏
  // ============================================

  @Builder
  buildNavBar() {
    Row() {
      // 返回按钮
      Button() {
        // 左箭头用文字模拟
        Text('<')
          .fontSize(FontSize.Xxl)
          .fontColor(SemanticColors.Text1)
      }
      .type(ButtonType.Circle)
      .backgroundColor(Color.Transparent)
      .width(ComponentSizes.Button.Lg.height)
      .height(ComponentSizes.Button.Lg.height)
      .onClick(() => {
        // 返回上一页
      })

      Text('Offer 分析')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 右侧占位
      Button() {
        Text('+')
          .fontSize(FontSize.Xxl)
          .fontColor(SemanticColors.Text1)
      }
      .type(ButtonType.Circle)
      .backgroundColor(Color.Transparent)
      .width(ComponentSizes.Button.Lg.height)
      .height(ComponentSizes.Button.Lg.height)
      .onClick(() => {
        this.showAddSheet = true;
      })
    }
    .width('100%')
    .height(HarmonyDesign.NavBarHeight)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(SemanticColors.Background)
  }

  // ============================================
  // Tab 栏
  // ============================================

  @Builder
  buildTabBar() {
    Row() {
      this.buildTabItem('录入', 'input', 0)
      if (this.offers.length >= 2) {
        this.buildTabItem('对比', 'compare', 1)
      }
      if (this.analysisResult) {
        this.buildTabItem('分析', 'result', this.offers.length >= 2 ? 2 : 1)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(SemanticColors.Surface1)
  }

  @Builder
  buildTabItem(title: string, tab: PageTab, index: number) {
    Column() {
      Text(title)
        .fontSize(FontSize.Sm)
        .fontWeight(this.currentTab === tab ? FontWeight.Semibold : FontWeight.Normal)
        .fontColor(this.currentTab === tab ? BrandColors.Brand500 : SemanticColors.Text3)
        .padding({ top: SemanticSpacing.Sm, bottom: SemanticSpacing.Xs })

      // 底部指示条
      Row()
        .width(this.currentTab === tab ? 24 : 0)
        .height(2)
        .backgroundColor(BrandColors.Brand500)
        .borderRadius(SemanticRadius.Pill)
        .animation({ duration: 200 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (tab === 'result' && !this.analysisResult) return;
      if (tab === 'compare' && this.offers.length < 2) return;
      this.currentTab = tab;
    })
  }

  // ============================================
  // 录入 Tab
  // ============================================

  @Builder
  buildInputTab() {
    Scroll() {
      Column() {
        // Offer 切换器
        if (this.offers.length > 1) {
          this.buildOfferSwitcher();
        }

        // 基本信息卡片
        this.buildBasicInfoCard();

        // 薪资信息卡片
        this.buildSalaryCard();

        // 工作条件卡片
        this.buildWorkConditionCard();

        // 福利保障卡片
        this.buildBenefitCard();

        // 备注卡片
        this.buildNoteCard();

        // 操作按钮
        this.buildActionButtons();

        // 底部间距
        Row().height(SemanticSpacing.Xxl3)
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Md })
    }
    .scrollBar(BarState.Auto)
    .layoutWeight(1)
  }

  /** Offer 切换器 */
  @Builder
  buildOfferSwitcher() {
    Row() {
      Text('当前 Offer')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .layoutWeight(1)

      ForEach(this.offers, (offer: OfferInput, index: number) => {
        Text(`${index + 1}`)
          .fontSize(FontSize.Sm)
          .fontColor(this.currentOfferIndex === index ? NeutralColors.Neutral0 : SemanticColors.Text2)
          .backgroundColor(this.currentOfferIndex === index ? BrandColors.Brand500 : SemanticColors.Surface2)
          .borderRadius(SemanticRadius.Pill)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .margin({ left: SemanticSpacing.Xs })
          .onClick(() => {
            this.saveCurrentOffer();
            this.loadFormFromOffer(index);
          })
      }, (offer: OfferInput, index: number) => `${index}`)
    }
    .width('100%')
    .padding(SemanticSpacing.Md)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 基本信息卡片 */
  @Builder
  buildBasicInfoCard() {
    Column() {
      Text('基本信息')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 公司名称
      this.buildFormItem('公司名称', '', true, (value: string) => {
        this.formCompany = value;
      }, this.formCompany, '请输入公司名称', InputType.Normal)

      // 职位名称
      this.buildFormItem('职位名称', '', true, (value: string) => {
        this.formPosition = value;
      }, this.formPosition, '请输入职位名称', InputType.Normal)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 薪资信息卡片 */
  @Builder
  buildSalaryCard() {
    Column() {
      Text('薪资信息')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 月薪
      this.buildFormItem('月薪（元）', '元', true, (value: string) => {
        this.formSalary = value;
      }, this.formSalary, '请输入月薪', InputType.Number)

      // 年终奖
      this.buildFormItem('年终奖（月数）', '个月', false, (value: string) => {
        this.formBonus = value;
      }, this.formBonus, '如：2', InputType.Number)

      // 股权
      this.buildFormItem('股权/期权', '', false, (value: string) => {
        this.formEquity = value;
      }, this.formEquity, '如：期权 10000 股', InputType.Normal)

      // 五险一金比例
      this.buildFormItem('五险一金比例', '', false, (value: string) => {
        this.formInsurance = value;
      }, this.formInsurance, '如：0.2（即 20%）', InputType.Number)

      // 年包预估
      if (this.formSalary && parseFloat(this.formSalary) > 0) {
        Row() {
          Text('预估年包')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
          Text(`${this.calcAnnualPackage().toLocaleString()} 元`)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Semibold)
            .fontColor(BrandColors.Brand500)
            .margin({ left: SemanticSpacing.Xs })
        }
        .width('100%')
        .padding({ top: SemanticSpacing.Sm })
        .justifyContent(FlexAlign.SpaceBetween)
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 工作条件卡片 */
  @Builder
  buildWorkConditionCard() {
    Column() {
      Text('工作条件')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 每周工作时长
      this.buildFormItem('每周工时', '小时/周', false, (value: string) => {
        this.formWorkHours = value;
      }, this.formWorkHours, '如：40', InputType.Number)

      // 加班频率
      Row() {
        Text('加班频率')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width(80)

        Text(OvertimeFrequencyLabels[this.formOvertime])
          .fontSize(FontSize.Base)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .padding({ right: SemanticSpacing.Sm })

        Text('>')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text3)
      }
      .width('100%')
      .height(48)
      .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
      .backgroundColor(SemanticColors.Surface3)
      .borderRadius(SemanticRadius.Control)
      .margin({ bottom: SemanticSpacing.Md })
      .onClick(() => {
        this.showOvertimePicker = true;
      })

      // 通勤时间
      this.buildFormItem('通勤时间', '分钟', false, (value: string) => {
        this.formCommute = value;
      }, this.formCommute, '如：30', InputType.Number)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 福利保障卡片 */
  @Builder
  buildBenefitCard() {
    Column() {
      Row() {
        Text('福利保障')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Semibold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)

        Text(`已选 ${this.selectedBenefits.length} 项`)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text3)
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Md })

      // 福利标签
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.allBenefits, (type: BenefitType) => {
          Text(BenefitTypeLabels[type])
            .fontSize(FontSize.Xs)
            .fontColor(this.selectedBenefits.includes(type) ? BrandColors.Brand500 : SemanticColors.Text2)
            .backgroundColor(this.selectedBenefits.includes(type) ? BrandColors.Brand50 : SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Pill)
            .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md, top: SemanticSpacing.Sm, bottom: SemanticSpacing.Sm })
            .margin({ right: SemanticSpacing.Sm, bottom: SemanticSpacing.Sm })
            .border({
              width: 1,
              color: this.selectedBenefits.includes(type) ? BrandColors.Brand500 : SemanticColors.Border,
              radius: SemanticRadius.Pill,
            })
            .onClick(() => {
              this.toggleBenefit(type);
            })
        }, (type: BenefitType) => type)
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 备注卡片 */
  @Builder
  buildNoteCard() {
    Column() {
      Text('备注')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      TextArea({ text: this.formNote, placeholder: '其他需要记录的信息...' })
        .width('100%')
        .height(80)
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text1)
        .placeholderColor(SemanticColors.Text4)
        .backgroundColor(SemanticColors.Surface3)
        .borderRadius(SemanticRadius.Control)
        .padding(SemanticSpacing.Md)
        .onChange((value: string) => {
          this.formNote = value;
        })
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 操作按钮 */
  @Builder
  buildActionButtons() {
    Column() {
      // 分析按钮
      Button('分析当前 Offer')
        .width('100%')
        .height(ComponentSizes.Button.Lg.height)
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(NeutralColors.Neutral0)
        .backgroundColor(BrandColors.Brand500)
        .borderRadius(SemanticRadius.Control)
        .margin({ bottom: SemanticSpacing.Md })
        .onClick(() => {
          this.startAnalysis();
        })

      // 对比按钮
      if (this.offers.length >= 2) {
        Button('对比所有 Offer')
          .width('100%')
          .height(ComponentSizes.Button.Lg.height)
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Medium)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Control)
          .border({ width: 1, color: BrandColors.Brand500, radius: SemanticRadius.Control })
          .onClick(() => {
            this.startComparison();
          })
      }
    }
    .width('100%')
    .margin({ top: SemanticSpacing.Sm })
  }

  /** 通用表单项 */
  @Builder
  buildFormItem(
    label: string,
    unit: string,
    required: boolean,
    onChange: (value: string) => void,
    value: string,
    placeholder: string,
    inputType: InputType
  ) {
    Column() {
      Row() {
        Text(label)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
        if (required) {
          Text(' *')
            .fontSize(FontSize.Sm)
            .fontColor(ErrorColors.Error500)
        }
        if (unit) {
          Text(`（${unit}）`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
        }
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Xs })

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(ComponentSizes.Input.Md.height)
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text1)
        .placeholderColor(SemanticColors.Text4)
        .backgroundColor(SemanticColors.Surface3)
        .borderRadius(SemanticRadius.Control)
        .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
        .type(inputType)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: SemanticSpacing.Md })
  }

  /** 计算预估年包 */
  calcAnnualPackage(): number {
    const salary = parseFloat(this.formSalary) || 0;
    const bonus = parseFloat(this.formBonus) || 0;
    return Math.round(salary * (12 + bonus));
  }

  // ============================================
  // 分析结果 Tab
  // ============================================

  @Builder
  buildResultTab() {
    Scroll() {
      Column() {
        if (this.analysisResult) {
          // 综合评分
          this.buildOverallScore();

          // 雷达图
          this.buildRadarChartSection();

          // 各维度评分
          this.buildDimensionScores();

          // 市场对比
          this.buildMarketComparison();

          // AI 建议
          this.buildSuggestions();

          // 谈判建议
          this.buildNegotiationTips();
        }

        Row().height(SemanticSpacing.Xxl3)
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Md })
    }
    .scrollBar(BarState.Auto)
    .layoutWeight(1)
  }

  /** 综合评分 */
  @Builder
  buildOverallScore() {
    Column() {
      Text('综合评分')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .margin({ bottom: SemanticSpacing.Lg })

      Row() {
        // 圆形评分
        Stack() {
          // 背景圆环
          Circle({ width: 100, height: 100 })
            .fill(Color.Transparent)
            .stroke(SemanticColors.Surface2)
            .strokeWidth(8)

          // 进度圆环
          Circle({ width: 100, height: 100 })
            .fill(Color.Transparent)
            .stroke(this.getProgressColor(this.analysisResult!.overallScore))
            .strokeWidth(8)
            .startAngle(90)
            .sweepAngle(this.analysisResult!.overallScore / 100 * 360)

          // 分数
          Text(`${this.analysisResult!.overallScore}`)
            .fontSize(FontSize.Xxxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getProgressColor(this.analysisResult!.overallScore))
        }
        .width(100)
        .height(100)

        Column() {
          Text(this.getScoreLabel(this.analysisResult!.overallScore))
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Semibold)
            .fontColor(SemanticColors.Text1)
          Text(`${this.offers[this.currentOfferIndex]?.company || ''} - ${this.offers[this.currentOfferIndex]?.position || ''}`)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .margin({ top: SemanticSpacing.Xs })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: SemanticSpacing.Xxl })
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 雷达图区域 */
  @Builder
  buildRadarChartSection() {
    Column() {
      Text('能力雷达图')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      Canvas(this.radarContext)
        .width(300)
        .height(300)
        .onReady(() => {
          this.drawRadarChart();
        })
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
    .alignItems(HorizontalAlign.Center)
  }

  /** 各维度评分 */
  @Builder
  buildDimensionScores() {
    Column() {
      Text('维度评分')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      ForEach(this.analysisResult!.dimensions, (dim: DimensionScore) => {
        Column() {
          Row() {
            Text(dim.name)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .width(80)

            Progress({ value: dim.score, total: 100, type: ProgressBarType.Linear })
              .layoutWeight(1)
              .height(8)
              .color(this.getProgressColor(dim.score))
              .backgroundColor(SemanticColors.Surface2)
              .style({ strokeWidth: 8 })

            Text(`${dim.score}`)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Semibold)
              .fontColor(this.getProgressColor(dim.score))
              .width(30)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Xs })

          Row() {
            Text(dim.description)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .layoutWeight(1)
            Text(dim.label)
              .fontSize(FontSize.Xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getProgressColor(dim.score))
              .padding({ left: SemanticSpacing.Sm, right: SemanticSpacing.Sm, top: 2, bottom: 2 })
              .backgroundColor(this.getScoreBgColor(dim.score))
              .borderRadius(SemanticRadius.Pill)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Md })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (dim: DimensionScore) => dim.name)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 市场对比 */
  @Builder
  buildMarketComparison() {
    if (!this.analysisResult?.marketComparison) return;
    const mc = this.analysisResult.marketComparison;

    Column() {
      Text('市场对比')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      Text(mc.description)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 薪资范围条
      Column() {
        Row() {
          Text(`低位 ${mc.salaryRange.low.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
          Text(`中位 ${mc.salaryRange.median.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
          Text(`高位 ${mc.salaryRange.high.toLocaleString()}`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: SemanticSpacing.Xs })

        // 薪资范围进度条
        Stack() {
          Row()
            .width('100%')
            .height(8)
            .backgroundColor(SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Pill)

          Row()
            .width(`${mc.salaryPercentile}%`)
            .height(8)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
        }
        .width('100%')
        .alignContent(Alignment.Start)

        Text(`超过市场 ${mc.salaryPercentile}% 的水平`)
          .fontSize(FontSize.Xs)
          .fontColor(BrandColors.Brand500)
          .margin({ top: SemanticSpacing.Xs })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** AI 建议 */
  @Builder
  buildSuggestions() {
    Column() {
      Row() {
        Text('AI 分析建议')
          .fontSize(FontSize.Base)
          .fontWeight(FontWeight.Semibold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
        Text('AI')
          .fontSize(FontSize.Xs)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Pill)
          .padding({ left: SemanticSpacing.Sm, right: SemanticSpacing.Sm, top: 2, bottom: 2 })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Md })

      ForEach(this.analysisResult!.suggestions, (suggestion: string, index: number) => {
        Row() {
          Text(`${index + 1}.`)
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
            .margin({ right: SemanticSpacing.Sm })
          Text(suggestion)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .layoutWeight(1)
            .lineHeight(22)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: SemanticSpacing.Sm })
      }, (suggestion: string, index: number) => `${index}`)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 谈判建议 */
  @Builder
  buildNegotiationTips() {
    Column() {
      Text('谈判建议')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      ForEach(this.analysisResult!.negotiationTips, (tip: string, index: number) => {
        Row() {
          Text(`💡`)
            .fontSize(FontSize.Sm)
            .margin({ right: SemanticSpacing.Sm })
          Text(tip)
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)
            .layoutWeight(1)
            .lineHeight(22)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding(SemanticSpacing.Md)
        .margin({ bottom: SemanticSpacing.Sm })
        .backgroundColor(WarningColors.Warning50)
        .borderRadius(SemanticRadius.Element)
      }, (tip: string, index: number) => `${index}`)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  // ============================================
  // 对比 Tab
  // ============================================

  @Builder
  buildCompareTab() {
    Scroll() {
      Column() {
        if (this.comparisonResult) {
          // 对比雷达图
          this.buildComparisonRadarSection();

          // 对比总结
          this.buildComparisonSummary();

          // 各 Offer 概览
          this.buildComparisonOffers();

          // 维度对比详情
          this.buildComparisonDimensions();
        }

        Row().height(SemanticSpacing.Xxl3)
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Md })
    }
    .scrollBar(BarState.Auto)
    .layoutWeight(1)
  }

  /** 对比雷达图 */
  @Builder
  buildComparisonRadarSection() {
    Column() {
      Text('对比雷达图')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      // 图例
      Row() {
        ForEach(this.comparisonResult!.offers, (item: { company: string }, index: number) => {
          Row() {
            Row()
              .width(12)
              .height(12)
              .borderRadius(SemanticRadius.Element)
              .backgroundColor(this.getCompareColor(index))
            Text(item.company)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text2)
              .margin({ left: SemanticSpacing.Xs })
          }
          .margin({ right: SemanticSpacing.Lg })
        }, (item: { company: string }, index: number) => `${index}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: SemanticSpacing.Md })

      Canvas(this.compareRadarContext)
        .width(320)
        .height(320)
        .onReady(() => {
          this.drawComparisonRadar();
        })
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
    .alignItems(HorizontalAlign.Center)
  }

  /** 对比总结 */
  @Builder
  buildComparisonSummary() {
    Column() {
      Text('对比结论')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      Text(this.comparisonResult!.summary)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .lineHeight(22)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 各 Offer 概览 */
  @Builder
  buildComparisonOffers() {
    ForEach(this.comparisonResult!.offers, (item: { company: string; position: string; overallScore: number;
      advantages: string[]; disadvantages: string[] }, index: number) => {
      Column() {
        Row() {
          Row()
            .width(4)
            .height(40)
            .borderRadius(SemanticRadius.Pill)
            .backgroundColor(this.getCompareColor(index))

          Column() {
            Text(`${item.company} - ${item.position}`)
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Semibold)
              .fontColor(SemanticColors.Text1)
            Text(`综合评分：${item.overallScore} 分`)
              .fontSize(FontSize.Sm)
              .fontColor(this.getProgressColor(item.overallScore))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: SemanticSpacing.Md })
          .layoutWeight(1)

          if (index === this.comparisonResult!.recommendedIndex) {
            Text('推荐')
              .fontSize(FontSize.Xs)
              .fontColor(NeutralColors.Neutral0)
              .backgroundColor(SuccessColors.Success500)
              .borderRadius(SemanticRadius.Pill)
              .padding({ left: SemanticSpacing.Sm, right: SemanticSpacing.Sm, top: 2, bottom: 2 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 优势
        if (item.advantages.length > 0) {
          Column() {
            Text('优势')
              .fontSize(FontSize.Xs)
              .fontColor(SuccessColors.Success500)
              .fontWeight(FontWeight.Medium)
            ForEach(item.advantages, (adv: string) => {
              Text(`  ${adv}`)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text2)
            }, (adv: string) => adv)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .margin({ top: SemanticSpacing.Sm })
        }

        // 劣势
        if (item.disadvantages.length > 0) {
          Column() {
            Text('劣势')
              .fontSize(FontSize.Xs)
              .fontColor(WarningColors.Warning500)
              .fontWeight(FontWeight.Medium)
            ForEach(item.disadvantages, (dis: string) => {
              Text(`  ${dis}`)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text2)
            }, (dis: string) => dis)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .margin({ top: SemanticSpacing.Sm })
        }
      }
      .width('100%')
      .padding(SemanticSpacing.Xxl)
      .margin({ bottom: SemanticSpacing.Md })
      .backgroundColor(SemanticColors.Surface1)
      .borderRadius(SemanticRadius.Component)
      .alignItems(HorizontalAlign.Start)
    }, (item: { company: string }, index: number) => `${index}`)
  }

  /** 维度对比详情 */
  @Builder
  buildComparisonDimensions() {
    Column() {
      Text('维度对比')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Md })

      ForEach(this.comparisonResult!.dimensionComparison, (dimComp: { name: string; scores: number[];
        description: string }) => {
        Column() {
          Text(dimComp.name)
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Xs })

          ForEach(dimComp.scores, (score: number, sIdx: number) => {
            Row() {
              Text(this.comparisonResult!.offers[sIdx]?.company || `Offer ${sIdx + 1}`)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text3)
                .width(80)

              Progress({ value: score, total: 100, type: ProgressBarType.Linear })
                .layoutWeight(1)
                .height(6)
                .color(this.getCompareColor(sIdx))
                .backgroundColor(SemanticColors.Surface2)

              Text(`${score}`)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text2)
                .width(30)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .margin({ bottom: 2 })
          }, (score: number, sIdx: number) => `${sIdx}`)

          Text(dimComp.description)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .width('100%')
            .margin({ top: SemanticSpacing.Xs, bottom: SemanticSpacing.Md })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: SemanticSpacing.Md })
        .borderRadius(SemanticRadius.Element)
      }, (dimComp: { name: string }) => dimComp.name)
    }
    .width('100%')
    .padding(SemanticSpacing.Xxl)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  // ============================================
  // 加载与错误
  // ============================================

  @Builder
  buildLoadingView() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(BrandColors.Brand500)
      Text('正在分析中...')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .margin({ top: SemanticSpacing.Md })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildErrorToast() {
    Row() {
      Text(this.errorMessage)
        .fontSize(FontSize.Sm)
        .fontColor(ErrorColors.Error500)
        .layoutWeight(1)
      Text('关闭')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text3)
        .onClick(() => {
          this.errorMessage = '';
        })
    }
    .width('100%')
    .padding(SemanticSpacing.Md)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    .backgroundColor(ErrorColors.Error50)
    .borderRadius(SemanticRadius.Control)
  }

  // ============================================
  // BindSheet - 新增 Offer 弹窗
  // ============================================

  @Builder
  buildAddSheetBuilder() {
    Column() {
      // 弹窗标题
      Row() {
        Text('新增 Offer')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Semibold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
        Text('取消')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text3)
          .onClick(() => {
            this.showAddSheet = false;
          })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Xxl })

      Text('将添加一份新的空白 Offer 表单，当前 Offer 数据已自动保存。')
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .lineHeight(22)
        .margin({ bottom: SemanticSpacing.Xxl })

      // 确认按钮
      Button('确认添加')
        .width('100%')
        .height(ComponentSizes.Button.Lg.height)
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Semibold)
        .fontColor(NeutralColors.Neutral0)
        .backgroundColor(BrandColors.Brand500)
        .borderRadius(SemanticRadius.Control)
        .onClick(() => {
          this.addNewOffer();
        })
    }
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(SemanticColors.Background)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
  }

  // ============================================
  // BindSheet - 加班频率选择弹窗
  // ============================================

  @Builder
  buildOvertimeSheetBuilder() {
    Column() {
      Row() {
        Text('选择加班频率')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Semibold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
        Text('取消')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text3)
          .onClick(() => {
            this.showOvertimePicker = false;
          })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Lg })

      ForEach(this.overtimeOptions, (freq: OvertimeFrequency) => {
        Row() {
          Text(OvertimeFrequencyLabels[freq])
            .fontSize(FontSize.Base)
            .fontColor(this.formOvertime === freq ? BrandColors.Brand500 : SemanticColors.Text1)
            .layoutWeight(1)

          if (this.formOvertime === freq) {
            Text('✓')
              .fontSize(FontSize.Base)
              .fontColor(BrandColors.Brand500)
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
        .backgroundColor(this.formOvertime === freq ? BrandColors.Brand50 : Color.Transparent)
        .borderRadius(SemanticRadius.Control)
        .margin({ bottom: SemanticSpacing.Xs })
        .onClick(() => {
          this.formOvertime = freq;
          this.showOvertimePicker = false;
        })
      }, (freq: OvertimeFrequency) => freq)
    }
    .padding(SemanticSpacing.Xxl)
    .backgroundColor(SemanticColors.Background)
    .borderRadius({ topLeft: SemanticRadius.BottomSheet, topRight: SemanticRadius.BottomSheet })
  }

  // ============================================
  // 辅助方法
  // ============================================

  /** 获取对比颜色 */
  getCompareColor(index: number): string {
    const colors = [BrandColors.Brand500, InfoColors.Info500, WarningColors.Warning500];
    return colors[index % colors.length];
  }

  /** 获取评分背景色 */
  getScoreBgColor(score: number): string {
    if (score >= 85) return SuccessColors.Success50;
    if (score >= 70) return InfoColors.Info50;
    if (score >= 55) return WarningColors.Warning50;
    return ErrorColors.Error50;
  }
}
