import { commentManager } from '@kit.AppGalleryKit';

/**
 * 应用评论服务
 * 使用鸿蒙6.0 AppGallery Kit 应用内评论功能
 */
export class AppReviewService {
  private static instance: AppReviewService;

  static getInstance(): AppReviewService {
    if (!AppReviewService.instance) {
      AppReviewService.instance = new AppReviewService();
    }
    return AppReviewService.instance;
  }

  /**
   * 打开应用内评论弹窗
   */
  async openComment(): Promise<void> {
    try {
      await commentManager.openComment();
    } catch (error) {
      console.error('[AppReviewService] Open comment failed:', error);
    }
  }
}

export default AppReviewService;
