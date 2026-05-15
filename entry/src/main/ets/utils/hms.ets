import { BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { agconnect } from '@hw-agconnect/core';
import { hmsAccount } from '@hw-agconnect/auth';
import { hmsPush } from '@hw-agconnect/push';

/**
 * HMS Core 错误码定义
 */
export class HMSErrorCode {
  static readonly SUCCESS: number = 0;
  static readonly UNKNOWN_ERROR: number = -1;
  static readonly TIMEOUT: number = -2;
  static readonly NETWORK_ERROR: number = -3;
  static readonly HMS_CORE_NOT_AVAILABLE: number = -4;
  static readonly HMS_VERSION_TOO_OLD: number = -5;
  static readonly ACCOUNT_AUTH_CANCELLED: number = 2012;
  static readonly ACCOUNT_AUTH_FAILED: number = 2013;
  static readonly ACCOUNT_AUTH_NETWORK_ERROR: number = 2014;
  static readonly ACCOUNT_AUTH_SERVICE_UNAVAILABLE: number = 2015;
  static readonly ACCOUNT_AUTH_TOKEN_EXPIRED: number = 2016;
  static readonly PAYMENT_CANCELLED: number = 60001;
  static readonly PAYMENT_FAILED: number = 60002;
  static readonly PAYMENT_PRODUCT_NOT_EXIST: number = 60003;
  static readonly PAYMENT_PRODUCT_ALREADY_OWNED: number = 60004;
  static readonly PAYMENT_USER_NOT_LOGIN: number = 60005;
  static readonly PUSH_TOKEN_INVALID: number = 70001;
  static readonly PUSH_SERVICE_ERROR: number = 70002;
  static readonly PUSH_NETWORK_ERROR: number = 70003;
}

/**
 * HMS Core 错误信息映射
 */
function getErrorMessageMap(): Map<number, string> {
  const map = new Map<number, string>();
  map.set(0, '操作成功');
  map.set(-1, '未知错误');
  map.set(-2, '请求超时');
  map.set(-3, '网络错误');
  map.set(-4, 'HMS Core 服务不可用');
  map.set(-5, 'HMS Core 版本过低');
  map.set(2012, '用户取消授权');
  map.set(2013, '授权失败');
  map.set(2014, '授权网络错误');
  map.set(2015, '账号服务不可用');
  map.set(2016, '登录态已过期');
  map.set(60001, '支付已取消');
  map.set(60002, '支付失败');
  map.set(60003, '商品不存在');
  map.set(60004, '已拥有该商品');
  map.set(60005, '用户未登录');
  map.set(70001, '推送令牌无效');
  map.set(70002, '推送服务错误');
  map.set(70003, '推送网络错误');
  return map;
}

const ErrorMessageMap = getErrorMessageMap();

/**
 * HMS Core 服务类型
 */
export enum HMSServiceType {
  ACCOUNT = 'account',
  PUSH = 'push',
  IAP = 'iap',
  ANALYTICS = 'analytics',
  CRASH = 'crash',
  ADS = 'ads',
}

/**
 * HMS Core 工具类
 */
export class HMSUtils {
  private static instance: HMSUtils;
  private serviceAvailability: Map<HMSServiceType, boolean> = new Map();
  private agcInstance: agconnect.AGConnectInstance | null = null;

  private constructor() {}

  static getInstance(): HMSUtils {
    if (!HMSUtils.instance) {
      HMSUtils.instance = new HMSUtils();
    }
    return HMSUtils.instance;
  }

  /**
   * 初始化 AppGallery Connect
   */
  async initializeAGC(context: Context): Promise<boolean> {
    try {
      this.agcInstance = agconnect.instance();
      if (!this.agcInstance) {
        await agconnect.initialize(context);
        this.agcInstance = agconnect.instance();
      }
      console.info('[HMSUtils] AGC initialized successfully');
      return true;
    } catch (error) {
      console.error('[HMSUtils] AGC initialization failed:', error);
      return false;
    }
  }

  /**
   * 获取 AGC 实例
   */
  getAGCInstance(): agconnect.AGConnectInstance | null {
    return this.agcInstance;
  }

  /**
   * 检查 HMS Core 是否可用
   */
  async checkHMSCoreAvailability(): Promise<boolean> {
    try {
      // 检查 AGC 是否已初始化
      if (!this.agcInstance) {
        return false;
      }
      return true;
    } catch (error) {
      console.error('[HMSUtils] HMS Core availability check failed:', error);
      return false;
    }
  }

  /**
   * 检查特定 HMS 服务是否可用
   */
  async checkServiceAvailability(serviceType: HMSServiceType): Promise<boolean> {
    try {
      let isAvailable = false;

      switch (serviceType) {
        case HMSServiceType.ACCOUNT:
          isAvailable = await hmsAccount.isAuthServiceAvailable();
          break;
        case HMSServiceType.PUSH:
          isAvailable = await hmsPush.isPushServiceAvailable();
          break;
        case HMSServiceType.IAP:
          // IAP 服务可用性检查
          isAvailable = false; // 暂不支持
          break;
        default:
          isAvailable = false;
      }

      this.serviceAvailability.set(serviceType, isAvailable);
      return isAvailable;
    } catch (error) {
      console.error(`[HMSUtils] Check ${serviceType} availability failed:`, error);
      this.serviceAvailability.set(serviceType, false);
      return false;
    }
  }

  /**
   * 批量检查服务可用性
   */
  async checkMultipleServices(serviceTypes: HMSServiceType[]): Promise<Map<HMSServiceType, boolean>> {
    const results = new Map<HMSServiceType, boolean>();
    for (let i = 0; i < serviceTypes.length; i++) {
      const type = serviceTypes[i];
      const available = await this.checkServiceAvailability(type);
      results.set(type, available);
    }
    return results;
  }

  /**
   * 获取错误信息
   */
  getErrorMessage(errorCode: number): string {
    return ErrorMessageMap.get(errorCode) || `未知错误 (代码: ${errorCode})`;
  }

  /**
   * 处理 HMS 错误
   */
  handleHMSError(error: BusinessError | Error | Object, showToast: boolean = true): string {
    let errorCode = HMSErrorCode.UNKNOWN_ERROR;
    let errorMessage = '操作失败';

    if (error && typeof error === 'object') {
      const errorObj = error as Record<string, Object>;
      if (errorObj.code !== undefined) {
        errorCode = errorObj.code as number;
        errorMessage = this.getErrorMessage(errorCode);
      } else if (errorObj.message !== undefined) {
        errorMessage = errorObj.message as string;
      }
    } else if (typeof error === 'string') {
      errorMessage = error;
    }

    console.error('[HMSUtils] Error:', { code: errorCode, message: errorMessage });

    if (showToast) {
      promptAction.showToast({
        message: errorMessage,
        duration: 2000,
      });
    }

    return errorMessage;
  }

  /**
   * 申请权限
   */
  async requestPermissions(permissions: Permissions[]): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const authResults = await atManager.requestPermissionsFromUser(
        getContext(this),
        permissions
      );

      // 检查所有权限是否都已授权
      const allGranted = authResults.authResults.every(result => result === 0);
      return allGranted;
    } catch (error) {
      console.error('[HMSUtils] Request permissions failed:', error);
      return false;
    }
  }

  /**
   * 检查权限
   */
  async checkPermissions(permissions: Permissions[]): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const tokenId = getContext(this).applicationInfo.accessTokenId;

      for (let i = 0; i < permissions.length; i++) {
        const permission = permissions[i];
        const authStatus = await atManager.checkAccessToken(tokenId, permission);
        if (authStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (error) {
      console.error('[HMSUtils] Check permissions failed:', error);
      return false;
    }
  }

  /**
   * 获取 HMS Core 版本号
   */
  async getHMSCoreVersion(): Promise<string | null> {
    try {
      if (this.agcInstance) {
        const version = this.agcInstance.getSDKVersion();
        return version || null;
      }
      return null;
    } catch (error) {
      console.error('[HMSUtils] Get HMS Core version failed:', error);
      return null;
    }
  }

  /**
   * 检查服务是否已初始化
   */
  isServiceAvailable(serviceType: HMSServiceType): boolean {
    return this.serviceAvailability.get(serviceType) || false;
  }
}

