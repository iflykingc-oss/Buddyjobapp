import { common, Want } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { Logger } from './logger';

const TAG = 'ShareUtils';

/**
 * 分享内容类型
 */
export enum ShareType {
  /** 纯文本 */
  TEXT = 'text',
  /** 图片 */
  IMAGE = 'image',
  /** 网页链接 */
  WEBPAGE = 'webpage',
  /** 文件 */
  FILE = 'file',
  /** 多媒体（图文混合） */
  MULTIMEDIA = 'multimedia'
}

/**
 * 分享配置接口
 */
export interface ShareConfig {
  /** 分享标题 */
  title?: string;
  /** 分享描述/摘要 */
  description?: string;
  /** 分享内容 */
  content: string;
  /** 分享类型 */
  type: ShareType;
  /** 缩略图 URI（可选） */
  thumbnailUri?: string;
  /** 目标应用包名（可选，不指定则弹出系统分享面板） */
  targetBundleName?: string;
  /** 目标应用 Ability 名称（可选） */
  targetAbilityName?: string;
}

/**
 * 分享结果回调
 */
export interface ShareCallback {
  onSuccess?: () => void;
  onFailure?: (error: string) => void;
  onCancel?: () => void;
}

/**
 * 系统分享工具类
 * 封装 HarmonyOS 系统分享能力（UIAbilityContext.startAbility）
 * 支持分享文字、图片、网页等内容到微信、QQ 等第三方应用
 */
export class ShareUtils {
  private static instance: ShareUtils;

  private constructor() {}

  static getInstance(): ShareUtils {
    if (!ShareUtils.instance) {
      ShareUtils.instance = new ShareUtils();
    }
    return ShareUtils.instance;
  }

  /**
   * 分享纯文本内容
   * @param text 要分享的文本内容
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareText(
    text: string,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    const config: ShareConfig = {
      content: text,
      type: ShareType.TEXT,
      title: '一职搭子分享'
    };
    await ShareUtils.share(config, context, callback);
  }

  /**
   * 分享带标题的文本
   * @param title 标题
   * @param content 内容
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareTextWithTitle(
    title: string,
    content: string,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    const config: ShareConfig = {
      title: title,
      content: content,
      type: ShareType.TEXT
    };
    await ShareUtils.share(config, context, callback);
  }

  /**
   * 分享图片
   * @param imageUri 图片文件 URI
   * @param context UIAbilityContext 上下文
   * @param title 分享标题（可选）
   * @param callback 分享结果回调（可选）
   */
  static async shareImage(
    imageUri: string,
    context: common.UIAbilityContext,
    title?: string,
    callback?: ShareCallback
  ): Promise<void> {
    const config: ShareConfig = {
      content: imageUri,
      type: ShareType.IMAGE,
      title: title || '分享图片'
    };
    await ShareUtils.share(config, context, callback);
  }

  /**
   * 分享网页链接
   * @param url 网页 URL
   * @param title 网页标题
   * @param description 网页描述（可选）
   * @param thumbnailUri 缩略图 URI（可选）
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareWebpage(
    url: string,
    title: string,
    description?: string,
    thumbnailUri?: string,
    context?: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    if (!context) {
      Logger.error(TAG, 'UIAbilityContext is required for sharing webpage');
      return;
    }

    const config: ShareConfig = {
      content: url,
      type: ShareType.WEBPAGE,
      title: title,
      description: description,
      thumbnailUri: thumbnailUri
    };
    await ShareUtils.share(config, context, callback);
  }

  /**
   * 分享文件
   * @param fileUri 文件 URI
   * @param mimeType 文件 MIME 类型
   * @param context UIAbilityContext 上下文
   * @param title 分享标题（可选）
   * @param callback 分享结果回调（可选）
   */
  static async shareFile(
    fileUri: string,
    mimeType: string,
    context: common.UIAbilityContext,
    title?: string,
    callback?: ShareCallback
  ): Promise<void> {
    const config: ShareConfig = {
      content: fileUri,
      type: ShareType.FILE,
      title: title || '分享文件',
      description: mimeType
    };
    await ShareUtils.share(config, context, callback);
  }

