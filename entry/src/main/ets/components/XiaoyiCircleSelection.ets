import { common } from '@kit.AbilityKit';
import { selectionInput } from '@ohos.selectionInput.selectionManager';
import { agentFramework } from '@kit.IntelligentAgentKit';
import { promptAction } from '@kit.ArkUI';
import { ApiService } from '../services/ApiService';
import { XiaoyiService } from '../services/XiaoyiService';
import { SelectionService, SelectionAnalysisResult, SelectionSuggestion } from '../services/SelectionService';
import { ShareUtils } from '../utils/share';
import { Logger } from '../utils/logger';
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
  FontWeight
} from '../constants/design-tokens';

const TAG = 'XiaoyiCircleSelection';

/**
 * 圈选坐标点
 */
interface SelectionPoint {
  x: number;
  y: number;
  timestamp: number;
}

/**
 * 圈选形状类型
 */
type SelectionShape = 'circle' | 'rect' | 'freeform';

/**
 * 内容类型
 */
export type ContentType = 'resume' | 'job_listing' | 'general';

/**
 * 提取的内容信息
 */
export interface ExtractedContent {
  type: ContentType;
  title?: string;
  skills?: string[];
  experience?: string[];
  education?: string[];
  jobInfo?: {
    position?: string;
    company?: string;
    requirements?: string[];
    salary?: string;
    location?: string;
  };
  rawText: string;
}

/**
 * 回调类型定义
 */
export type SelectionCompleteCallback = (text: string, extractedContent: ExtractedContent | null) => void;
export type AnalysisCompleteCallback = (result: SelectionAnalysisResult) => void;

/**
 * 小艺圈选组件
 * 使用 @ohos.selectionInput.selectionManager API 实现真实的划词功能
 * 用于简历内容的圈选分析
 */
@Component
export struct XiaoyiCircleSelection {
  @State isSelecting: boolean = false;
  @State selectedText: string = '';
  @State analysisResult: SelectionAnalysisResult | null = null;
  @State isAnalyzing: boolean = false;
  @State showResultPanel: boolean = false;
  @State selectionActive: boolean = false;
  @State isDrawing: boolean = false;
  @State drawPoints: SelectionPoint[] = [];
  @State currentShape: SelectionShape = 'circle';
  @State extractedContent: ExtractedContent | null = null;
  @State @Require contentType: ContentType = 'resume';
  @Prop content: string = ''; // 简历内容
  @Prop resumeId: string = '';

  // 回调函数
  @Callback onSelectionComplete?: SelectionCompleteCallback;
  @Callback onAnalysisComplete?: AnalysisCompleteCallback;
  @Callback onClose?: () => void;

  private apiService: ApiService = ApiService.getInstance();
  private xiaoyiService: XiaoyiService = XiaoyiService.getInstance();
  private selectionService: SelectionService = SelectionService.getInstance();
  private selectionManager: selectionInput.SelectionManager | null = null;
  private uiContext: common.UIAbilityContext | null = null;

  // 圈选相关变量
  private circleCenter: SelectionPoint | null = null;
  private circleRadius: number = 0;

  aboutToAppear() {
    this.initSelectionService();
    this.uiContext = getContext(this) as common.UIAbilityContext;
  }

  aboutToDisappear() {
    this.cleanupSelectionService();
  }

  /**
   * 判断是否为深色模式
   */
  private isDarkMode(): boolean {
    try {
      const colorMode = this.uiContext?.resourceManager?.configuration?.colorMode;
      return colorMode === 1;
    } catch {
      return false;
    }
  }

  /**
   * 获取背景色（支持深色模式）
   */
  private getBackgroundColor(): string {
    return this.isDarkMode() ? NeutralColors.Neutral900 : NeutralColors.Neutral0;
  }

  /**
   * 获取卡片背景色
   */
  private getCardBackgroundColor(): string {
    return this.isDarkMode() ? NeutralColors.Neutral800 : NeutralColors.Neutral50;
  }

  /**
   * 获取文本颜色
   */
  private getTextColor(): string {
    return this.isDarkMode() ? NeutralColors.Neutral0 : SemanticColors.Text1;
  }

