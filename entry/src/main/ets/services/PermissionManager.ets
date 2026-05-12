/**
 * 运行时权限管理服务
 * 基于 HarmonyOS 权限管理框架
 * 实现权限申请、检查、引导
 */
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { common, bundleManager } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const TAG = 'PermissionManager';
const DOMAIN = 0xFF00;

// 权限类型
export enum PermissionType {
  INTERNET = 'ohos.permission.INTERNET',
  GET_NETWORK_INFO = 'ohos.permission.GET_NETWORK_INFO',
  ACCESS_WIFI_STATE = 'ohos.permission.ACCESS_WIFI_STATE',
  READ_MEDIA = 'ohos.permission.READ_MEDIA',
  WRITE_MEDIA = 'ohos.permission.WRITE_MEDIA',
  READ_IMAGEVIDEO = 'ohos.permission.READ_IMAGEVIDEO',
  WRITE_IMAGEVIDEO = 'ohos.permission.WRITE_IMAGEVIDEO',
  READ_FILE = 'ohos.permission.READ_FILE',
  WRITE_FILE = 'ohos.permission.WRITE_FILE',
  ACCESS_BIOMETRIC = 'ohos.permission.ACCESS_BIOMETRIC',
  CAMERA = 'ohos.permission.CAMERA',
  MICROPHONE = 'ohos.permission.MICROPHONE',
  LOCATION = 'ohos.permission.LOCATION',
  APPROXIMATELY_LOCATION = 'ohos.permission.APPROXIMATELY_LOCATION',
  DISTRIBUTED_DATASYNC = 'ohos.permission.DISTRIBUTED_DATASYNC'
}

// 权限分组
export enum PermissionGroup {
  NETWORK = 'network',
  STORAGE = 'storage',
  MEDIA = 'media',
  BIOMETRIC = 'biometric',
  LOCATION = 'location',
  DISTRIBUTED = 'distributed'
}

// 权限配置
interface PermissionConfig {
  permission: PermissionType;
  group: PermissionGroup;
  label: string;
  description: string;
  reason: string;
  isRequired: boolean;
  isSensitive: boolean;
}

// 权限状态
export interface PermissionStatus {
  permission: PermissionType;
  granted: boolean;
  canRequest: boolean;  // 是否可以再次请求
}

/**
 * 权限管理器
 * 提供权限申请、检查、引导功能
 */
export class PermissionManager {
  private static instance: PermissionManager;
  private context: common.UIAbilityContext | null = null;
  private accessTokenManager: abilityAccessCtrl.AtManager | null = null;

