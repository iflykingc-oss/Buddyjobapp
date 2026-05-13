import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import {
  submitFeedback,
  getFAQs,
  FeedbackType,
  FeedbackTypeLabels,
  FAQCategory,
  FAQCategoryLabels,
  ContactInfo,
  type FAQItem,
  type FeedbackData
} from '../../services/FeedbackService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  SuccessColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight
} from '../../constants/design-tokens';

@Component
export struct HelpFeedbackPage {
  // FAQ 相关状态
  @State faqList: FAQItem[] = [];
  @State expandedFAQId: string = '';
  @State selectedCategory: FAQCategory | 'all' = 'all';
  @State isLoadingFAQs: boolean = true;

  // 反馈表单状态
  @State feedbackType: FeedbackType = FeedbackType.ISSUE;
  @State feedbackTitle: string = '';
  @State feedbackContent: string = '';
  @State feedbackContact: string = '';
  @State isSubmitting: boolean = false;
  @State showFeedbackForm: boolean = false;

  // 分类标签
  private categories: Array<{ key: FAQCategory | 'all'; label: string }> = [
    { key: 'all', label: '全部' },
    { key: FAQCategory.ACCOUNT, label: FAQCategoryLabels[FAQCategory.ACCOUNT] },
    { key: FAQCategory.RESUME, label: FAQCategoryLabels[FAQCategory.RESUME] },
    { key: FAQCategory.ASSESSMENT, label: FAQCategoryLabels[FAQCategory.ASSESSMENT] },
    { key: FAQCategory.PAYMENT, label: FAQCategoryLabels[FAQCategory.PAYMENT] },
    { key: FAQCategory.OTHER, label: FAQCategoryLabels[FAQCategory.OTHER] }
  ];

  aboutToAppear() {
    this.loadFAQs();
  }

  async loadFAQs() {
    this.isLoadingFAQs = true;
    try {
      this.faqList = await getFAQs();
    } catch (error) {
      console.error('Failed to load FAQs:', error);
    } finally {
      this.isLoadingFAQs = false;
    }
  }

  get filteredFAQs(): FAQItem[] {
    if (this.selectedCategory === 'all') {
      return this.faqList;
    }
    return this.faqList.filter(item => item.category === this.selectedCategory);
  }

