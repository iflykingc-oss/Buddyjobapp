/**
 * 会员服务 - 会员中心业务逻辑
 * 
 * 提供会员状态查询、权益管理、购买流程等功能
 */

import { ApiService } from './ApiService';
import { PaymentService, PurchaseResult, SubscriptionStatus } from './PaymentService';
import { API_ENDPOINTS } from '../constants/config';
import { Storage } from '../utils/storage';

/**
 * 会员等级枚举
 */
export enum MemberLevel {
  NONE = 0,       // 非会员
  MONTHLY = 1,    // 月度会员
  QUARTERLY = 2,  // 季度会员
  YEARLY = 3,     // 年度会员
}

/**
 * 会员状态
 */
export interface MemberStatus {
  isMember: boolean;
  level: MemberLevel;
  levelName: string;
  expireTime: number;
  remainingDays: number;
  autoRenewing: boolean;
  productId: string;
  subscriptionId?: string;
}

/**
 * 权益项定义
 */
export interface Benefit {
  id: string;
  name: string;
  icon: string;
  description: string;
  isActive: boolean;
  usageCount?: number;
  usageLimit?: number;
}

/**
 * 套餐定义
 */
export interface Package {
  id: string;
  productId: string;
  name: string;
  price: number;
  originalPrice: number;
  duration: number; // 天数
  period: string;
  tag?: string; // 推荐标签
  discount?: string; // 折扣文案
}

/**
 * 使用记录
 */
export interface UsageRecord {
  id: string;
  benefitId: string;
  benefitName: string;
  usedAt: number;
  detail: string;
}

/**
 * 会员服务类
 */
export class MemberService {
  private static instance: MemberService;
  private apiService: ApiService;
  private paymentService: PaymentService;
  private memberStatus: MemberStatus | null = null;
  private benefits: Benefit[] = [];
  
  // 套餐定义
  private packages: Package[] = [
    {
      id: 'monthly',
      productId: 'vip_monthly',
      name: '月度会员',
      price: 19.9,
      originalPrice: 29.9,
      duration: 30,
      period: '月',
      discount: '省10元'
    },
    {
      id: 'quarterly',
      productId: 'vip_quarterly',
      name: '季度会员',
      price: 49.9,
      originalPrice: 89.7,
      duration: 90,
      period: '季',
      tag: '推荐',
      discount: '省40元'
    },
    {
      id: 'yearly',
      productId: 'vip_yearly',
      name: '年度会员',
      price: 168.0,
      originalPrice: 358.8,
      duration: 365,
      period: '年',
      tag: '最划算',
      discount: '省190元'
    }
  ];
  