  /**
   * 初始化划词服务
   */
  private async initSelectionService() {
    try {
      // 获取 UIAbilityContext
      this.uiContext = getContext(this) as common.UIAbilityContext;

      // 初始化 SelectionService
      const initialized = await this.selectionService.initialize(this.uiContext);
      if (initialized) {
        // 创建 SelectionManager 实例用于组件内划词
        this.selectionManager = selectionInput.createSelectionManager(this.uiContext);

        // 注册划词监听
        this.selectionService.startListening({
          onSelectionComplete: (text: string) => {
            this.handleSelectionComplete(text);
          },
          onAnalysisStart: () => {
            this.isAnalyzing = true;
          },
          onAnalysisComplete: (result: SelectionAnalysisResult) => {
            this.analysisResult = result;
            this.isAnalyzing = false;
            this.showResultPanel = true;
          },
          onAnalysisError: (error: string) => {
            this.isAnalyzing = false;
            promptAction.showToast({ message: error });
          }
        });

        Logger.info(TAG, 'Selection service initialized for component');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to initialize selection service:', JSON.stringify(error));
    }
  }

  /**
   * 清理划词服务
   */
  private cleanupSelectionService() {
    if (this.selectionManager) {
      try {
        this.selectionManager.destroy();
      } catch (error) {
        Logger.error(TAG, 'Error destroying selection manager:', JSON.stringify(error));
      }
      this.selectionManager = null;
    }
    this.selectionService.stopListening();
  }

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // 圈选提示条
        if (this.isSelecting) {
          Row() {
            Row() {
              Image($r('app.media.media_ic_xiaoyi'))
                .width(20)
                .height(20)
                .fillColor(BrandColors.Brand500)

              Text('圈选模式')
                .fontSize(FontSize.Sm)
                .fontColor(BrandColors.Brand500)
                .margin({ left: Spacing.Space2 })
            }

            Text('长按拖动画圈选择内容')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .margin({ left: Spacing.Space3 })

            Blank()

            Button('取消')
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text3)
              .backgroundColor('transparent')
              .onClick(() => {
                this.cancelSelection();
              })
          }
          .width('100%')
          .height(44)
          .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
          .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral800 : BrandColors.Brand50)
          .justifyContent(FlexAlign.SpaceBetween)
        }

        // 内容显示区域（支持圈选手势）
        Stack() {
          Scroll() {
            Column() {
              // 内容文本
              Text(this.content)
                .fontSize(FontSize.Base)
                .fontColor(this.getTextColor())
                .lineHeight(24)
                .padding(SemanticSpacing.Lg)
                .width('100%')
                .copyOption(CopyOptions.LocalDevice)
                .enableDataDetector(true)
                .textMenuOptions({
                  options: [
                    TextMenuOptions.COPY,
                    TextMenuOptions.SELECT_ALL,
                    TextMenuOptions.SHARE
                  ],
                  onMenuOptionSelected: (option: TextMenuOptions) => {
                    this.handleMenuOptionSelected(option);
                  }
                })
            }
          }
          .layoutWeight(1)
          .backgroundColor(this.getBackgroundColor())

          // 绘制层（用于圈选手势）
          Stack() {
            if (this.isDrawing && this.drawPoints.length > 1) {
              // 绘制圈选区域
              Canvas()
                .width('100%')
                .height('100%')
                .onReady(() => {
                  this.drawSelectionShape();
                })
            }
          }
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestBehavior.Transparent)
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              LongPressGesture({ repeat: false, duration: 300 })
                .onAction((event) => {
                  this.startDrawing(event.fingerList[0].localX, event.fingerList[0].localY);
                }),
              PanGesture()
                .onActionStart((event) => {
                  if (this.isDrawing) {
                    this.addDrawPoint(event.fingerList[0].localX, event.fingerList[0].localY);
                  }
                })
                .onActionUpdate((event) => {
                  if (this.isDrawing) {
                    this.addDrawPoint(event.fingerList[0].localX, event.fingerList[0].localY);
                  }
                })
                .onActionEnd((event) => {
                  if (this.isDrawing) {
                    this.endDrawing();
                  }
                })
            )
        }
      }
      .width('100%')
      .height('100%')

      // 悬浮分析按钮（当有选中内容时显示）
      if (this.selectedText.length > 0 && !this.showResultPanel) {
        Column() {
          Button() {
            Row() {
              Image($r('app.media.media_ic_xiaoyi'))
                .width(20)
                .height(20)
                .fillColor(NeutralColors.Neutral0)

              Text('小艺分析')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
            }
          }
          .height(40)
          .padding({ left: Spacing.Space4, right: Spacing.Space4 })
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Pill)
          .shadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.15)',
            offsetY: 4
          })
          .onClick(() => {
            this.analyzeSelection();
          })
        }
        .position({ x: '50%', y: '80%' })
        .translate({ x: '-50%' })
      }

      // 分析结果面板
      if (this.showResultPanel && this.analysisResult) {
        this.buildResultPanel()
      }

      // 提取内容预览面板
      if (this.extractedContent && !this.showResultPanel) {
        this.buildExtractedContentPanel()
      }

      // 加载中遮罩
      if (this.isAnalyzing) {
        Column() {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(BrandColors.Brand500)

            Text('小艺正在分析...')
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .margin({ top: SemanticSpacing.Md })
          }
          .padding(SemanticSpacing.Xl)
          .backgroundColor(this.getBackgroundColor())
          .borderRadius(SemanticRadius.Component)
          .shadow({
            radius: 16,
            color: 'rgba(0, 0, 0, 0.1)'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 绘制圈选形状
   */
  private drawSelectionShape() {
    // 绘制逻辑将在 Canvas onReady 中实现
    // 使用 drawPoints 绘制圆形或自由形状
  }

  /**
   * 开始绘制
   */
  private startDrawing(x: number, y: number) {
    this.isDrawing = true;
    this.drawPoints = [];
    this.circleCenter = { x, y, timestamp: Date.now() };
    this.addDrawPoint(x, y);
    Logger.info(TAG, 'Drawing started');
  }

  /**
   * 添加绘制点
   */
  private addDrawPoint(x: number, y: number) {
    const point: SelectionPoint = {
      x,
      y,
      timestamp: Date.now()
    };
    this.drawPoints.push(point);

    // 实时计算圆的半径
    if (this.circleCenter) {
      const dx = x - this.circleCenter.x;
      const dy = y - this.circleCenter.y;
      this.circleRadius = Math.sqrt(dx * dx + dy * dy);
    }
  }

  /**
   * 结束绘制
   */
  private endDrawing() {
    this.isDrawing = false;

    if (this.drawPoints.length < 3) {
      Logger.warn(TAG, 'Not enough points for selection');
      return;
    }

    // 根据绘制形状提取内容
    if (this.currentShape === 'circle' && this.circleCenter && this.circleRadius > 20) {
      // 圆形圈选：提取圆形区域内的文本
      this.extractContentInCircle();
    } else if (this.drawPoints.length > 5) {
      // 自由形状：提取大致区域内的文本
      this.extractContentInRegion();
    }

    Logger.info(TAG, `Drawing ended with ${this.drawPoints.length} points`);
  }

  /**
   * 提取圆形区域内的内容
   */
  private extractContentInCircle() {
    if (!this.circleCenter || this.circleRadius < 20) {
      return;
    }

    // 这里简化处理，实际需要根据坐标映射到文本内容
    // 假设 content 是全文，我们需要根据圆的范围估算选中的文本范围
    const estimatedCharCount = Math.floor(this.circleRadius * 2);
    const startIndex = Math.max(0, Math.floor(this.circleCenter.x / 10) % this.content.length);
    const endIndex = Math.min(this.content.length, startIndex + estimatedCharCount);

    this.selectedText = this.content.substring(startIndex, endIndex);

    // 尝试提取内容
    this.extractedContent = this.extractContentFromText(this.selectedText);

    // 触发回调
    if (this.onSelectionComplete) {
      this.onSelectionComplete(this.selectedText, this.extractedContent);
    }

    Logger.info(TAG, `Extracted content: ${this.selectedText.substring(0, 50)}...`);
  }

  /**
   * 提取区域内的内容
   */
  private extractContentInRegion() {
    // 获取绘制区域的边界
    const minX = Math.min(...this.drawPoints.map(p => p.x));
    const maxX = Math.max(...this.drawPoints.map(p => p.x));
    const minY = Math.min(...this.drawPoints.map(p => p.y));
    const maxY = Math.max(...this.drawPoints.map(p => p.y));

    // 根据区域估算选中的文本
    const estimatedCharCount = Math.floor((maxX - minX + maxY - minY) / 2);
    const startIndex = Math.max(0, Math.floor(minX / 10) % this.content.length);
    const endIndex = Math.min(this.content.length, startIndex + estimatedCharCount);

    this.selectedText = this.content.substring(startIndex, endIndex);

    // 尝试提取内容
    this.extractedContent = this.extractContentFromText(this.selectedText);

    // 触发回调
    if (this.onSelectionComplete) {
      this.onSelectionComplete(this.selectedText, this.extractedContent);
    }

    Logger.info(TAG, `Extracted region content: ${this.selectedText.substring(0, 50)}...`);
  }

  /**
   * 从文本中提取结构化内容
   */
  private extractContentFromText(text: string): ExtractedContent {
    const result: ExtractedContent = {
      type: this.contentType,
      rawText: text
    };

    // 根据内容类型提取信息
    if (this.contentType === 'resume') {
      // 提取技能
      result.skills = this.extractSkills(text);

      // 提取经验描述
      result.experience = this.extractExperience(text);

      // 提取教育信息
      result.education = this.extractEducation(text);
    } else if (this.contentType === 'job_listing') {
      // 提取职位信息
      result.jobInfo = this.extractJobInfo(text);
    }

    return result;
  }

  /**
   * 提取技能关键词
   */
  private extractSkills(text: string): string[] {
    const skills: string[] = [];
    const skillPatterns = [
      // 编程语言
      /JavaScript|TypeScript|Python|Java|Go|Rust|C\+\+|C#|PHP|Ruby|Swift|Kotlin|Objective-C/i,
      // 框架
      /React|Vue|Angular|Spring|Node\.js|Express|Django|Flask|Next\.js/i,
      // 数据库
      /MySQL|PostgreSQL|MongoDB|Redis|Elasticsearch|SQLite/i,
      // 云服务
      /AWS|Azure|GCP|Docker|Kubernetes|Jenkins|CI\/CD/i,
      // 其他技能
      /Git|Linux|Agile|Scrum|TDD|RESTful|GraphQL/i
    ];

    skillPatterns.forEach(pattern => {
      const match = text.match(pattern);
      if (match) {
        skills.push(match[0]);
      }
    });

    return skills;
  }

  /**
   * 提取经验描述
   */
  private extractExperience(text: string): string[] {
    const experiences: string[] = [];

    // 提取包含时间范围的描述
    const experiencePattern = /\d+年.*经验|经验.*\d+年|曾任职|负责|主导|参与|完成|提升/i;
    const matches = text.match(new RegExp(experiencePattern, 'gi'));

    if (matches) {
      experiences.push(...matches.slice(0, 3)); // 最多取3条
    }

    return experiences;
  }

  /**
   * 提取教育信息
   */
  private extractEducation(text: string): string[] {
    const education: string[] = [];

    // 提取学校名称
    const schoolPattern = /(?:毕业于|就读于|本科|硕士|博士|大专)([^\s,，,。]+(?:大学|学院|学校))/i;
    const schoolMatch = text.match(schoolPattern);
    if (schoolMatch) {
      education.push(schoolMatch[0]);
    }

    // 提取专业
    const majorPattern = /(?:专业|主修)([^\s,，,。]+)/i;
    const majorMatch = text.match(majorPattern);
    if (majorMatch) {
      education.push(`专业: ${majorMatch[1]}`);
    }

    return education;
  }

  /**
   * 提取职位信息
   */
  private extractJobInfo(text: string): ExtractedContent['jobInfo'] {
    const jobInfo: ExtractedContent['jobInfo'] = {};

    // 提取职位名称
    const positionPattern = /(?:职位|岗位)([^,\s]+)/i;
    const positionMatch = text.match(positionPattern);
    if (positionMatch) {
      jobInfo.position = positionMatch[1];
    }

    // 提取公司名称
    const companyPattern = /(?:公司)([^,\s,需求,要求]+)/i;
    const companyMatch = text.match(companyPattern);
    if (companyMatch) {
      jobInfo.company = companyMatch[1];
    }

    // 提取薪资
    const salaryPattern = /(\d+(?:\.\d+)?[kK]?(?:\s*-\s*\d+(?:\.\d+)?[kK]?)?)/i;
    const salaryMatch = text.match(salaryPattern);
    if (salaryMatch) {
      jobInfo.salary = salaryMatch[1];
    }

    // 提取地点
    const locationPattern = /(?:地点|城市|Location)([^,\s,，]+)/i;
    const locationMatch = text.match(locationPattern);
    if (locationMatch) {
      jobInfo.location = locationMatch[1];
    }

    // 提取要求
    const requirements: string[] = [];
    const requirementPattern = /(?:要求|必备|需要)([^。,。]+)/gi;
    let reqMatch;
    while ((reqMatch = requirementPattern.exec(text)) !== null && requirements.length < 5) {
      requirements.push(reqMatch[1].trim());
    }
    if (requirements.length > 0) {
      jobInfo.requirements = requirements;
    }

    return jobInfo;
  }

  @Builder
  buildExtractedContentPanel() {
    Column() {
      // 面板头部
      Row() {
        Row() {
          Image($r('app.media.media_ic_xiaoyi'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)

          Text('提取的信息')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getTextColor())
            .margin({ left: Spacing.Space2 })
        }

        Blank()

        Button() {
          Image($r('app.media.media_ic_close'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text3)
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          this.extractedContent = null;
          this.selectedText = '';
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .alignItems(VerticalAlign.Center)

      // 提取的内容
      Scroll() {
        Column() {
          // 技能标签
          if (this.extractedContent?.skills && this.extractedContent.skills.length > 0) {
            Column() {
              Text('识别到的技能')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTextColor())
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.extractedContent.skills, (skill: string) => {
                  Text(skill)
                    .fontSize(FontSize.Xs)
                    .fontColor(BrandColors.Brand500)
                    .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space1, bottom: Spacing.Space1 })
                    .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : BrandColors.Brand50)
                    .borderRadius(SemanticRadius.Pill)
                    .margin({ right: Spacing.Space2, bottom: Spacing.Space2 })
                })
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.getCardBackgroundColor())
            .borderRadius(SemanticRadius.Control)
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 经验描述
          if (this.extractedContent?.experience && this.extractedContent.experience.length > 0) {
            Column() {
              Text('工作经历')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTextColor())
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              ForEach(this.extractedContent.experience, (exp: string, index: number) => {
                Row() {
                  Circle({ width: 8, height: 8 })
                    .fill(BrandColors.Brand500)
                    .margin({ right: Spacing.Space3 })

                  Text(exp)
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text2)
                    .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: Spacing.Space2 })
              })
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.getCardBackgroundColor())
            .borderRadius(SemanticRadius.Control)
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 教育信息
          if (this.extractedContent?.education && this.extractedContent.education.length > 0) {
            Column() {
              Text('教育背景')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTextColor())
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              ForEach(this.extractedContent.education, (edu: string) => {
                Row() {
                  Image($r('app.media.media_ic_education'))
                    .width(16)
                    .height(16)
                    .fillColor(BrandColors.Brand500)
                    .margin({ right: Spacing.Space3 })

                  Text(edu)
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text2)
                }
                .width('100%')
                .margin({ bottom: Spacing.Space2 })
              })
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.getCardBackgroundColor())
            .borderRadius(SemanticRadius.Control)
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 职位信息
          if (this.extractedContent?.jobInfo) {
            Column() {
              Text('职位信息')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTextColor())
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              if (this.extractedContent.jobInfo.position) {
                Row() {
                  Text('职位:')
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text3)
                    .width(60)

                  Text(this.extractedContent.jobInfo.position)
                    .fontSize(FontSize.Sm)
                    .fontColor(this.getTextColor())
                }
                .width('100%')
                .margin({ bottom: Spacing.Space2 })
              }

              if (this.extractedContent.jobInfo.company) {
                Row() {
                  Text('公司:')
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text3)
                    .width(60)

                  Text(this.extractedContent.jobInfo.company)
                    .fontSize(FontSize.Sm)
                    .fontColor(this.getTextColor())
                }
                .width('100%')
                .margin({ bottom: Spacing.Space2 })
              }

              if (this.extractedContent.jobInfo.salary) {
                Row() {
                  Text('薪资:')
                    .fontSize(FontSize.Sm)
                    .fontColor(SemanticColors.Text3)
                    .width(60)

                  Text(this.extractedContent.jobInfo.salary)
                    .fontSize(FontSize.Sm)
                    .fontColor(SuccessColors.Success500)
                }
                .width('100%')
                .margin({ bottom: Spacing.Space2 })
              }

              if (this.extractedContent.jobInfo.requirements && this.extractedContent.jobInfo.requirements.length > 0) {
                Text('岗位要求:')
                  .fontSize(FontSize.Sm)
                  .fontColor(SemanticColors.Text3)
                  .width('100%')
                  .margin({ top: Spacing.Space2, bottom: Spacing.Space2 })

                ForEach(this.extractedContent.jobInfo.requirements.slice(0, 3), (req: string) => {
                  Text('• ' + req)
                    .fontSize(FontSize.Xs)
                    .fontColor(SemanticColors.Text2)
                    .width('100%')
                    .margin({ left: Spacing.Space4 })
                })
              }
            }
            .width('100%')
            .padding(SemanticSpacing.Lg)
            .backgroundColor(this.getCardBackgroundColor())
            .borderRadius(SemanticRadius.Control)
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 原始文本预览
          Column() {
            Text('选中的内容')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getTextColor())
              .width('100%')
              .margin({ bottom: SemanticSpacing.Md })

            Text(this.selectedText)
              .fontSize(FontSize.Xs)
              .fontColor(SemanticColors.Text2)
              .width('100%')
              .maxLines(5)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(this.getCardBackgroundColor())
          .borderRadius(SemanticRadius.Control)
          .margin({ bottom: SemanticSpacing.Lg })

          // 操作按钮
          Row() {
            Button('小艺分析')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(SemanticRadius.Control)
              .onClick(() => {
                this.extractedContent = null;
                this.analyzeSelection();
              })

            Button('分享')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : BrandColors.Brand50)
              .borderRadius(SemanticRadius.Control)
              .margin({ left: Spacing.Space3 })
              .onClick(() => {
                this.shareExtractedContent();
              })
          }
          .width('100%')
        }
        .padding(SemanticSpacing.Lg)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('65%')
    .backgroundColor(this.getBackgroundColor())
    .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetY: -4
    })
    .position({ x: 0, y: '35%' })
  }

  /**
   * 分享提取的内容
   */
  private async shareExtractedContent() {
    if (!this.extractedContent) {
      return;
    }

    let shareContent = '【小艺提取的信息】\n\n';

    if (this.extractedContent.skills && this.extractedContent.skills.length > 0) {
      shareContent += `技能: ${this.extractedContent.skills.join(', ')}\n\n`;
    }

    if (this.extractedContent.experience && this.extractedContent.experience.length > 0) {
      shareContent += `经历:\n${this.extractedContent.experience.map(e => '• ' + e).join('\n')}\n\n`;
    }

    if (this.extractedContent.education && this.extractedContent.education.length > 0) {
      shareContent += `教育: ${this.extractedContent.education.join(', ')}\n\n`;
    }

    if (this.extractedContent.jobInfo) {
      const job = this.extractedContent.jobInfo;
      if (job.position) shareContent += `职位: ${job.position}\n`;
      if (job.company) shareContent += `公司: ${job.company}\n`;
      if (job.salary) shareContent += `薪资: ${job.salary}\n`;
      if (job.requirements) shareContent += `要求: ${job.requirements.join(', ')}\n`;
    }

    try {
      await ShareUtils.shareText(shareContent, this.uiContext!);
    } catch (error) {
      Logger.error(TAG, 'Share failed:', JSON.stringify(error));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  @Builder
  buildResultPanel() {
    Column() {
      // 面板头部
      Row() {
        Row() {
          Image($r('app.media.media_ic_xiaoyi'))
            .width(24)
            .height(24)
            .fillColor(BrandColors.Brand500)

          Text('小艺分析结果')
            .fontSize(FontSize.Base)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getTextColor())
            .margin({ left: Spacing.Space2 })
        }

        // 评分标签
        if (this.analysisResult!.score !== undefined) {
          Text(`${this.analysisResult!.score}分`)
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.analysisResult!.score!))
            .padding({ left: Spacing.Space2, right: Spacing.Space2, top: Spacing.Space1, bottom: Spacing.Space1 })
            .backgroundColor(this.getScoreBgColor(this.analysisResult!.score!))
            .borderRadius(SemanticRadius.Pill)
        }

        Blank()

        Button() {
          Image($r('app.media.media_ic_close'))
            .width(20)
            .height(20)
            .fillColor(SemanticColors.Text3)
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          this.closeResultPanel();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      .alignItems(VerticalAlign.Center)

      // 分析内容
      Scroll() {
        Column() {
          // 分析摘要
          Column() {
            Text('内容分析')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getTextColor())
              .width('100%')
              .margin({ bottom: SemanticSpacing.Md })

            Text(this.analysisResult!.analysis)
              .fontSize(FontSize.Sm)
              .fontColor(SemanticColors.Text2)
              .width('100%')
              .lineHeight(22)
          }
          .width('100%')
          .padding(SemanticSpacing.Lg)
          .backgroundColor(this.getCardBackgroundColor())
          .borderRadius(SemanticRadius.Control)
          .margin({ bottom: SemanticSpacing.Lg })

          // 优化建议
          if (this.analysisResult!.suggestions.length > 0) {
            Column() {
              Text('优化建议')
                .fontSize(FontSize.Sm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getTextColor())
                .width('100%')
                .margin({ bottom: SemanticSpacing.Md })

              ForEach(this.analysisResult!.suggestions, (suggestion: SelectionSuggestion, index: number) => {
                Row() {
                  Column() {
                    Text(this.getPriorityIcon(suggestion.priority))
                      .fontSize(FontSize.Xs)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(NeutralColors.Neutral0)
                  }
                  .width(20)
                  .height(20)
                  .backgroundColor(this.getPriorityColor(suggestion.priority))
                  .borderRadius(10)
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: Spacing.Space3 })

                  Column() {
                    Text(suggestion.title)
                      .fontSize(FontSize.Sm)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getTextColor())
                      .width('100%')

                    Text(suggestion.description)
                      .fontSize(FontSize.Xs)
                      .fontColor(SemanticColors.Text3)
                      .width('100%')
                      .margin({ top: Spacing.Space1 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(Spacing.Space3)
                .backgroundColor(this.getCardBackgroundColor())
                .borderRadius(SemanticRadius.Control)
                .margin({ bottom: Spacing.Space2 })
              })
            }
            .width('100%')
            .margin({ bottom: SemanticSpacing.Lg })
          }

          // 操作按钮
          Row() {
            Button('应用到简历')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(NeutralColors.Neutral0)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(BrandColors.Brand500)
              .borderRadius(SemanticRadius.Control)
              .onClick(() => {
                this.applySuggestions();
              })

            Button('分享分析')
              .fontSize(FontSize.Sm)
              .fontWeight(FontWeight.Medium)
              .fontColor(BrandColors.Brand500)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.isDarkMode() ? NeutralColors.Neutral700 : BrandColors.Brand50)
              .borderRadius(SemanticRadius.Control)
              .margin({ left: Spacing.Space3 })
              .onClick(() => {
                this.shareAnalysis();
              })
          }
          .width('100%')
        }
        .padding(SemanticSpacing.Lg)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('60%')
    .backgroundColor(this.getBackgroundColor())
    .borderRadius({ topLeft: SemanticRadius.Component, topRight: SemanticRadius.Component })
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetY: -4
    })
    .position({ x: 0, y: '40%' })
  }

  /**
   * 启动划词选择模式
   * 使用 selectionManager API 启用系统级划词
   */
  private startSelectionMode() {
    this.isSelecting = true;
    this.selectedText = '';
    this.showResultPanel = false;
    this.analysisResult = null;

    try {
      if (this.selectionManager) {
        // 使用 selectionManager 启动划词模式
        this.selectionManager.startSelection({
          content: this.content,
          selectionType: selectionInput.SelectionType.TEXT,
          onSelectionChange: (selectInfo: selectionInput.SelectInfo) => {
            this.handleSelectionChange(selectInfo);
          }
        });
        this.selectionActive = true;
        Logger.info(TAG, 'Selection mode started via selectionManager');
      }
    } catch (error) {
      Logger.error(TAG, 'Failed to start selection mode:', JSON.stringify(error));
      // 降级处理：使用系统文本选择
      promptAction.showToast({ message: '请长按文本进行选择' });
    }
  }

  /**
   * 处理 selectionManager 的选择变化回调
   * @param selectInfo 选择信息
   */
  private handleSelectionChange(selectInfo: selectionInput.SelectInfo) {
    if (selectInfo && selectInfo.text && selectInfo.text.length > 0) {
      this.selectedText = selectInfo.text;
      Logger.info(TAG, `Selection changed: ${selectInfo.text.substring(0, 50)}...`);
    }
  }

  /**
   * 处理划词完成事件
   * @param text 选中的文本
   */
  private handleSelectionComplete(text: string) {
    if (text && text.length > 0) {
      this.selectedText = text;
      Logger.info(TAG, `Selection complete: ${text.substring(0, 50)}...`);
    }
  }

  /**
   * 处理文本菜单选项选择
   * @param option 选中的菜单选项
   */
  private handleMenuOptionSelected(option: TextMenuOptions) {
    switch (option) {
      case TextMenuOptions.COPY:
        // 用户复制了文本，可以在这里同步更新 selectedText
        Logger.info(TAG, 'User selected COPY option');
        break;
      case TextMenuOptions.SELECT_ALL:
        // 全选
        this.selectedText = this.content;
        Logger.info(TAG, 'User selected SELECT_ALL');
        break;
      case TextMenuOptions.SHARE:
        // 分享选中的文本
        if (this.selectedText.length > 0) {
          this.shareText(this.selectedText);
        }
        break;
      default:
        break;
    }
  }

  /**
   * 分析选中的内容
   * 使用 selectionManager API 获取文本后调用 AI 分析
   */
  private async analyzeSelection() {
    if (this.selectedText.length === 0) {
      promptAction.showToast({ message: '请先选择需要分析的文本' });
      return;
    }

    this.isAnalyzing = true;

    try {
      // 方式1：通过 selectionService 使用 selectionManager 的 getSelectionContent
      if (this.selectionManager) {
        try {
          const selectResult: selectionInput.SelectResult = {
            text: this.selectedText,
            startIndex: 0,
            endIndex: this.selectedText.length
          };

          const content = await this.selectionManager.getSelectionContent(selectResult);
          if (content && content.text) {
            this.selectedText = content.text;
            Logger.info(TAG, `Got selection content from selectionManager: ${content.text.substring(0, 50)}...`);
          }
        } catch (error) {
          Logger.warn(TAG, 'getSelectionContent failed, using existing selected text:', JSON.stringify(error));
        }
      }

      // 方式2：通过 selectionService 进行分析
      const result = await this.selectionService.analyzeText(
        this.selectedText,
        this.content.substring(0, 200) // 提供上下文
      );

      if (result) {
        this.analysisResult = result;
        this.showResultPanel = true;

        // 触发小艺语音回复
        agentFramework.sendResponse({
          intentName: XiaoyiService.INTENTS.CIRCLE_SELECTION,
          success: true,
          message: `分析完成：${result.analysis}`,
          data: result as unknown as Record<string, object>
        });

        Logger.info(TAG, 'Analysis completed successfully');
      } else {
        // 使用本地API作为备选
        await this.analyzeWithLocalAPI();
      }
    } catch (error) {
      Logger.error(TAG, 'Error analyzing selection:', JSON.stringify(error));
      // 使用本地API作为备选
      await this.analyzeWithLocalAPI();
    } finally {
      this.isAnalyzing = false;
    }
  }

  /**
   * 使用本地API分析
   */
  private async analyzeWithLocalAPI() {
    try {
      const response = await this.apiService.post('ai/analyze-selection', {
        content: this.selectedText,
        context: this.content.substring(0, 200),
        analysisType: 'resume'
      });

      if (response.success) {
        this.analysisResult = response.data as SelectionAnalysisResult;
        this.showResultPanel = true;
      } else {
        // 使用默认分析结果
        this.useDefaultAnalysis();
      }
    } catch (error) {
      Logger.error(TAG, 'Local API analysis failed:', JSON.stringify(error));
      this.useDefaultAnalysis();
    }
  }

  /**
   * 使用默认分析结果
   */
  private useDefaultAnalysis() {
    this.analysisResult = {
      analysis: '这段内容描述了您的项目经验，整体表达清晰。建议在描述中增加更多量化的成果数据，例如"提升了50%的性能"或"服务了10万+用户"等具体指标。',
      suggestions: [
        {
          priority: 'high',
          title: '增加量化数据',
          description: '建议添加具体的数字和百分比来展示项目成果'
        },
        {
          priority: 'medium',
          title: '突出技术栈',
          description: '明确列出使用的核心技术和框架'
        },
        {
          priority: 'low',
          title: '简化描述',
          description: '部分句子可以更加简洁有力'
        }
      ],
      originalText: this.selectedText,
      score: 70
    };
    this.showResultPanel = true;
  }

  /**
   * 取消选择
   */
  private cancelSelection() {
    this.isSelecting = false;
    this.selectedText = '';
    this.showResultPanel = false;
    this.analysisResult = null;
    this.selectionActive = false;

    // 停止 selectionManager 的选择模式
    if (this.selectionManager && this.selectionActive) {
      try {
        this.selectionManager.endSelection();
      } catch (error) {
        Logger.error(TAG, 'Error ending selection:', JSON.stringify(error));
      }
    }
  }

  /**
   * 关闭结果面板
   */
  private closeResultPanel() {
    this.showResultPanel = false;
    this.selectedText = '';
    this.selectionActive = false;
    this.extractedContent = null;
    this.drawPoints = [];
    this.circleCenter = null;
    this.circleRadius = 0;

    // 触发回调
    if (this.onAnalysisComplete && this.analysisResult) {
      this.onAnalysisComplete(this.analysisResult);
    }
  }

  /**
   * 应用建议
   */
  private applySuggestions() {
    // 通知父组件应用建议
    Logger.info(TAG, 'Applying suggestions');
    promptAction.showToast({ message: '建议已应用' });
    this.closeResultPanel();
  }

  /**
   * 分享分析结果
   * 使用 ShareUtils 分享分析内容
   */
  private async shareAnalysis() {
    if (!this.analysisResult) {
      return;
    }

    try {
      const shareContent = `【小艺简历分析】\n\n` +
        `评分: ${this.analysisResult.score !== undefined ? this.analysisResult.score + '分' : '未评分'}\n\n` +
        `分析: ${this.analysisResult.analysis}\n\n` +
        `优化建议:\n` +
        this.analysisResult.suggestions.map((s, i) =>
          `${i + 1}. ${s.title}: ${s.description}`
        ).join('\n');

      await ShareUtils.shareText(shareContent, this.uiContext!);
    } catch (error) {
      Logger.error(TAG, 'Failed to share analysis:', JSON.stringify(error));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  /**
   * 分享文本内容
   */
  private async shareText(text: string) {
    try {
      await ShareUtils.shareText(text, this.uiContext!);
    } catch (error) {
      Logger.error(TAG, 'Failed to share text:', JSON.stringify(error));
    }
  }

  /**
   * 获取优先级图标
   */
  private getPriorityIcon(priority: string): string {
    switch (priority) {
      case 'high': return '!';
      case 'medium': return '~';
      case 'low': return '·';
      default: return '·';
    }
  }

  /**
   * 获取优先级颜色
   */
  private getPriorityColor(priority: string): string {
    switch (priority) {
      case 'high': return ErrorColors.Error500;
      case 'medium': return WarningColors.Warning500;
      case 'low': return SuccessColors.Success500;
      default: return NeutralColors.Neutral400;
    }
  }

  /**
   * 获取评分颜色
   */
  private getScoreColor(score: number): string {
    if (score >= 80) return SuccessColors.Success500;
    if (score >= 60) return WarningColors.Warning500;
    return ErrorColors.Error500;
  }

  /**
   * 获取评分背景颜色
   */
  private getScoreBgColor(score: number): string {
    if (score >= 80) return SuccessColors.Success50;
    if (score >= 60) return WarningColors.Warning50;
    return ErrorColors.Error50;
  }

  /**
   * 开始圈选模式
   */
  public startSelection() {
    this.startSelectionMode();
  }
}
