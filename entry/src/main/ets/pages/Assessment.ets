import { Assessment, Question, AssessmentResult, DimensionScore } from '../models/Assessment';
import { ApiService } from '../services/ApiService';
import { HistoryService } from '../services/HistoryService';
import { PageStateSync, AssessmentPageState } from '../utils/distributed';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';

@Component
export struct AssessmentPage {
  @State assessmentList: Assessment[] = [];
  @State currentAssessment: Assessment | null = null;
  @State currentQuestionIndex: number = 0;
  @State answers: Record<string, string | string[]> = {};
  @State result: AssessmentResult | null = null;
  @State isLoading: boolean = false;
  @State isSubmitting: boolean = false;
  @State isContinueRestore: boolean = false;
  @State showContinuePrompt: boolean = false;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  private apiService: ApiService = ApiService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private pageStateSync: PageStateSync = new PageStateSync('pages/Assessment');

  aboutToAppear() {
    // 注册当前页面
    AppStorage.setOrCreate('currentPage', 'pages/Assessment');
    
    // 检查是否是跨设备流转恢复
    this.checkContinueRestore();
    
    // 加载测评列表
    this.loadAssessments();
    
    // 开始自动同步页面状态
    this.pageStateSync.startAutoSync(() => this.getCurrentState());
    
    // 监听跨设备流转恢复事件
    const eventHub = getContext(this).eventHub;
    eventHub.on('onContinueRestore', (data) => {
      this.handleContinueRestore(data);
    });
  }

  aboutToDisappear() {
    // 停止自动同步
    this.pageStateSync.stopAutoSync();
    
    // 移除事件监听
    const eventHub = getContext(this).eventHub;
    eventHub.off('onContinueRestore');
  }

  /**
   * 检查是否是跨设备流转恢复
   */
  private checkContinueRestore(): void {
    const isContinueRestore = AppStorage.get<boolean>('isContinueRestore') || false;
    const continueData = AppStorage.get<Record<string, any>>('continueData');
    
    if (isContinueRestore && continueData) {
      this.handleContinueRestore(continueData);
    }
  }

  /**
   * 处理跨设备流转恢复
   */
  private handleContinueRestore(data: Record<string, any>): void {
    console.log('[AssessmentPage] Handling continue restore:', JSON.stringify(data));
    
    if (data.pageUrl === 'pages/Assessment' && data.pageState) {
      const state = data.pageState as AssessmentPageState;
      
      this.isContinueRestore = true;
      this.showContinuePrompt = true;
      
      // 恢复测评列表
      if (state.assessmentList && state.assessmentList.length > 0) {
        this.assessmentList = state.assessmentList;
      }
      
      // 恢复当前测评
      if (state.currentAssessmentId) {
        const assessment = this.assessmentList.find(a => a.id === state.currentAssessmentId);
        if (assessment) {
          this.currentAssessment = assessment;
          this.currentQuestionIndex = state.currentQuestionIndex || 0;
          this.answers = state.answers || {};
          
          // 恢复结果状态
          if (state.showResult && state.result) {
            this.result = state.result;
          }
        }
      }
      
      // 更新全局页面状态
      this.updateGlobalPageState();
      
      console.log('[AssessmentPage] State restored successfully');
    }
  }

  /**
   * 获取当前页面状态
   */
  private getCurrentState(): AssessmentPageState {
    return {
      currentAssessmentId: this.currentAssessment?.id || '',
      currentQuestionIndex: this.currentQuestionIndex,
      answers: this.answers,
      assessmentList: this.assessmentList,
      showResult: this.result !== null,
      result: this.result
    };
  }

  /**
   * 更新全局页面状态（用于跨设备流转）
   */
  private updateGlobalPageState(): void {
    const pageState = this.getCurrentState();
    AppStorage.setOrCreate('currentPageState', pageState);
    
    // 立即同步到分布式数据对象
    this.pageStateSync.syncState(pageState);
  }

  async loadAssessments(): Promise<void> {
    this.isLoading = true;
    try {
      const response = await this.apiService.get<Assessment[]>('/assessments/list');
      if (response.success && response.data) {
        this.assessmentList = response.data;
      } else {
        // 使用默认数据作为 fallback
        this.assessmentList = this.getDefaultAssessments();
      }
    } catch (error) {
      // 使用默认数据作为 fallback
      this.assessmentList = this.getDefaultAssessments();
    } finally {
      this.isLoading = false;
    }
  }

