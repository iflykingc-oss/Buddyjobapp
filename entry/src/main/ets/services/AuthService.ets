import { ApiService } from './ApiService';
import { LoginParams, LoginResult, User } from '../models/User';
import { API_ENDPOINTS } from '../constants/config';
import { HMSUtils, HMSErrorCode, HMSServiceType, HMSConfig, HMSAccountUtils } from '../utils/hms';
import promptAction from '@ohos.promptAction';
import { hmsAccount } from '@hw-agconnect/auth';

/**
 * 华为账号授权参数
 */
export interface HuaweiAuthParams {
  // 授权类型
  authType: 'silent' | 'id' | 'authorizationCode';
  // 是否需要获取手机号
  needPhone?: boolean;
  // 额外权限
  extraScopes?: string[];
}

/**
 * 华为账号信息
 */
export interface HuaweiAccountInfo {
  openId: string;
  unionId: string;
  displayName: string;
  photoUrl?: string;
  email?: string;
  phone?: string;
  authorizationCode?: string;
  accessToken?: string;
  expireTime: number;
}

/**
 * 认证服务 - 支持华为账号登录和手机号登录
 */
export class AuthService {
  private apiService: ApiService;
  private hmsUtils: HMSUtils;
  private static instance: AuthService;
  private isHuaweiAuthAvailable: boolean = false;
  private tokenRefreshTimer: number | null = null;

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.hmsUtils = HMSUtils.getInstance();
    this.initHuaweiAuth();
  }

  static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  /**
   * 初始化华为账号服务
   */
  private async initHuaweiAuth(): Promise<void> {
    try {
      this.isHuaweiAuthAvailable = await this.hmsUtils.checkServiceAvailability(HMSServiceType.ACCOUNT);
      if (this.isHuaweiAuthAvailable) {
        console.info('[AuthService] Huawei Account Kit is available');
        // 设置登录态刷新定时器
        this.setupTokenRefreshTimer();
      } else {
        console.warn('[AuthService] Huawei Account Kit is not available');
      }
    } catch (error) {
      console.error('[AuthService] Failed to init Huawei Auth:', error);
      this.isHuaweiAuthAvailable = false;
    }
  }

  /**
   * 检查华为账号服务是否可用
   */
  isHuaweiLoginAvailable(): boolean {
    return this.isHuaweiAuthAvailable;
  }

  /**
   * 华为账号静默登录（无需用户交互）
   * 适用于已授权过的用户
   */
  async silentLoginWithHuawei(): Promise<LoginResult | null> {
    if (!this.isHuaweiAuthAvailable) {
      console.warn('[AuthService] Huawei Account Kit not available');
      return null;
    }

    try {
      const result: hmsAccount.SignInResult | null = await HMSAccountUtils.silentSignIn();

      if (result && result.accessToken) {
        console.info('[AuthService] Huawei silent sign in success');
        const accountInfo = this.parseHuaweiAccountInfo(result);
        return await this.loginWithHuaweiAccount(accountInfo);
      }

      return null;
    } catch (error) {
      console.error('[AuthService] Huawei silent login failed:', error);
      return null;
    }
  }

  /**
   * 华为账号一键登录（带界面）
   */
  async loginWithHuawei(params?: HuaweiAuthParams): Promise<LoginResult> {
    if (!this.isHuaweiAuthAvailable) {
      throw new Error('华为账号服务不可用');
    }

    try {
      // 先尝试静默登录
      const silentResult = await this.silentLoginWithHuawei();
      if (silentResult) {
        return silentResult;
      }

      // 静默登录失败，唤起授权界面
      const scopes = params?.extraScopes || ['openid', 'profile'];
      const result = await HMSAccountUtils.signIn(scopes);

      if (!result) {
        throw new Error('获取华为账号信息失败');
      }

      const accountInfo = this.parseHuaweiAccountInfo(result);

      // 如果需要手机号且未获取到，额外请求
      if (params?.needPhone && !accountInfo.phone) {
        accountInfo.phone = await this.getHuaweiPhoneNumber();
      }

      return await this.loginWithHuaweiAccount(accountInfo);
    } catch (error) {
      console.error('[AuthService] Huawei login failed:', error);
      this.hmsUtils.handleHMSError(error);
      throw new Error(String(error));
    }
  }

  /**
   * 获取华为账号手机号（需要额外授权）
   */
  private async getHuaweiPhoneNumber(): Promise<string | undefined> {
    try {
      // 华为账号 SDK 不直接提供手机号获取，需要通过后端交换
      // 这里返回 undefined，实际手机号需要通过后端获取
      console.info('[AuthService] Phone number should be obtained from backend');
      return undefined;
    } catch (error) {
      console.error('[AuthService] Get phone number failed:', error);
      return undefined;
    }
  }

  /**
   * 解析华为账号信息
   */
  private parseHuaweiAccountInfo(data: hmsAccount.SignInResult): HuaweiAccountInfo {
    return {
      openId: data.openId || '',
      unionId: data.unionId || '',
      displayName: data.displayName || data.nickName || '华为用户',
      photoUrl: data.photoUriString || data.avatarUriString,
      email: data.email,
      phone: data.phoneNumber,
      authorizationCode: data.authorizationCode,
      accessToken: data.accessToken,
      expireTime: data.expireTime || Date.now() + 3600 * 1000, // 默认1小时
    };
  }

  /**
   * 使用华为账号信息登录后端
   */
  private async loginWithHuaweiAccount(accountInfo: HuaweiAccountInfo): Promise<LoginResult> {
    const loginData: HuaweiLoginRequest = {
      openId: accountInfo.openId,
      unionId: accountInfo.unionId,
      authorizationCode: accountInfo.authorizationCode || '',
      accessToken: accountInfo.accessToken || '',
      displayName: accountInfo.displayName,
      photoUrl: accountInfo.photoUrl || '',
      email: accountInfo.email || '',
      phone: accountInfo.phone || ''
    };

    const response = await this.apiService.post<LoginResult>(
      API_ENDPOINTS.LOGIN + '/huawei',
      loginData
    );

    if (!response.success || !response.data) {
      const errorMsg = typeof response.error === 'string' ? response.error : '华为账号登录失败';
      throw new Error(errorMsg);
    }

    // 保存 token 和用户信息
    this.apiService.setToken(response.data.token);
    AppStorage.setOrCreate('userInfo', JSON.stringify(response.data.userInfo));
    AppStorage.setOrCreate('huaweiAccountInfo', JSON.stringify(accountInfo));

    // 设置登录态刷新
    this.setupTokenRefreshTimer();

    return response.data;
  }

  /**
   * 刷新华为登录态
   */
  async refreshHuaweiToken(): Promise<boolean> {
    if (!this.isHuaweiAuthAvailable) {
      return false;
    }

    try {
      const result = await HMSAccountUtils.silentSignIn();

      if (result && result.accessToken) {
        const accountInfo = this.parseHuaweiAccountInfo(result);

        // 更新本地存储的华为账号信息
        AppStorage.setOrCreate('huaweiAccountInfo', JSON.stringify(accountInfo));

        // 通知后端刷新
        const refreshData = {
          openId: accountInfo.openId,
          accessToken: accountInfo.accessToken || ''
        } as Record<string, Object>;
        await this.apiService.post<Record<string, Object>>(API_ENDPOINTS.LOGIN + '/huawei/refresh', refreshData);

        console.info('[AuthService] Huawei token refreshed successfully');
        return true;
      }

      return false;
    } catch (error) {
      console.error('[AuthService] Refresh Huawei token failed:', error);
      return false;
    }
  }

  /**
   * 设置登录态刷新定时器
   */
  private setupTokenRefreshTimer(): void {
    // 清除旧定时器
    if (this.tokenRefreshTimer) {
      clearInterval(this.tokenRefreshTimer);
    }

    // 获取存储的华为账号信息
    const accountInfoStr = AppStorage.get<string>('huaweiAccountInfo');
    if (!accountInfoStr) {
      return;
    }

    try {
      const accountInfo: HuaweiAccountInfo = JSON.parse(accountInfoStr);
      const now = Date.now();
      const expireTime = accountInfo.expireTime;

      // 如果已过期或即将过期，立即刷新
      if (expireTime - now < HMSConfig.TOKEN_REFRESH_THRESHOLD) {
        this.refreshHuaweiToken();
      }

      // 设置定时检查（每10分钟检查一次）
      this.tokenRefreshTimer = setInterval(() => {
        const currentAccountStr = AppStorage.get<string>('huaweiAccountInfo');
        if (currentAccountStr) {
          const currentAccount: HuaweiAccountInfo = JSON.parse(currentAccountStr);
          if (currentAccount.expireTime - Date.now() < HMSConfig.TOKEN_REFRESH_THRESHOLD) {
            this.refreshHuaweiToken();
          }
        }
      }, 10 * 60 * 1000); // 10分钟

    } catch (error) {
      console.error('[AuthService] Setup token refresh timer failed:', error);
    }
  }

  /**
   * 发送验证码（手机号登录）
   */
  async sendCode(phone: string): Promise<void> {
    const response = await this.apiService.post<Record<string, Object>>(API_ENDPOINTS.SEND_CODE, {
      phone: phone,
      type: 'login'
    } as Record<string, Object>);

    if (!response.success) {
      throw new Error(response.error || '发送验证码失败');
    }
  }

  /**
   * 验证码登录（手机号登录）
   */
  async loginWithCode(phone: string, code: string): Promise<LoginResult> {
    const response = await this.apiService.post<LoginResult>(API_ENDPOINTS.LOGIN, {
      phone: phone,
      code: code
    } as Record<string, Object>);

    if (!response.success || !response.data) {
      throw new Error(response.error || '登录失败');
    }

    // 保存 token
    this.apiService.setToken(response.data.token);
    AppStorage.setOrCreate('userInfo', JSON.stringify(response.data.userInfo));

    return response.data;
  }

  /**
   * 获取用户信息
   */
  async getUserInfo(): Promise<User> {
    const response = await this.apiService.get<User>(API_ENDPOINTS.USER_INFO);

    if (!response.success || !response.data) {
      throw new Error(response.error || '获取用户信息失败');
    }

    return response.data;
  }

  /**
   * 更新用户信息
   */
  async updateUser(userData: Partial<User>): Promise<User> {
    const response = await this.apiService.post<User>(API_ENDPOINTS.UPDATE_USER, userData);

    if (!response.success || !response.data) {
      throw new Error(response.error || '更新用户信息失败');
    }

    return response.data;
  }

  /**
   * 退出登录
   */
  async logout(): Promise<void> {
    try {
      // 如果是华为账号登录，先退出华为账号
      if (this.isHuaweiAuthAvailable && AppStorage.get<string>('huaweiAccountInfo')) {
        try {
          await HMSAccountUtils.signOut();
        } catch (e) {
          console.warn('[AuthService] Huawei sign out failed:', e);
        }
      }

      await this.apiService.post<Record<string, Object>>(API_ENDPOINTS.LOGOUT, new Object() as Record<string, Object>);
    } finally {
      // 清除定时器
      if (this.tokenRefreshTimer) {
        clearInterval(this.tokenRefreshTimer);
        this.tokenRefreshTimer = null;
      }

      // 清除本地数据
      this.apiService.clearToken();
      AppStorage.delete('userInfo');
      AppStorage.delete('huaweiAccountInfo');
      AppStorage.delete('chatHistory');
    }
  }

  /**
   * 检查登录状态
   */
  isLoggedIn(): boolean {
    const token = AppStorage.get<string>('token');
    return !!token;
  }

  /**
   * 获取当前用户信息（从本地存储）
   */
  getLocalUserInfo(): User | null {
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        return JSON.parse(userStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /**
   * 获取华为账号信息
   */
  getHuaweiAccountInfo(): HuaweiAccountInfo | null {
    const accountStr = AppStorage.get<string>('huaweiAccountInfo');
    if (accountStr) {
      try {
        return JSON.parse(accountStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /**
   * 取消华为账号授权（注销）
   */
  async cancelHuaweiAuthorization(): Promise<boolean> {
    if (!this.isHuaweiAuthAvailable) {
      return false;
    }

    try {
      return await HMSAccountUtils.cancelAuthorization();
    } catch (error) {
      console.error('[AuthService] Cancel authorization failed:', error);
      return false;
    }
  }
}

export default AuthService.getInstance();
