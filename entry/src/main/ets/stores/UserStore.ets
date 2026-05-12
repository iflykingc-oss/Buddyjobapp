import { User } from '../models/User';
import { AuthService } from '../services/AuthService';
import { Storage } from '../utils/storage';

/**
 * 用户状态管理
 * 使用 AppStorage 进行全局状态存储
 * 使用 Storage 进行持久化存储（仅存储账号和VIP状态）
 */
export class UserStore {
  private static instance: UserStore;
  private authService: AuthService;

  private constructor() {
    this.authService = AuthService.getInstance();
  }

  static getInstance(): UserStore {
    if (!UserStore.instance) {
      UserStore.instance = new UserStore();
    }
    return UserStore.instance;
  }

  // 用户信息
  getUser(): User | null {
    return this.getUserInfo();
  }

  setUser(user: User): void {
    this.setUserInfo(user);
  }

  // 获取用户信息
  getUserInfo(): User | null {
    let userInfoStr = AppStorage.get<string>('userInfo');
    if (!userInfoStr) {
      // 从持久化存储读取
      userInfoStr = Storage.getInstance().getSync<string>('userInfo') as string;
      if (userInfoStr) {
        AppStorage.setOrCreate('userInfo', userInfoStr);
      }
    }
    if (userInfoStr) {
      try {
        return JSON.parse(userInfoStr) as User;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // 设置用户信息
  setUserInfo(userInfo: User): void {
    AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
    // 持久化到本地
    Storage.getInstance().setSync('userInfo', JSON.stringify(userInfo));
  }

  clearUser(): void {
    this.clearUserData();
  }

  // 登录状态
  isLoggedIn(): boolean {
    const token = this.getToken();
    return !!token;
  }

  // VIP 状态
  isVip(): boolean {
    const user = this.getUser();
    if (!user) return false;

    // 检查 VIP 是否过期
    if (user.vipExpireTime && user.vipExpireTime < Date.now()) {
      return false;
    }

    return user.vipLevel > 0;
  }

  // 获取 token
  getToken(): string | undefined {
    let token = AppStorage.get<string>('token');
    if (!token) {
      // 从持久化存储读取
      token = Storage.getInstance().getSync<string>('token') as string;
      if (token) {
        AppStorage.setOrCreate('token', token);
      }
    }
    return token;
  }

  // 设置 token
  setToken(token: string): void {
    AppStorage.setOrCreate('token', token);
    // 持久化到本地
    Storage.getInstance().setSync('token', token);
  }

  // 清除用户数据（退出登录时调用）
  clearUserData(): void {
    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('userInfo', null);
    Storage.getInstance().remove('token');
    Storage.getInstance().remove('userInfo');
  }

  // 清除登录状态
  async logout(): Promise<void> {
    await this.authService.logout();
    this.clearUserData();
  }

  // 刷新用户信息
  async refreshUser(): Promise<User | null> {
    try {
      const user = await this.authService.getUserInfo();
      this.setUserInfo(user);
      return user;
    } catch (error) {
      console.error('Refresh user failed:', error);
      return null;
    }
  }
}

// 全局用户状态观察者
export function useUserState(): User | null {
  return UserStore.getInstance().getUser();
}
