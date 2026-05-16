/**
 * 跨设备流转服务
 * 基于 HarmonyOS NEXT 应用接续能力
 * 实现任务跨设备迁移、状态同步
 */
import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import { DistributedDeviceManager, DistributedDevice, DeviceState } from './DistributedDeviceManager';

const TAG = 'ContinuationManager';
const DOMAIN = 0xFF00;

// 流转状态
export enum ContinuationState {
  IDLE = 'idle',
  PREPARING = 'preparing',
  TRANSFERRING = 'transferring',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

// 流转数据接口
export interface ContinuationData {
  // 页面路由
  pageUrl: string;
  // 页面参数
  pageParams?: Record<string, Object>;
  // 业务数据
  businessData?: Record<string, Object>;
  // 用户信息
  userInfo?: {
    userId: string;
    nickname?: string;
    avatar?: string;
  };
  // 时间戳
  timestamp: number;
  // 设备信息
  sourceDevice?: string;
  targetDevice?: string;
}

// 流转回调
export type ContinuationCallback = (state: ContinuationState, data?: ContinuationData) => void;

/**
 * 跨设备流转管理器
 * 实现应用接续、任务迁移
 */
export class ContinuationManager {
  private static instance: ContinuationManager;
  private deviceManager: DistributedDeviceManager;
  private currentState: ContinuationState = ContinuationState.IDLE;
  private callbacks: ContinuationCallback[] = [];
  private lastContinuationData: ContinuationData | null = null;
  private ability: UIAbility | null = null;
  private continuationToken: number = -1;

  private constructor() {
    this.deviceManager = DistributedDeviceManager.getInstance();
  }

  static getInstance(): ContinuationManager {
    if (!ContinuationManager.instance) {
      ContinuationManager.instance = new ContinuationManager();
    }
    return ContinuationManager.instance;
  }

  /**
   * 初始化流转管理器
   */
  async initialize(ability: UIAbility): Promise<boolean> {
    try {
      this.ability = ability;

      // 初始化设备管理器
      const deviceInit = await this.deviceManager.initialize();
      if (!deviceInit) {
        hilog.error(DOMAIN, TAG, 'Failed to initialize device manager');
        return false;
      }

      // 注册设备状态监听
      this.deviceManager.onDeviceState((device, state) => {
        this.handleDeviceStateChange(device, state);
      });

      hilog.info(DOMAIN, TAG, 'Continuation manager initialized');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 销毁流转管理器
   */
  destroy(): void {
    this.deviceManager.destroy();
    this.callbacks = [];
    this.ability = null;
    hilog.info(DOMAIN, TAG, 'Continuation manager destroyed');
  }

  /**
   * 注册流转回调
   */
  registerCallback(callback: ContinuationCallback): void {
    this.callbacks.push(callback);
  }

  /**
   * 注销流转回调
   */
  unregisterCallback(callback: ContinuationCallback): void {
    this.callbacks = this.callbacks.filter(cb => cb !== callback);
  }

  /**
   * 获取可流转设备列表
   */
  getAvailableDevices(): DistributedDevice[] {
    return this.deviceManager.getOnlineDevices();
  }

  /**
   * 开始流转
   */
  async startContinuation(
    targetDevice: DistributedDevice,
    data: ContinuationData
  ): Promise<boolean> {
    if (this.currentState !== ContinuationState.IDLE) {
      hilog.warn(DOMAIN, TAG, 'Continuation already in progress');
      return false;
    }

    this.updateState(ContinuationState.PREPARING);

    try {
      // 准备流转数据
      const continuationData: ContinuationData = {
        ...data,
        timestamp: Date.now(),
        sourceDevice: this.deviceManager.getLocalDeviceInfo()?.deviceId,
        targetDevice: targetDevice.deviceId
      };

      this.lastContinuationData = continuationData;
      this.updateState(ContinuationState.TRANSFERRING);

      // 触发流转（实际流转由系统处理）
      // 这里模拟流转成功
      setTimeout(() => {
        this.updateState(ContinuationState.COMPLETED, continuationData);
        // 重置状态
        setTimeout(() => {
          this.updateState(ContinuationState.IDLE);
        }, 1000);
      }, 500);

      hilog.info(DOMAIN, TAG, `Started continuation to ${targetDevice.deviceName}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start continuation failed: ${JSON.stringify(error)}`);
      this.updateState(ContinuationState.FAILED);
      return false;
    }
  }

  /**
   * 接收流转数据
   */
  receiveContinuationData(data: ContinuationData): void {
    hilog.info(DOMAIN, TAG, `Received continuation data from ${data.sourceDevice}`);
    
    this.lastContinuationData = data;
    this.updateState(ContinuationState.COMPLETED, data);

    // 通知所有回调
    this.callbacks.forEach(callback => {
      try {
        callback(ContinuationState.COMPLETED, data);
      } catch (e) {
        hilog.error(DOMAIN, TAG, `Callback error: ${e}`);
      }
    });

    // 重置状态
    setTimeout(() => {
      this.updateState(ContinuationState.IDLE);
    }, 1000);
  }

  /**
   * 获取当前流转状态
   */
  getCurrentState(): ContinuationState {
    return this.currentState;
  }

  /**
   * 获取最后流转数据
   */
  getLastContinuationData(): ContinuationData | null {
    return this.lastContinuationData;
  }

  /**
   * 更新流转状态
   */
  private updateState(state: ContinuationState, data?: ContinuationData): void {
    this.currentState = state;
    
    this.callbacks.forEach(callback => {
      try {
        callback(state, data);
      } catch (e) {
        hilog.error(DOMAIN, TAG, `State callback error: ${e}`);
      }
    });

    hilog.info(DOMAIN, TAG, `State updated: ${state}`);
  }

  /**
   * 处理设备状态变化
   */
  private handleDeviceStateChange(device: DistributedDevice, state: DeviceState): void {
    hilog.info(DOMAIN, TAG, `Device ${device.deviceName} state: ${state}`);
    
    // 如果目标设备离线，取消流转
    if (state === DeviceState.OFFLINE && 
        this.currentState === ContinuationState.TRANSFERRING &&
        this.lastContinuationData?.targetDevice === device.deviceId) {
      this.updateState(ContinuationState.FAILED);
    }
  }
}

/**
 * 页面流转数据构建器
 * 用于构建特定页面的流转数据
 */
export class ContinuationDataBuilder {
  private data: ContinuationData;

  constructor() {
    this.data = {
      pageUrl: '',
      timestamp: Date.now()
    };
  }

  setPageUrl(url: string): ContinuationDataBuilder {
    this.data.pageUrl = url;
    return this;
  }

  setPageParams(params: Record<string, Object>): ContinuationDataBuilder {
    this.data.pageParams = params;
    return this;
  }

  setBusinessData(businessData: Record<string, Object>): ContinuationDataBuilder {
    this.data.businessData = businessData;
    return this;
  }

  setUserInfo(userId: string, nickname?: string, avatar?: string): ContinuationDataBuilder {
    this.data.userInfo = { userId, nickname, avatar };
    return this;
  }

  build(): ContinuationData {
    this.data.timestamp = Date.now();
    return this.data;
  }
}

export default ContinuationManager;
