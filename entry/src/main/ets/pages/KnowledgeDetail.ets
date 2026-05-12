import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
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

interface ArticleDetail {
  id: string;
  title: string;
  category: string;
  publishTime: string;
  readCount: number;
  content: string;
  author: string;
}

@Entry
@Component
struct KnowledgeDetail {
  @State article: ArticleDetail | null = null;
  @State isFavorited: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['id']) {
      this.article = this.getArticleById(params['id']);
    }
    if (!this.article) {
      // 默认显示第一篇文章
      this.article = this.getArticleById('1');
    }
  }

  private getArticleById(id: string): ArticleDetail {
    const articles: Record<string, ArticleDetail> = {
      '1': {
        id: '1',
        title: '如何写一份好简历',
        category: '简历技巧',
        publishTime: '2025-01-15',
        readCount: 12580,
        author: '一职搭子编辑部',
        content: '一份优秀的简历是求职成功的第一步。以下是几个关键要点：\n\n一、简历结构\n\n1. 个人信息：包括姓名、联系方式、求职意向等基本信息，保持简洁明了。\n\n2. 教育背景：按时间倒序排列，突出与目标岗位相关的学历和专业。\n\n3. 工作经历：使用 STAR 法则描述工作成果，量化你的成就。\n\n4. 技能特长：列出与目标岗位匹配的核心技能。\n\n二、内容优化\n\n1. 关键词匹配：仔细研究目标岗位的 JD，在简历中合理嵌入关键词。\n\n2. 量化成果：用数据说话，比如"提升了30%的转化率"比"提升了转化率"更有说服力。\n\n3. 精简表达：每段描述控制在2-3行以内，HR 平均浏览一份简历只有6-10秒。\n\n三、注意事项\n\n1. 排版整洁：使用统一的字体和格式，避免花哨的设计。\n\n2. 无错别字：仔细校对，错别字会严重影响专业形象。\n\n3. 适度定制：针对不同岗位调整简历重点，但不要过度夸大。'
      },
      '2': {
        id: '2',
        title: '面试常见问题解答',
        category: '面试攻略',
        publishTime: '2025-01-12',
        readCount: 9860,
        author: '一职搭子编辑部',
        content: '面试是求职过程中最关键的环节之一。本文整理了面试中最高频的问题及参考回答思路。\n\n一、自我介绍\n\n建议使用"现在-过去-未来"框架：\n- 现在：简要介绍当前状态\n- 过去：强调相关经验和成就\n- 未来：说明为什么这个岗位适合你\n\n二、优缺点问题\n\n优点要具体且有证据支撑，缺点要真实但不是致命缺陷，最重要的是说明你正在如何改进。\n\n三、为什么选择我们公司\n\n提前研究公司文化、产品和发展方向，结合自身职业规划给出真诚的回答。\n\n四、职业规划\n\n展示你的职业目标与公司发展方向的一致性，同时体现你的进取心和学习能力。\n\n五、薪资期望\n\n提前了解市场行情，给出合理区间，同时表达灵活态度。'
      },
      '3': {
        id: '3',
        title: '产品经理职业发展路径',
        category: '职场法则',
        publishTime: '2025-01-10',
        readCount: 15230,
        author: '一职搭子编辑部',
        content: '产品经理是互联网行业最热门的岗位之一，了解其职业发展路径对求职者至关重要。\n\n一、入门阶段（0-2年）\n\n在这个阶段，重点是打好基础：学习需求分析、原型设计、项目管理等核心技能。建议多参与实际项目，积累经验。\n\n二、成长阶段（2-5年）\n\n开始独立负责产品模块或完整产品线，培养商业思维和用户洞察力。这个阶段需要从执行者转变为思考者。\n\n三、成熟阶段（5-8年）\n\n负责产品战略规划，带领产品团队，与业务线深度协同。需要具备跨部门沟通和资源整合能力。\n\n四、高级阶段（8年以上）\n\n产品总监或VP级别，负责公司产品矩阵的整体战略，参与公司级决策。\n\n五、关键能力培养\n\n1. 数据分析能力\n2. 用户研究能力\n3. 技术理解力\n4. 商业敏感度\n5. 沟通协调能力'
      },
      '4': {
        id: '4',
        title: '技术面试算法题精选',
        category: '面试攻略',
        publishTime: '2025-01-08',
        readCount: 25680,
        author: '一职搭子编辑部',
        content: '技术面试中算法题是必考环节，本文精选了几道高频算法题及解题思路。\n\n一、数组类\n\n1. 两数之和：使用哈希表可以将时间复杂度从 O(n^2) 降到 O(n)。\n\n2. 三数之和：排序 + 双指针，注意去重处理。\n\n二、链表类\n\n1. 反转链表：迭代法和递归法都要掌握。\n\n2. 环形链表：快慢指针法，快指针每次走两步，慢指针每次走一步。\n\n三、树类\n\n1. 二叉树遍历：前序、中序、后序遍历的递归和迭代实现。\n\n2. 层序遍历：使用队列实现 BFS。\n\n四、动态规划\n\n1. 爬楼梯问题：经典入门 DP 题。\n\n2. 最长公共子序列：理解状态转移方程。\n\n五、面试建议\n\n1. 先理清思路再写代码\n2. 注意边界条件处理\n3. 主动分析时间和空间复杂度\n4. 写完后进行代码走查'
      },
      '5': {
        id: '5',
        title: '如何谈薪资',
        category: '职场法则',
        publishTime: '2025-01-05',
        readCount: 8760,
        author: '一职搭子编辑部',
        content: '薪资谈判是求职过程中最敏感也最重要的环节之一。\n\n一、做好市场调研\n\n在谈判之前，了解目标岗位在市场上的薪资水平。可以通过招聘网站、行业报告、同行交流等渠道获取信息。\n\n二、确定自己的底线\n\n考虑生活成本、职业发展空间、公司福利等因素，确定你能接受的最低薪资。\n\n三、谈判技巧\n\n1. 不要先亮底牌：让对方先给出薪资范围\n2. 给出区间而非具体数字：提供灵活空间\n3. 强调价值而非需求：谈论你能为公司带来的价值\n4. 考虑整体薪酬包：base、奖金、期权、福利都要考虑\n\n四、常见误区\n\n1. 过早讨论薪资\n2. 接受第一次报价\n3. 只看月薪不看总包\n4. 用个人困难作为加薪理由'
      },
      '6': {
        id: '6',
        title: '互联网公司职级体系解读',
        category: '行业动态',
        publishTime: '2025-01-03',
        readCount: 6540,
        author: '一职搭子编辑部',
        content: '了解互联网公司的职级体系，对职业规划至关重要。\n\n一、主流大厂职级对比\n\n1. 阿里巴巴：P4-P14，P7 是分水岭（技术专家）\n2. 腾讯：T1-T11，T8-T9 是高级工程师\n3. 字节跳动：1-1 到 5-2，2-2 是关键节点\n4. 美团：L4-L9，L6 是资深级别\n\n二、晋升要素\n\n1. 业务影响力：你负责的工作对业务的实际贡献\n2. 技术深度：在专业领域的技术水平\n3. 团队贡献：对团队的培养和带动作用\n4. 创新能力：技术方案和业务模式的创新\n\n三、薪资范围参考\n\n不同职级对应的薪资范围差异很大，受公司、城市、业务线等因素影响。一般来说，大厂高级工程师年薪在50-100万区间。\n\n四、职业建议\n\n1. 不要只盯着职级数字\n2. 选择比努力更重要\n3. 持续学习保持竞争力\n4. 建立个人技术品牌'
      }
    };
    return articles[id] || articles['1'];
  }

  formatReadCount(count: number): string {
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + 'w';
    }
    return count.toString();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Image($r('app.media.ic_arrow_right'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text1)
            .rotate({ angle: 180 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text('文章详情')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位保持标题居中
        Column()
          .width(40)
          .height(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: Spacing.Space2, right: SemanticSpacing.Lg })
      .backgroundColor(NeutralColors.Neutral0)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      if (this.article) {
        // 文章内容
        Scroll() {
          Column() {
            // 文章标题
            Text(this.article.title)
              .fontSize(FontSize.Xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(SemanticColors.Text1)
              .width('100%')
              .margin({ top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })

            // 标签信息
            Row() {
              Text(this.article.category)
                .fontSize(FontSize.Xs)
                .fontColor(BrandColors.Brand500)
                .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                .backgroundColor(BrandColors.Brand50)
                .borderRadius(SemanticRadius.Pill)

              Text(this.article.author)
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text3)
                .margin({ left: Spacing.Space4 })

              Blank()

              Text('阅读 ' + this.formatReadCount(this.article.readCount))
                .fontSize(FontSize.Xs)
                .fontColor(SemanticColors.Text4)
            }
            .width('100%')
            .margin({ bottom: Spacing.Space4 })

            // 发布时间
            Text(this.article.publishTime)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text4)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            Divider()

            // 文章正文
            Text(this.article.content)
              .fontSize(FontSize.Base)
              .fontColor(SemanticColors.Text1)
              .lineHeight(28)
              .width('100%')
              .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })
          }
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        }
        .layoutWeight(1)
        .backgroundColor(NeutralColors.Neutral50)

        // 底部操作栏
        Row() {
          // 收藏按钮
          Row() {
            Column() {
              Image($r('app.media.ic_favorite'))
                .width(ComponentSizes.Icon.Lg)
                .height(ComponentSizes.Icon.Lg)
                .fillColor(this.isFavorited ? WarningColors.Warning500 : SemanticColors.Text3)
            }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)

            Text(this.isFavorited ? '已收藏' : '收藏')
              .fontSize(FontSize.Xs)
              .fontColor(this.isFavorited ? WarningColors.Warning500 : SemanticColors.Text3)
          }
          .layoutWeight(1)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.isFavorited = !this.isFavorited;
            promptAction.showToast({
              message: this.isFavorited ? '已收藏' : '已取消收藏'
            });
          })

          Divider()
            .vertical(true)
            .height(24)
            .color(NeutralColors.Neutral200)

          // 分享按钮
          Row() {
            Column() {
              Image($r('app.media.ic_share'))
                .width(ComponentSizes.Icon.Lg)
                .height(ComponentSizes.Icon.Lg)
                .fillColor(SemanticColors.Text3)
            }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)

            Text('分享')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
          }
          .layoutWeight(1)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            promptAction.showToast({ message: '分享链接已复制' });
          })
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .backgroundColor(NeutralColors.Neutral0)
        .border({ width: { top: 1 }, color: NeutralColors.Neutral200 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }
}
