import { AppStore } from '../stores/AppStore';
import { ConnectionType } from '../utils/NetworkUtil';
import {
  BrandColors,
  SemanticColors,
  DarkSemanticColors,
  WarningColors,
  DarkWarningColors,
  Spacing,
  FontSize,
  FontWeight,
  Duration,
  ZIndex
} from '../constants/design-tokens';

/**
 * 网络状态横幅组件
 * 当网络断开时从顶部滑入显示，网络恢复时自动隐藏
 */
@Component
export struct NetworkStatusBanner {
  // 是否显示横幅
  @State isVisible: boolean = false;
  // 横幅 Y 轴偏移量（用于动画）
  @State translateY: number = -60;
  // 上一次是否在线
  private wasOnline: boolean = true;
  // 自动隐藏定时器
  private autoHideTimer: number | null = null;
  // AppStore 实例
  private appStore: AppStore = AppStore.getInstance();
  // 定时器 ID
  private timerController: number = 0;

  // 获取暗黑模式
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  // 获取网络状态
  @StorageLink('isOnline') isOnline: boolean = true;
  @StorageLink('connectionType') connectionType: string = ConnectionType.UNKNOWN;

  // 监听网络状态变化
  @Watch('onNetworkChange')
  @StorageLink('isOnline') isOnlineWatched: boolean = true;

  aboutToAppear(): void {
    // 初始化检查网络状态
    this.wasOnline = this.appStore.isOnline();
    this.isVisible = !this.wasOnline;
    this.translateY = this.wasOnline ? -60 : 0;
  }

  aboutToDisappear(): void {
    // 清理定时器
    if (this.autoHideTimer !== null) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = null;
    }
  }

  /**
   * 网络状态变化回调
   */
  onNetworkChange() {
    const currentOnline = this.isOnline;

    if (!currentOnline && this.wasOnline) {
      // 网络断开：显示横幅
      this.showBanner();
    } else if (currentOnline && !this.wasOnline) {
      // 网络恢复：延迟隐藏横幅
      this.scheduleHideBanner();
    }

    this.wasOnline = currentOnline;
  }

  /**
   * 显示横幅
   */
  showBanner(): void {
    if (this.autoHideTimer !== null) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = null;
    }

    this.isVisible = true;
    animateTo({
      duration: Duration.Normal,
      curve: Curve.EaseOut,
    }, () => {
      this.translateY = 0;
    });
  }

  /**
   * 延迟隐藏横幅（3秒后）
   */
  scheduleHideBanner(): void {
    // 延迟 3 秒后隐藏
    this.autoHideTimer = setTimeout(() => {
      this.hideBanner();
      this.autoHideTimer = null;
    }, 3000) as number;
  }

  /**
   * 隐藏横幅
   */
  hideBanner(): void {
    animateTo({
      duration: Duration.Normal,
      curve: Curve.EaseIn,
    }, () => {
      this.translateY = -60;
    });

    setTimeout(() => {
      this.isVisible = false;
    }, Duration.Normal);
  }

  /**
   * 获取网络类型描述
   */
  getConnectionTypeText(): string {
    const type = this.connectionType as ConnectionType;
    switch (type) {
      case ConnectionType.WIFI:
        return 'WiFi';
      case ConnectionType.CELLULAR:
        return '移动数据';
      case ConnectionType.ETHERNET:
        return '以太网';
      case ConnectionType.NONE:
        return '无网络';
      case ConnectionType.UNKNOWN:
      default:
        return '网络';
    }
  }

  /**
   * 获取警告色
   */
  getWarningBackgroundColor(): ResourceColor {
    if (this.isDarkMode) {
      return DarkWarningColors.Warning50;
    }
    return WarningColors.Warning50;
  }

  /**
   * 获取警告文字色
   */
  getWarningTextColor(): ResourceColor {
    if (this.isDarkMode) {
      return DarkWarningColors.Warning900;
    }
    return WarningColors.Warning900;
  }

  /**
   * 获取图标色
   */
  getIconColor(): ResourceColor {
    if (this.isDarkMode) {
      return DarkWarningColors.Warning500;
    }
    return WarningColors.Warning500;
  }

  build() {
    // 离线时显示横幅
    if (!this.isOnline) {
      Row() {
        // 警告图标
        Image($r('app.media.ic_network_off'))
          .width(20)
          .height(20)
          .fillColor(this.getIconColor())
          .margin({ right: Spacing.Space2 })

        // 提示文字
        Text('网络连接已断开')
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getWarningTextColor())

        // 网络类型（可选）
        if (this.connectionType !== ConnectionType.NONE) {
          Text(`(${this.getConnectionTypeText()})`)
            .fontSize(FontSize.Xs)
            .fontColor(this.getWarningTextColor())
            .opacity(0.8)
            .margin({ left: Spacing.Space1 })
        }

        Blank()

        // 重新连接指示器
        if (!this.isOnline) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(this.getIconColor())
        }
      }
      .width('100%')
      .height(48)
      .padding({
        left: Spacing.Space4,
        right: Spacing.Space4
      })
      .backgroundColor(this.getWarningBackgroundColor())
      .transition(TransitionEffect.OPACITY.animation({
        duration: Duration.Normal
      }))
      .alignItems(VerticalAlign.Center)
      .translate({ y: this.translateY })
    }
  }
}

