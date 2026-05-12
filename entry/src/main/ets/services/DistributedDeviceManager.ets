/**
 * 分布式设备管理服务
 * 基于 HarmonyOS NEXT 分布式软总线能力
 * 实现设备发现、连接、状态监听
 */
import deviceManager from '@ohos.distributedDeviceManager';
import hilog from '@ohos.hilog';
import { emitter } from '@kit.BasicServicesKit';

const TAG = 'DistributedDeviceManager';
const DOMAIN = 0xFF00;

// 设备状态
export enum DeviceState {
  UNKNOWN = 'unknown',
  ONLINE = 'online',
  OFFLINE = 'offline',
  CONNECTING = 'connecting',
  DISCONNECTING = 'disconnecting'
}

// 设备类型
export enum DeviceType {
  UNKNOWN = 0,
  PHONE = 0x0E,
  TABLET = 0x11,
  WATCH = 0x6D,
  TV = 0x9C,
  PC = 0x0C,
  CAR = 0x83
}

// 设备信息接口
export interface DistributedDevice {
  deviceId: string;
  deviceName: string;
  deviceType: DeviceType;
  deviceState: DeviceState;
  networkId: string;
  isOnline: boolean;
  lastSeenTime: number;
}

// 设备发现回调
export type DeviceDiscoveryCallback = (devices: DistributedDevice[]) => void;
export type DeviceStateCallback = (device: DistributedDevice, state: DeviceState) => void;

/**
 * 分布式设备管理器
 * 封装 DeviceManager API，提供设备发现、连接、状态监听能力
 */
export class DistributedDeviceManager {
  private static instance: DistributedDeviceManager;
  private deviceManager: deviceManager.DeviceManager | null = null;
  private discoveredDevices: Map<string, DistributedDevice> = new Map();
  private discoveryCallbacks: DeviceDiscoveryCallback[] = [];
  private stateCallbacks: DeviceStateCallback[] = [];
  private isDiscovering: boolean = false;

  private constructor() {}

  static getInstance(): DistributedDeviceManager {
    if (!DistributedDeviceManager.instance) {
      DistributedDeviceManager.instance = new DistributedDeviceManager();
    }
    return DistributedDeviceManager.instance;
  }