  // 添加默认数据方法
  private getDefaultAssessments(): Assessment[] {
    return [
      {
        id: '1',
        title: '职业性格测试',
        description: '了解您的职业性格特点，帮助您找到最适合的工作环境',
        type: 'personality',
        questions: this.generateSampleQuestions('personality'),
        duration: 10,
        status: 'not_started'
      },
      {
        id: '2',
        title: '职业价值观测评',
        description: '识别您最看重的职业因素，明确职业发展方向',
        type: 'value',
        questions: this.generateSampleQuestions('value'),
        duration: 8,
        status: 'not_started'
      },
      {
        id: '3',
        title: '技能水平测试',
        description: '评估您的职业技能水平，找到提升方向',
        type: 'skill',
        questions: this.generateSampleQuestions('skill'),
        duration: 15,
        status: 'not_started'
      }
    ];
  }

  generateSampleQuestions(type: string): Question[] {
    const questions: Question[] = [];
    for (let i = 0; i < 5; i++) {
      questions.push({
        id: `${type}_q_${i}`,
        type: 'single',
        title: this.getQuestionTitle(type, i),
        options: [
          { id: 'a', text: this.getOptionText(type, i, 0) },
          { id: 'b', text: this.getOptionText(type, i, 1) },
          { id: 'c', text: this.getOptionText(type, i, 2) },
          { id: 'd', text: this.getOptionText(type, i, 3) }
        ],
        required: true
      });
    }
    return questions;
  }

  getQuestionTitle(type: string, index: number): string {
    const titles: Record<string, string[]> = {
      personality: [
        '在团队项目中，您通常扮演什么角色？',
        '面对压力时，您的第一反应是什么？',
        '您更喜欢什么样的工作方式？',
        '在与他人沟通时，您更注重什么？',
        '您认为成功的关键因素是什么？'
      ],
      value: [
        '您最看重工作的哪个方面？',
        '如果必须选择，您更倾向于？',
        '什么样的工作环境让您最舒适？',
        '您认为职业发展中最重要的是？',
        '什么样的成就会让您最有成就感？'
      ],
      skill: [
        '您对数据分析的掌握程度如何？',
        '您的项目管理能力如何？',
        '您如何描述您的沟通能力？',
        '您的学习能力属于什么水平？',
        '您的问题解决能力如何？'
      ]
    };
    return titles[type]?.[index] || '问题 ' + (index + 1);
  }

  getOptionText(type: string, qIndex: number, oIndex: number): string {
    const options: Record<string, string[][]> = {
      personality: [
        ['领导者，制定方向和计划', '执行者，完成具体任务', '协调者，促进团队合作', '创新者，提出新想法'],
        ['冷静分析问题', '立即采取行动', '寻求他人建议', '暂时回避压力'],
        ['独立完成工作', '与团队协作', '灵活切换', '专注于细节'],
        ['逻辑和事实', '情感和感受', '双赢结果', '效率和时间'],
        ['努力和坚持', '机遇和环境', '人际关系', '专业技能']
      ],
      value: [
        ['薪资待遇', '个人成长', '工作氛围', '工作稳定性'],
        ['高压高回报', '平衡生活', '快速晋升', '稳定发展'],
        ['开放自由的办公环境', '结构化规范的团队', '灵活远程办公', '充满挑战的创业环境'],
        ['专业能力提升', '管理经验积累', '行业资源拓展', '个人品牌建立'],
        ['获得高额奖金', '得到认可和尊重', '帮助他人成长', '创造独特价值']
      ],
      skill: [
        ['精通，能够独立完成复杂分析', '熟练，能够处理常规任务', '了解基础概念', '完全不了解'],
        ['精通PMP认证', '有项目经验', '了解基本概念', '没有经验'],
        ['非常擅长', '良好', '一般', '需要提升'],
        ['非常强，能快速掌握新知识', '较强，学习效率高', '一般，需要时间', '较弱'],
        ['非常强', '良好', '一般', '较弱']
      ]
    };
    return options[type]?.[qIndex]?.[oIndex] || '选项 ' + (oIndex + 1);
  }

  startAssessment(assessment: Assessment) {
    this.currentAssessment = assessment;
    this.currentQuestionIndex = 0;
    this.answers = {};
    this.result = null;
    this.showContinuePrompt = false;
    
    // 更新全局页面状态
    this.updateGlobalPageState();
  }

  selectOption(questionId: string, optionId: string) {
    this.answers[questionId] = optionId;
    
    // 更新全局页面状态（答案变化时同步）
    this.updateGlobalPageState();
  }

