/**
 * 简历模板页面
 * 展示和选择各类简历模板
 * 
 * 功能：
 * - 模板分类（全部/技术岗/产品岗/运营岗/管培生）
 * - 模板卡片网格展示
 * - 模板预览和选择
 * - 支持暗黑模式
 * 
 * 设计规范：
 * - 使用鸿蒙设计令牌
 * - 响应式布局
 */

import promptAction from '@ohos.promptAction';
import { Router } from '../utils/Router';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  SuccessColors,
  WarningColors,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration
} from '../constants/design-tokens';

// 模板接口
export interface ResumeTemplate {
  id: string;
  name: string;
  category: string;
  description: string;
  previewColor: string;
  accentColor: string;
  style: 'modern' | 'classic' | 'creative' | 'minimal';
 适用人群: string;
}

// 模板数据
const TEMPLATES: ResumeTemplate[] = [
  {
    id: 'template_1',
    name: '通用模板',
    category: 'all',
    description: '简洁大方，适合大多数岗位申请',
    previewColor: '#FFFFFF',
    accentColor: BrandColors.Brand500,
    style: 'modern',
    适用人群: '适用于应届毕业生及职场人士'
  },
  {
    id: 'template_2',
    name: '技术岗模板',
    category: 'tech',
    description: '突出技术栈和项目经验，适合IT工程师',
    previewColor: '#F0F9FF',
    accentColor: '#3B82F6',
    style: 'modern',
    适用人群: '前端、后端、算法、移动端工程师'
  },
  {
    id: 'template_3',
    name: '产品岗模板',
    category: 'product',
    description: '强调产品思维和项目成果，适合产品经理',
    previewColor: '#FDF4FF',
    accentColor: '#A855F7',
    style: 'creative',
    适用人群: '产品经理、产品运营'
  },
  {
    id: 'template_4',
    name: '运营岗模板',
    category: 'operation',
    description: '突出数据分析和活动策划能力',
    previewColor: '#FFF7ED',
    accentColor: '#F97316',
    style: 'modern',
    适用人群: '用户运营、内容运营、活动运营'
  },
  {
    id: 'template_5',
    name: '管培生模板',
    category: 'trainee',
    description: '展现学习能力和潜力，适合应届生',
    previewColor: '#F0FDF4',
    accentColor: '#22C55E',
    style: 'classic',
    适用人群: '管理培训生、储备干部'
  },
  {
    id: 'template_6',
    name: '经典模板',
    category: 'all',
    description: '传统排版，稳重专业，适合国企外企',
    previewColor: '#FAFAFA',
    accentColor: NeutralColors.Neutral600,
    style: 'classic',
    适用人群: '金融、咨询、国企'
  },
  {
    id: 'template_7',
    name: '创意模板',
    category: 'all',
    description: '设计感强，适合创意类岗位',
    previewColor: '#FDF2F8',
    accentColor: '#EC4899',
    style: 'creative',
    适用人群: '设计、市场、品牌'
  },
  {
    id: 'template_8',
    name: '简约模板',
    category: 'all',
    description: '极简风格，突出核心内容',
    previewColor: '#FAFAFA',
    accentColor: NeutralColors.Neutral700,
    style: 'minimal',
    适用人群: '资深专业人士'
  }
];

// 分类标签
const CATEGORIES: { key: string; label: string }[] = [
  { key: 'all', label: '全部' },
  { key: 'tech', label: '技术岗' },
  { key: 'product', label: '产品岗' },
  { key: 'operation', label: '运营岗' },
  { key: 'trainee', label: '管培生' }
];

// 样式图标映射
const STYLE_ICONS: Record<string, string> = {
  'modern': 'ic_analysis',
  'classic': 'ic_document',
  'creative': 'ic_palette',
  'minimal': 'ic_minimal'
};

@Component
export struct ResumeTemplates {
  // 当前分类
  @State private currentCategory: string = 'all';
  // 选中模板
  @State private selectedTemplate: ResumeTemplate | null = null;
  // 是否显示预览弹窗
  @State private showPreview: boolean = false;
  // 暗黑模式
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  // 获取过滤后的模板列表
  private get filteredTemplates(): ResumeTemplate[] {
    if (this.currentCategory === 'all') {
      return TEMPLATES;
    }
    return TEMPLATES.filter(t => t.category === this.currentCategory || t.category === 'all');
  }

  aboutToAppear() {
    // 注册当前页面
    AppStorage.setOrCreate('currentPage', 'pages/ResumeTemplates');
  }

