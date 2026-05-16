import { AssessmentService } from '../services/AssessmentService';
import { HistoryService } from '../services/HistoryService';
import { LazyDataLoader } from '../services/LazyDataLoader';
import { Assessment, Question, AssessmentResult } from '../models/Assessment';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct Assessment {
  @State private assessments: Assessment[] = [];
  @State private isLoading: boolean = false;
  @State private selectedAssessment: Assessment | null = null;
  @State private assessmentResult: AssessmentResult | null = null;
  @State private currentPage: number = 0;
  @State private answers: number[] = [];
  @State private questions: Question[] = [];
  private assessmentService: AssessmentService = AssessmentService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private lazyLoader: LazyDataLoader = LazyDataLoader.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.loadAssessments();
  }

  private async loadAssessments(): Promise<void> {
    this.isLoading = true;
    try {
      this.assessments = await this.assessmentService.getAssessments();
    } catch (err) {
      promptAction.showToast({ message: '加载测评失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private selectAssessment(assessment: Assessment): void {
    this.selectedAssessment = assessment;
    this.questions = assessment.questions ?? [];
    this.answers = new Array(this.questions.length).fill(-1);
    this.currentPage = 0;
  }

  private async submitAssessment(): Promise<void> {
    if (!this.selectedAssessment) {
      return;
    }
    this.isLoading = true;
    try {
      this.assessmentResult = await this.assessmentService.submitAssessment(
        this.selectedAssessment.id,
        this.answers
      );
    } catch (err) {
      promptAction.showToast({ message: '提交失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        if (this.selectedAssessment !== null) {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.selectedAssessment = null;
              this.assessmentResult = null;
            })
        }
        Text(this.selectedAssessment !== null ? this.selectedAssessment!.title : '岗位测评')
          .fontSize(FontSize.LG)
          .fontWeight(FontWeight.SEMIBOLD)
          .fontColor(NeutralColors.GRAY_900)
          .layoutWeight(1)
          .textAlign(this.selectedAssessment !== null ? TextAlign.Center : TextAlign.Start)
      }
      .width('100%')
      .height(ComponentSizes.NAV_BAR)
      .padding({ left: SemanticSpacing.PAGE_H, right: SemanticSpacing.PAGE_H })

      if (this.isLoading && this.assessments.length === 0) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(BrandColors.PRIMARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.assessmentResult !== null) {
        // 结果页
        Scroll() {
          Column() {
            Text('测评完成！')
              .fontSize(FontSize.XL)
              .fontWeight(FontWeight.BOLD)
              .fontColor(NeutralColors.GRAY_900)
              .margin({ top: Spacing.XL, bottom: Spacing.MD })

            Text(`综合得分：${this.assessmentResult!.overallScore ?? 0}分`)
              .fontSize(FontSize.LG)
              .fontColor(BrandColors.PRIMARY)
              .margin({ bottom: Spacing.LG })

            Text(this.assessmentResult!.summary ?? '')
              .fontSize(FontSize.MD)
              .fontColor(NeutralColors.GRAY_700)
              .lineHeight(24)
              .padding({ left: SemanticSpacing.PAGE_H, right: SemanticSpacing.PAGE_H })

            Button('返回测评列表')
              .width('90%')
              .height(ComponentSizes.BTN_LG)
              .backgroundColor(BrandColors.PRIMARY)
              .fontColor(NeutralColors.WHITE)
              .borderRadius(SemanticRadius.BTN)
              .margin({ top: Spacing.XL })
              .onClick(() => {
                this.assessmentResult = null;
                this.selectedAssessment = null;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
      } else if (this.selectedAssessment !== null && this.questions.length > 0) {
        // 答题页
        Column() {
          // 进度
          Text(`第 ${this.currentPage + 1} / ${this.questions.length} 题`)
            .fontSize(FontSize.SM)
            .fontColor(NeutralColors.GRAY_500)
            .margin({ bottom: Spacing.MD })

          // 题目
          Column() {
            Text(this.questions[this.currentPage].content)
              .fontSize(FontSize.MD)
              .fontColor(NeutralColors.GRAY_900)
              .lineHeight(24)
          }
          .width('90%')
          .padding(SemanticSpacing.CARD)
          .backgroundColor(NeutralColors.WHITE)
          .borderRadius(SemanticRadius.CARD)
          .margin({ bottom: Spacing.LG })

          // 选项
          ForEach(this.questions[this.currentPage].options ?? [], (opt: string, idx: number) => {
            Row() {
              Text(opt)
                .fontSize(FontSize.MD)
                .fontColor(this.answers[this.currentPage] === idx ? NeutralColors.WHITE : NeutralColors.GRAY_800)
                .layoutWeight(1)
            }
            .width('90%')
            .padding(SemanticSpacing.CARD)
            .backgroundColor(this.answers[this.currentPage] === idx ? BrandColors.PRIMARY : NeutralColors.WHITE)
            .borderRadius(SemanticRadius.CARD)
            .margin({ bottom: Spacing.SM })
            .onClick(() => {
              const newAnswers = [...this.answers];
              newAnswers[this.currentPage] = idx;
              this.answers = newAnswers;
            })
          })

          // 导航按钮
          Row() {
            if (this.currentPage > 0) {
              Button('上一题')
                .height(ComponentSizes.BTN_MD)
                .backgroundColor(NeutralColors.GRAY_200)
                .fontColor(NeutralColors.GRAY_700)
                .borderRadius(SemanticRadius.BTN)
                .onClick(() => { this.currentPage--; })
            }

            Button(this.currentPage === this.questions.length - 1 ? '提交' : '下一题')
              .height(ComponentSizes.BTN_MD)
              .backgroundColor(BrandColors.PRIMARY)
              .fontColor(NeutralColors.WHITE)
              .borderRadius(SemanticRadius.BTN)
              .enabled(this.answers[this.currentPage] !== -1)
              .onClick(() => {
                if (this.currentPage < this.questions.length - 1) {
                  this.currentPage++;
                } else {
                  this.submitAssessment();
                }
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: Spacing.LG })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      } else {
        // 测评列表
        Scroll() {
          Column() {
            ForEach(this.assessments, (item: Assessment) => {
              Column() {
                Text(item.title)
                  .fontSize(FontSize.MD)
                  .fontWeight(FontWeight.SEMIBOLD)
                  .fontColor(NeutralColors.GRAY_900)
                  .margin({ bottom: Spacing.XS })

                Text(item.description ?? '')
                  .fontSize(FontSize.SM)
                  .fontColor(NeutralColors.GRAY_500)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ bottom: Spacing.MD })

                Button('开始测评')
                  .height(ComponentSizes.BTN_SM)
                  .backgroundColor(BrandColors.PRIMARY)
                  .fontColor(NeutralColors.WHITE)
                  .fontSize(FontSize.SM)
                  .borderRadius(SemanticRadius.BTN)
                  .onClick(() => this.selectAssessment(item))
              }
              .width('100%')
              .padding(SemanticSpacing.CARD)
              .backgroundColor(NeutralColors.WHITE)
              .borderRadius(SemanticRadius.CARD)
              .margin({ bottom: Spacing.MD, left: SemanticSpacing.PAGE_H, right: SemanticSpacing.PAGE_H })
              .alignItems(HorizontalAlign.Start)
            })
          }
          .padding({ bottom: Spacing.XL })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.GRAY_50)
  }
}
