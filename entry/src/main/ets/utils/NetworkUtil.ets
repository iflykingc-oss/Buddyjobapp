import connection from '@ohos.net.connection';
import hiSysEvent from '@ohos.hiSysEvent';

/**
 * 网络连接类型枚举
 */
export enum ConnectionType {
  WIFI = 'wifi',
  CELLULAR = 'cellular',
  ETHERNET = 'ethernet',
  NONE = 'none',
  UNKNOWN = 'unknown'
}

/**
 * 网络状态变化回调类型
 */
export type NetworkChangeCallback = (type: ConnectionType) => void;

/**
 * 网络工具类
 * 提供网络状态检测和监控功能
 */
export class NetworkUtil {
  private static instance: NetworkUtil;
  private networkCallback: connection.NetConnection | null = null;
  private networkChangeCallbacks: NetworkChangeCallback[] = [];
  private cachedConnectionType: ConnectionType = ConnectionType.UNKNOWN;

  private constructor() {}

  /**
   * 获取 NetworkUtil 单例
   */
  static getInstance(): NetworkUtil {
    if (!NetworkUtil.instance) {
      NetworkUtil.instance = new NetworkUtil();
    }
    return NetworkUtil.instance;
  }

  /**
   * 检查网络是否可用
   * @returns Promise<boolean> 网络是否可用
   */
  async isNetworkAvailable(): Promise<boolean> {
    try {
      const netHandle = await connection.getNetHandle();
      const isConnected = await connection.getAllNets();
      return isConnected.length > 0 && netHandle !== undefined;
    } catch (error) {
      console.error('[NetworkUtil] Failed to check network availability:', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 获取当前连接类型
   * @returns Promise<ConnectionType> 连接类型
   */
  async getConnectionType(): Promise<ConnectionType> {
    try {
      const netHandle = await connection.getNetHandle();
      if (!netHandle) {
        return ConnectionType.NONE;
      }

      // 获取网络Capabilities
      const capabilities = await connection.getNetworkCapabilities(netHandle);
      if (!capabilities) {
        return ConnectionType.UNKNOWN;
      }

      // 根据能力判断连接类型
      if (capabilities.netCapabilities & connection.NetCap.NET_CAPABILITY_WIFI) {
        this.cachedConnectionType = ConnectionType.WIFI;
      } else if (capabilities.netCapabilities & connection.NetCap.NET_CAPABILITY_MOBILE) {
        this.cachedConnectionType = ConnectionType.CELLULAR;
      } else if (capabilities.netCapabilities & connection.NetCap.NET_CAPABILITY_ETHERNET) {
        this.cachedConnectionType = ConnectionType.ETHERNET;
      } else {
        this.cachedConnectionType = ConnectionType.UNKNOWN;
      }

      return this.cachedConnectionType;
    } catch (error) {
      console.error('[NetworkUtil] Failed to get connection type:', JSON.stringify(error));
      return ConnectionType.NONE;
    }
  }

  /**
   * 检查到指定URL的连通性
   * @param url 要检查的URL，默认为百度
   * @returns Promise<boolean> 是否可以连通
   */
  async checkConnectivity(url: string = 'https://www.baidu.com'): Promise<boolean> {
    try {
      const netHandle = await connection.getNetHandle();
      if (!netHandle) {
        return false;
      }

      // 使用 netHandle 进行 HTTP 请求测试
      const httpRequest = await uni.request({
        url: url,
        method: 'GET',
        timeout: 5000,
        netHandle: netHandle
      });

      return httpRequest.statusCode >= 200 && httpRequest.statusCode < 400;
    } catch (error) {
      console.error('[NetworkUtil] Connectivity check failed:', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 获取当前网络类型描述
   * @returns string 网络类型描述
   */
  getConnectionTypeDesc(): string {
    const typeMap: Record<ConnectionType, string> = {
      [ConnectionType.WIFI]: 'WiFi',
      [ConnectionType.CELLULAR]: '移动数据',
      [ConnectionType.ETHERNET]: '以太网',
      [ConnectionType.NONE]: '无网络',
      [ConnectionType.UNKNOWN]: '未知'
    };
    return typeMap[this.cachedConnectionType] || '未知';
  }

  /**
   * 注册网络状态变化监听
   * @param callback 网络状态变化回调函数
   */
  onNetworkChange(callback: NetworkChangeCallback): void {
    if (!this.networkChangeCallbacks.includes(callback)) {
      this.networkChangeCallbacks.push(callback);
    }

    // 如果是第一个监听器，则注册系统监听
    if (this.networkChangeCallbacks.length === 1) {
      this.registerNetworkListener();
    }
  }

  /**
   * 取消网络状态变化监听
   * @param callback 要取消的回调函数
   */
  offNetworkChange(callback: NetworkChangeCallback): void {
    const index = this.networkChangeCallbacks.indexOf(callback);
    if (index > -1) {
      this.networkChangeCallbacks.splice(index, 1);
    }

    // 如果没有监听器了，则注销系统监听
    if (this.networkChangeCallbacks.length === 0) {
      this.unregisterNetworkListener();
    }
  }

  /**
   * 注册网络状态监听器
   */
  private registerNetworkListener(): void {
    try {
      this.networkCallback = {
        onAvailable: (netHandle) => {
          console.info('[NetworkUtil] Network available:', JSON.stringify(netHandle));
          this.notifyNetworkChange(ConnectionType.UNKNOWN);
          this.refreshConnectionType();
        },
        onUnavailable: () => {
          console.info('[NetworkUtil] Network unavailable');
          this.notifyNetworkChange(ConnectionType.NONE);
        },
        onNetLost: () => {
          console.info('[NetworkUtil] Network lost');
          this.notifyNetworkChange(ConnectionType.NONE);
        },
        onNetUnavailable: () => {
          console.info('[NetworkUtil] Network unavailable');
          this.notifyNetworkChange(ConnectionType.NONE);
        },
        onConnectSync: (netHandle) => {
          console.info('[NetworkUtil] Network connect sync:', JSON.stringify(netHandle));
          this.refreshConnectionType();
        }
      };

      connection.createNetConnection(this.networkCallback, (error, connection) => {
        if (error) {
          console.error('[NetworkUtil] Failed to create net connection:', JSON.stringify(error));
          return;
        }
        console.info('[NetworkUtil] Network listener registered successfully');
      });
    } catch (error) {
      console.error('[NetworkUtil] Failed to register network listener:', JSON.stringify(error));
    }
  }

  /**
   * 注销网络状态监听器
   */
  private unregisterNetworkListener(): void {
    try {
      if (this.networkCallback) {
        // 使用完需要主动注销
        connection.deleteNetConnection(this.networkCallback);
        this.networkCallback = null;
        console.info('[NetworkUtil] Network listener unregistered');
      }
    } catch (error) {
      console.error('[NetworkUtil] Failed to unregister network listener:', JSON.stringify(error));
    }
  }

  /**
   * 刷新连接类型
   */
  private async refreshConnectionType(): Promise<void> {
    const type = await this.getConnectionType();
    this.notifyNetworkChange(type);
  }

  /**
   * 通知所有监听器网络状态变化
   * @param type 新的连接类型
   */
  private notifyNetworkChange(type: ConnectionType): void {
    this.networkChangeCallbacks.forEach(callback => {
      try {
        callback(type);
      } catch (error) {
        console.error('[NetworkUtil] Callback error:', JSON.stringify(error));
      }
    });
  }

  /**
   * 主动检查并同步网络状态
   * @returns Promise<ConnectionType> 当前连接类型
   */
  async checkAndSync(): Promise<ConnectionType> {
    const isAvailable = await this.isNetworkAvailable();
    if (!isAvailable) {
      this.cachedConnectionType = ConnectionType.NONE;
      this.notifyNetworkChange(ConnectionType.NONE);
      return ConnectionType.NONE;
    }
    return await this.getConnectionType();
  }
}

/**
 * 获取网络工具单例
 */
export function getNetworkUtil(): NetworkUtil {
  return NetworkUtil.getInstance();
}

export default NetworkUtil;
