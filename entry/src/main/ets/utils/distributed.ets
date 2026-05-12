import distributedDataObject from '@ohos.data.distributedDataObject';
import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';

const TAG = 'DistributedDataManager';
const DOMAIN = 0x0001;

// 分布式数据对象名称
const DISTRIBUTED_OBJECT_NAME = 'buddyjob_continue_data';

// 跨设备流转数据接口
export interface ContinueData {
  // 当前页面路径
  pageUrl: string;
  // 页面状态数据
  pageState: Record<string, any>;
  // 用户信息
  userInfo?: Record<string, any>;
  // 时间戳
  timestamp: number;
}

// 简历页面状态
export interface ResumePageState {
  // 是否有简历
  hasResume: boolean;
  // 分析结果
  analysisResult: any;
  // 选中的文件名
  selectedFileName: string;
  // 当前编辑的简历内容
  resumeContent?: string;
  // 编辑状态
  isEditing?: boolean;
}

// 测评页面状态
export interface AssessmentPageState {
  // 当前测评ID
  currentAssessmentId: string;
  // 当前题目索引
  currentQuestionIndex: number;
  // 答案记录
  answers: Record<string, string | string[]>;
  // 测评列表
  assessmentList: any[];
  // 是否显示结果
  showResult: boolean;
  // 结果数据
  result?: any;
}

// 分布式数据对象类型
interface DistributedContinueData {
  continueData: string;
  lastUpdateTime: number;
  deviceId: string;
}

/**
 * 分布式数据管理器
 * 封装分布式数据对象 API，实现跨设备数据同步
 */
export class DistributedDataManager {
  private static instance: DistributedDataManager;
  private context: common.UIAbilityContext = null;
  private distributedObject: distributedDataObject.DataObject | null = null;
  private sessionId: string = 'buddyjob_distributed_session';
  private deviceId: string = '';

  private constructor() {}

  static getInstance(): DistributedDataManager {
    if (!DistributedDataManager.instance) {
      DistributedDataManager.instance = new DistributedDataManager();
    }
    return DistributedDataManager.instance;
  }

