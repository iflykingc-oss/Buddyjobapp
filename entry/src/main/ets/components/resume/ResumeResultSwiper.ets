/**
 * 简历结果 Swiper 展示组件
 */

import { ResumeAnalysisResult, Dimension, Suggestion } from '../../models/Resume';

@Component
export struct ResumeResultSwiper {
  @Prop analysisResult: ResumeAnalysisResult | null = null;
  private swiperController: SwiperController = new SwiperController();
  @State currentIndex: number = 0;

  @Builder
  buildScoreCard() {
    Column({ space: 12 }) {
      Text('综合评分')
        .fontSize(16)
        .fontColor('#666666')
      Text(`${this.analysisResult?.atsScore ?? 0}`)
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2563EB')
      Text('分')
        .fontSize(16)
        .fontColor('#666666')
      if (this.analysisResult?.summary) {
        Text(this.analysisResult.summary)
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16 })
      }
      ForEach(this.analysisResult?.dimensions ?? [], (dim: Dimension) => {
        Column({ space: 4 }) {
          Row() {
            Text(dim.name)
              .fontSize(13)
              .fontColor('#555555')
              .layoutWeight(1)
            Text(`${dim.score}分`)
              .fontSize(13)
              .fontColor('#2563EB')
          }
          .width('100%')
          Progress({ value: dim.score, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(6)
            .color('#2563EB')
          if (dim.description) {
            Text(dim.description)
              .fontSize(11)
              .fontColor('#888888')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  buildSuggestionsCard() {
    Column({ space: 12 }) {
      Text('优化建议')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
      ForEach(this.analysisResult?.suggestions ?? [], (item: Suggestion, index: number) => {
        Row({ space: 8 }) {
          Text(`${(index as number) + 1}`)
            .fontSize(12)
            .fontColor(Color.White)
            .width(20)
            .height(20)
            .textAlign(TextAlign.Center)
            .backgroundColor(
              item.priority === 'high' ? '#DC2626' :
              item.priority === 'medium' ? '#F59E0B' : '#6B7280'
            )
            .borderRadius(10)
          Column({ space: 2 }) {
            Text(item.title)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
            Text(item.description)
              .fontSize(12)
              .fontColor('#666666')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  buildKeywordsCard() {
    Column({ space: 12 }) {
      Text('关键词')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.analysisResult?.keywords ?? [], (kw: string) => {
          Text(kw)
            .fontSize(12)
            .fontColor('#2563EB')
            .backgroundColor('#EFF6FF')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(4)
            .margin({ right: 6, bottom: 6 })
        })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  buildDots() {
    Row({ space: 8 }) {
      ForEach([0, 1, 2], (i: number) => {
        Circle()
          .width(i === this.currentIndex ? 16 : 6)
          .height(6)
          .fill(i === this.currentIndex ? '#2563EB' : '#D1D5DB')
      })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .margin({ top: 12 })
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        this.buildScoreCard()
        this.buildSuggestionsCard()
        this.buildKeywordsCard()
      }
      .index(this.currentIndex)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .indicator(false)
      .loop(false)
      .cachedCount(2)

      this.buildDots()
    }
    .width('100%')
  }
}
