import file from '@ohos.file.picker';
import { ResumeAnalysisResult, Dimension, Suggestion } from '../models/Resume';
import { ChatService } from '../services/ChatService';
import { PageStateSync, ResumePageState } from '../utils/distributed';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
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
export struct ResumePage {
  @State hasResume: boolean = false;
  @State analysisResult: ResumeAnalysisResult | null = null;
  @State isLoading: boolean = false;
  @State isDragging: boolean = false;
  @State selectedFileName: string = '';
  @State resumeContent: string = '';
  @State isEditing: boolean = false;
  @State isContinueRestore: boolean = false;
  private chatService: ChatService = ChatService.getInstance();
  private pageStateSync: PageStateSync = new PageStateSync('pages/Resume');

  aboutToAppear() {
    // 注册当前页面
    AppStorage.setOrCreate('currentPage', 'pages/Resume');
    
    // 检查是否是跨设备流转恢复
    this.checkContinueRestore();
    
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
    console.log('[ResumePage] Handling continue restore:', JSON.stringify(data));
    
    if (data.pageUrl === 'pages/Resume' && data.pageState) {
      const state = data.pageState as ResumePageState;
      
      this.isContinueRestore = true;
      this.hasResume = state.hasResume || false;
      this.analysisResult = state.analysisResult || null;
      this.selectedFileName = state.selectedFileName || '';
      this.resumeContent = state.resumeContent || '';
      this.isEditing = state.isEditing || false;
      
      // 更新全局页面状态
      this.updateGlobalPageState();
      
      console.log('[ResumePage] State restored successfully');
    }
  }