  /**
   * 通用分享方法
   * 使用系统分享面板（UIAbilityContext.startAbility）发起分享
   * @param config 分享配置
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async share(
    config: ShareConfig,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    if (!context) {
      Logger.error(TAG, 'UIAbilityContext is required for sharing');
      callback?.onFailure?.('缺少应用上下文');
      return;
    }

    if (!config.content) {
      Logger.error(TAG, 'Share content cannot be empty');
      callback?.onFailure?.('分享内容不能为空');
      return;
    }

    try {
      // 构建 Want 对象，使用系统分享 Action
      const want: Want = this.buildShareWant(config);

      Logger.info(TAG, `Sharing ${config.type}: ${config.content.substring(0, 100)}...`);

      // 通过 startAbility 拉起系统分享面板
      await context.startAbility(want);

      Logger.info(TAG, 'Share panel launched successfully');
      callback?.onSuccess?.();
    } catch (error) {
      const errorMessage = `分享失败: ${JSON.stringify(error)}`;
      Logger.error(TAG, errorMessage);

      // 如果系统分享面板不可用，尝试使用备用分享方式
      const fallbackSuccess = await ShareUtils.fallbackShare(config, context);
      if (fallbackSuccess) {
        callback?.onSuccess?.();
      } else {
        callback?.onFailure?.(errorMessage);
        promptAction.showToast({ message: '分享失败，请检查是否安装了相关应用' });
      }
    }
  }

  /**
   * 直接分享到指定应用
   * @param config 分享配置
   * @param targetBundleName 目标应用包名
   * @param targetAbilityName 目标应用 Ability 名称
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareToApp(
    config: ShareConfig,
    targetBundleName: string,
    targetAbilityName: string,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    if (!context) {
      Logger.error(TAG, 'UIAbilityContext is required');
      callback?.onFailure?.('缺少应用上下文');
      return;
    }

    try {
      const want: Want = this.buildShareWant(config);
      want.bundleName = targetBundleName;
      want.abilityName = targetAbilityName;

      Logger.info(TAG, `Sharing to ${targetBundleName}`);

      await context.startAbility(want);
      callback?.onSuccess?.();
    } catch (error) {
      const errorMessage = `分享到 ${targetBundleName} 失败: ${JSON.stringify(error)}`;
      Logger.error(TAG, errorMessage);
      callback?.onFailure?.(errorMessage);
      promptAction.showToast({ message: `分享失败，请确认已安装${targetBundleName}` });
    }
  }

  /**
   * 分享到微信
   * @param config 分享配置
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareToWeChat(
    config: ShareConfig,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    await ShareUtils.shareToApp(
      config,
      'com.tencent.mm', // 微信包名
      'com.tencent.mm.ui.tools.ShareToTimelineActivity',
      context,
      callback
    );
  }

  /**
   * 分享到QQ
   * @param config 分享配置
   * @param context UIAbilityContext 上下文
   * @param callback 分享结果回调（可选）
   */
  static async shareToQQ(
    config: ShareConfig,
    context: common.UIAbilityContext,
    callback?: ShareCallback
  ): Promise<void> {
    await ShareUtils.shareToApp(
      config,
      'com.tencent.mobileqq', // QQ 包名
      'com.tencent.mobileqq.activity.JumpActivity',
      context,
      callback
    );
  }

  /**
   * 构建分享 Want 对象
   * @param config 分享配置
   * @returns Want 对象
   */
  private static buildShareWant(config: ShareConfig): Want {
    const want: Want = {
      action: 'ohos.want.action.sendData',
      type: ShareUtils.getMimeType(config.type),
      parameters: {
        'ohos.extra.shareTitle': config.title || '一职搭子分享',
        'ohos.extra.shareDescription': config.description || '',
      }
    };

    // 根据分享类型设置不同的参数
    switch (config.type) {
      case ShareType.TEXT:
        want.action = 'ohos.want.action.sendText';
        want.parameters!['ohos.extra.text'] = config.content;
        want.parameters!['ability.params.stream'] = {
          key: 'shareText',
          value: config.content
        };
        break;

      case ShareType.IMAGE:
        want.action = 'ohos.want.action.sendData';
        want.uri = config.content; // 图片文件 URI
        want.parameters!['ability.params.stream'] = {
          key: 'shareImage',
          value: {
            imageUri: config.content
          }
        };
        break;

      case ShareType.WEBPAGE:
        want.action = 'ohos.want.action.sendData';
        want.uri = config.content; // 网页 URL
        want.parameters!['ohos.extra.shareUrl'] = config.content;
        if (config.thumbnailUri) {
          want.parameters!['ohos.extra.shareThumbnail'] = config.thumbnailUri;
        }
        break;

      case ShareType.FILE:
        want.action = 'ohos.want.action.sendData';
        want.uri = config.content; // 文件 URI
        want.type = config.description || 'application/octet-stream'; // MIME type
        break;

      case ShareType.MULTIMEDIA:
        want.action = 'ohos.want.action.sendMultipleData';
        want.parameters!['ability.params.stream'] = {
          key: 'shareMultimedia',
          value: JSON.parse(config.content)
        };
        break;
    }

    // 设置目标应用（如果指定了）
    if (config.targetBundleName) {
      want.bundleName = config.targetBundleName;
    }
    if (config.targetAbilityName) {
      want.abilityName = config.targetAbilityName;
    }

    return want;
  }

  /**
   * 获取分享类型的 MIME 类型
   * @param type 分享类型
   * @returns MIME 类型字符串
   */
  private static getMimeType(type: ShareType): string {
    switch (type) {
      case ShareType.TEXT:
        return 'text/plain';
      case ShareType.IMAGE:
        return 'image/*';
      case ShareType.WEBPAGE:
        return 'text/html';
      case ShareType.FILE:
        return 'application/octet-stream';
      case ShareType.MULTIMEDIA:
        return '*/*';
      default:
        return 'text/plain';
    }
  }

  /**
   * 备用分享方式
   * 当系统分享面板不可用时，使用复制到剪贴板作为备选
   * @param config 分享配置
   * @param context UIAbilityContext 上下文
   * @returns 是否成功
   */
  private static async fallbackShare(
    config: ShareConfig,
    context: common.UIAbilityContext
  ): Promise<boolean> {
    try {
      // 对于文本类型，复制到剪贴板并提示
      if (config.type === ShareType.TEXT) {
        const pasteData = await import('@ohos.pasteboard');
        const systemPasteboard = pasteData.getSystemPasteboard();
        await systemPasteboard.setData(pasteData.createPlainTextData(config.content));

        promptAction.showToast({
          message: '已复制到剪贴板，可手动粘贴分享',
          duration: 2000
        });
        return true;
      }

      // 对于其他类型，尝试使用 UIAbility 的 openLink
      if (config.type === ShareType.WEBPAGE && config.content.startsWith('http')) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          uri: config.content
        });
        return true;
      }

      return false;
    } catch (error) {
      Logger.error(TAG, 'Fallback share also failed:', JSON.stringify(error));
      return false;
    }
  }
}

export default ShareUtils.getInstance();
