import { ApiService } from './ApiService';
import { API_ENDPOINTS } from '../constants/config';

export interface MemberInfo {
  level: number;
  expireTime: number;
  features: string[];
  autoRenew: boolean;
}

export interface MembershipPlan {
  planId: string;
  name: string;
  price: number;
  originalPrice: number;
  features: string[];
  duration: number;
  unit: 'day' | 'month' | 'year';
}

export class MemberService {
  private static instance: MemberService;
  private apiService: ApiService;
  private memberInfo: MemberInfo | null = null;

  private constructor() {
    this.apiService = ApiService.getInstance();
  }

  static getInstance(): MemberService {
    if (!MemberService.instance) {
      MemberService.instance = new MemberService();
    }
    return MemberService.instance;
  }

  async getMemberInfo(): Promise<MemberInfo | null> {
    try {
      const response = await this.apiService.get<MemberInfo>(API_ENDPOINTS.MEMBER_INFO);
      if (response.success && response.data) {
        this.memberInfo = response.data;
        return this.memberInfo;
      }
      return null;
    } catch (error) {
      console.error('[MemberService] Get member info failed:', error);
      return null;
    }
  }

  async getMembershipPlans(): Promise<MembershipPlan[]> {
    try {
      const response = await this.apiService.get<MembershipPlan[]>(API_ENDPOINTS.MEMBER_PLANS);
      if (response.success && response.data) {
        return response.data;
      }
      return [];
    } catch (error) {
      console.error('[MemberService] Get plans failed:', error);
      return [];
    }
  }

  async checkFeatureAccess(feature: string): Promise<boolean> {
    try {
      const info = await this.getMemberInfo();
      return info?.features.includes(feature) || false;
    } catch (error) {
      return false;
    }
  }

  isActiveMember(): boolean {
    const userStr = AppStorage.get<string>('userInfo');
    if (!userStr) return false;
    try {
      const u = JSON.parse(userStr) as Record<string, Object>;
      return (u['vipLevel'] as number) > 0 && (u['vipExpireTime'] as number) > Date.now();
    } catch {
      return false;
    }
  }

  getDailyFreeUsage(featureKey: string): { used: number; limit: number } {
    const today = new Date().toISOString().slice(0, 10);
    const key = `daily_usage_${featureKey}_${today}`;
    const raw = AppStorage.get<string>(key);
    const used = raw ? parseInt(raw, 10) : 0;
    const limits: Record<string, number> = { chat: 5, interview: 5, resume: 3 };
    return { used, limit: limits[featureKey] ?? 5 };
  }

  incrementDailyUsage(featureKey: string): void {
    const today = new Date().toISOString().slice(0, 10);
    const key = `daily_usage_${featureKey}_${today}`;
    const raw = AppStorage.get<string>(key);
    const current = raw ? parseInt(raw, 10) : 0;
    AppStorage.setOrCreate(key, String(current + 1));
  }
}

export default MemberService.getInstance();