  nextQuestion() {
    if (this.currentQuestionIndex < this.currentAssessment!.questions.length - 1) {
      this.currentQuestionIndex++;
      
      // 更新全局页面状态
      this.updateGlobalPageState();
    }
  }

  prevQuestion() {
    if (this.currentQuestionIndex > 0) {
      this.currentQuestionIndex--;
      
      // 更新全局页面状态
      this.updateGlobalPageState();
    }
  }

  async submitAssessment(): Promise<void> {
    if (!this.currentAssessment) return;

    this.isSubmitting = true;
    try {
      const answers = this.answers;
      const response = await this.apiService.post<AssessmentResult>('/assessments/submit', {
        assessmentId: this.currentAssessment.id,
        answers: answers
      });

      if (response.success && response.data) {
        this.result = response.data;
      } else {
        // 使用模拟结果作为 fallback
        this.result = this.generateMockResult();
      }

      // 保存到历史记录
      this.saveToHistory();

      // 更新全局页面状态
      this.updateGlobalPageState();
    } catch (error) {
      // 使用模拟结果作为 fallback
      this.result = this.generateMockResult();

      // 保存到历史记录
      this.saveToHistory();

      // 更新全局页面状态
      this.updateGlobalPageState();
    } finally {
      this.isSubmitting = false;
    }
  }

  /**
   * 保存测评结果到历史记录
   */
  private async saveToHistory(): Promise<void> {
    if (this.result && this.currentAssessment) {
      await this.historyService.addHistory({
        type: 'assessment',
        title: `测评完成 - ${this.currentAssessment.title}`,
        content: `得分: ${this.result.score}分，${this.result.suggestions[0] || ''}`,
        metadata: {
          assessmentId: this.currentAssessment.id,
          assessmentTitle: this.currentAssessment.title,
          score: this.result.score,
          dimensionScores: this.result.dimensionScores
        }
      });
    }
  }

  // 添加模拟结果生成方法
  private generateMockResult(): AssessmentResult {
    const totalScore = Math.floor(Math.random() * 30) + 70; // 70-100
    return {
      assessmentId: this.currentAssessment?.id || '',
      score: totalScore,
      dimensionScores: [
        { dimension: '专业知识', score: Math.floor(Math.random() * 30) + 70, description: '表现良好' },
        { dimension: '实践能力', score: Math.floor(Math.random() * 30) + 70, description: '能力良好' },
        { dimension: '沟通协作', score: Math.floor(Math.random() * 30) + 70, description: '有较大潜力' },
        { dimension: '学习能力', score: Math.floor(Math.random() * 30) + 70, description: '有较大潜力' }
      ],
      suggestions: [
        '建议加强专业知识学习',
        '多参与实际项目提升实践能力',
        '注重团队协作和沟通技巧'
      ]
    };
  }

