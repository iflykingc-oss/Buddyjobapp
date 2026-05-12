import { share } from '@kit.ShareKit';

/**
 * 分享内容类型
 */
export enum ShareType {
  TEXT = 'text',       // 文字
  IMAGE = 'image',     // 图片
  WEBPAGE = 'webpage', // 网页
}

/**
 * 分享内容
 */
export interface ShareContent {
  type: ShareType;
  text?: string;        // 分享文字内容
  imageUrl?: string;    // 图片本地路径或网络URL
  title?: string;       // 网页标题
  url?: string;         // 网页链接
  description?: string; // 描述信息
}

/**
 * 分享结果
 */
export interface ShareResult {
  success: boolean;
  errorMessage?: string;
}

/**
 * 系统分享服务 - 基于鸿蒙6.0 Share Kit
 * 支持分享文字、图片、网页
 * 用于语音备忘录分享、知识库文章分享等场景
 */
export class ShareService {
  private static instance: ShareService;

  private constructor() {
  }

  static getInstance(): ShareService {
    if (!ShareService.instance) {
      ShareService.instance = new ShareService();
    }
    return ShareService.instance;
  }

  /**
   * 分享文本
   */
  async shareText(text: string, title?: string): Promise<ShareResult> {
    try {
      await share({
        text: text,
        title: title || '一职搭子'
      });
      return { success: true };
    } catch (error) {
      console.error('[ShareService] Share text failed:', error);
      return { success: false, errorMessage: '分享文字失败' };
    }
  }

  /**
   * 分享链接
   */
  async shareLink(url: string, title?: string, description?: string): Promise<ShareResult> {
    try {
      await share({
        text: `${title || '一职搭子'} - ${description || ''}`,
        title: title || '一职搭子',
        uri: url
      });
      return { success: true };
    } catch (error) {
      console.error('[ShareService] Share link failed:', error);
      return { success: false, errorMessage: '分享链接失败' };
    }
  }

  /**
   * 分享图片
   * 适用场景：语音备忘录波形图分享、简历截图分享
   * @param imageUrl 图片本地路径或网络URL
   * @param title 可选标题
   */
  async shareImage(imageUrl: string, title?: string): Promise<ShareResult> {
    try {
      await share({
        uri: imageUrl,
        title: title || '一职搭子'
      });
      return { success: true };
    } catch (error) {
      console.error('[ShareService] Share image failed:', error);
      return { success: false, errorMessage: '分享图片失败' };
    }
  }

  /**
   * 分享网页
   * 适用场景：知识库文章分享、面试技巧链接分享
   * @param url 网页链接
   * @param title 网页标题
   * @param description 网页描述
   * @param imageUrl 缩略图URL（可选）
   */
  async shareWebpage(url: string, title: string, description?: string, imageUrl?: string): Promise<ShareResult> {
    try {
      await share({
        text: description || title,
        title: title,
        uri: url
      });
      return { success: true };
    } catch (error) {
      console.error('[ShareService] Share webpage failed:', error);
      return { success: false, errorMessage: '分享网页失败' };
    }
  }

  /**
   * 通用分享方法 - 根据 ShareContent 自动选择分享方式
   * @param content 分享内容对象
   */
  async share(content: ShareContent): Promise<ShareResult> {
    try {
      switch (content.type) {
        case ShareType.TEXT:
          return this.shareText(content.text || '', content.title);

        case ShareType.IMAGE:
          return this.shareImage(content.imageUrl || '', content.title);

        case ShareType.WEBPAGE:
          return this.shareWebpage(content.url || '', content.title || '', content.description, content.imageUrl);

        default:
          return { success: false, errorMessage: '不支持的分享类型' };
      }
    } catch (error) {
      console.error('[ShareService] Share failed:', error);
      return { success: false, errorMessage: '分享失败' };
    }
  }

  /**
   * 分享语音备忘录
   * @param title 备忘录标题
   * @param content 备忘录文字内容
   * @param imageUrl 可选波形图或封面图
   */
  async shareVoiceMemo(title: string, content: string, imageUrl?: string): Promise<ShareResult> {
    try {
      await share({
        text: content,
        title: title
      });
      return { success: true };
    } catch (error) {
      console.error('[ShareService] Share voice memo failed:', error);
      return { success: false, errorMessage: '分享语音备忘录失败' };
    }
  }

  /**
   * 分享知识文章
   */
  async shareArticle(title: string, url: string): Promise<ShareResult> {
    return this.shareLink(url, title, '来自一职搭子的求职知识分享');
  }

  /**
   * 分享知识库文章（兼容旧接口）
   * @param title 文章标题
   * @param url 文章链接
   * @param description 文章摘要
   * @param imageUrl 封面图URL（可选）
   */
  async shareKnowledgeArticle(title: string, url: string, description?: string, imageUrl?: string): Promise<ShareResult> {
    return this.shareWebpage(url, title, description, imageUrl);
  }
}

export default ShareService.getInstance();
