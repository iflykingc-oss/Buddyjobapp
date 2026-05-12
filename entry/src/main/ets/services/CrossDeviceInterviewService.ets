/**
 * 跨设备面试准备服务 - 支持多设备协同
 * 实现面试准备资料在手机、平板、手表间同步
 */
import distributedDeviceManager from '@ohos.distributedDeviceManager';
import distributedDataSync from '@ohos.distributedDataSync';
import hilog from '@ohos.hilog';
import { storage } from '../utils/storage';

const TAG = 'CrossDeviceInterviewService';
const DOMAIN = 0xFF00;

/**
 * 设备类型
 */
export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  WATCH = 'watch',
  TV = 'tv'
}

/**
 * 设备信息
 */
export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  deviceType: DeviceType;
  isOnline: boolean;
  lastSyncTime?: string;
}

/**
 * 面试准备数据
 */
export interface InterviewPrepData {
  id: string;
  company: string;
  position: string;
  interviewTime: string;
  preparationNotes: string[];
  keyQuestions: string[];
  companyResearch: CompanyResearch;
  selfIntroduction: string;
  questionsToAsk: string[];
  checklist: ChecklistItem[];
  lastModified: string;
}

/**
 * 公司调研信息
 */
export interface CompanyResearch {
  overview: string;
  products: string[];
  culture: string;
  recentNews: string[];
  interviewExperiences: string[];
}

/**
 * 检查清单项
 */
export interface ChecklistItem {
  id: string;
  content: string;
  completed: boolean;
  category: 'document' | 'appearance' | 'knowledge' | 'logistics';
}

/**
 * 同步状态
 */
export interface SyncStatus {
  isSyncing: boolean;
  lastSyncTime: string;
  syncedDevices: string[];
  pendingChanges: number;
}

export class CrossDeviceInterviewService {
  private static deviceManager: distributedDeviceManager.DeviceManager | null = null;
  private static syncManager: distributedDataSync.DistributedDataSync | null = null;
  private static readonly STORE_ID = 'interview_prep_sync';