  async handleSubmitFeedback() {
    // 表单验证
    if (!this.feedbackTitle.trim()) {
      promptAction.showToast({ message: '请输入反馈标题' });
      return;
    }
    if (!this.feedbackContent.trim()) {
      promptAction.showToast({ message: '请输入反馈内容' });
      return;
    }

    this.isSubmitting = true;
    try {
      const data: FeedbackData = {
        type: this.feedbackType,
        title: this.feedbackTitle.trim(),
        content: this.feedbackContent.trim(),
        contact: this.feedbackContact.trim() || undefined
      };

      const success = await submitFeedback(data);
      if (success) {
        promptAction.showToast({ message: '反馈提交成功，感谢您的建议！' });
        // 重置表单
        this.feedbackTitle = '';
        this.feedbackContent = '';
        this.feedbackContact = '';
        this.feedbackType = FeedbackType.ISSUE;
        this.showFeedbackForm = false;
      } else {
        promptAction.showToast({ message: '提交失败，请稍后重试' });
      }
    } catch (error) {
      console.error('Submit feedback error:', error);
      promptAction.showToast({ message: '提交失败，请稍后重试' });
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      this.HeaderBar()

      // 内容区域
      Scroll() {
        Column() {
          // FAQ 区域
          this.FAQSection()

          // 反馈表单区域
          this.FeedbackSection()

          // 联系方式区域
          this.ContactSection()
        }
        .width('100%')
        .padding({ bottom: SemanticSpacing.Xxl })
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  @Builder
  HeaderBar() {
    Row() {
      // 返回按钮
      Row() {
        Image($r('app.media.media_ic_arrow_left'))
          .width(24)
          .height(24)
          .fillColor(SemanticColors.Text1)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        router.back();
      })

      // 标题
      Text('帮助与反馈')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位，保持标题居中
      Blank()
        .width(40)
    }
    .width('100%')
    .height(56)
    .padding({ left: Spacing.Space3, right: Spacing.Space3 })
    .backgroundColor(NeutralColors.Neutral0)
  }

  @Builder
  FAQSection() {
    Column() {
      // FAQ 标题
      Row() {
        Text('常见问题')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)

        Blank()

        Text(`共 ${this.filteredFAQs.length} 条`)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text3)
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Lg })

      // 分类标签
      Scroll() {
        Row() {
          ForEach(this.categories, (category: { key: FAQCategory | 'all'; label: string }) => {
            Text(category.label)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedCategory === category.key ? NeutralColors.Neutral0 : SemanticColors.Text2)
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
              .backgroundColor(this.selectedCategory === category.key ? BrandColors.Brand500 : NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Pill)
              .margin({ right: Spacing.Space3 })
              .onClick(() => {
                this.selectedCategory = category.key;
              })
          })
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Horizontal)
      .margin({ bottom: SemanticSpacing.Lg })

      // FAQ 列表
      if (this.isLoadingFAQs) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(BrandColors.Brand500)
          Text('加载中...')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
            .margin({ top: Spacing.Space3 })
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
      } else if (this.filteredFAQs.length === 0) {
        Column() {
          Text('暂无相关问题')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text3)
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
      } else {
        ForEach(this.filteredFAQs, (faq: FAQItem) => {
          this.FAQItem(faq)
        })
      }
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .padding(SemanticSpacing.Lg)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  FAQItem(faq: FAQItem) {
    Column() {
      // 问题标题（可点击展开）
      Row() {
        Text(faq.question)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .maxLines(this.expandedFAQId === faq.id ? undefined : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Image(this.expandedFAQId === faq.id ? $r('app.media.media_ic_arrow_up') : $r('app.media.media_ic_arrow_down'))
          .width(16)
          .height(16)
          .fillColor(SemanticColors.Text3)
          .margin({ left: Spacing.Space3 })
      }
      .width('100%')
      .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
      .onClick(() => {
        this.expandedFAQId = this.expandedFAQId === faq.id ? '' : faq.id;
      })

      // 答案内容（展开时显示）
      if (this.expandedFAQId === faq.id) {
        Text(faq.answer)
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .lineHeight(22)
          .width('100%')
          .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })
          .backgroundColor(NeutralColors.Neutral50)
          .padding(Spacing.Space4)
          .borderRadius(SemanticRadius.Control)
          .margin({ top: Spacing.Space2 })
      }

      Divider()
        .margin({ top: Spacing.Space3 })
        .color(NeutralColors.Neutral100)
    }
    .width('100%')
  }

  @Builder
  FeedbackSection() {
    Column() {
      // 反馈区域标题
      Row() {
        Text('意见反馈')
          .fontSize(FontSize.Lg)
          .fontWeight(FontWeight.Medium)
          .fontColor(SemanticColors.Text1)

        Blank()

        // 展开/收起按钮
        Text(this.showFeedbackForm ? '收起' : '填写反馈')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .onClick(() => {
            this.showFeedbackForm = !this.showFeedbackForm;
          })
      }
      .width('100%')
      .margin({ bottom: this.showFeedbackForm ? SemanticSpacing.Lg : 0 })

      if (this.showFeedbackForm) {
        // 反馈类型选择
        Text('反馈类型')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width('100%')
          .margin({ bottom: Spacing.Space3 })

        Row() {
          ForEach([
            FeedbackType.ISSUE,
            FeedbackType.SUGGESTION,
            FeedbackType.OTHER
          ] as FeedbackType[], (type: FeedbackType) => {
            Text(FeedbackTypeLabels[type])
              .fontSize(FontSize.Sm)
              .fontColor(this.feedbackType === type ? BrandColors.Brand500 : SemanticColors.Text2)
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
              .backgroundColor(this.feedbackType === type ? BrandColors.Brand50 : NeutralColors.Neutral50)
              .borderRadius(SemanticRadius.Control)
              .border({
                width: 1,
                color: this.feedbackType === type ? BrandColors.Brand500 : NeutralColors.Neutral200
              })
              .margin({ right: Spacing.Space3 })
              .onClick(() => {
                this.feedbackType = type;
              })
          })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

        // 标题输入
        Text('标题')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width('100%')
          .margin({ bottom: Spacing.Space3 })

        TextInput({ placeholder: '请简要描述您的问题或建议', text: this.feedbackTitle })
          .width('100%')
          .height(44)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .fontSize(FontSize.Sm)
          .maxLength(50)
          .onChange((value: string) => {
            this.feedbackTitle = value;
          })

        Text(`${this.feedbackTitle.length}/50`)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text4)
          .width('100%')
          .textAlign(TextAlign.End)
          .margin({ top: Spacing.Space2, bottom: SemanticSpacing.Lg })

        // 内容输入
        Text('详细描述')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width('100%')
          .margin({ bottom: Spacing.Space3 })

        TextArea({ placeholder: '请详细描述您遇到的问题或建议，我们会认真阅读每一条反馈...', text: this.feedbackContent })
          .width('100%')
          .height(120)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .fontSize(FontSize.Sm)
          .maxLength(500)
          .onChange((value: string) => {
            this.feedbackContent = value;
          })

        Text(`${this.feedbackContent.length}/500`)
          .fontSize(FontSize.Xs)
          .fontColor(SemanticColors.Text4)
          .width('100%')
          .textAlign(TextAlign.End)
          .margin({ top: Spacing.Space2, bottom: SemanticSpacing.Lg })

        // 联系方式（可选）
        Text('联系方式（选填）')
          .fontSize(FontSize.Sm)
          .fontColor(SemanticColors.Text2)
          .width('100%')
          .margin({ bottom: Spacing.Space3 })

        TextInput({ placeholder: '手机号或邮箱，方便我们回复您', text: this.feedbackContact })
          .width('100%')
          .height(44)
          .backgroundColor(NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Control)
          .fontSize(FontSize.Sm)
          .maxLength(50)
          .onChange((value: string) => {
            this.feedbackContact = value;
          })
          .margin({ bottom: SemanticSpacing.Lg })

        // 提交按钮
        Button(this.isSubmitting ? '提交中...' : '提交反馈')
          .width('100%')
          .height(48)
          .backgroundColor(this.isSubmitting ? NeutralColors.Neutral300 : BrandColors.Brand500)
          .fontSize(FontSize.Base)
          .fontColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Control)
          .enabled(!this.isSubmitting)
          .onClick(() => {
            this.handleSubmitFeedback();
          })
      }
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .padding(SemanticSpacing.Lg)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  ContactSection() {
    Column() {
      Text('联系我们')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Medium)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      // 客服电话
      Row() {
        Column() {
          Image($r('app.media.media_ic_phone'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)
        }
        .width(40)
        .height(40)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .margin({ right: SemanticSpacing.Lg })

        Column() {
          Text('客服电话')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)

          Text(ContactInfo.phone)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.media_ic_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(SemanticColors.Text4)
      }
      .width('100%')
      .padding(Spacing.Space4)
      .backgroundColor(NeutralColors.Neutral50)
      .borderRadius(SemanticRadius.Control)
      .margin({ bottom: Spacing.Space3 })

      // 客服邮箱
      Row() {
        Column() {
          Image($r('app.media.media_ic_email'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)
        }
        .width(40)
        .height(40)
        .backgroundColor(BrandColors.Brand50)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .margin({ right: SemanticSpacing.Lg })

        Column() {
          Text('客服邮箱')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)

          Text(ContactInfo.email)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.media_ic_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(SemanticColors.Text4)
      }
      .width('100%')
      .padding(Spacing.Space4)
      .backgroundColor(NeutralColors.Neutral50)
      .borderRadius(SemanticRadius.Control)
      .margin({ bottom: Spacing.Space3 })

      // 工作时间
      Row() {
        Column() {
          Image($r('app.media.media_ic_time'))
            .width(24)
            .height(24)
            .fillColor(SuccessColors.Success500)
        }
        .width(40)
        .height(40)
        .backgroundColor(SuccessColors.Success50)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .margin({ right: SemanticSpacing.Lg })

        Column() {
          Text('工作时间')
            .fontSize(FontSize.Sm)
            .fontColor(SemanticColors.Text2)

          Text(ContactInfo.workHours)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(SemanticColors.Text1)
            .margin({ top: Spacing.Space2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(Spacing.Space4)
      .backgroundColor(NeutralColors.Neutral50)
      .borderRadius(SemanticRadius.Control)
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .padding(SemanticSpacing.Lg)
    .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }
}