/**
 * HMS 账号服务工具类
 */
export class HMSAccountUtils {
  /**
   * 华为账号静默登录（无需用户交互）
   * 适用于已授权过的用户
   */
  static async silentSignIn(): Promise<hmsAccount.SignInResult | null> {
    try {
      const result = await hmsAccount.silentSignIn();
      if (result && result.accessToken) {
        console.info('[HMSAccountUtils] Silent sign in success');
        return result;
      }
      return null;
    } catch (error) {
      console.error('[HMSAccountUtils] Silent sign in failed:', error);
      return null;
    }
  }

  /**
   * 华为账号授权登录（带界面）
   */
  static async signIn(scopes?: string[]): Promise<hmsAccount.SignInResult> {
    try {
      const signInOptions: hmsAccount.SignInOptions = {
        scopes: scopes || ['openid', 'profile'],
      };
      const result = await hmsAccount.signIn(signInOptions);
      console.info('[HMSAccountUtils] Sign in success');
      return result;
    } catch (error) {
      console.error('[HMSAccountUtils] Sign in failed:', error);
      throw new Error('Sign in failed');
    }
  }

  /**
   * 获取华为账号信息
   */
  static async getAccountInfo(): Promise<hmsAccount.AccountInfo | null> {
    try {
      const result = await hmsAccount.getAccountInfo();
      return result;
    } catch (error) {
      console.error('[HMSAccountUtils] Get account info failed:', error);
      return null;
    }
  }

