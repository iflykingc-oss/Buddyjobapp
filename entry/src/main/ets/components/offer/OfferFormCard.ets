/**
 * Offer 表单卡片组件
 *
 * 包含基本信息、薪资信息、工作条件、福利标签选择等表单区域。
 * 使用 @Link 双向绑定 OfferInput，实时计算年包预估。
 * 使用 design-tokens 的间距、圆角、字体等常量。
 */

import {
  BrandColors,
  SemanticColors,
  ErrorColors,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes,
} from '../../constants/design-tokens';
import {
  OfferInput,
  BenefitType,
  BenefitTypeLabels,
  OvertimeFrequency,
  OvertimeFrequencyLabels,
  DEFAULT_BENEFITS,
} from '../../models/OfferAnalysis';

@Component
export struct OfferFormCard {
  /** Offer 输入数据（双向绑定） */
  @Link offer: OfferInput;

  @State private selectedBenefits: BenefitType[] = [...DEFAULT_BENEFITS];

  /** 所有加班频率选项 */
  private overtimeOptions: { value: OvertimeFrequency; label: string }[] = [
    { value: 'never', label: '几乎不加班' },
    { value: 'rarely', label: '偶尔加班' },
    { value: 'sometimes', label: '有时加班' },
    { value: 'often', label: '经常加班' },
    { value: 'always', label: '频繁加班' },
  ];

  /** 所有福利类型列表 */
  private allBenefits: BenefitType[] = [
    BenefitType.SUPPLEMENTAL_MEDICAL,
    BenefitType.EXTRA_LEAVE,
    BenefitType.MEAL_ALLOWANCE,
    BenefitType.TRANSPORT_ALLOWANCE,
    BenefitType.HOUSING_ALLOWANCE,
    BenefitType.HEALTH_CHECKUP,
    BenefitType.OTHER,
  ];

  aboutToAppear() {
    this.selectedBenefits = [...this.offer.benefits];
  }

  /** 切换福利选择 */
  private toggleBenefit(type: BenefitType) {
    const idx = this.selectedBenefits.indexOf(type);
    if (idx >= 0) {
      this.selectedBenefits.splice(idx, 1);
    } else {
      this.selectedBenefits.push(type);
    }
    this.offer.benefits = [...this.selectedBenefits];
  }

  /** 计算预估年包 = 月薪 x (12 + 年终奖月数) */
  private calcAnnualPackage(): number {
    const salary = this.offer.monthlySalary || 0;
    const bonus = this.offer.annualBonus || 0;
    return Math.round(salary * (12 + bonus));
  }

