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

/**
 * 导航项定义
 */
interface NavItem {
  title: string;
  icon: Resource;
  builder: () => void;
}

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('windowUtil') windowUtil: WindowUtil | undefined = undefined;
  private tabController: TabsController = new TabsController()

  // 导航项列表
  private navItems: NavItem[] = [
    { title: '聊天', icon: $r('app.media.ic_chat'), builder: () => {} },
    { title: '简历', icon: $r('app.media.ic_resume'), builder: () => {} },
    { title: '测评', icon: $r('app.media.ic_assessment'), builder: () => {} },
    { title: '知识库', icon: $r('app.media.ic_knowledge'), builder: () => {} },
    { title: '我的', icon: $r('app.media.ic_profile'), builder: () => {} },
  ]

  aboutToAppear() {
    // 初始化 WindowUtil（如果尚未初始化）
    if (!this.windowUtil) {
      const wu = new WindowUtil();
      wu.init();
    }
  }

  /**
   * 切换Tab页
   */
  switchTab(index: number) {
    this.currentTabIndex = index;
    this.tabController.changeIndex(index);
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

      // 主内容区域
      Row() {
        // 宽屏时显示侧边导航栏
        if (this.windowUtil?.isWideScreen()) {
          this.SideBar()
        }

        // Tab内容区域
        Column() {
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
          .barHeight(64)
          .barWidth('100%')
          .barBackgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
          .onChange((index: number) => {
            this.currentTabIndex = index
          })
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 宽屏侧边导航栏
   */
  @Builder
  SideBar() {
    Column() {
      // 顶部：应用Logo和名称
      Row({ space: Spacing.Space3 }) {
        Column() {
          Image($r('app.media.app_icon'))
            .width(36)
            .height(36)
            .borderRadius(SemanticRadius.Md)
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)

        Column({ space: 2 }) {
          Text('BuddyJob')
            .fontSize(FontSize.Lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          Text('智能求职助手')
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        top: SemanticSpacing.Lg,
        bottom: SemanticSpacing.Xl
      })

      // 分割线
      Divider()
        .color(this.isDarkMode ? DarkSemanticColors.Divider : SemanticColors.Divider)
        .width('100%')

      // 导航项列表
      Column({ space: Spacing.Space1 }) {
        ForEach(this.navItems, (item: NavItem, index?: number) => {
          this.SideNavItem(item.title, item.icon, index ?? 0)
        }, (item: NavItem, index?: number) => `${index}_${item.title}`)
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Sm, right: SemanticSpacing.Sm, top: SemanticSpacing.Sm })
      .layoutWeight(1)

      // 分割线
      Divider()
        .color(this.isDarkMode ? DarkSemanticColors.Divider : SemanticColors.Divider)
        .width('100%')

      // 底部用户信息
      Row({ space: Spacing.Space3 }) {
        Column() {
          Image($r('app.media.ic_profile'))
            .width(28)
            .height(28)
            .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface3 : SemanticColors.Surface3)
        .justifyContent(FlexAlign.Center)

        Column({ space: 2 }) {
          Text('用户')
            .fontSize(FontSize.Sm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
          Text('个人中心')
            .fontSize(FontSize.Xs)
            .fontColor(this.isDarkMode ? DarkSemanticColors.Text4 : SemanticColors.Text4)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: SemanticSpacing.Lg,
        right: SemanticSpacing.Lg,
        top: SemanticSpacing.Md,
        bottom: SemanticSpacing.Lg
      })
    }
    .width(260)
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
    .shadow({
      radius: 12,
      color: this.isDarkMode ? 'rgba(0,0,0,0.3)' : 'rgba(0,0,0,0.06)',
      offsetY: 2
    })
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 侧边栏导航项
   */
  @Builder
  SideNavItem(title: string, icon: Resource, index: number) {
    Row({ space: Spacing.Space3 }) {
      // 图标
      Column() {
        Image(icon)
          .width(ComponentSizes.Icon.Lg)
          .height(ComponentSizes.Icon.Lg)
          .fillColor(this.currentTabIndex === index
            ? BrandColors.Brand500
            : (this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3))
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)

      // 文字
      Text(title)
        .fontSize(FontSize.Md)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTabIndex === index
          ? BrandColors.Brand500
          : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
    }
    .width('100%')
    .height(48)
    .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
    .borderRadius(SemanticRadius.Md)
    .backgroundColor(this.currentTabIndex === index
      ? (this.isDarkMode ? 'rgba(59,130,246,0.12)' : 'rgba(59,130,246,0.08)')
      : Color.Transparent)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.switchTab(index);
    })
  }

  /**
   * 底部Tab项（窄屏时显示）
   */
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