  /**
   * 初始化分布式数据管理器
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    
    try {
      // 获取设备ID
      this.deviceId = await this.getDeviceId();
      
      // 创建分布式数据对象
      const initialData: DistributedContinueData = {
        continueData: '',
        lastUpdateTime: 0,
        deviceId: this.deviceId
      };
      
      this.distributedObject = distributedDataObject.create(context, initialData);
      
      // 设置状态变更监听
      this.distributedObject.on('change', (sessionId: string, fields: string[]) => {
        this.onDataChanged(sessionId, fields);
      });
      
      // 设置状态监听
      this.distributedObject.on('status', (sessionId: string, networkId: string, status: 'online' | 'offline') => {
        this.onStatusChanged(sessionId, networkId, status);
      });
      
      // 加入分布式会话
      this.distributedObject.setSessionId(this.sessionId);
      
      hilog.info(DOMAIN, TAG, 'Distributed data manager initialized');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Init failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 销毁分布式数据管理器
   */
  destroy(): void {
    try {
      if (this.distributedObject) {
        // 移除监听
        this.distributedObject.off('change');
        this.distributedObject.off('status');
        
        // 离开会话
        this.distributedObject.setSessionId('');
        
        hilog.info(DOMAIN, TAG, 'Distributed data manager destroyed');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Destroy failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 保存跨设备流转数据
   */
  saveContinueData(data: ContinueData): void {
    try {
      if (!this.distributedObject) {
        hilog.warn(DOMAIN, TAG, 'Distributed object not initialized');
        return;
      }

      const distributedData: DistributedContinueData = {
        continueData: JSON.stringify(data),
        lastUpdateTime: Date.now(),
        deviceId: this.deviceId
      };

      // 更新分布式数据对象
      this.distributedObject['continueData'] = distributedData.continueData;
      this.distributedObject['lastUpdateTime'] = distributedData.lastUpdateTime;
      this.distributedObject['deviceId'] = distributedData.deviceId;

      hilog.info(DOMAIN, TAG, 'Continue data saved to distributed object');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Save continue data failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取跨设备流转数据
   */
  getContinueData(): ContinueData | null {
    try {
      if (!this.distributedObject) {
        hilog.warn(DOMAIN, TAG, 'Distributed object not initialized');
        return null;
      }

      const continueDataStr = this.distributedObject['continueData'] as string;
      if (!continueDataStr) {
        return null;
      }

      return JSON.parse(continueDataStr) as ContinueData;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get continue data failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 保存简历页面状态
   */
  saveResumeState(state: ResumePageState): void {
    try {
      const continueData: ContinueData = {
        pageUrl: 'pages/Resume',
        pageState: state,
        timestamp: Date.now()
      };
      this.saveContinueData(continueData);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Save resume state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取简历页面状态
   */
  getResumeState(): ResumePageState | null {
    try {
      const continueData = this.getContinueData();
      if (continueData && continueData.pageUrl === 'pages/Resume') {
        return continueData.pageState as ResumePageState;
      }
      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get resume state failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 保存测评页面状态
   */
  saveAssessmentState(state: AssessmentPageState): void {
    try {
      const continueData: ContinueData = {
        pageUrl: 'pages/Assessment',
        pageState: state,
        timestamp: Date.now()
      };
      this.saveContinueData(continueData);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Save assessment state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 获取测评页面状态
   */
  getAssessmentState(): AssessmentPageState | null {
    try {
      const continueData = this.getContinueData();
      if (continueData && continueData.pageUrl === 'pages/Assessment') {
        return continueData.pageState as AssessmentPageState;
      }
      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get assessment state failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 同步数据到指定设备
   */
  async syncToDevice(deviceId: string): Promise<boolean> {
    try {
      if (!this.distributedObject) {
        hilog.warn(DOMAIN, TAG, 'Distributed object not initialized');
        return false;
      }

      // 触发数据同步
      this.distributedObject.sync(deviceId);
      hilog.info(DOMAIN, TAG, 'Data synced to device: %{public}s', deviceId);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Sync to device failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 获取在线设备列表
   */
  async getOnlineDevices(): Promise<string[]> {
    try {
      if (!this.distributedObject) {
        return [];
      }

      // 获取分布式数据对象的参与者列表
      const participants = this.distributedObject.getParticipants();
      return participants || [];
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get online devices failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 数据变更回调
   */
  private onDataChanged(sessionId: string, fields: string[]): void {
    hilog.info(DOMAIN, TAG, 'Data changed, sessionId: %{public}s, fields: %{public}s', sessionId, JSON.stringify(fields));
    
    // 通知应用数据已变更
    AppStorage.setOrCreate('distributedDataChanged', {
      sessionId,
      fields,
      timestamp: Date.now()
    });
  }

  /**
   * 状态变更回调
   */
  private onStatusChanged(sessionId: string, networkId: string, status: 'online' | 'offline'): void {
    hilog.info(DOMAIN, TAG, 'Device status changed, networkId: %{public}s, status: %{public}s', networkId, status);
    
    // 通知应用设备状态变更
    AppStorage.setOrCreate('distributedDeviceStatus', {
      sessionId,
      networkId,
      status,
      timestamp: Date.now()
    });
  }

  /**
   * 获取设备ID
   */
  private async getDeviceId(): Promise<string> {
    try {
      // 生成或使用已有设备ID
      let deviceId = AppStorage.get<string>('deviceId');
      if (!deviceId) {
        deviceId = this.generateDeviceId();
        AppStorage.setOrCreate('deviceId', deviceId);
      }
      return deviceId;
    } catch (error) {
      return this.generateDeviceId();
    }
  }

  /**
   * 生成设备ID
   */
  private generateDeviceId(): string {
    return 'device_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
}

/**
 * 页面状态同步工具
 * 用于页面内实时同步状态到分布式数据对象
 */
export class PageStateSync {
  private distributedManager: DistributedDataManager;
  private pageName: string;
  private syncInterval: number = 5000; // 同步间隔 5 秒
  private timer: number | null = null;
  private lastState: string = '';

  constructor(pageName: string) {
    this.distributedManager = DistributedDataManager.getInstance();
    this.pageName = pageName;
  }

  /**
   * 开始自动同步
   */
  startAutoSync(getState: () => Record<string, any>): void {
    // 立即同步一次
    this.syncState(getState());

    // 设置定时同步
    this.timer = setInterval(() => {
      const state = getState();
      const stateStr = JSON.stringify(state);
      
      // 只有状态变化时才同步
      if (stateStr !== this.lastState) {
        this.syncState(state);
        this.lastState = stateStr;
      }
    }, this.syncInterval);
  }

  /**
   * 停止自动同步
   */
  stopAutoSync(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /**
   * 立即同步状态
   */
  syncState(state: Record<string, any>): void {
    try {
      if (this.pageName === 'pages/Resume') {
        this.distributedManager.saveResumeState(state as ResumePageState);
      } else if (this.pageName === 'pages/Assessment') {
        this.distributedManager.saveAssessmentState(state as AssessmentPageState);
      } else {
        const continueData: ContinueData = {
          pageUrl: this.pageName,
          pageState: state,
          timestamp: Date.now()
        };
        this.distributedManager.saveContinueData(continueData);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Sync state failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 恢复页面状态
   */
  restoreState<T>(): T | null {
    try {
      if (this.pageName === 'pages/Resume') {
        return this.distributedManager.getResumeState() as T;
      } else if (this.pageName === 'pages/Assessment') {
        return this.distributedManager.getAssessmentState() as T;
      } else {
        const continueData = this.distributedManager.getContinueData();
        if (continueData && continueData.pageUrl === this.pageName) {
          return continueData.pageState as T;
        }
      }
      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Restore state failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }
}

export default DistributedDataManager;