  /**
   * 初始化设备管理器
   */
  async initialize(): Promise<boolean> {
    try {
      // 创建设备管理器实例
      this.deviceManager = deviceManager.createDeviceManager('com.buddyjob.app');
      
      // 注册设备状态回调
      this.deviceManager.on('deviceStateChange', (data) => {
        this.handleDeviceStateChange(data);
      });

      // 注册设备发现回调
      this.deviceManager.on('deviceFound', (data) => {
        this.handleDeviceFound(data);
      });

      // 注册发现失败回调
      this.deviceManager.on('discoverFail', (data) => {
        hilog.error(DOMAIN, TAG, `Discovery failed: ${JSON.stringify(data)}`);
        this.isDiscovering = false;
      });

      hilog.info(DOMAIN, TAG, 'Device manager initialized successfully');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 销毁设备管理器
   */
  destroy(): void {
    try {
      if (this.deviceManager) {
        this.stopDeviceDiscovery();
        this.deviceManager.off('deviceStateChange');
        this.deviceManager.off('deviceFound');
        this.deviceManager.off('discoverFail');
        deviceManager.releaseDeviceManager(this.deviceManager);
        this.deviceManager = null;
      }
      this.discoveredDevices.clear();
      hilog.info(DOMAIN, TAG, 'Device manager destroyed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Destroy failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 开始设备发现
   */
  async startDeviceDiscovery(): Promise<boolean> {
    if (!this.deviceManager) {
      hilog.error(DOMAIN, TAG, 'Device manager not initialized');
      return false;
    }

    if (this.isDiscovering) {
      hilog.warn(DOMAIN, TAG, 'Already discovering');
      return true;
    }

    try {
      const subscribeInfo: deviceManager.SubscribeInfo = {
        subscribeId: 1,
        mode: 'DISCOVER_MODE_ACTIVE',
        medium: 'AUTO',
        freq: 'MID',
        isSameAccount: true,  // 同账号设备
        isWakeRemote: false,
        capability: 'ddmpCapability'
      };

      this.deviceManager.startDeviceDiscovery(subscribeInfo);
      this.isDiscovering = true;
      hilog.info(DOMAIN, TAG, 'Started device discovery');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start discovery failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 停止设备发现
   */
  stopDeviceDiscovery(): void {
    if (!this.deviceManager || !this.isDiscovering) {
      return;
    }

    try {
      this.deviceManager.stopDeviceDiscovery({ subscribeId: 1 });
      this.isDiscovering = false;
      hilog.info(DOMAIN, TAG, 'Stopped device discovery');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Stop discovery failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 获取已发现的设备列表
   */
  getDiscoveredDevices(): DistributedDevice[] {
    return Array.from(this.discoveredDevices.values());
  }

  /**
   * 获取在线设备列表
   */
  getOnlineDevices(): DistributedDevice[] {
    return this.getDiscoveredDevices().filter(d => d.isOnline);
  }

  /**
   * 获取本地设备信息
   */
  getLocalDeviceInfo(): DistributedDevice | null {
    if (!this.deviceManager) {
      return null;
    }

    try {
      const localInfo = this.deviceManager.getLocalDeviceInfoSync();
      return {
        deviceId: localInfo.deviceId,
        deviceName: localInfo.deviceName,
        deviceType: localInfo.deviceType as DeviceType,
        deviceState: DeviceState.ONLINE,
        networkId: localInfo.networkId || '',
        isOnline: true,
        lastSeenTime: Date.now()
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get local device info failed: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * 设置设备发现回调
   */
  onDeviceDiscovery(callback: DeviceDiscoveryCallback): void {
    this.discoveryCallbacks.push(callback);
  }

  /**
   * 设置设备状态回调
   */
  onDeviceState(callback: DeviceStateCallback): void {
    this.stateCallbacks.push(callback);
  }

  /**
   * 移除回调
   */
  removeCallback(callback: Function): void {
    this.discoveryCallbacks = this.discoveryCallbacks.filter(cb => cb !== callback);
    this.stateCallbacks = this.stateCallbacks.filter(cb => cb !== callback);
  }

  /**
   * 处理设备状态变化
   */
  private handleDeviceStateChange(data: deviceManager.DeviceInfo): void {
    const device: DistributedDevice = {
      deviceId: data.deviceId,
      deviceName: data.deviceName,
      deviceType: data.deviceType as DeviceType,
      deviceState: data.online ? DeviceState.ONLINE : DeviceState.OFFLINE,
      networkId: data.networkId || '',
      isOnline: data.online,
      lastSeenTime: Date.now()
    };

    // 更新设备列表
    this.discoveredDevices.set(device.deviceId, device);

    // 通知状态回调
    this.stateCallbacks.forEach(callback => {
      try {
        callback(device, device.deviceState);
      } catch (e) {
        hilog.error(DOMAIN, TAG, `State callback error: ${e}`);
      }
    });

    // 通知发现回调
    this.notifyDiscoveryCallbacks();

    // 发送事件通知
    emitter.emit({ eventId: 1001 }, {
      data: { deviceId: device.deviceId, state: device.deviceState }
    });

    hilog.info(DOMAIN, TAG, `Device state changed: ${device.deviceName} -> ${device.deviceState}`);
  }

  /**
   * 处理设备发现
   */
  private handleDeviceFound(data: deviceManager.DeviceInfo): void {
    const device: DistributedDevice = {
      deviceId: data.deviceId,
      deviceName: data.deviceName,
      deviceType: data.deviceType as DeviceType,
      deviceState: DeviceState.ONLINE,
      networkId: data.networkId || '',
      isOnline: true,
      lastSeenTime: Date.now()
    };

    this.discoveredDevices.set(device.deviceId, device);
    this.notifyDiscoveryCallbacks();

    hilog.info(DOMAIN, TAG, `Device found: ${device.deviceName}`);
  }

  /**
   * 通知发现回调
   */
  private notifyDiscoveryCallbacks(): void {
    const devices = this.getDiscoveredDevices();
    this.discoveryCallbacks.forEach(callback => {
      try {
        callback(devices);
      } catch (e) {
        hilog.error(DOMAIN, TAG, `Discovery callback error: ${e}`);
      }
    });
  }
}

export default DistributedDeviceManager;
