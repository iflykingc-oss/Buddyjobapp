import promptAction from '@ohos.promptAction';
import { ApiService } from '../services/ApiService';
import { API_ENDPOINTS } from '../constants/config';
import { ESObject } from '@arkts.lang';

// 声明 HMS IAP 模块
declare const purchase: ESObject;

export interface Product {
  productId: string;
  price: string;
  priceType: number;
  productName: string;
  productDesc: string;
}

export interface PurchaseResult {
  success: boolean;
  orderId?: string;
  verified?: boolean;
  errorCode?: string;
  errorMessage?: string;
}

export interface OrderInfo {
  orderId: string;
  productId: string;
  purchaseToken: string;
  purchaseTime: number;
}

/**
 * 华为支付工具类
 */
export class HuaweiPay {
  private static instance: HuaweiPay;
  private apiService: ApiService;
  private isInitialized: boolean = false;

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): HuaweiPay {
    if (!HuaweiPay.instance) {
      HuaweiPay.instance = new HuaweiPay();
    }
    return HuaweiPay.instance;
  }

  /**
   * 初始化 IAP 服务
   */
  async init(): Promise<boolean> {
    try {
      if (typeof purchase !== 'undefined') {
        const result = await purchase.isReady();
        this.isInitialized = result.code === 0;
        return this.isInitialized;
      }
      console.warn('[HuaweiPay] HMS IAP not available');
      return false;
    } catch (error) {
      console.error('[HuaweiPay] Init failed:', error);
      return false;
    }
  }

  /**
   * 获取商品列表
   */
  async getProducts(productIds: string[]): Promise<Product[]> {
    try {
      const response = await this.apiService.post<{ products: Product[] }>(
        API_ENDPOINTS.PAYMENT_PRODUCTS,
        { productIds }
      );

      if (response.success && response.data) {
        return response.data.products;
      }
      return [];
    } catch (error) {
      console.error('[HuaweiPay] Get products failed:', error);
      return [];
    }
  }

  /**
   * 发起支付
   */
  async purchase(productId: string): Promise<PurchaseResult> {
    try {
      if (typeof purchase === 'undefined') {
        promptAction.showToast({ message: '支付服务暂时不可用' });
        return {
          success: false,
          errorCode: 'HMS_NOT_AVAILABLE',
          errorMessage: '华为支付服务不可用'
        };
      }

      const result = await purchase.purchase({
        priceType: purchase.PriceType.IN_APP_CONSUMABLE,
        productId: productId
      });

      if (result.code === 0 && result.orderInfo) {
        const verified = await this.verifyPurchase(result.orderInfo);
        return {
          success: true,
          orderId: result.orderInfo.orderId,
          verified: verified
        };
      }

      return {
        success: false,
        errorCode: result.code?.toString(),
        errorMessage: result.msg || '支付取消'
      };
    } catch (error) {
      console.error('[HuaweiPay] Purchase failed:', error);
      return {
        success: false,
        errorCode: 'UNKNOWN',
        errorMessage: '支付异常'
      };
    }
  }

  /**
   * 验证购买
   */
  private async verifyPurchase(orderInfo: OrderInfo): Promise<boolean> {
    try {
      const response = await this.apiService.post<{ verified: boolean }>(
        API_ENDPOINTS.PAYMENT_VERIFY,
        orderInfo
      );
      return response.success && response.data?.verified === true;
    } catch (error) {
      console.error('[HuaweiPay] Verify failed:', error);
      return false;
    }
  }

  /**
   * 检查是否可用
   */
  isAvailable(): boolean {
    return this.isInitialized && typeof purchase !== 'undefined';
  }
}