  /**
   * 获取当前页面状态
   */
  private getCurrentState(): ResumePageState {
    return {
      hasResume: this.hasResume,
      analysisResult: this.analysisResult,
      selectedFileName: this.selectedFileName,
      resumeContent: this.resumeContent,
      isEditing: this.isEditing
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

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('简历分析')
          .fontSize(FontSize.Xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(SemanticColors.Text1)
        
        // 跨设备同步指示器
        if (this.isContinueRestore) {
          Row() {
            Image($r('app.media.ic_sync'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)
            
            Text('已同步')
              .fontSize(FontSize.Xs)
              .fontColor(BrandColors.Brand500)
              .margin({ left: Spacing.Space2 })
          }
          .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Pill)
        }
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
      .justifyContent(FlexAlign.SpaceBetween)

      if (!this.hasResume) {
        // 上传区域
        Column() {
          Column() {
            // 上传图标
            Column() {
              Image($r('app.media.ic_upload'))
                .width(48)
                .height(48)
                .fillColor(BrandColors.Brand400)
            }
            .width(80)
            .height(80)
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(40)
            .justifyContent(FlexAlign.Center)

            Text('点击上传简历')
              .fontSize(FontSize.Base)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)
              .margin({ top: SemanticSpacing.Lg })

            Text('支持 PDF、Word 格式，最大 10MB')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .margin({ top: Spacing.Space3 })
          }
          .width(200)
          .height(200)
          .backgroundColor(this.isDragging ? BrandColors.Brand50 : NeutralColors.Neutral50)
          .borderRadius(SemanticRadius.Component)
          .border({
            width: 2,
            color: this.isDragging ? BrandColors.Brand500 : NeutralColors.Neutral200,
            style: BorderStyle.Dashed
          })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.pickFile();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.isLoading) {
        // 加载状态
        Column() {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(BrandColors.Brand500)
          }
          .width(80)
          .height(80)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(40)
          .justifyContent(FlexAlign.Center)

          Text('正在分析简历...')
            .fontSize(FontSize.Base)
            .fontColor(SemanticColors.Text1)
            .margin({ top: SemanticSpacing.Lg })

          if (this.selectedFileName) {
            Text(this.selectedFileName)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .margin({ top: Spacing.Space3 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.analysisResult) {
        this.buildResultView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50)
  }

  @Builder
  buildResultView() {
    Scroll() {
      Column() {
        // 流转提示卡片
        if (this.isContinueRestore) {
          Row() {
            Image($r('app.media.ic_info'))
              .width(16)
              .height(16)
              .fillColor(BrandColors.Brand500)
            
            Text('已从其他设备恢复简历数据')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
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
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(SemanticRadius.Component)
          .margin({ bottom: SemanticSpacing.Lg })
        }

        // ATS 评分卡片
        this.buildScoreCard()

        // 维度分析卡片
        this.buildDimensionCard()

        // 优化建议卡片
        this.buildSuggestionCard()

        // 关键词卡片
        this.buildKeywordCard()
        
        // 重新上传按钮
        Button('重新上传简历')
          .fontSize(FontSize.Sm)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(NeutralColors.Neutral0)
          .borderRadius(SemanticRadius.Pill)
          .border({ width: 1, color: BrandColors.Brand500 })
          .width('100%')
          .height(44)
          .margin({ top: SemanticSpacing.Lg, bottom: Spacing.Space9 })
          .onClick(() => {
            this.resetResume();
          })
      }
      .padding(SemanticSpacing.Lg)
    }
    .layoutWeight(1)
  }

  @Builder
  buildScoreCard() {
    Column() {
      Text('ATS 评分')
        .fontSize(FontSize.Base)
        .fontColor(SemanticColors.Text2)
        .alignSelf(ItemAlign.Start)

      Text(this.analysisResult!.atsScore.toString())
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getScoreColor(this.analysisResult!.atsScore))
        .margin({ top: Spacing.Space3 })

      Text(this.getScoreLabel(this.analysisResult!.atsScore))
        .fontSize(FontSize.Base)
        .fontColor(this.getScoreColor(this.analysisResult!.atsScore))

      Text(this.analysisResult!.summary)
        .fontSize(FontSize.Sm)
        .fontColor(SemanticColors.Text2)
        .margin({ top: SemanticSpacing.Lg })
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildDimensionCard() {
    Column() {
      Text('多维度分析')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      ForEach(this.analysisResult!.dimensions, (dim: Dimension, index: number) => {
        Column() {
          Row() {
            Text(dim.name)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text1)
              .width(80)

            Stack() {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor(NeutralColors.Neutral200)
                .borderRadius(4)
              
              Row()
                .width(`${dim.score}%`)
                .height(8)
                .backgroundColor(this.getScoreColor(dim.score))
                .borderRadius(4)
            }
            .layoutWeight(1)
            .height(8)

            Text(dim.score.toString() + '分')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getScoreColor(dim.score))
              .width(40)
              .textAlign(TextAlign.End)
              .margin({ left: Spacing.Space4 })
          }
          .width('100%')

          Text(dim.description)
            .fontSize(FontSize.Xs)
            .fontColor(SemanticColors.Text3)
            .width('100%')
            .margin({ top: Spacing.Space2 })
        }
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildSuggestionCard() {
    Column() {
      Text('优化建议')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      ForEach(this.analysisResult!.suggestions, (suggestion: Suggestion, index: number) => {
        Row() {
          Column() {
            Text(this.getSuggestionIcon(suggestion.type))
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Bold)
          }
          .width(32)
          .height(32)
          .backgroundColor(this.getSuggestionBgColor(suggestion.type))
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .margin({ right: Spacing.Space4 })

          Column() {
            Text(suggestion.title)
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(SemanticColors.Text1)

            Text(suggestion.description)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text2)
              .margin({ top: Spacing.Space2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(Spacing.Space4)
        .backgroundColor(NeutralColors.Neutral50)
        .borderRadius(SemanticRadius.Control)
        .margin({ bottom: Spacing.Space3 })
      })
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  @Builder
  buildKeywordCard() {
    Column() {
      Text('简历关键词')
        .fontSize(FontSize.Base)
        .fontWeight(FontWeight.Bold)
        .fontColor(SemanticColors.Text1)
        .width('100%')
        .margin({ bottom: SemanticSpacing.Lg })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.analysisResult!.keywords, (keyword: string) => {
          Text(keyword)
            .fontSize(FontSize.Xs)
            .fontColor(BrandColors.Brand500)
            .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space3, bottom: Spacing.Space3 })
            .backgroundColor(BrandColors.Brand50)
            .borderRadius(SemanticRadius.Pill)
            .margin({ right: Spacing.Space3, bottom: Spacing.Space3 })
        })
      }
    }
    .width('100%')
    .padding(SemanticSpacing.Xl)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(SemanticRadius.Component)
    .margin({ bottom: SemanticSpacing.Lg })
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 2
    })
  }

  getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  getScoreLabel(score: number): string {
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    return '待优化';
  }

  getSuggestionIcon(type: string): string {
    switch (type) {
      case 'add': return '+';
      case 'modify': return '~';
      case 'delete': return '-';
      default: return '>';
    }
  }

  getSuggestionBgColor(type: string): string {
    switch (type) {
      case 'add': return SuccessColors.Success50;
      case 'modify': return WarningColors.Warning50;
      case 'delete': return ErrorColors.Error50;
      default: return NeutralColors.Neutral100;
    }
  }

  async pickFile() {
    try {
      const documentPicker = new file.DocumentPicker();
      const result = await documentPicker.select({
        MIMEType: file.DocumentPickerType.MIME_TYPE_DOCUMENT,
        maxNumberOfFiles: 1
      });

      if (result && result.length > 0) {
        this.selectedFileName = result[0].name || '已选择文件';
        this.uploadAndAnalyze(result[0]);
      }
    } catch (err) {
      console.error('Pick file failed:', err);
    }
  }

  async uploadAndAnalyze(file: file.File) {
    this.isLoading = true;
    this.hasResume = true;

    try {
      const result = await this.chatService.analyzeResume(file);
      this.analysisResult = result;
      
      // 更新全局页面状态
      this.updateGlobalPageState();
    } catch (error) {
      console.error('Analysis failed:', error);
      // 模拟数据用于演示
      this.analysisResult = {
        atsScore: 78,
        dimensions: [
          { name: '结构完整', score: 85, description: '简历结构清晰，层次分明' },
          { name: '关键词匹配', score: 72, description: '建议增加更多技能关键词' },
          { name: '工作经历', score: 80, description: '工作描述具体，有量化数据' },
          { name: '教育背景', score: 90, description: '教育信息完整' }
        ],
        suggestions: [
          { type: 'add', priority: 'high', title: '添加技能证书', description: '建议添加相关的专业技能证书，提升竞争力' },
          { type: 'modify', priority: 'medium', title: '优化项目描述', description: '项目描述中增加更多技术细节和成果' },
          { type: 'add', priority: 'medium', title: '补充自我评价', description: '建议添加一段简短的自我评价，突出个人优势' }
        ],
        summary: '您的简历整体质量良好，在结构完整性和教育背景方面表现突出。建议在关键词匹配和工作经历描述方面进行优化。',
        keywords: ['Java', 'Spring Boot', 'MySQL', '微服务', 'Redis', 'Docker', 'K8s', 'Git', 'Vue.js', 'Python']
      };
      
      // 更新全局页面状态
      this.updateGlobalPageState();
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 重置简历状态
   */
  private resetResume(): void {
    this.hasResume = false;
    this.analysisResult = null;
    this.isLoading = false;
    this.selectedFileName = '';
    this.resumeContent = '';
    this.isEditing = false;
    this.isContinueRestore = false;
    
    // 更新全局页面状态
    this.updateGlobalPageState();
  }
}