  // 权限配置映射
  private permissionConfigs: Map<PermissionType, PermissionConfig> = new Map([
    [PermissionType.INTERNET, {
      permission: PermissionType.INTERNET,
      group: PermissionGroup.NETWORK,
      label: '网络访问',
      description: '用于访问互联网获取求职信息',
      reason: '需要网络访问权限来获取最新的职位信息和AI服务',
      isRequired: true,
      isSensitive: false
    }],
    [PermissionType.GET_NETWORK_INFO, {
      permission: PermissionType.GET_NETWORK_INFO,
      group: PermissionGroup.NETWORK,
      label: '网络状态',
      description: '用于检查网络连接状态',
      reason: '需要获取网络状态以提供最佳体验',
      isRequired: false,
      isSensitive: false
    }],
    [PermissionType.READ_MEDIA, {
      permission: PermissionType.READ_MEDIA,
      group: PermissionGroup.MEDIA,
      label: '读取媒体文件',
      description: '用于读取简历文件和头像图片',
      reason: '需要读取您的简历文件进行AI分析',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.WRITE_MEDIA, {
      permission: PermissionType.WRITE_MEDIA,
      group: PermissionGroup.MEDIA,
      label: '写入媒体文件',
      description: '用于保存简历分析报告',
      reason: '需要保存简历分析报告到本地',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.READ_IMAGEVIDEO, {
      permission: PermissionType.READ_IMAGEVIDEO,
      group: PermissionGroup.MEDIA,
      label: '读取图片视频',
      description: '用于读取简历图片',
      reason: '需要读取您上传的简历图片',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.WRITE_IMAGEVIDEO, {
      permission: PermissionType.WRITE_IMAGEVIDEO,
      group: PermissionGroup.MEDIA,
      label: '写入图片视频',
      description: '用于保存简历截图',
      reason: '需要保存简历分析截图',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.READ_FILE, {
      permission: PermissionType.READ_FILE,
      group: PermissionGroup.STORAGE,
      label: '读取文件',
      description: '用于读取简历文档',
      reason: '需要读取您的简历文档进行分析',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.WRITE_FILE, {
      permission: PermissionType.WRITE_FILE,
      group: PermissionGroup.STORAGE,
      label: '写入文件',
      description: '用于保存分析报告',
      reason: '需要保存简历分析报告',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.ACCESS_BIOMETRIC, {
      permission: PermissionType.ACCESS_BIOMETRIC,
      group: PermissionGroup.BIOMETRIC,
      label: '生物识别',
      description: '用于指纹/面容登录',
      reason: '需要生物识别权限以提供安全快捷的登录方式',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.CAMERA, {
      permission: PermissionType.CAMERA,
      group: PermissionGroup.MEDIA,
      label: '相机',
      description: '用于拍摄简历或头像',
      reason: '需要相机权限来拍摄简历或头像',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.MICROPHONE, {
      permission: PermissionType.MICROPHONE,
      group: PermissionGroup.MEDIA,
      label: '麦克风',
      description: '用于语音面试练习',
      reason: '需要麦克风权限进行语音面试练习',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.LOCATION, {
      permission: PermissionType.LOCATION,
      group: PermissionGroup.LOCATION,
      label: '精确位置',
      description: '用于推荐附近职位',
      reason: '需要位置权限来推荐附近的职位机会',
      isRequired: false,
      isSensitive: true
    }],
    [PermissionType.DISTRIBUTED_DATASYNC, {
      permission: PermissionType.DISTRIBUTED_DATASYNC,
      group: PermissionGroup.DISTRIBUTED,
      label: '分布式数据同步',
      description: '用于跨设备数据同步',
      reason: '需要分布式数据同步权限实现跨设备协同',
      isRequired: false,
      isSensitive: true
    }]
  ]);

  private constructor() {}

  static getInstance(): PermissionManager {
    if (!PermissionManager.instance) {
      PermissionManager.instance = new PermissionManager();
    }
    return PermissionManager.instance;
  }

  /**
   * 初始化权限管理器
   */
  initialize(context: common.UIAbilityContext): void {
    this.context = context;
    this.accessTokenManager = abilityAccessCtrl.createAtManager();
    hilog.info(DOMAIN, TAG, 'Permission manager initialized');
  }

  /**
   * 检查单个权限状态
   */
  async checkPermission(permission: PermissionType): Promise<PermissionStatus> {
    if (!this.accessTokenManager || !this.context) {
      return {
        permission,
        granted: false,
        canRequest: false
      };
    }

    try {
      const grantStatus = await this.accessTokenManager.checkAccessToken(
        this.context.applicationInfo.accessTokenId,
        permission as Permissions
      );

      const granted = grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      // 检查是否可以再次请求
      let canRequest = true;
      if (!granted) {
        try {
          const bundleInfo = await bundleManager.getBundleInfoForSelf(
            bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
          );
          canRequest = await this.accessTokenManager.canRequestPermission(
            bundleInfo.name,
            permission as Permissions
          );
        } catch (e) {
          canRequest = false;
        }
      }

      return {
        permission,
        granted,
        canRequest
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Check permission failed: ${JSON.stringify(error)}`);
      return {
        permission,
        granted: false,
        canRequest: false
      };
    }
  }

  /**
   * 批量检查权限状态
   */
  async checkPermissions(permissions: PermissionType[]): Promise<Map<PermissionType, PermissionStatus>> {
    const results = new Map<PermissionType, PermissionStatus>();

    for (const permission of permissions) {
      const status = await this.checkPermission(permission);
      results.set(permission, status);
    }

    return results;
  }

  /**
   * 请求单个权限
   */
  async requestPermission(permission: PermissionType): Promise<boolean> {
    if (!this.context) {
      return false;
    }

    try {
      const result = await this.accessTokenManager!.requestPermissionsFromUser(
        this.context,
        [permission as Permissions]
      );

      const granted = result.authResults[0] === 0;
      hilog.info(DOMAIN, TAG, `Request permission ${permission}: ${granted ? 'granted' : 'denied'}`);
      return granted;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Request permission failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 批量请求权限
   */
  async requestPermissions(permissions: PermissionType[]): Promise<Map<PermissionType, boolean>> {
    if (!this.context) {
      return new Map();
    }

    const results = new Map<PermissionType, boolean>();

    try {
      const result = await this.accessTokenManager!.requestPermissionsFromUser(
        this.context,
        permissions as Permissions[]
      );

      permissions.forEach((permission, index) => {
        results.set(permission, result.authResults[index] === 0);
      });

      return results;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Request permissions failed: ${JSON.stringify(error)}`);
      permissions.forEach(p => results.set(p, false));
      return results;
    }
  }

  /**
   * 请求权限组
   */
  async requestPermissionGroup(group: PermissionGroup): Promise<Map<PermissionType, boolean>> {
    const permissions = Array.from(this.permissionConfigs.values())
      .filter(config => config.group === group)
      .map(config => config.permission);

    return this.requestPermissions(permissions);
  }

  /**
   * 获取权限配置
   */
  getPermissionConfig(permission: PermissionType): PermissionConfig | undefined {
    return this.permissionConfigs.get(permission);
  }

  /**
   * 获取权限组配置
   */
  getPermissionGroupConfig(group: PermissionGroup): PermissionConfig[] {
    return Array.from(this.permissionConfigs.values())
      .filter(config => config.group === group);
  }

  /**
   * 检查并请求必要权限
   */
  async checkAndRequestRequired(): Promise<boolean> {
    const requiredPermissions = Array.from(this.permissionConfigs.values())
      .filter(config => config.isRequired)
      .map(config => config.permission);

    const statusMap = await this.checkPermissions(requiredPermissions);

    let allGranted = true;
    for (const [permission, status] of statusMap) {
      if (!status.granted && status.canRequest) {
        const granted = await this.requestPermission(permission);
        if (!granted) {
          allGranted = false;
        }
      } else if (!status.granted) {
        allGranted = false;
      }
    }

    return allGranted;
  }

  /**
   * 打开系统权限设置页面
   */
  openPermissionSettings(): void {
    if (!this.context) {
      return;
    }

    try {
      // 使用 Want 打开应用设置页面
      // 实际实现需要根据系统API
      hilog.info(DOMAIN, TAG, 'Opening permission settings');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Open settings failed: ${JSON.stringify(error)}`);
    }
  }
}

export default PermissionManager;