/**
 * 网络状态横幅的简洁版本
 * 适用于不需要复杂动画的场景
 */
@Component
export struct SimpleNetworkBanner {
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('isOnline') isOnline: boolean = true;

  build() {
    if (!this.isOnline) {
      Column() {
        Row() {
          Image($r('app.media.ic_network_off'))
            .width(18)
            .height(18)
            .fillColor(this.isDarkMode ? DarkWarningColors.Warning500 : WarningColors.Warning500)

          Text('网络连接已断开')
            .fontSize(FontSize.Sm)
            .fontColor(this.isDarkMode ? DarkWarningColors.Warning900 : WarningColors.Warning900)
            .margin({ left: Spacing.Space2 })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({
        top: Spacing.Space2,
        bottom: Spacing.Space2,
        left: Spacing.Space4,
        right: Spacing.Space4
      })
      .backgroundColor(this.isDarkMode ? DarkWarningColors.Warning50 : WarningColors.Warning50)
    }
  }
}

/**
 * 网络状态徽章组件
 * 在界面上显示当前网络状态
 */
@Component
export struct NetworkStatusBadge {
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  @StorageLink('isOnline') isOnline: boolean = true;
  @StorageLink('connectionType') connectionType: string = ConnectionType.UNKNOWN;

  build() {
    Row({ space: 4 }) {
      // 状态指示点
      Circle()
        .width(8)
        .height(8)
        .fill(this.isOnline
          ? (this.isDarkMode ? DarkSemanticColors.Success : SemanticColors.Success)
          : (this.isDarkMode ? DarkWarningColors.Warning500 : WarningColors.Warning500))

      // 网络类型文字
      Text(this.getStatusText())
        .fontSize(FontSize.Xs)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
    }
    .padding({
      left: Spacing.Space2,
      right: Spacing.Space2,
      top: Spacing.Space1,
      bottom: Spacing.Space1
    })
    .backgroundColor(this.isDarkMode
      ? DarkSemanticColors.Surface2
      : SemanticColors.Surface2)
    .borderRadius(Spacing.Space3)
  }

  getStatusText(): string {
    if (!this.isOnline) {
      return '离线';
    }

    const type = this.connectionType as ConnectionType;
    switch (type) {
      case ConnectionType.WIFI:
        return 'WiFi';
      case ConnectionType.CELLULAR:
        return '4G/5G';
      case ConnectionType.ETHERNET:
        return '有线';
      default:
        return '在线';
    }
  }
}

export default NetworkStatusBanner;