  resetAssessment() {
    this.currentAssessment = null;
    this.currentQuestionIndex = 0;
    this.answers = {};
    this.result = null;
    this.showContinuePrompt = false;
    this.isContinueRestore = false;
    
    // 更新全局页面状态
    this.updateGlobalPageState();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('岗位测评')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

        if (this.currentAssessment) {
          Row() {
            // 跨设备同步指示器
            if (this.isContinueRestore) {
              Row() {
                Image($r('app.media.ic_sync'))
                  .width(14)
                  .height(14)
                  .fillColor(BrandColors.Brand500)

                Text('已同步')
                  .fontSize(FontSize.Xs)
                  .fontColor(BrandColors.Brand500)
                  .margin({ left: Spacing.Space1 })
              }
              .padding({ left: Spacing.Space2, right: Spacing.Space2, top: Spacing.Space1, bottom: Spacing.Space1 })
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
              .borderRadius(SemanticRadius.Pill)
              .margin({ right: Spacing.Space3 })
            }

            Button('返回')
              .fontSize(FontSize.Sm)
              .fontColor(BrandColors.Brand500)
              .backgroundColor('transparent')
              .onClick(() => this.resetAssessment())
          }
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .justifyContent(FlexAlign.SpaceBetween)
      .shadow({
        radius: 8,
        color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
        offsetY: 2
      })

      if (this.currentAssessment && !this.result) {
        this.buildQuestionView()
      } else if (this.result) {
        this.buildResultView()
      } else {
        this.buildListView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }

  @Builder
  buildListView() {
    // 加载状态
    if (this.isLoading) {
      LoadingSpinner({ text: '加载中...' })
        .layoutWeight(1)
    } else {
    Column() {
      // 流转恢复提示
      if (this.showContinuePrompt) {
        Row() {
          Image($r('app.media.ic_info'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)
          
          Text('检测到未完成的测评，是否继续？')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .margin({ left: Spacing.Space3 })
            .layoutWeight(1)

          Button('继续')
            .fontSize(FontSize.Xs)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
            .height(28)
            .padding({ left: Spacing.Space4, right: Spacing.Space4 })
            .onClick(() => {
              this.showContinuePrompt = false;
            })

          Button('忽略')
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
            .backgroundColor('transparent')
            .margin({ left: Spacing.Space2 })
            .onClick(() => {
              this.showContinuePrompt = false;
              this.resetAssessment();
            })
        }
        .width('100%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
        .margin({ bottom: SemanticSpacing.Lg })
      }
      
      List() {
        ForEach(this.assessmentList, (assessment: Assessment) => {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text(assessment.title)
                    .fontSize(FontSize.Base)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

                  Text(assessment.description)
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
                    .margin({ top: Spacing.Space3 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)

                Text(assessment.duration + '分钟')
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                  .padding({ left: SemanticSpacing.Md })
              }

              Row() {
                Text(this.getTypeLabel(assessment.type))
                  .fontSize(FontSize.Xs)
                  .fontColor(BrandColors.Brand500)
                  .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2, bottom: Spacing.Space2 })
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .borderRadius(SemanticRadius.Pill)

                Blank()

                Button('开始测评')
                  .fontSize(FontSize.Xs)
                  .fontColor(NeutralColors.Neutral0)
                  .backgroundColor(BrandColors.Brand500)
                  .borderRadius(SemanticRadius.Pill)
                  .height(32)
                  .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
                  .onClick(() => this.startAssessment(assessment))
              }
              .margin({ top: SemanticSpacing.Lg })
            }
            .width('100%')
            .padding(SemanticSpacing.Xl)
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Component)
            .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space4 })
            .shadow({
              radius: 8,
              color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
              offsetY: 2
            })
          }
        })
      }
      .layoutWeight(1)
      .padding({ top: SemanticSpacing.Lg })
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
    }
    .width('100%')
    .layoutWeight(1)
    }
  }

  @Builder
  buildQuestionView() {
    Column() {
      // 流转提示
      if (this.isContinueRestore && this.showContinuePrompt) {
        Row() {
          Image($r('app.media.ic_info'))
            .width(16)
            .height(16)
            .fillColor(BrandColors.Brand500)

          Text(`已从其他设备恢复，当前第 ${this.currentQuestionIndex + 1} 题`)
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .margin({ left: Spacing.Space3 })
            .layoutWeight(1)

          Button('知道了')
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .backgroundColor('transparent')
            .onClick(() => {
              this.showContinuePrompt = false;
            })
        }
        .width('100%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
        .margin({ bottom: Spacing.Space4 })
      }

      // 进度条
      Column() {
        Row() {
          Stack() {
            // 背景轨道
            Row()
              .width('100%')
              .height(4)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
              .borderRadius(2)

            // 进度
            Row()
              .width(`${((this.currentQuestionIndex + 1) / this.currentAssessment!.questions.length) * 100}%`)
              .height(4)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(2)
          }
          .layoutWeight(1)
          .height(4)

          Text((this.currentQuestionIndex + 1) + '/' + this.currentAssessment!.questions.length)
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
            .margin({ left: SemanticSpacing.Md })
        }
      }
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, top: SemanticSpacing.Lg, bottom: Spacing.Space4 })

      // 问题内容
      Scroll() {
        Column() {
          Text(this.currentAssessment!.questions[this.currentQuestionIndex].title)
            .fontSize(FontSize.Lg)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Xl })

          ForEach(this.currentAssessment!.questions[this.currentQuestionIndex].options || [], (option) => {
            Row() {
              Row() {
                Radio({ value: option.id, group: 'assessment' })
                  .checked(this.answers[this.currentAssessment!.questions[this.currentQuestionIndex].id] === option.id)
                  .width(20)
                  .height(20)
                  .checkedColor(BrandColors.Brand500)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.selectOption(this.currentAssessment!.questions[this.currentQuestionIndex].id, option.id);
                    }
                  })

                Text(option.text)
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .margin({ left: Spacing.Space4 })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding(SemanticSpacing.Lg)
              .backgroundColor(this.answers[this.currentAssessment!.questions[this.currentQuestionIndex].id] === option.id ? (this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50) : (this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1))
              .borderRadius(SemanticRadius.Control)
              .border({
                width: 1,
                color: this.answers[this.currentAssessment!.questions[this.currentQuestionIndex].id] === option.id ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
              })
            }
            .width('100%')
            .margin({ bottom: Spacing.Space4 })
          })
        }
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }
      .layoutWeight(1)

      // 按钮区域
      Row() {
        if (this.currentQuestionIndex > 0) {
          Button('上一题')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
            .borderRadius(SemanticRadius.Pill)
            .height(44)
            .layoutWeight(1)
            .onClick(() => this.prevQuestion())
        } else {
          Blank()
        }

        if (this.currentQuestionIndex < this.currentAssessment!.questions.length - 1) {
          Button('下一题')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
            .height(44)
            .layoutWeight(1)
            .margin({ left: SemanticSpacing.Md })
            .onClick(() => this.nextQuestion())
        } else {
          Button('提交')
            .fontSize(FontSize.Sm)
            .fontColor(NeutralColors.Neutral0)
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
            .height(44)
            .layoutWeight(1)
            .margin({ left: SemanticSpacing.Md })
            .loading(this.isSubmitting)
            .onClick(() => this.submitAssessment())
        }
      }
      .width('100%')
      .padding(SemanticSpacing.Lg)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    }
  }

  @Builder
  buildResultView() {
    Scroll() {
      Column() {
        // 流转提示
        if (this.isContinueRestore) {
          Row() {
            Image($r('app.media.ic_info'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)
            
            Text('已从其他设备恢复测评结果')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .margin({ left: Spacing.Space3 })
            .layoutWeight(1)

            Button('知道了')
              .fontSize(FontSize.Xs)
              .fontColor(BrandColors.Brand500)
              .backgroundColor('transparent')
              .onClick(() => {
                this.isContinueRestore = false;
              })
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
          .borderRadius(SemanticRadius.Component)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
        }
        
        // 总分卡片
        Column() {
          Text('您的测评得分')
            .fontSize(FontSize.Base)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)

          Text(this.result!.score.toString())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.result!.score))
            .margin({ top: Spacing.Space3 })

          Text(this.getScoreLabel(this.result!.score))
            .fontSize(FontSize.Base)
            .fontColor(this.getScoreColor(this.result!.score))
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
        .shadow({
          radius: 8,
          color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
          offsetY: 2
        })

        // 维度得分
        Column() {
          Text('维度分析')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })

          ForEach(this.result!.dimensionScores, (dim: DimensionScore) => {
            Row() {
              Text(dim.dimension)
                .fontSize(FontSize.Sm)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .width(80)

              Stack() {
                Row()
                  .width('100%')
                  .height(8)
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
                  .borderRadius(4)

                Row()
                  .width(`${dim.score}%`)
                  .height(8)
                  .backgroundColor(this.getScoreColor(dim.score))
                  .borderRadius(4)
              }
              .layoutWeight(1)
              .height(8)

              Text(dim.score.toString())
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getScoreColor(dim.score))
                .width(36)
                .textAlign(TextAlign.End)
                .margin({ left: Spacing.Space4 })
            }
            .width('100%')
            .margin({ bottom: Spacing.Space4 })
          })
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
        .shadow({
          radius: 8,
          color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
          offsetY: 2
        })

        // 建议
        Column() {
          Text('发展建议')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })

          ForEach(this.result!.suggestions, (suggestion: string, index: number) => {
            Row() {
              Text((index + 1).toString())
                .fontSize(FontSize.Xs)
                .fontColor(NeutralColors.Neutral0)
                .width(20)
                .height(20)
                .backgroundColor(BrandColors.Brand500)
                .borderRadius(10)
                .textAlign(TextAlign.Center)

              Text(suggestion)
                .fontSize(FontSize.Sm)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .margin({ left: Spacing.Space4 })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: Spacing.Space4 })
          })
        }
        .width('100%')
        .padding(SemanticSpacing.Xl)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg })
        .shadow({
          radius: 8,
          color: this.isDarkMode ? 'rgba(0, 0, 0, 0.16)' : 'rgba(0, 0, 0, 0.04)',
          offsetY: 2
        })

        // 重新测评按钮
        Button('重新测评')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Pill)
          .border({ width: 1, color: BrandColors.Brand500 })
          .width('calc(100% - 32px)')
          .height(44)
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space9 })
          .onClick(() => this.resetAssessment())
      }
      .padding({ top: SemanticSpacing.Lg })
    }
    .layoutWeight(1)
  }

  getTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      personality: '性格测试',
      career: '职业测试',
      skill: '技能测试',
      value: '价值观测试'
    };
    return labels[type] || '测评';
  }

  getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  getScoreLabel(score: number): string {
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    return '待提升';
  }
}