  // 默认权益定义
  private defaultBenefits: Benefit[] = [
    {
      id: 'resume_analyze',
      name: '简历分析',
      icon: 'ic_resume',
      description: '无限次AI简历分析',
      isActive: false,
      usageLimit: -1 // -1 表示无限制
    },
    {
      id: 'job_assess',
      name: '岗位测评',
      icon: 'ic_assessment',
      description: '无限次岗位匹配测评',
      isActive: false,
      usageLimit: -1
    },
    {
      id: 'ai_chat',
      name: 'AI对话',
      icon: 'ic_chat',
      description: 'AI对话优先响应',
      isActive: false,
      usageLimit: -1
    },
    {
      id: 'career_report',
      name: '职业规划',
      icon: 'ic_knowledge',
      description: '专属职业规划报告',
      isActive: false,
      usageLimit: 3
    },
    {
      id: 'resume_polish',
      name: '简历润色',
      icon: 'ic_favorite',
      description: 'AI智能润色简历',
      isActive: false,
      usageLimit: 10
    },
    {
      id: 'priority_support',
      name: '专属客服',
      icon: 'ic_help',
      description: '优先客服支持',
      isActive: false,
      usageLimit: -1
    }
  ];

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.paymentService = PaymentService.getInstance();
    this.loadCachedStatus();
  }

  static getInstance(): MemberService {
    if (!MemberService.instance) {
      MemberService.instance = new MemberService();
    }
    return MemberService.instance;
  }

  /**
   * 获取会员状态
   */
  async getMemberStatus(): Promise<MemberStatus> {
    try {
      // 先从本地缓存获取
      if (this.memberStatus) {
        return this.memberStatus;
      }
      
      // 从服务器获取
      const response = await this.apiService.get<MemberStatus>(
        API_ENDPOINTS.USER_INFO + '/member'
      );
      
      if (response.success && response.data) {
        this.memberStatus = response.data;
        this.cacheMemberStatus(response.data);
        return response.data;
      }
      
      // 返回默认非会员状态
      return this.getDefaultStatus();
    } catch (error) {
      console.error('[MemberService] Get member status failed:', error);
      return this.memberStatus || this.getDefaultStatus();
    }
  }

  /**
   * 从本地缓存加载状态
   */
  private loadCachedStatus(): void {
    try {
      const cached = Storage.getInstance().getSync<string>('memberStatus');
      if (cached) {
        this.memberStatus = JSON.parse(cached);
      }
    } catch (e) {
      // ignore
    }
  }

  /**
   * 缓存会员状态
   */
  private cacheMemberStatus(status: MemberStatus): void {
    try {
      Storage.getInstance().setSync('memberStatus', JSON.stringify(status));
    } catch (e) {
      // ignore
    }
  }

  /**
   * 获取默认非会员状态
   */
  private getDefaultStatus(): MemberStatus {
    return {
      isMember: false,
      level: MemberLevel.NONE,
      levelName: '非会员',
      expireTime: 0,
      remainingDays: 0,
      autoRenewing: false,
      productId: ''
    };
  }

  /**
   * 检查是否是会员
   */
  isMember(): boolean {
    const status = this.memberStatus;
    if (!status) return false;
    return status.isMember && status.expireTime > Date.now();
  }

  /**
   * 获取会员等级名称
   */
  getLevelName(): string {
    const status = this.memberStatus;
    if (!status || !status.isMember) return '非会员';
    
    switch (status.level) {
      case MemberLevel.MONTHLY:
        return '月度会员';
      case MemberLevel.QUARTERLY:
        return '季度会员';
      case MemberLevel.YEARLY:
        return '年度会员';
      default:
        return '会员';
    }
  }

  /**
   * 获取剩余天数
   */
  getRemainingDays(): number {
    const status = this.memberStatus;
    if (!status || !status.isMember) return 0;
    
    const remaining = Math.ceil((status.expireTime - Date.now()) / (24 * 60 * 60 * 1000));
    return Math.max(0, remaining);
  }

  /**
   * 格式化到期时间
   */
  formatExpireTime(): string {
    const status = this.memberStatus;
    if (!status || !status.isMember || !status.expireTime) return '';
    
    const date = new Date(status.expireTime);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    
    return `${year}-${month}-${day} 到期`;
  }

  /**
   * 获取权益列表
   */
  async getBenefits(): Promise<Benefit[]> {
    try {
      const isMember = this.isMember();
      
      // 从服务器获取权益使用情况
      const response = await this.apiService.get<Benefit[]>(
        API_ENDPOINTS.USER_INFO + '/benefits'
      );
      
      if (response.success && response.data) {
        this.benefits = response.data.map(benefit => ({
          ...benefit,
          isActive: isMember || benefit.isActive
        }));
        return this.benefits;
      }
      
      // 返回默认权益列表
      return this.defaultBenefits.map(benefit => ({
        ...benefit,
        isActive: isMember
      }));
    } catch (error) {
      console.error('[MemberService] Get benefits failed:', error);
      const isMember = this.isMember();
      return this.defaultBenefits.map(benefit => ({
        ...benefit,
        isActive: isMember
      }));
    }
  }

  /**
   * 获取套餐列表
   */
  getPackages(): Package[] {
    return this.packages;
  }

  /**
   * 获取指定套餐
   */
  getPackage(id: string): Package | undefined {
    return this.packages.find(pkg => pkg.id === id);
  }

  /**
   * 购买会员
   */
  async purchaseMember(
    packageId: string,
    onSuccess?: (result: PurchaseResult) => void,
    onError?: (error: { code: string; message: string }) => void
  ): Promise<PurchaseResult> {
    const pkg = this.getPackage(packageId);
    if (!pkg) {
      const error = { code: 'INVALID_PACKAGE', message: '无效的套餐' };
      onError?.(error);
      return { success: false, errorCode: error.code, errorMessage: error.message };
    }
    
    try {
      const result = await this.paymentService.purchaseSubscription(pkg.productId, {
        onSuccess: (purchaseResult) => {
          // 更新本地会员状态
          this.updateLocalMemberStatus(pkg);
          onSuccess?.(purchaseResult);
        },
        onError: (error) => {
          onError?.(error);
        },
        onCancelled: () => {
          onError?.({ code: 'CANCELLED', message: '支付已取消' });
        }
      });
      
      return result;
    } catch (error) {
      console.error('[MemberService] Purchase failed:', error);
      const err = { code: 'UNKNOWN', message: '购买失败，请重试' };
      onError?.(err);
      return { success: false, errorCode: err.code, errorMessage: err.message };
    }
  }

  /**
   * 更新本地会员状态
   */
  private updateLocalMemberStatus(pkg: Package): void {
    const level = this.getLevelFromPackageId(pkg.id);
    const expireTime = Date.now() + pkg.duration * 24 * 60 * 60 * 1000;
    
    this.memberStatus = {
      isMember: true,
      level: level,
      levelName: pkg.name,
      expireTime: expireTime,
      remainingDays: pkg.duration,
      autoRenewing: true,
      productId: pkg.productId
    };
    
    this.cacheMemberStatus(this.memberStatus);
    
    // 更新 AppStorage
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        const userInfo = JSON.parse(userStr);
        userInfo.vipLevel = level;
        userInfo.vipExpireTime = expireTime;
        userInfo.vipProductId = pkg.productId;
        AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
      } catch (e) {
        // ignore
      }
    }
  }

  /**
   * 从套餐ID获取会员等级
   */
  private getLevelFromPackageId(packageId: string): MemberLevel {
    switch (packageId) {
      case 'monthly':
        return MemberLevel.MONTHLY;
      case 'quarterly':
        return MemberLevel.QUARTERLY;
      case 'yearly':
        return MemberLevel.YEARLY;
      default:
        return MemberLevel.MONTHLY;
    }
  }

  /**
   * 获取使用记录
   */
  async getUsageRecords(limit: number = 20): Promise<UsageRecord[]> {
    try {
      const response = await this.apiService.get<UsageRecord[]>(
        API_ENDPOINTS.USER_INFO + '/usage-records',
        { limit }
      );
      
      if (response.success && response.data) {
        return response.data;
      }
      
      return [];
    } catch (error) {
      console.error('[MemberService] Get usage records failed:', error);
      return [];
    }
  }

  /**
   * 查询订阅状态
   */
  async getSubscriptionStatus(): Promise<SubscriptionStatus | null> {
    try {
      return await this.paymentService.querySubscriptionStatus();
    } catch (error) {
      console.error('[MemberService] Get subscription status failed:', error);
      return null;
    }
  }

  /**
   * 取消自动续费
   */
  async cancelAutoRenew(): Promise<boolean> {
    try {
      const status = this.memberStatus;
      if (!status || !status.productId) {
        return false;
      }
      
      const result = await this.paymentService.cancelSubscription(status.productId);
      
      if (result && this.memberStatus) {
        this.memberStatus.autoRenewing = false;
        this.cacheMemberStatus(this.memberStatus);
      }
      
      return result;
    } catch (error) {
      console.error('[MemberService] Cancel auto renew failed:', error);
      return false;
    }
  }

  /**
   * 恢复购买
   */
  async restorePurchases(): Promise<PurchaseResult[]> {
    try {
      const results = await this.paymentService.restorePurchases();
      
      if (results.length > 0) {
        // 刷新会员状态
        await this.getMemberStatus();
      }
      
      return results;
    } catch (error) {
      console.error('[MemberService] Restore purchases failed:', error);
      return [];
    }
  }

  /**
   * 刷新会员状态
   */
  async refreshStatus(): Promise<MemberStatus> {
    this.memberStatus = null;
    return await this.getMemberStatus();
  }

  /**
   * 清除会员状态缓存
   */
  clearCache(): void {
    this.memberStatus = null;
    try {
      Storage.getInstance().remove('memberStatus');
    } catch (e) {
      // ignore
    }
  }
}

export default MemberService.getInstance();
