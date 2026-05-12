import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import { HMSUtils, HMSServiceType } from '../utils/hms';
import { AuthService } from '../services/AuthService';
import { PushService } from '../services/PushService';
import { agconnect } from '@hw-agconnect/core';
import { MultiApi } from '@mlethe/multi-api';

const TAG = 'EntryAbility';
const DOMAIN = 0x0001;

/**
 * AppGallery Connect 配置
 * 注意：需要在华为开发者联盟创建应用后获取以下配置
 */
const AGC_CONFIG = {
  // 从 AppGallery Connect 获取的 App ID
  appId: '',
  // 从 AppGallery Connect 获取的 API Key
  apiKey: '',
  // 从 AppGallery Connect 获取的 Client ID
  clientId: '',
  // 从 AppGallery Connect 获取的 Client Secret
  clientSecret: '',
  // 项目 ID
  projectId: '',
  // 包名
  packageName: 'com.buddyjob.app',
};

export default class EntryAbility extends UIAbility {
  private hmsUtils: HMSUtils = HMSUtils.getInstance();
  private authService: AuthService = AuthService.getInstance();
  private pushService: PushService = PushService.getInstance();

  onCreate(want, launchParam) {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');

    // 初始化全局配置
    AppStorage.setOrCreate('baseUrl', 'https://api.buddyjob.com');
    AppStorage.setOrCreate('apiVersion', 'v1');

    // 初始化 HMS 服务
    this.initializeHMS();
  }

  onDestroy() {
    hilog.info(DOMAIN, TAG, 'Ability on Destroy');

    // 清理 HMS 服务
    this.cleanupHMS();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // 加载主页面
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Splash', (err, data) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data));
    });
  }

  onWindowStageDestroy() {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground() {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');

    // MultiApi 前台生命周期处理
    MultiApi.instance.onForeground();

    // 应用切换到前台时，检查 HMS 服务状态
    this.checkHMSServices();
  }

  onBackground() {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  onNewWant(want, launchParam) {
    hilog.info(DOMAIN, TAG, 'Ability onNewWant');

    // MultiApi 处理 Want 回调
    MultiApi.instance.handleWant(want);
  }

  /**
   * 初始化 HMS 服务
   */
  private async initializeHMS(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Initializing HMS services...');

      // 1. 初始化 AppGallery Connect
      const agcInitialized = await this.hmsUtils.initializeAGC(this.context);
      if (!agcInitialized) {
        hilog.warn(DOMAIN, TAG, 'AGC initialization failed or not configured');
      } else {
        hilog.info(DOMAIN, TAG, 'AGC initialized successfully');
      }

      // 2. 检查 HMS Core 可用性
      const hmsAvailable = await this.hmsUtils.checkHMSCoreAvailability();
      if (!hmsAvailable) {
        hilog.warn(DOMAIN, TAG, 'HMS Core is not available');
        return;
      }

      // 3. 批量检查服务可用性
      const serviceResults = await this.hmsUtils.checkMultipleServices([
        HMSServiceType.ACCOUNT,
        HMSServiceType.PUSH,
        HMSServiceType.IAP,
      ]);

      hilog.info(DOMAIN, TAG, 'HMS Service availability: %{public}s', JSON.stringify(Object.fromEntries(serviceResults)));

      // 4. 初始化推送服务
      if (serviceResults.get(HMSServiceType.PUSH)) {
        await this.initializePushService();
      }

      // 5. 尝试静默登录（如果之前已登录过）
      if (serviceResults.get(HMSServiceType.ACCOUNT)) {
        await this.trySilentLogin();
      }

      hilog.info(DOMAIN, TAG, 'HMS services initialization completed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'HMS initialization failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 初始化推送服务
   */
  private async initializePushService(): Promise<void> {
    try {
      const pushInitialized = await this.pushService.init({
        autoGetToken: true,
        showNotification: true,
        onMessageClick: (message) => {
          hilog.info(DOMAIN, TAG, 'Push message clicked: %{public}s', message.messageId);
          // 可以在这里添加全局的消息点击处理逻辑
        },
      });

      if (pushInitialized) {
        hilog.info(DOMAIN, TAG, 'Push service initialized successfully');

        // 订阅系统通知主题
        await this.pushService.subscribeTopic('system_notifications');
        await this.pushService.subscribeTopic('chat_messages');
      } else {
        hilog.warn(DOMAIN, TAG, 'Push service initialization failed');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Push service initialization error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 尝试静默登录
   */
  private async trySilentLogin(): Promise<void> {
    try {
      // 检查是否已有华为账号登录信息
      const huaweiAccountInfo = this.authService.getHuaweiAccountInfo();
      if (huaweiAccountInfo) {
        hilog.info(DOMAIN, TAG, 'Found existing Huawei account, trying silent login...');
        const loginResult = await this.authService.silentLoginWithHuawei();
        if (loginResult) {
          hilog.info(DOMAIN, TAG, 'Silent login successful');
          AppStorage.setOrCreate('isLoggedIn', true);
        } else {
          hilog.warn(DOMAIN, TAG, 'Silent login failed, user needs to login again');
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Silent login error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 检查 HMS 服务状态
   */
  private async checkHMSServices(): Promise<void> {
    try {
      // 检查推送 token 是否有效
      const pushToken = this.pushService.getCurrentToken();
      if (!pushToken && this.pushService.isAvailable()) {
        hilog.info(DOMAIN, TAG, 'Push token not available, requesting new token...');
        await this.pushService.getPushToken();
      }

      // 刷新华为账号登录态
      if (this.authService.isHuaweiLoginAvailable() && this.authService.getHuaweiAccountInfo()) {
        await this.authService.refreshHuaweiToken();
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Check HMS services error: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 清理 HMS 服务
   */
  private async cleanupHMS(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Cleaning up HMS services...');

      // 销毁推送服务
      await this.pushService.destroy();

      hilog.info(DOMAIN, TAG, 'HMS services cleanup completed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'HMS cleanup error: %{public}s', JSON.stringify(error));
    }
  }
}
