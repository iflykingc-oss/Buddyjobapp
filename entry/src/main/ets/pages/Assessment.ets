import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { Assessment, Question, AssessmentResult, DimensionScore, DimensionDetail } from '../models/Assessment';
import { AssessmentService } from '../services/AssessmentService';
import { PageStateSync, AssessmentPageState } from '../utils/distributed';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { WindowUtil } from '../utils/WindowUtil';
import { Router } from '../utils/Router';
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
  @State showBackConfirm: boolean = false;
  @State isCompleted: boolean = false;
  @State searchKeyword: string = '';
  @State filterType: string = 'all';
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;
  private assessmentService: AssessmentService = AssessmentService.getInstance();
  private pageStateSync: PageStateSync = new PageStateSync('pages/Assessment');

  aboutToAppear() {
    AppStorage.setOrCreate('currentPage', 'pages/Assessment');
    this.checkContinueRestore();
    this.loadAssessments();
    this.pageStateSync.startAutoSync(() => this.getCurrentState());
    const eventHub = getContext(this).eventHub;
    eventHub.on('onContinueRestore', (data) => {
      this.handleContinueRestore(data);
    });
  }

  aboutToDisappear() {
    this.pageStateSync.stopAutoSync();
    const eventHub = getContext(this).eventHub;
    eventHub.off('onContinueRestore');
  }

  onBackPress(): boolean {
    if (this.currentAssessment && this.currentQuestionIndex > 0 && !this.isCompleted) {
      this.showBackConfirm = true;
      return true;
    }
    return false;
  }

  private checkContinueRestore(): void {
    const isContinueRestore = AppStorage.get<boolean>('isContinueRestore') || false;
    const continueData = AppStorage.get<Record<string, any>>('continueData');
    if (isContinueRestore && continueData) {
      this.handleContinueRestore(continueData);
    }
  }

  private handleContinueRestore(data: Record<string, any>): void {
    console.log('[AssessmentPage] Handling continue restore:', JSON.stringify(data));
    if (data.pageUrl === 'pages/Assessment' && data.pageState) {
      const state = data.pageState as AssessmentPageState;
      this.isContinueRestore = true;
      this.showContinuePrompt = true;
      if (state.assessmentList && state.assessmentList.length > 0) {
        this.assessmentList = state.assessmentList;
      }
      if (state.currentAssessmentId) {
        const assessment = this.assessmentList.find(a => a.id === state.currentAssessmentId);
        if (assessment) {
          this.currentAssessment = assessment;
          this.currentQuestionIndex = state.currentQuestionIndex || 0;
          this.answers = state.answers || {};
          if (state.showResult && state.result) {
            this.result = state.result;
          }
        }
      }
      this.updateGlobalPageState();
      console.log('[AssessmentPage] State restored successfully');
    }
  }

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

  private updateGlobalPageState(): void {
    const pageState = this.getCurrentState();
    AppStorage.setOrCreate('currentPageState', pageState);
    this.pageStateSync.syncState(pageState);
  }

  async loadAssessments(): Promise<void> {
    this.isLoading = true;
    try {
      this.assessmentList = await this.assessmentService.getAssessments();
    } finally {
      this.isLoading = false;
    }
  }

  // ==================== 搜索过滤 ====================

  private getFilteredAssessments(): Assessment[] {
    return this.assessmentList.filter(a => {
      const matchType = this.filterType === 'all' || a.type === this.filterType;
      const matchSearch = !this.searchKeyword ||
        a.title.includes(this.searchKeyword) ||
        a.description.includes(this.searchKeyword);
      return matchType && matchSearch;
    });
  }

  // ==================== 测评逻辑方法 ====================

  startAssessment(assessment: Assessment) {
    this.currentAssessment = assessment;
    this.currentQuestionIndex = 0;
    this.answers = {};
    this.result = null;
    this.showContinuePrompt = false;
    this.updateGlobalPageState();
  }

  selectOption(questionId: string, optionId: string) {
    this.answers[questionId] = optionId;
    this.updateGlobalPageState();
  }

  nextQuestion() {
    if (this.currentAssessment && this.currentQuestionIndex < this.currentAssessment.questions.length - 1) {
      this.currentQuestionIndex++;
      this.updateGlobalPageState();
    }
  }

  prevQuestion() {
    if (this.currentQuestionIndex > 0) {
      this.currentQuestionIndex--;
      this.updateGlobalPageState();
    }
  }

  async submitAssessment(): Promise<void> {
    if (!this.currentAssessment) return;
    this.isSubmitting = true;
    try {
      this.result = await this.assessmentService.submitAssessment(this.currentAssessment.id, this.answers);
      this.updateGlobalPageState();
    } finally {
      this.isSubmitting = false;
    }
  }

  resetAssessment() {
    this.currentAssessment = null;
    this.currentQuestionIndex = 0;
    this.answers = {};
    this.result = null;
    this.showContinuePrompt = false;
    this.isContinueRestore = false;
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
      .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
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
    .bindSheet($$this.showBackConfirm, this.BackConfirmSheet(), {
      height: '30%',
      dragBar: true,
      backgroundColor: this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1,
    })
  }

  @Builder
  BackConfirmSheet() {
    Column() {
      Text('确认退出测评？')
        .fontSize(FontSize.Lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: Spacing.Space4 })

      Text('退出后当前答题进度将不会保存')
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Xl })

      Row() {
        Button('继续答题')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .backgroundColor('transparent')
          .borderRadius(SemanticRadius.Pill)
          .layoutWeight(1)
          .onClick(() => {
            this.showBackConfirm = false;
          })

        Button('确认退出')
          .fontSize(FontSize.Sm)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(ErrorColors.Error500)
          .borderRadius(SemanticRadius.Pill)
          .layoutWeight(1)
          .margin({ left: SemanticSpacing.Md })
          .onClick(() => {
            this.showBackConfirm = false;
            this.resetAssessment();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
  }

  @Builder
  buildListView() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(BrandColors.Brand500)
        Text('加载中...')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ top: Spacing.Space3 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
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
              .height(40)
              .padding({ left: Spacing.Space4, right: Spacing.Space4 })
              .onClick(() => {
                this.showContinuePrompt = false;
              })

            Button('忽略')
              .fontSize(FontSize.Xs)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
              .backgroundColor('transparent')
              .height(40)
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

        // 搜索栏
        Row() {
          Row() {
            Image($r('app.media.ic_search'))
              .width(16)
              .height(16)
              .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3 })

            TextInput({ placeholder: '搜索测评...', text: this.searchKeyword })
              .fontSize(FontSize.Sm)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
              .placeholderColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
              .backgroundColor('transparent')
              .layoutWeight(1)
              .margin({ left: Spacing.Space2 })
              .onChange((value: string) => {
                this.searchKeyword = value;
              })

            if (this.searchKeyword) {
              Image($r('app.media.ic_close'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                .margin({ right: Spacing.Space3 })
                .onClick(() => {
                  this.searchKeyword = '';
                })
            }
          }
          .width('100%')
          .height(40)
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
          .borderRadius(SemanticRadius.Pill)
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .margin({ bottom: Spacing.Space3 })

        // 过滤 chips
        Scroll() {
          Row({ space: Spacing.Space2 }) {
            Text('全部')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'all' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'all' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'all'; })

            Text('性格')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'personality' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'personality' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'personality'; })

            Text('兴趣')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'career' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'career' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'career'; })

            Text('竞争力')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'skill' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'skill' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'skill'; })

            Text('情商')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'eq' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'eq' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'eq'; })

            Text('面试准备')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'interview_readiness' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'interview_readiness' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'interview_readiness'; })

            Text('价值观')
              .fontSize(FontSize.Xs)
              .fontColor(this.filterType === 'value' ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
              .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
              .borderRadius(SemanticRadius.Pill)
              .backgroundColor(this.filterType === 'value' ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
              .onClick(() => { this.filterType = 'value'; })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
        .margin({ bottom: Spacing.Space3 })

        List() {
          ForEach(this.getFilteredAssessments(), (assessment: Assessment) => {
            ListItem() {
              Column() {
                Row() {
                  // 图标
                  Text(assessment.icon || '')
                    .fontSize(28)
                    .width(48)
                    .height(48)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
                    .borderRadius(SemanticRadius.Control)

                  Column() {
                    Text(assessment.title)
                      .fontSize(FontSize.Base)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)

                    Text(assessment.description)
                      .fontSize(FontSize.Xs)
                      .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
                      .margin({ top: Spacing.Space1 })
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .margin({ left: SemanticSpacing.Md })
                }

                // 底部信息行
                Row() {
                  Text(assessment.category || this.getTypeLabel(assessment.type))
                    .fontSize(FontSize.Xs)
                    .fontColor(BrandColors.Brand500)
                    .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space1, bottom: Spacing.Space1 })
                    .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                    .borderRadius(SemanticRadius.Pill)

                  Text(`${assessment.questions.length}题`)
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                    .margin({ left: Spacing.Space2 })

                  Text(`${assessment.duration}分钟`)
                    .fontSize(FontSize.Xs)
                    .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                    .margin({ left: Spacing.Space2 })

                  Blank()

                  Button('开始测评')
                    .fontSize(FontSize.Xs)
                    .fontColor(NeutralColors.Neutral0)
                    .backgroundColor(BrandColors.Brand500)
                    .borderRadius(SemanticRadius.Pill)
                    .height(36)
                    .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
                    .onClick(() => this.startAssessment(assessment))
                }
                .margin({ top: SemanticSpacing.Md })
              }
              .width('100%')
              .padding(SemanticSpacing.Xl)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
              .borderRadius(SemanticRadius.Component)
              .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: Spacing.Space3 })
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
            .height(40)
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
            Row()
              .width('100%')
              .height(4)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200)
              .borderRadius(2)

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
            .width(this.windowUtil?.isWideScreen() ? '48%' : '100%')
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

        // 类型描述（MBTI/霍兰德）
        if (this.result!.typeDescription) {
          Column() {
            Text('类型分析')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            Text(this.result!.typeDescription)
              .fontSize(FontSize.Lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(BrandColors.Brand500)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: SemanticSpacing.Md })
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
        }

        // 职业匹配推荐
        if (this.result!.careerMatch && this.result!.careerMatch.length > 0) {
          Column() {
            Text('推荐职业方向')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            Row({ space: Spacing.Space2 }) {
              ForEach(this.result!.careerMatch, (career: string) => {
                Text(career)
                  .fontSize(FontSize.Sm)
                  .fontColor(BrandColors.Brand500)
                  .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
                  .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
                  .borderRadius(SemanticRadius.Pill)
              })
            }
            .width('100%')
            .flexWrap(FlexWrap.Wrap)
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
        }

        // 维度得分（增强版 - 带详细解读）
        Column() {
          Text('维度分析')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })

          ForEach(this.result!.dimensionScores, (dim: DimensionScore, index: number) => {
            Column() {
              Row() {
                Text(dim.dimension)
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .width(100)

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

                Text(dim.score + '%')
                  .fontSize(FontSize.Sm)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getScoreColor(dim.score))
                  .width(40)
                  .textAlign(TextAlign.End)
                  .margin({ left: Spacing.Space4 })
              }
              .width('100%')

              // 维度详细解读
              if (this.result!.dimensionDetails && this.result!.dimensionDetails[index]) {
                const detail = this.result!.dimensionDetails[index];
                Text(detail.interpretation)
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
                  .width('100%')
                  .margin({ top: Spacing.Space2 })
                  .maxLines(2)

                if (detail.level === 'low') {
                  Row() {
                    Image($r('app.media.ic_info'))
                      .width(12)
                      .height(12)
                      .fillColor(WarningColors.Warning500)

                    Text(detail.advice)
                      .fontSize(FontSize.Xs)
                      .fontColor(WarningColors.Warning500)
                      .margin({ left: Spacing.Space1 })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .margin({ top: Spacing.Space1 })
                }
              }
            }
            .width('100%')
            .padding({ bottom: index < (this.result!.dimensionScores.length - 1) ? SemanticSpacing.Md : 0 })
            .border({
              width: index < (this.result!.dimensionScores.length - 1) ? { bottom: 1 } : 0,
              color: this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200
            })
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

        // 发展建议
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
            .margin({ bottom: Spacing.Space3 })
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

        // 推荐下一步行动
        if (this.result!.nextActions && this.result!.nextActions.length > 0) {
          Column() {
            Text('推荐下一步行动')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
              .width('100%')
              .margin({ bottom: SemanticSpacing.Lg })

            ForEach(this.result!.nextActions, (action: string) => {
              Row() {
                Image($r('app.media.ic_check'))
                  .width(16)
                  .height(16)
                  .fillColor(SuccessColors.Success500)

                Text(action)
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .margin({ left: Spacing.Space3 })
                  .layoutWeight(1)
              }
              .width('100%')
              .margin({ bottom: Spacing.Space3 })
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
        }

        // 推荐下一步 - 跨模块导航
        Column() {
          Text('推荐下一步')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })

          // 根据分数推荐不同操作
          if (this.result!.score < 60) {
            Row() {
              Column() {
                Image($r('app.media.ic_knowledge'))
                  .width(20)
                  .height(20)
                  .fillColor(WarningColors.Warning500)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
              .justifyContent(FlexAlign.Center)

              Column() {
                Text('建议先学习相关知识')
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .fontWeight(FontWeight.Medium)

                Text('前往知识库补充基础')
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                  .margin({ top: Spacing.Space1 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(64)
            .padding({ left: Spacing.Space3, right: SemanticSpacing.Lg })
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Component)
            .onClick(() => {
              AppStorage.setOrCreate('currentTab', 3);
              router.back();
            })
          } else if (this.result!.score <= 80) {
            Row() {
              Column() {
                Image($r('app.media.ic_chat'))
                  .width(20)
                  .height(20)
                  .fillColor(BrandColors.Brand500)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
              .justifyContent(FlexAlign.Center)

              Column() {
                Text('可以开始模拟面试练习')
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .fontWeight(FontWeight.Medium)

                Text('通过面试提升实战能力')
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                  .margin({ top: Spacing.Space1 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(64)
            .padding({ left: Spacing.Space3, right: SemanticSpacing.Lg })
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Component)
            .onClick(() => {
              Router.push('pages/Interview');
            })
          } else {
            Row() {
              Column() {
                Image($r('app.media.ic_order'))
                  .width(20)
                  .height(20)
                  .fillColor(SuccessColors.Success500)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
              .justifyContent(FlexAlign.Center)

              Column() {
                Text('准备好分析Offer了')
                  .fontSize(FontSize.Sm)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                  .fontWeight(FontWeight.Medium)

                Text('让AI帮你分析薪资和福利')
                  .fontSize(FontSize.Xs)
                  .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                  .margin({ top: Spacing.Space1 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: Spacing.Space3 })

              Image($r('app.media.ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
            }
            .width('100%')
            .height(64)
            .padding({ left: Spacing.Space3, right: SemanticSpacing.Lg })
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
            .borderRadius(SemanticRadius.Component)
            .onClick(() => {
              Router.push('pages/OfferAnalysis');
            })
          }

          // 始终显示：查看求职看板
          Row() {
            Column() {
              Image($r('app.media.ic_history'))
                .width(20)
                .height(20)
                .fillColor(BrandColors.Brand500)
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(this.isDarkMode ? DarkSemanticColors.AccentSubtle : BrandColors.Brand50)
            .justifyContent(FlexAlign.Center)

            Column() {
              Text('查看求职看板')
                .fontSize(FontSize.Sm)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
                .fontWeight(FontWeight.Medium)

              Text('管理求职进度和任务')
                .fontSize(FontSize.Xs)
                .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
                .margin({ top: Spacing.Space1 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: Spacing.Space3 })

            Image($r('app.media.ic_arrow_right'))
              .width(16)
              .height(16)
              .fillColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
          }
          .width('100%')
          .height(64)
          .padding({ left: Spacing.Space3, right: SemanticSpacing.Lg })
          .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .borderRadius(SemanticRadius.Component)
          .margin({ top: Spacing.Space3 })
          .onClick(() => {
            Router.push('pages/Kanban');
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
          .margin({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg, bottom: (AppStorage.get<number>('bottomSafeArea') || 0) + Spacing.Space9 })
          .onClick(() => this.resetAssessment())
      }
      .padding({ top: SemanticSpacing.Lg })
      .constraintSize({ maxWidth: this.windowUtil?.getContentMaxWidth() })
      .width('100%')
    }
    .layoutWeight(1)
  }

  getTypeLabel(type: string): string {
    const labels: Record<string, string> = {
      personality: '性格测评',
      career: '兴趣测评',
      skill: '能力测评',
      value: '价值观测评',
      eq: '情商测评',
      interview_readiness: '面试准备'
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
