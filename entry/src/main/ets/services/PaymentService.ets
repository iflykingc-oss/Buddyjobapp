import promptAction from '@ohos.promptAction';
import { ApiService } from './ApiService';
import { API_ENDPOINTS, Config } from '../constants/config';
import { HMSUtils, HMSErrorCode, HMSServiceType } from '../utils/hms';

// 华为 IAP 模块类型声明
declare const purchase: any;

/**
 * 商品类型
 */
export enum ProductType {
  CONSUMABLE = 0,      // 消耗型商品
  NON_CONSUMABLE = 1,  // 非消耗型商品
  SUBSCRIPTION = 2,    // 订阅型商品
}

/**
 * 商品信息
 */
export interface Product {
  productId: string;
  price: string;
  priceType: number;
  productName: string;
  productDesc: string;
  currency: string;
  microPrice: number;
  originalPrice?: string;
  subscriptionPeriod?: string; // 订阅周期，如 "P1M" 表示1个月
  freeTrialPeriod?: string;    // 免费试用周期
}

/**
 * 订阅商品信息
 */
export interface SubscriptionProduct extends Product {
  subscriptionPeriod: string;
  freeTrialPeriod?: string;
  introductoryPrice?: string;
  introductoryPricePeriod?: string;
}

/**
 * 会员套餐定义
 */
export const MEMBERSHIP_PRODUCTS = {
  // 月度会员
  VIP_MONTHLY: {
    productId: 'vip_monthly',
    type: ProductType.SUBSCRIPTION,
    name: '月度会员',
    desc: '享受30天会员权益',
    period: 'P1M',
  },
  // 年度会员
  VIP_YEARLY: {
    productId: 'vip_yearly',
    type: ProductType.SUBSCRIPTION,
    name: '年度会员',
    desc: '享受365天会员权益，立省40%',
    period: 'P1Y',
  },
  // 季度会员
  VIP_QUARTERLY: {
    productId: 'vip_quarterly',
    type: ProductType.SUBSCRIPTION,
    name: '季度会员',
    desc: '享受90天会员权益',
    period: 'P3M',
  },
} as const;

/**
 * 购买结果
 */
export interface PurchaseResult {
  success: boolean;
  orderId?: string;
  purchaseToken?: string;
  productId?: string;
  verified?: boolean;
  isSubscription?: boolean;
  errorCode?: string;
  errorMessage?: string;
}

/**
 * 订单信息
 */
export interface OrderInfo {
  orderId: string;
  productId: string;
  purchaseToken: string;
  purchaseTime: number;
  purchaseState: number;
  consumptionState?: number;
  subscriptionId?: string;
  expirationDate?: number;
  autoRenewing?: boolean;
}

/**
 * 订阅状态
 */
export interface SubscriptionStatus {
  productId: string;
  subscriptionId: string;
  isActive: boolean;
  expirationDate: number;
  autoRenewing: boolean;
  isFreeTrial: boolean;
}

/**
 * 支付回调处理
 */
export interface PaymentCallback {
  onSuccess?: (result: PurchaseResult) => void;
  onError?: (error: { code: string; message: string }) => void;
  onCancelled?: () => void;
}

/**
 * 华为支付服务 - 支持消耗型商品和订阅型商品
 * TODO: 等待华为支付 SDK 接入，目前使用 mock 实现
 */