  /**
   * 退出华为账号登录
   */
  static async signOut(): Promise<boolean> {
    try {
      await hmsAccount.signOut();
      console.info('[HMSAccountUtils] Sign out success');
      return true;
    } catch (error) {
      console.error('[HMSAccountUtils] Sign out failed:', error);
      return false;
    }
  }

  /**
   * 取消华为账号授权
   */
  static async cancelAuthorization(): Promise<boolean> {
    try {
      await hmsAccount.cancelAuthorization();
      console.info('[HMSAccountUtils] Cancel authorization success');
      return true;
    } catch (error) {
      console.error('[HMSAccountUtils] Cancel authorization failed:', error);
      return false;
    }
  }
}

/**
 * HMS 推送服务工具类
 */
export class HMSPushUtils {
  private static tokenCallback: ((token: string) => void) | null = null;
  private static messageCallback: ((message: hmsPush.PushMessage) => void) | null = null;

  /**
   * 获取推送 Token
   */
  static async getToken(): Promise<string | null> {
    try {
      const token = await hmsPush.getToken();
      console.info('[HMSPushUtils] Get token success:', token.substring(0, 10) + '...');
      return token;
    } catch (error) {
      console.error('[HMSPushUtils] Get token failed:', error);
      return null;
    }
  }

  /**
   * 删除推送 Token
   */
  static async deleteToken(): Promise<boolean> {
    try {
      await hmsPush.deleteToken();
      console.info('[HMSPushUtils] Delete token success');
      return true;
    } catch (error) {
      console.error('[HMSPushUtils] Delete token failed:', error);
      return false;
    }
  }

  /**
   * 订阅主题
   */
  static async subscribeTopic(topic: string): Promise<boolean> {
    try {
      await hmsPush.subscribeTopic(topic);
      console.info('[HMSPushUtils] Subscribe topic success:', topic);
      return true;
    } catch (error) {
      console.error('[HMSPushUtils] Subscribe topic failed:', error);
      return false;
    }
  }

  /**
   * 取消订阅主题
   */
  static async unsubscribeTopic(topic: string): Promise<boolean> {
    try {
      await hmsPush.unsubscribeTopic(topic);
      console.info('[HMSPushUtils] Unsubscribe topic success:', topic);
      return true;
    } catch (error) {
      console.error('[HMSPushUtils] Unsubscribe topic failed:', error);
      return false;
    }
  }

  /**
   * 注册 Token 回调
   */
  static onToken(callback: (token: string) => void): void {
    HMSPushUtils.tokenCallback = callback;
    hmsPush.onToken((token: string) => {
      console.info('[HMSPushUtils] Token received:', token.substring(0, 10) + '...');
      if (HMSPushUtils.tokenCallback) {
        HMSPushUtils.tokenCallback(token);
      }
    });
  }

  /**
   * 注册消息接收回调
   */
  static onMessage(callback: (message: hmsPush.PushMessage) => void): void {
    HMSPushUtils.messageCallback = callback;
    hmsPush.onMessage((message: hmsPush.PushMessage) => {
      console.info('[HMSPushUtils] Message received:', message);
      if (HMSPushUtils.messageCallback) {
        HMSPushUtils.messageCallback(message);
      }
    });
  }

  /**
   * 注册消息点击回调
   */
  static onMessageClicked(callback: (message: hmsPush.PushMessage) => void): void {
    hmsPush.onMessageClicked((message: hmsPush.PushMessage) => {
      console.info('[HMSPushUtils] Message clicked:', message);
      callback(message);
    });
  }

  /**
   * 取消注册回调
   */
  static offAll(): void {
    HMSPushUtils.tokenCallback = null;
    HMSPushUtils.messageCallback = null;
    hmsPush.offToken();
    hmsPush.offMessage();
    hmsPush.offMessageClicked();
  }
}

/**
 * HMS 权限配置
 */
export class HMSPermissions {
  static readonly PUSH: Permissions[] = [
    'ohos.permission.INTERNET',
    'ohos.permission.GET_NETWORK_INFO',
  ];

  static readonly ACCOUNT: Permissions[] = [
    'ohos.permission.INTERNET',
  ];

  static readonly IAP: Permissions[] = [
    'ohos.permission.INTERNET',
    'ohos.permission.GET_NETWORK_INFO',
  ];

  static readonly ALL: Permissions[] = [
    'ohos.permission.INTERNET',
    'ohos.permission.GET_NETWORK_INFO',
  ];
}

/**
 * HMS 配置常量
 */
export class HMSConfig {
  static readonly TIMEOUT: number = 30000;
  static readonly MAX_RETRY_COUNT: number = 3;
  static readonly RETRY_DELAY: number = 1000;
  static readonly TOKEN_REFRESH_THRESHOLD: number = 5 * 60 * 1000;
}

export default HMSUtils.getInstance();