  /**
   * 初始化跨设备服务
   */
  static async initialize(): Promise<boolean> {
    try {
      // 创建设备管理器
      this.deviceManager = distributedDeviceManager.createDeviceManager('com.buddyjob.app');
      hilog.info(DOMAIN, TAG, 'Device manager created');

      // 创建数据同步管理器
      this.syncManager = distributedDataSync.createDistributedDataSync({
        storeId: this.STORE_ID,
        bundleName: 'com.buddyjob.app'
      });

      // 监听设备状态变化
      this.setupDeviceListener();

      // 监听数据变化
      this.setupDataListener();

      hilog.info(DOMAIN, TAG, 'Cross device service initialized');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${error}`);
      return false;
    }
  }

  /**
   * 获取可用设备列表
   */
  static async getAvailableDevices(): Promise<DeviceInfo[]> {
    try {
      if (!this.deviceManager) {
        return [];
      }

      const devices = this.deviceManager.getAvailableDeviceList();
      const deviceInfos: DeviceInfo[] = devices.map((device) => ({
        deviceId: device.deviceId,
        deviceName: device.deviceName,
        deviceType: this.parseDeviceType(device.deviceType),
        isOnline: true
      }));

      return deviceInfos;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get devices failed: ${error}`);
      return [];
    }
  }

  /**
   * 创建面试准备
   */
  static async createInterviewPrep(data: Omit<InterviewPrepData, 'id' | 'lastModified'>): Promise<InterviewPrepData | null> {
    try {
      const prepData: InterviewPrepData = {
        ...data,
        id: this.generateId(),
        lastModified: new Date().toISOString()
      };

      // 保存到本地
      await this.saveLocalPrep(prepData);

      // 同步到其他设备
      await this.syncToDevices(prepData);

      hilog.info(DOMAIN, TAG, `Interview prep created: ${prepData.id}`);
      return prepData;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Create prep failed: ${error}`);
      return null;
    }
  }

  /**
   * 更新面试准备
   */
  static async updateInterviewPrep(prepData: InterviewPrepData): Promise<boolean> {
    try {
      prepData.lastModified = new Date().toISOString();

      // 更新本地数据
      await this.saveLocalPrep(prepData);

      // 同步到其他设备
      await this.syncToDevices(prepData);

      hilog.info(DOMAIN, TAG, `Interview prep updated: ${prepData.id}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Update prep failed: ${error}`);
      return false;
    }
  }

  /**
   * 获取面试准备数据
   */
  static async getInterviewPrep(prepId: string): Promise<InterviewPrepData | null> {
    try {
      const key = `prep_${prepId}`;
      const data = await storage.get(key, null);

      if (data) {
        return JSON.parse(data) as InterviewPrepData;
      }

      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get prep failed: ${error}`);
      return null;
    }
  }

  /**
   * 获取所有面试准备列表
   */
  static async getAllInterviewPreps(): Promise<InterviewPrepData[]> {
    try {
      const keys = await storage.getAllKeys();
      const prepKeys = keys.filter(key => key.startsWith('prep_'));

      const preps: InterviewPrepData[] = [];
      for (const key of prepKeys) {
        const data = await storage.get(key, null);
        if (data) {
          preps.push(JSON.parse(data) as InterviewPrepData);
        }
      }

      // 按修改时间排序
      preps.sort((a, b) =>
        new Date(b.lastModified).getTime() - new Date(a.lastModified).getTime()
      );

      return preps;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get all preps failed: ${error}`);
      return [];
    }
  }

  /**
   * 同步到指定设备
   */
  static async syncToDevice(deviceId: string, prepData: InterviewPrepData): Promise<boolean> {
    try {
      if (!this.syncManager) {
        return false;
      }

      await this.syncManager.syncData({
        deviceId,
        data: {
          key: `prep_${prepData.id}`,
          value: JSON.stringify(prepData)
        }
      });

      hilog.info(DOMAIN, TAG, `Synced to device: ${deviceId}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Sync to device failed: ${error}`);
      return false;
    }
  }

  /**
   * 同步到所有设备
   */
  static async syncToDevices(prepData: InterviewPrepData): Promise<void> {
    try {
      const devices = await this.getAvailableDevices();

      for (const device of devices) {
        await this.syncToDevice(device.deviceId, prepData);
      }

      hilog.info(DOMAIN, TAG, `Synced to ${devices.length} devices`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Sync to devices failed: ${error}`);
    }
  }

  /**
   * 请求从其他设备同步
   */
  static async requestSyncFromDevice(deviceId: string): Promise<boolean> {
    try {
      if (!this.syncManager) {
        return false;
      }

      await this.syncManager.requestSync({
        deviceId,
        keys: ['prep_'] // 请求所有 prep_ 开头的数据
      });

      hilog.info(DOMAIN, TAG, `Requested sync from device: ${deviceId}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Request sync failed: ${error}`);
      return false;
    }
  }

  /**
   * 获取同步状态
   */
  static async getSyncStatus(): Promise<SyncStatus> {
    try {
      const lastSyncTime = await storage.get('last_sync_time', '');
      const syncedDevices = await storage.get('synced_devices', '[]');
      const pendingChanges = await storage.get('pending_changes', 0);

      return {
        isSyncing: false,
        lastSyncTime,
        syncedDevices: JSON.parse(syncedDevices),
        pendingChanges
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Get sync status failed: ${error}`);
      return {
        isSyncing: false,
        lastSyncTime: '',
        syncedDevices: [],
        pendingChanges: 0
      };
    }
  }

  /**
   * 更新检查清单项
   */
  static async updateChecklistItem(
    prepId: string,
    itemId: string,
    completed: boolean
  ): Promise<boolean> {
    try {
      const prep = await this.getInterviewPrep(prepId);
      if (!prep) {
        return false;
      }

      const item = prep.checklist.find(i => i.id === itemId);
      if (item) {
        item.completed = completed;
        await this.updateInterviewPrep(prep);
        return true;
      }

      return false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Update checklist item failed: ${error}`);
      return false;
    }
  }

  /**
   * 添加准备笔记
   */
  static async addPreparationNote(prepId: string, note: string): Promise<boolean> {
    try {
      const prep = await this.getInterviewPrep(prepId);
      if (!prep) {
        return false;
      }

      prep.preparationNotes.push(note);
      await this.updateInterviewPrep(prep);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Add note failed: ${error}`);
      return false;
    }
  }

  /**
   * 设置设备监听器
   */
  private static setupDeviceListener(): void {
    if (!this.deviceManager) {
      return;
    }

    this.deviceManager.on('deviceStateChange', (device) => {
      hilog.info(DOMAIN, TAG, `Device state changed: ${device.deviceId}, online: ${device.isOnline}`);

      if (device.isOnline) {
        // 设备上线时自动同步
        this.syncAllToDevice(device.deviceId);
      }
    });
  }

  /**
   * 设置数据监听器
   */
  private static setupDataListener(): void {
    if (!this.syncManager) {
      return;
    }

    this.syncManager.on('dataChange', (data) => {
      hilog.info(DOMAIN, TAG, `Data changed from remote: ${data.key}`);

      // 保存接收到的数据
      storage.set(data.key, data.value);

      // 更新同步时间
      storage.set('last_sync_time', new Date().toISOString());
    });
  }

  /**
   * 同步所有数据到指定设备
   */
  private static async syncAllToDevice(deviceId: string): Promise<void> {
    try {
      const preps = await this.getAllInterviewPreps();

      for (const prep of preps) {
        await this.syncToDevice(deviceId, prep);
      }

      hilog.info(DOMAIN, TAG, `Synced all data to device: ${deviceId}`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Sync all to device failed: ${error}`);
    }
  }

  /**
   * 保存本地准备数据
   */
  private static async saveLocalPrep(prepData: InterviewPrepData): Promise<void> {
    const key = `prep_${prepData.id}`;
    await storage.set(key, JSON.stringify(prepData));
  }

  /**
   * 解析设备类型
   */
  private static parseDeviceType(type: number): DeviceType {
    switch (type) {
      case 0x00:
        return DeviceType.PHONE;
      case 0x01:
        return DeviceType.TABLET;
      case 0x02:
        return DeviceType.WATCH;
      case 0x03:
        return DeviceType.TV;
      default:
        return DeviceType.PHONE;
    }
  }

  /**
   * 生成唯一ID
   */
  private static generateId(): string {
    return `prep_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 销毁服务
   */
  static destroy(): void {
    if (this.deviceManager) {
      this.deviceManager.off('deviceStateChange');
    }

    if (this.syncManager) {
      this.syncManager.off('dataChange');
    }

    hilog.info(DOMAIN, TAG, 'Cross device service destroyed');
  }
}
