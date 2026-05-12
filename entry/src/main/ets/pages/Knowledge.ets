import router from '@ohos.router';
import { ApiService } from '../services/ApiService';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';

interface KnowledgeItem {
  id: string;
  title: string;
  category: string;
  summary: string;
  readCount: number;
  updateTime: string;
}

@Component
export struct KnowledgePage {
  @State knowledgeList: KnowledgeItem[] = [];
  @State selectedCategory: string = '全部';
  @State searchText: string = '';
  @State isSearchMode: boolean = false;
  @State isLoading: boolean = false;

  private categories: string[] = ['全部', '简历技巧', '面试攻略', '职场法则', '行业动态'];
  private apiService: ApiService = ApiService.getInstance();

  aboutToAppear() {
    this.loadKnowledge();
  }

  async loadKnowledge(): Promise<void> {
    this.isLoading = true;
    try {
      const response = await this.apiService.get<KnowledgeItem[]>('/knowledge/list');
      if (response.success && response.data) {
        this.knowledgeList = response.data;
      } else {
        this.knowledgeList = this.getDefaultKnowledge();
      }
    } catch (error) {
      this.knowledgeList = this.getDefaultKnowledge();
    } finally {
      this.isLoading = false;
    }
  }

  private getDefaultKnowledge(): KnowledgeItem[] {
    return [
      { id: '1', title: '如何写一份好简历', category: '简历技巧', summary: '从简历结构、内容优化、关键词匹配等方面全面提升简历质量', readCount: 12580, updateTime: '2025-01-15' },
      { id: '2', title: '面试常见问题解答', category: '面试攻略', summary: '深度解析面试高频问题，提供参考答案和答题思路', readCount: 9860, updateTime: '2025-01-12' },
      { id: '3', title: '产品经理职业发展路径', category: '职场法则', summary: '帮助职场新人快速适应环境，建立良好的职业形象', readCount: 15230, updateTime: '2025-01-10' },
      { id: '4', title: '技术面试算法题精选', category: '面试攻略', summary: '最新互联网各岗位薪资水平和发展趋势分析', readCount: 25680, updateTime: '2025-01-08' },
      { id: '5', title: '如何谈薪资', category: '职场法则', summary: '掌握STAR法则，让工作经历描述更加具体和有说服力', readCount: 8760, updateTime: '2025-01-05' },
      { id: '6', title: '互联网公司职级体系解读', category: '行业动态', summary: '视频面试的注意事项、技巧和常见问题处理', readCount: 6540, updateTime: '2025-01-03' }
    ];
  }

  getFilteredList(): KnowledgeItem[] {
    let list = this.knowledgeList;

    if (this.selectedCategory !== '全部') {
      list = list.filter(item => item.category === this.selectedCategory);
    }

    if (this.searchText) {
      list = list.filter(item =>
        item.title.includes(this.searchText) ||
        item.summary.includes(this.searchText)
      );
    }

    return list;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('知识库')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      // 搜索栏
      Row() {
        Column() {
          Image($r('app.media.ic_search'))
            .width(18)
            .height(18)
            .fillColor(SemanticColors.Text4)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)

        TextInput({ placeholder: '搜索知识库', text: this.searchText })
          .layoutWeight(1)
          .height(36)
          .backgroundColor('transparent')
          .placeholderColor(SemanticColors.Text4)
          .placeholderFont({ size: FontSize.Sm })
          .fontColor(SemanticColors.Text1)
          .fontSize(FontSize.Sm)
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('100%')
      .padding({ left: Spacing.Space4, right: Spacing.Space4 })
      .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space4, bottom: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral100)
      .borderRadius(SemanticRadius.Pill)

      // 分类标签
      Scroll() {
        Row() {
          ForEach(this.categories, (category: string) => {
            Text(category)
              .fontSize(FontSize.Sm)
              .fontWeight(this.selectedCategory === category ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.selectedCategory === category ? NeutralColors.Neutral0 : SemanticColors.Text2)
              .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: Spacing.Space3, bottom: Spacing.Space3 })
              .backgroundColor(this.selectedCategory === category ? BrandColors.Brand500 : NeutralColors.Neutral100)
              .borderRadius(SemanticRadius.Pill)
              .margin({ right: Spacing.Space3 })
              .onClick(() => {
                this.selectedCategory = category;
              })
          })
        }
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .backgroundColor(NeutralColors.Neutral0)
      .padding({ top: Spacing.Space3, bottom: Spacing.Space3 })

      // 内容列表
      List() {
        ForEach(this.getFilteredList(), (item: KnowledgeItem) => {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text(item.title)
                    .fontSize(FontSize.Sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(SemanticColors.Text1)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(item.summary)
                    .fontSize(FontSize.Xs)
                    .fontColor(SemanticColors.Text2)
                    .margin({ top: Spacing.Space3 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .lineHeight(18)

                  Row() {
                    Text(item.category)
                      .fontSize(FontSize.Xs)
                      .fontColor(BrandColors.Brand500)
                      .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                      .backgroundColor(BrandColors.Brand50)
                      .borderRadius(SemanticRadius.Pill)

                    Blank()

                    Text('阅读 ' + this.formatReadCount(item.readCount))
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text4)

                    Text(' | ')
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text4)

                    Text(item.updateTime)
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text4)
                  }
                  .margin({ top: Spacing.Space4 })
                }
                .layoutWeight(1)
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(NeutralColors.Neutral0)
            .borderRadius(SemanticRadius.Component)
            .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
            .shadow({
              radius: 4,
              color: 'rgba(0, 0, 0, 0.02)',
              offsetY: 1
            })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/KnowledgeDetail',
                params: { id: item.id }
              });
            })
          }
        })
      }
      .layoutWeight(1)
      .padding({ top: Spacing.Space4 })
      .backgroundColor(NeutralColors.Neutral50)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  formatReadCount(count: number): string {
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + 'w';
    }
    return count.toString();
  }
}
