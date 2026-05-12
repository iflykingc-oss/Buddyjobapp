/**
 * 安全数据存储服务
 * 基于 HarmonyOS HUKS 和分级数据保护
 * 实现敏感数据加密存储
 */
import huks from '@ohos.security.huks';
import hilog from '@ohos.hilog';
import { common, contextConstant } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';

const TAG = 'SecureStorageService';
const DOMAIN = 0xFF00;

// 数据安全等级
export enum DataSecurityLevel {
  S1 = 'S1',  // 低敏感：性别、国籍等
  S2 = 'S2',  // 中敏感：姓名、地址等
  S3 = 'S3',  // 高敏感：身份证、定位等
  S4 = 'S4'   // 严重敏感：密码、Token、生物信息等
}

// 加密分区类型
export enum EncryptionLevel {
  EL1 = 'el1',  // 设备级加密：开机即可访问
  EL2 = 'el2',  // 用户级加密：首次解锁后可访问
  EL3 = 'el3',  // 安全级加密：锁定后不可访问
  EL4 = 'el4'   // 最高级加密：锁定10秒后不可访问
}

// 敏感数据类型
export enum SensitiveDataType {
  USER_TOKEN = 'user_token',
  USER_PASSWORD = 'user_password',
  USER_PHONE = 'user_phone',
  USER_EMAIL = 'user_email',
  RESUME_DATA = 'resume_data',
  PAYMENT_INFO = 'payment_info',
  BIOMETRIC = 'biometric'
}

// 数据安全配置
interface DataSecurityConfig {
  level: DataSecurityLevel;
  encryptionLevel: EncryptionLevel;
  needEncryption: boolean;
  description: string;
}

/**
 * 安全数据存储服务
 * 提供敏感数据的加密存储、读取、删除功能
 */
export class SecureStorageService {
  private static instance: SecureStorageService;
  private context: common.UIAbilityContext | null = null;
  private keyAlias: string = 'buddyjob_secure_key';
  private isInitialized: boolean = false;

  // 数据类型与安全配置映射
  private securityConfigs: Map<SensitiveDataType, DataSecurityConfig> = new Map([
    [SensitiveDataType.USER_TOKEN, {
      level: DataSecurityLevel.S4,
      encryptionLevel: EncryptionLevel.EL2,
      needEncryption: true,
      description: '用户认证令牌'
    }],
    [SensitiveDataType.USER_PASSWORD, {
      level: DataSecurityLevel.S4,
      encryptionLevel: EncryptionLevel.EL4,
      needEncryption: true,
      description: '用户密码'
    }],
    [SensitiveDataType.USER_PHONE, {
      level: DataSecurityLevel.S3,
      encryptionLevel: EncryptionLevel.EL2,
      needEncryption: true,
      description: '用户手机号'
    }],
    [SensitiveDataType.USER_EMAIL, {
      level: DataSecurityLevel.S2,
      encryptionLevel: EncryptionLevel.EL2,
      needEncryption: true,
      description: '用户邮箱'
    }],
    [SensitiveDataType.RESUME_DATA, {
      level: DataSecurityLevel.S3,
      encryptionLevel: EncryptionLevel.EL2,
      needEncryption: true,
      description: '简历数据'
    }],
    [SensitiveDataType.PAYMENT_INFO, {
      level: DataSecurityLevel.S4,
      encryptionLevel: EncryptionLevel.EL4,
      needEncryption: true,
      description: '支付信息'
    }],
    [SensitiveDataType.BIOMETRIC, {
      level: DataSecurityLevel.S4,
      encryptionLevel: EncryptionLevel.EL4,
      needEncryption: true,
      description: '生物识别数据'
    }]
  ]);

  private constructor() {}

  static getInstance(): SecureStorageService {
    if (!SecureStorageService.instance) {
      SecureStorageService.instance = new SecureStorageService();
    }
    return SecureStorageService.instance;
  }

