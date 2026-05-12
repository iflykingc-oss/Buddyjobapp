import ChatPage from './Chat';
import ResumePage from './Resume';
import AssessmentPage from './Assessment';
import KnowledgePage from './Knowledge';
import ProfilePage from './Profile';
import { ThemeManager, ThemeMode } from '../utils/Theme';
import { WindowUtil } from '../utils/WindowUtil';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  Spacing,
  SemanticSpacing,
  BorderRadius,
  SemanticRadius,
  FontSize,
  FontWeight,
  ComponentSizes
} from '../constants/design-tokens';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;
  private tabController: TabsController = new TabsController()

  aboutToAppear() {
    // 初始化 WindowUtil（如果尚未初始化）
    if (!this.windowUtil) {
      const wu = new WindowUtil();
      wu.init();
    }
  }

  build() {
    Stack() {
      // 微妙的背景效果
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [BrandColors.Brand50, 0],
            [NeutralColors.Neutral50, 0.3],
            [NeutralColors.Neutral50, 1]
          ]
        })

      // 主内容
      Tabs({ barPosition: BarPosition.End, controller: this.tabController }) {
        TabContent() {
          ChatPage()
        }
        .tabBar(this.tabBuilder(0, '聊天', $r('app.media.ic_chat')))

        TabContent() {
          ResumePage()
        }
        .tabBar(this.tabBuilder(1, '简历', $r('app.media.ic_resume')))

        TabContent() {
          AssessmentPage()
        }
        .tabBar(this.tabBuilder(2, '测评', $r('app.media.ic_assessment')))

        TabContent() {
          KnowledgePage()
        }
        .tabBar(this.tabBuilder(3, '知识库', $r('app.media.ic_knowledge')))

        TabContent() {
          ProfilePage()
        }
        .tabBar(this.tabBuilder(4, '我的', $r('app.media.ic_profile')))
      }
      .barHeight(this.windowUtil?.isWideScreen() ? 64 : 60)
      .barWidth(this.windowUtil?.isWideScreen() ? '60%' : '100%')
      .barBackgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .onChange((index: number) => {
        this.currentTabIndex = index
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  tabBuilder(index: number, title: string, icon: Resource) {
    Column({ space: Spacing.Space2 }) {
      // 图标
      Column() {
        Image(icon)
          .width(ComponentSizes.Icon.Lg)
          .height(ComponentSizes.Icon.Lg)
          .fillColor(this.currentTabIndex === index ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4))
      }
      .width(40)
      .height(28)
      .justifyContent(FlexAlign.Center)

      // 标签文字
      Text(title)
        .fontSize(FontSize.Xs)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTabIndex === index ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4))
    }
    .width('100%')
    .height(60)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }
}