  /** 通用表单项构建器 */
  @Builder
  buildFormItem(
    label: string,
    unit: string,
    required: boolean,
    field: string,
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
          Text(`(${unit})`)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
        }
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Xs })

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(ComponentSizes.Input.Md.height)
        .fontSize(ComponentSizes.Input.Md.fontSize)
        .fontColor(SemanticColors.Text1)
        .placeholderColor(SemanticColors.Text4)
        .backgroundColor(SemanticColors.Surface3)
        .borderRadius(SemanticRadius.Control)
        .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
        .type(inputType)
        .onChange((val: string) => {
          if (field === 'monthlySalary' || field === 'annualBonus' ||
            field === 'workHours' || field === 'commuteMinutes') {
            (this.offer as Record<string, Object>)[field] = parseFloat(val) || 0;
          } else if (field === 'socialInsurance') {
            (this.offer as Record<string, Object>)[field] = parseFloat(val) || 0;
          } else {
            (this.offer as Record<string, Object>)[field] = val;
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: SemanticSpacing.Md })
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

      this.buildFormItem(
        '公司名称', '', true, 'company',
        this.offer.company, '请输入公司名称', InputType.Normal
      )

      this.buildFormItem(
        '职位名称', '', true, 'position',
        this.offer.position, '请输入职位名称', InputType.Normal
      )
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
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

      this.buildFormItem(
        '月薪', '元', true, 'monthlySalary',
        this.offer.monthlySalary > 0 ? this.offer.monthlySalary.toString() : '',
        '请输入月薪', InputType.Number
      )

      this.buildFormItem(
        '年终奖', '月数', false, 'annualBonus',
        this.offer.annualBonus > 0 ? this.offer.annualBonus.toString() : '',
        '如：2', InputType.Number
      )

      this.buildFormItem(
        '股权/期权', '', false, 'equity',
        this.offer.equity, '如：期权 10000 股', InputType.Normal
      )

      this.buildFormItem(
        '五险一金比例', '', false, 'socialInsurance',
        this.offer.socialInsurance > 0 ? this.offer.socialInsurance.toString() : '0.2',
        '如：0.2（即 20%）', InputType.Number
      )

      // 年包预估 = 月薪 x (12 + 年终奖月数)
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
    .width('100%')
    .padding(SemanticSpacing.Lg)
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

      this.buildFormItem(
        '每周工时', '小时/周', false, 'workHours',
        this.offer.workHours > 0 ? this.offer.workHours.toString() : '40',
        '如：40', InputType.Number
      )

      // 加班频率 - Row 按钮组选择
      Column() {
        Text('加班频率')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width('100%')
          .margin({ bottom: SemanticSpacing.Xs })

        Row({ space: SemanticSpacing.Xs }) {
          ForEach(this.overtimeOptions, (option: { value: OvertimeFrequency; label: string }) => {
            Text(option.label)
              .fontSize(FontSize.Xs)
              .fontColor(this.offer.overtimeFrequency === option.value ?
                BrandColors.Brand500 : SemanticColors.Text2)
              .backgroundColor(this.offer.overtimeFrequency === option.value ?
                BrandColors.Brand50 : SemanticColors.Surface2)
              .borderRadius(SemanticRadius.Pill)
              .padding({
                left: SemanticSpacing.Sm,
                right: SemanticSpacing.Sm,
                top: SemanticSpacing.Xs,
                bottom: SemanticSpacing.Xs,
              })
              .border({
                width: 1,
                color: this.offer.overtimeFrequency === option.value ?
                  BrandColors.Brand500 : SemanticColors.Border,
                radius: SemanticRadius.Pill,
              })
              .onClick(() => {
                this.offer.overtimeFrequency = option.value;
              })
          }, (option: { value: OvertimeFrequency; label: string }) => option.value)
        }
        .width('100%')
        .flexWrap(FlexWrap.Wrap)
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Md })

      this.buildFormItem(
        '通勤时间', '分钟', false, 'commuteMinutes',
        this.offer.commuteMinutes > 0 ? this.offer.commuteMinutes.toString() : '30',
        '如：30', InputType.Number
      )
    }
    .width('100%')
    .padding(SemanticSpacing.Lg)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  /** 福利标签选择卡片 */
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

      // 福利标签 - Flex + FlexWrap.Wrap 布局
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.allBenefits, (type: BenefitType) => {
          Text(BenefitTypeLabels[type])
            .fontSize(FontSize.Xs)
            .fontColor(this.selectedBenefits.includes(type) ? BrandColors.Brand500 : SemanticColors.Text2)
            .backgroundColor(this.selectedBenefits.includes(type) ? BrandColors.Brand50 : SemanticColors.Surface2)
            .borderRadius(SemanticRadius.Pill)
            .padding({
              left: SemanticSpacing.Md,
              right: SemanticSpacing.Md,
              top: SemanticSpacing.Sm,
              bottom: SemanticSpacing.Sm,
            })
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
    .padding(SemanticSpacing.Lg)
    .margin({ bottom: SemanticSpacing.Md })
    .backgroundColor(SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
  }

  build() {
    Column() {
      // 基本信息卡片
      this.buildBasicInfoCard()

      // 薪资信息卡片
      this.buildSalaryCard()

      // 工作条件卡片
      this.buildWorkConditionCard()

      // 福利标签选择卡片
      this.buildBenefitCard()
    }
    .width('100%')
  }
}