  /**
   * 初始化安全存储服务
   */
  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    try {
      this.context = context;

      // 生成加密密钥
      const keyGenerated = await this.generateAesKey();
      if (!keyGenerated) {
        hilog.error(DOMAIN, TAG, 'Failed to generate AES key');
        return false;
      }

      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, 'Secure storage service initialized');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 生成AES密钥
   */
  private async generateAesKey(): Promise<boolean> {
    try {
      // 检查密钥是否已存在
      const isKeyExist = await this.isKeyExist();
      if (isKeyExist) {
        hilog.info(DOMAIN, TAG, 'AES key already exists');
        return true;
      }

      // 生成密钥配置
      const properties: huks.HuksParam[] = [
        {
          tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
          value: huks.HuksKeyAlg.HUKS_ALG_AES
        },
        {
          tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
          value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | 
                 huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PADDING,
          value: huks.HuksKeyPadding.HUKS_PADDING_PKCS7
        },
        {
          tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
          value: huks.HuksCipherMode.HUKS_MODE_CBC
        }
      ];

      const options: huks.HuksOptions = {
        properties: properties,
        inData: new Uint8Array(0)
      };

      await huks.generateKeyItem(this.keyAlias, options);
      hilog.info(DOMAIN, TAG, 'AES key generated successfully');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Generate AES key failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 检查密钥是否存在
   */
  private async isKeyExist(): Promise<boolean> {
    try {
      const options: huks.HuksOptions = {
        properties: [],
        inData: new Uint8Array(0)
      };
      await huks.isKeyItemExist(this.keyAlias, options);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 加密数据
   */
  async encryptData(plainText: string): Promise<Uint8Array | null> {
    try {
      const iv = this.generateIV();
      
      const properties: huks.HuksParam[] = [
        {
          tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
          value: huks.HuksKeyAlg.HUKS_ALG_AES
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT
        },
        {
          tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
          value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PADDING,
          value: huks.HuksKeyPadding.HUKS_PADDING_PKCS7
        },
        {
          tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
          value: huks.HuksCipherMode.HUKS_MODE_CBC
        },
        {
          tag: huks.HuksTag.HUKS_TAG_IV,
          value: iv
        }
      ];

      const options: huks.HuksOptions = {
        properties: properties,
        inData: this.stringToUint8Array(plainText)
      };

      // 初始化加密会话
      const initResult = await huks.initSession(this.keyAlias, options);
      const handle = initResult.handle;

      // 完成加密
      const finishResult = await huks.finishSession(handle, options);
      return finishResult.outData as Uint8Array;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Encrypt data failed: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * 解密数据
   */
  async decryptData(encryptedData: Uint8Array): Promise<string | null> {
    try {
      const iv = this.generateIV();

      const properties: huks.HuksParam[] = [
        {
          tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
          value: huks.HuksKeyAlg.HUKS_ALG_AES
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        {
          tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
          value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PADDING,
          value: huks.HuksKeyPadding.HUKS_PADDING_PKCS7
        },
        {
          tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
          value: huks.HuksCipherMode.HUKS_MODE_CBC
        },
        {
          tag: huks.HuksTag.HUKS_TAG_IV,
          value: iv
        }
      ];

      const options: huks.HuksOptions = {
        properties: properties,
        inData: encryptedData
      };

      // 初始化解密会话
      const initResult = await huks.initSession(this.keyAlias, options);
      const handle = initResult.handle;

      // 完成解密
      const finishResult = await huks.finishSession(handle, options);
      return this.uint8ArrayToString(finishResult.outData as Uint8Array);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Decrypt data failed: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * 安全存储数据
   */
  async secureStore(
    dataType: SensitiveDataType,
    data: string
  ): Promise<boolean> {
    if (!this.isInitialized || !this.context) {
      hilog.error(DOMAIN, TAG, 'Service not initialized');
      return false;
    }

    const config = this.securityConfigs.get(dataType);
    if (!config) {
      hilog.error(DOMAIN, TAG, `Unknown data type: ${dataType}`);
      return false;
    }

    try {
      // 获取加密分区路径
      const filePath = this.getSecureFilePath(dataType, config.encryptionLevel);

      // 加密数据
      let dataToStore: string;
      if (config.needEncryption) {
        const encrypted = await this.encryptData(data);
        if (!encrypted) {
          return false;
        }
        dataToStore = this.uint8ArrayToBase64(encrypted);
      } else {
        dataToStore = data;
      }

      // 写入文件
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, dataToStore);
      fileIo.closeSync(file);

      hilog.info(DOMAIN, TAG, `Data stored securely: ${dataType}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Secure store failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 安全读取数据
   */
  async secureRetrieve(dataType: SensitiveDataType): Promise<string | null> {
    if (!this.isInitialized || !this.context) {
      hilog.error(DOMAIN, TAG, 'Service not initialized');
      return null;
    }

    const config = this.securityConfigs.get(dataType);
    if (!config) {
      hilog.error(DOMAIN, TAG, `Unknown data type: ${dataType}`);
      return null;
    }

    try {
      // 获取加密分区路径
      const filePath = this.getSecureFilePath(dataType, config.encryptionLevel);

      // 读取文件
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);

      const data = String.fromCharCode(...new Uint8Array(buffer));

      // 解密数据
      if (config.needEncryption) {
        const encrypted = this.base64ToUint8Array(data);
        return await this.decryptData(encrypted);
      }

      return data;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Secure retrieve failed: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * 安全删除数据
   */
  async secureDelete(dataType: SensitiveDataType): Promise<boolean> {
    if (!this.isInitialized || !this.context) {
      return false;
    }

    const config = this.securityConfigs.get(dataType);
    if (!config) {
      return false;
    }

    try {
      const filePath = this.getSecureFilePath(dataType, config.encryptionLevel);
      fileIo.unlinkSync(filePath);
      hilog.info(DOMAIN, TAG, `Data deleted: ${dataType}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Secure delete failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 获取安全文件路径
   */
  private getSecureFilePath(dataType: SensitiveDataType, level: EncryptionLevel): string {
    // 设置加密分区
    switch (level) {
      case EncryptionLevel.EL1:
        this.context!.area = contextConstant.AreaMode.EL1;
        break;
      case EncryptionLevel.EL2:
        this.context!.area = contextConstant.AreaMode.EL2;
        break;
      default:
        this.context!.area = contextConstant.AreaMode.EL2;
    }

    return `${this.context!.filesDir}/${dataType}.secure`;
  }

  /**
   * 生成IV向量
   */
  private generateIV(): Uint8Array {
    const iv = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }
    return iv;
  }

  /**
   * 字符串转Uint8Array
   */
  private stringToUint8Array(str: string): Uint8Array {
    const arr = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) {
      arr[i] = str.charCodeAt(i);
    }
    return arr;
  }

  /**
   * Uint8Array转字符串
   */
  private uint8ArrayToString(arr: Uint8Array): string {
    return String.fromCharCode(...arr);
  }

  /**
   * Uint8Array转Base64
   */
  private uint8ArrayToBase64(arr: Uint8Array): string {
    // 简化的Base64编码
    let binary = '';
    for (let i = 0; i < arr.length; i++) {
      binary += String.fromCharCode(arr[i]);
    }
    return btoa(binary);
  }

  /**
   * Base64转Uint8Array
   */
  private base64ToUint8Array(base64: string): Uint8Array {
    const binary = atob(base64);
    const arr = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      arr[i] = binary.charCodeAt(i);
    }
    return arr;
  }
}

export default SecureStorageService;