export class PaymentService {
  private static instance: PaymentService;
  private apiService: ApiService;
  private hmsUtils: HMSUtils;
  private isInitialized: boolean = false;
  private pendingOrders: Map<string, OrderInfo> = new Map();
  private callbacks: PaymentCallback = {};

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.hmsUtils = HMSUtils.getInstance();
  }

  static getInstance(): PaymentService {
    if (!PaymentService.instance) {
      PaymentService.instance = new PaymentService();
    }
    return PaymentService.instance;
  }

  /**
   * 初始化 IAP 服务
   * TODO: 等待华为支付 SDK 接入，目前使用 mock 实现
   */
  async init(): Promise<boolean> {
    try {
      // 检查 HMS IAP 是否可用
      const isAvailable = await this.hmsUtils.checkServiceAvailability(HMSServiceType.IAP);
      if (!isAvailable) {
        console.warn('[PaymentService] Huawei IAP is not available');
        return false;
      }

      if (typeof purchase !== 'undefined') {
        const result = await purchase.isReady();
        this.isInitialized = result.code === HMSErrorCode.SUCCESS;
        
        if (this.isInitialized) {
          console.info('[PaymentService] IAP initialized successfully');
          // 启动时检查并补单
          await this.checkAndRestorePendingOrders();
        }
      }
      return this.isInitialized;
    } catch (error) {
      console.error('[PaymentService] Init failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 获取商品列表
   * TODO: 等待华为支付 SDK 接入，目前使用 mock 实现
   * @param productIds 商品ID列表
   * @param priceType 商品类型
   */
  async getProducts(productIds: string[], priceType: ProductType = ProductType.CONSUMABLE): Promise<Product[]> {
    try {
      // 优先从服务器获取商品信息
      const response = await this.apiService.post<{ products: Product[] }>(
        API_ENDPOINTS.PAYMENT_PRODUCTS,
        { productIds, priceType }
      );

      if (response.success && response.data) {
        return response.data.products;
      }

      // 如果服务器请求失败，尝试使用华为 IAP
      if (typeof purchase !== 'undefined' && this.isInitialized) {
        const result = await purchase.getProducts({
          priceType: priceType,
          productIds: productIds
        });

        if (result.code === HMSErrorCode.SUCCESS) {
          return result.productList || [];
        }
      }

      return [];
    } catch (error) {
      console.error('[PaymentService] Get products failed:', error);
      this.hmsUtils.handleHMSError(error);
      return [];
    }
  }

  /**
   * 获取订阅商品列表
   */
  async getSubscriptionProducts(): Promise<SubscriptionProduct[]> {
    const productIds = [
      MEMBERSHIP_PRODUCTS.VIP_MONTHLY.productId,
      MEMBERSHIP_PRODUCTS.VIP_YEARLY.productId,
      MEMBERSHIP_PRODUCTS.VIP_QUARTERLY.productId,
    ];
    
    const products = await this.getProducts(productIds, ProductType.SUBSCRIPTION);
    return products as SubscriptionProduct[];
  }

  /**
   * 发起支付 - 消耗型商品
   */
  async purchase(productId: string, callback?: PaymentCallback): Promise<PurchaseResult> {
    return this.doPurchase(productId, ProductType.CONSUMABLE, callback);
  }

  /**
   * 购买订阅 - 订阅型商品
   */
  async purchaseSubscription(productId: string, callback?: PaymentCallback): Promise<PurchaseResult> {
    return this.doPurchase(productId, ProductType.SUBSCRIPTION, callback);
  }

  /**
   * 执行购买
   * TODO: 等待华为支付 SDK 接入，目前使用 mock 实现
   */
  private async doPurchase(
    productId: string, 
    priceType: ProductType,
    callback?: PaymentCallback
  ): Promise<PurchaseResult> {
    // 保存回调
    if (callback) {
      this.callbacks = { ...this.callbacks, ...callback };
    }

    try {
      if (!this.isInitialized || typeof purchase === 'undefined') {
        const error = {
          success: false,
          errorCode: 'HMS_NOT_AVAILABLE',
          errorMessage: '华为支付服务不可用'
        };
        this.callbacks.onError?.({ code: error.errorCode, message: error.errorMessage });
        return error;
      }

      // 调用华为 IAP 支付
      const result = await purchase.purchase({
        priceType: priceType,
        productId: productId,
        developerPayload: this.generateDeveloperPayload(productId)
      });

      if (result.code === HMSErrorCode.SUCCESS && result.orderInfo) {
        const orderInfo: OrderInfo = result.orderInfo;
        
        // 保存待处理订单
        this.pendingOrders.set(orderInfo.orderId, orderInfo);

        // 发送到服务器验证
        const verified = await this.verifyPurchase(orderInfo, priceType === ProductType.SUBSCRIPTION);

        if (verified) {
          // 消耗型商品需要确认消费
          if (priceType === ProductType.CONSUMABLE) {
            await this.consumePurchase(orderInfo.purchaseToken);
          }
          
          // 移除已处理订单
          this.pendingOrders.delete(orderInfo.orderId);
        }

        const purchaseResult: PurchaseResult = {
          success: true,
          orderId: orderInfo.orderId,
          purchaseToken: orderInfo.purchaseToken,
          productId: orderInfo.productId,
          verified: verified,
          isSubscription: priceType === ProductType.SUBSCRIPTION,
        };

        if (verified) {
          this.callbacks.onSuccess?.(purchaseResult);
        } else {
          this.callbacks.onError?.({ 
            code: 'VERIFY_FAILED', 
            message: '订单验证失败，请联系客服' 
          });
        }

        return purchaseResult;
      }

      // 用户取消
      if (result.code === HMSErrorCode.PAYMENT_CANCELLED) {
        this.callbacks.onCancelled?.();
        return {
          success: false,
          errorCode: 'CANCELLED',
          errorMessage: '支付已取消'
        };
      }

      // 其他错误
      const errorMessage = this.hmsUtils.getErrorMessage(result.code) || result.msg || '支付失败';
      const errorResult: PurchaseResult = {
        success: false,
        errorCode: result.code?.toString(),
        errorMessage: errorMessage
      };
      
      this.callbacks.onError?.({ 
        code: errorResult.errorCode!, 
        message: errorMessage 
      });
      
      return errorResult;

    } catch (error) {
      console.error('[PaymentService] Purchase failed:', error);
      const errorMessage = this.hmsUtils.handleHMSError(error, false);
      
      const errorResult: PurchaseResult = {
        success: false,
        errorCode: 'UNKNOWN',
        errorMessage: errorMessage
      };
      
      this.callbacks.onError?.({ 
        code: errorResult.errorCode, 
        message: errorMessage 
      });
      
      return errorResult;
    }
  }

  /**
   * 购买 VIP 会员（月度）
   */
  async purchaseVipMonthly(callback?: PaymentCallback): Promise<PurchaseResult> {
    return this.purchaseSubscription(MEMBERSHIP_PRODUCTS.VIP_MONTHLY.productId, callback);
  }

  /**
   * 购买 VIP 会员（年度）
   */
  async purchaseVipYearly(callback?: PaymentCallback): Promise<PurchaseResult> {
    return this.purchaseSubscription(MEMBERSHIP_PRODUCTS.VIP_YEARLY.productId, callback);
  }

  /**
   * 购买 VIP 会员（季度）
   */
  async purchaseVipQuarterly(callback?: PaymentCallback): Promise<PurchaseResult> {
    return this.purchaseSubscription(MEMBERSHIP_PRODUCTS.VIP_QUARTERLY.productId, callback);
  }

  /**
   * 验证购买（发送到服务器）
   * TODO: 等待华为支付 SDK 接入，目前使用 mock 实现
   */
  private async verifyPurchase(orderInfo: OrderInfo, isSubscription: boolean = false): Promise<boolean> {
    try {
      const endpoint = isSubscription 
        ? API_ENDPOINTS.PAYMENT_VERIFY + '/subscription'
        : API_ENDPOINTS.PAYMENT_VERIFY;

      const response = await this.apiService.post<{ 
        verified: boolean;
        vipExpireTime?: number;
        subscriptionStatus?: SubscriptionStatus;
      }>(endpoint, {
        ...orderInfo,
        platform: 'huawei'
      });

      if (response.success && response.data?.verified) {
        // 更新用户 VIP 状态
        if (isSubscription && response.data.vipExpireTime) {
          await this.updateUserVipStatus(orderInfo.productId, response.data.vipExpireTime);
        }
        
        return true;
      }

      return false;
    } catch (error) {
      console.error('[PaymentService] Verify failed:', error);
      return false;
    }
  }

  /**
   * 消耗型商品确认消费
   */
  private async consumePurchase(purchaseToken: string): Promise<boolean> {
    try {
      if (typeof purchase === 'undefined') {
        return false;
      }

      const result = await purchase.consume({
        purchaseToken: purchaseToken
      });

      return result.code === HMSErrorCode.SUCCESS;
    } catch (error) {
      console.error('[PaymentService] Consume failed:', error);
      return false;
    }
  }

  /**
   * 查询订单状态
   */
  async queryOrder(orderId: string): Promise<OrderInfo | null> {
    try {
      // 先查本地缓存
      if (this.pendingOrders.has(orderId)) {
        return this.pendingOrders.get(orderId)!;
      }

      // 查询服务器
      const response = await this.apiService.get<OrderInfo>(
        `${API_ENDPOINTS.PAYMENT_VERIFY}/query`,
        { orderId }
      );

      if (response.success && response.data) {
        return response.data;
      }

      return null;
    } catch (error) {
      console.error('[PaymentService] Query order failed:', error);
      return null;
    }
  }

  /**
   * 查询所有未完成订单（补单）
   */
  async queryPendingOrders(): Promise<OrderInfo[]> {
    try {
      if (typeof purchase === 'undefined' || !this.isInitialized) {
        return [];
      }

      const result = await purchase.getPendingOrders();
      
      if (result.code === HMSErrorCode.SUCCESS) {
        return result.orders || [];
      }

      return [];
    } catch (error) {
      console.error('[PaymentService] Query pending orders failed:', error);
      return [];
    }
  }

  /**
   * 检查并恢复未完成订单
   */
  async checkAndRestorePendingOrders(): Promise<void> {
    try {
      console.info('[PaymentService] Checking pending orders...');
      
      const pendingOrders = await this.queryPendingOrders();
      
      for (const order of pendingOrders) {
        console.info(`[PaymentService] Processing pending order: ${order.orderId}`);
        
        // 发送到服务器验证
        const isSubscription = this.isSubscriptionProduct(order.productId);
        const verified = await this.verifyPurchase(order, isSubscription);

        if (verified) {
          // 消耗型商品确认消费
          if (!isSubscription) {
            await this.consumePurchase(order.purchaseToken);
          }
          
          promptAction.showToast({
            message: '订单已恢复，权益已到账',
            duration: 2000
          });
        }
      }
    } catch (error) {
      console.error('[PaymentService] Restore pending orders failed:', error);
    }
  }

  /**
   * 查询订阅状态
   */
  async querySubscriptionStatus(productId?: string): Promise<SubscriptionStatus | null> {
    try {
      const response = await this.apiService.get<SubscriptionStatus>(
        API_ENDPOINTS.PAYMENT_VERIFY + '/subscription/status',
        { productId }
      );

      if (response.success && response.data) {
        return response.data;
      }

      return null;
    } catch (error) {
      console.error('[PaymentService] Query subscription status failed:', error);
      return null;
    }
  }

  /**
   * 取消订阅（在下一个周期生效）
   */
  async cancelSubscription(productId: string): Promise<boolean> {
    try {
      const response = await this.apiService.post(
        API_ENDPOINTS.PAYMENT_VERIFY + '/subscription/cancel',
        { productId }
      );

      if (response.success) {
        promptAction.showToast({
          message: '已取消自动续费，当前权益仍可使用至到期日',
          duration: 3000
        });
        return true;
      }

      return false;
    } catch (error) {
      console.error('[PaymentService] Cancel subscription failed:', error);
      this.hmsUtils.handleHMSError(error);
      return false;
    }
  }

  /**
   * 恢复购买（用于切换设备后恢复订阅）
   */
  async restorePurchases(): Promise<PurchaseResult[]> {
    try {
      const results: PurchaseResult[] = [];
      
      // 查询服务器获取用户的有效订阅
      const response = await this.apiService.get<SubscriptionStatus[]>(
        API_ENDPOINTS.PAYMENT_VERIFY + '/subscription/restore'
      );

      if (response.success && response.data) {
        for (const subscription of response.data) {
          if (subscription.isActive) {
            // 更新本地 VIP 状态
            await this.updateUserVipStatus(subscription.productId, subscription.expirationDate);
            
            results.push({
              success: true,
              productId: subscription.productId,
              isSubscription: true,
              verified: true
            });
          }
        }
      }

      if (results.length > 0) {
        promptAction.showToast({
          message: `成功恢复 ${results.length} 个订阅`,
          duration: 2000
        });
      }

      return results;
    } catch (error) {
      console.error('[PaymentService] Restore purchases failed:', error);
      return [];
    }
  }

  /**
   * 更新用户 VIP 状态
   */
  private async updateUserVipStatus(productId: string, expireTime: number): Promise<void> {
    try {
      const userStr = AppStorage.get<string>('userInfo');
      if (userStr) {
        const userInfo = JSON.parse(userStr);
        
        // 根据商品ID确定 VIP 等级
        let vipLevel = 1;
        if (productId.includes('yearly') || productId.includes('year')) {
          vipLevel = 2; // 年度会员更高等级
        }
        
        userInfo.vipLevel = vipLevel;
        userInfo.vipExpireTime = expireTime;
        userInfo.vipProductId = productId;
        
        AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
        
        // 通知服务器更新
        await this.apiService.post(API_ENDPOINTS.UPDATE_USER, {
          vipLevel,
          vipExpireTime: expireTime,
          vipProductId: productId
        });
      }
    } catch (e) {
      console.error('[PaymentService] Update VIP status failed:', e);
    }
  }

  /**
   * 生成开发者透传参数
   */
  private generateDeveloperPayload(productId: string): string {
    const payload = {
      productId,
      timestamp: Date.now(),
      userId: this.getCurrentUserId(),
      nonce: Math.random().toString(36).substring(2, 15)
    };
    return JSON.stringify(payload);
  }

  /**
   * 获取当前用户ID
   */
  private getCurrentUserId(): string {
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        const userInfo = JSON.parse(userStr);
        return userInfo.id || '';
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  /**
   * 判断是否为订阅商品
   */
  private isSubscriptionProduct(productId: string): boolean {
    return Object.values(MEMBERSHIP_PRODUCTS).some(
      product => product.productId === productId
    );
  }

  /**
   * 检查支付服务是否可用
   */
  isAvailable(): boolean {
    return this.isInitialized;
  }

  /**
   * 检查用户是否是 VIP
   */
  isVip(): boolean {
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        const userInfo = JSON.parse(userStr);
        if (userInfo.vipLevel > 0 && userInfo.vipExpireTime) {
          return Date.now() < userInfo.vipExpireTime;
        }
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /**
   * 获取 VIP 到期时间
   */
  getVipExpireTime(): number | null {
    const userStr = AppStorage.get<string>('userInfo');
    if (userStr) {
      try {
        const userInfo = JSON.parse(userStr);
        return userInfo.vipExpireTime || null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /**
   * 获取 VIP 剩余天数
   */
  getVipRemainingDays(): number {
    const expireTime = this.getVipExpireTime();
    if (expireTime) {
      const remaining = Math.ceil((expireTime - Date.now()) / (24 * 60 * 60 * 1000));
      return Math.max(0, remaining);
    }
    return 0;
  }
}

export default PaymentService.getInstance();