  build() {
    Column() {
      // 标题栏
      this.buildTitleBar()

      // 分类标签
      this.buildCategoryTabs()

      // 模板网格
      Scroll() {
        Column() {
          Grid() {
            ForEach(this.filteredTemplates, (template: ResumeTemplate) => {
              GridItem() {
                this.buildTemplateCard(template)
              }
            })
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(Spacing.Space4)
          .rowsGap(Spacing.Space4)
          .width('100%')
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }

  /**
   * 构建标题栏
   */
  @Builder
  buildTitleBar() {
    Row() {
      // 返回按钮
      Button() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
      }
      .backgroundColor('transparent')
      .width(40)
      .height(40)
      .onClick(() => {
        Router.back();
      })

      Text('简历模板')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 占位
      Row().width(40)
    }
    .width('100%')
    .height(56)
    .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Sm, right: SemanticSpacing.Sm })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 构建分类标签
   */
  @Builder
  buildCategoryTabs() {
    Scroll() {
      Row() {
        ForEach(CATEGORIES, (category: { key: string; label: string }) => {
          Column() {
            Text(category.label)
              .fontSize(FontSize.Base)
              .fontWeight(this.currentCategory === category.key ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.currentCategory === category.key ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
          .backgroundColor(this.currentCategory === category.key ? BrandColors.Brand500 : 'transparent')
          .borderRadius(SemanticRadius.Pill)
          .onClick(() => {
            animateTo({
              duration: Duration.Fast,
              curve: Curve.EaseInOut
            }, () => {
              this.currentCategory = category.key;
            })
          })
        })
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ top: SemanticSpacing.Md, bottom: SemanticSpacing.Md })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 构建模板卡片
   */
  @Builder
  buildTemplateCard(template: ResumeTemplate) {
    Column() {
      // 模板预览
      Stack() {
        // 预览背景
        Column()
          .width('100%')
          .height(160)
          .backgroundColor(template.previewColor)
          .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })

        // 预览内容模拟
        Column() {
          // 头部
          Column()
            .width(40)
            .height(8)
            .backgroundColor(template.accentColor)
            .borderRadius(4)
            .margin({ bottom: 8 })

          // 姓名
          Column()
            .width(60)
            .height(6)
            .backgroundColor(NeutralColors.Neutral400)
            .borderRadius(3)
            .margin({ bottom: 4 })

          // 联系方式
          Row() {
            Column()
              .width(30)
              .height(4)
              .backgroundColor(NeutralColors.Neutral300)
              .borderRadius(2)
            Column()
              .width(30)
              .height(4)
              .backgroundColor(NeutralColors.Neutral300)
              .borderRadius(2)
              .margin({ left: 8 })
          }
          .margin({ bottom: 12 })

          // 内容块
          ForEach([1, 2, 3], (i: number) => {
            Column() {
              Row() {
                Column()
                  .width(20)
                  .height(5)
                  .backgroundColor(template.accentColor + '60')
                  .borderRadius(2)
                Column()
                  .width('100%')
                  .height(4)
                  .backgroundColor(NeutralColors.Neutral200)
                  .borderRadius(2)
                  .margin({ left: 6 })
              }
              .width('100%')
              .margin({ bottom: 4 })

              Column()
                .width('90%')
                .height(3)
                .backgroundColor(NeutralColors.Neutral200)
                .borderRadius(2)
                .margin({ left: 20, bottom: 2 })

              Column()
                .width('80%')
                .height(3)
                .backgroundColor(NeutralColors.Neutral200)
                .borderRadius(2)
                .margin({ left: 20 })
            }
            .width('100%')
            .padding({ top: 6 })
          })
        }
        .width('85%')
        .padding({ top: 12 })

        // 选中状态
        if (this.selectedTemplate?.id === template.id) {
          Column() {
            Image($r('app.media.ic_check'))
              .width(24)
              .height(24)
              .fillColor(NeutralColors.Neutral0)
          }
          .width(32)
          .height(32)
          .backgroundColor(SuccessColors.Success500)
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .position({ x: '80%', y: 8 })
        }
      }
      .width('100%')
      .clip(true)
      .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
      .border({
        width: 2,
        color: this.selectedTemplate?.id === template.id ? BrandColors.Brand500 : 'transparent',
        radius: SemanticRadius.Component
      })

      // 模板信息
      Column() {
        Row() {
          Text(template.name)
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

          Blank()

          // 风格标签
          Text(this.getStyleLabel(template.style))
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .padding({ left: Spacing.Space2, right: Spacing.Space2, top: 2, bottom: 2 })
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(4)
        }
        .width('100%')
        .margin({ bottom: Spacing.Space1 })

        Text(template.description)
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md, top: Spacing.Space3, bottom: Spacing.Space3 })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius({ bottomLeft: SemanticRadius.Component, bottomRight: SemanticRadius.Component })

      // 使用按钮
      Row() {
        Button() {
          Row() {
            Image($r('app.media.ic_edit'))
              .width(14)
              .height(14)
              .fillColor(NeutralColors.Neutral0)
            Text('使用此模板')
              .fontSize(FontSize.Xs)
              .fontColor(NeutralColors.Neutral0)
              .margin({ left: Spacing.Space1 })
          }
        }
        .height(32)
        .width('100%')
        .backgroundColor(template.accentColor)
        .borderRadius({ bottomLeft: SemanticRadius.Component, bottomRight: SemanticRadius.Component })
        .onClick(() => {
          this.handleUseTemplate(template);
        })
      }
      .width('100%')
      .offset({ y: -1 })
    }
    .width('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .borderRadius(SemanticRadius.Component)
    .shadow({
      radius: 8,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
    .onClick(() => {
      this.selectedTemplate = template;
    })
  }

  /**
   * 获取样式标签
   */
  private getStyleLabel(style: string): string {
    const labels: Record<string, string> = {
      'modern': '现代',
      'classic': '经典',
      'creative': '创意',
      'minimal': '简约'
    };
    return labels[style] || style;
  }

  /**
   * 使用模板
   */
  private handleUseTemplate(template: ResumeTemplate): void {
    // 保存选中的模板到存储
    try {
      const storage = Storage.getInstance();
      storage.setObject('selected_template', template);
      
      promptAction.showToast({
        message: `已选择「${template.name}」，即将跳转到创建页面`,
        duration: 2000
      });

      // 跳转到简历创建引导页
      setTimeout(() => {
        Router.push('pages/ResumeGuide', { templateId: template.id });
      }, 1500);
    } catch (error) {
      console.error('[ResumeTemplates] Save template failed:', error);
      promptAction.showToast({
        message: '选择失败，请重试',
        duration: 1500
      });
    }
  }
}

export default ResumeTemplates;
