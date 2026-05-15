import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';

interface RouterParams {
  url: string;
  params?: Record<string, Object>;
}

interface TransitionOptions {
  type: router.TransitionType;
  duration: number;
  curve: Curve;
}

interface RouterOptions {
  url: string;
  params: Record<string, Object>;
  transition: TransitionOptions;
}

/**
 * 路由跳转工具
 * 统一管理路由跳转和转场动画
 */
export class Router {
  /**
   * 跳转到新页面
   */
  static async push(url: string, params?: Record<string, Object>): Promise<void> {
    try {
      const options: RouterOptions = {
        url,
        params: params || {},
        transition: {
          type: router.TransitionType.Push,
          duration: 300,
          curve: Curve.EaseInOut
        }
      };
      await router.pushUrl(options);
    } catch (err) {
      console.error(`[Router] Push ${url} failed: ${(err as Error).message}`);
      promptAction.showToast({
        message: '页面跳转失败，请稍后重试',
        duration: 2000
      });
    }
  }

  /**
   * 替换当前页面
   */
  static async replace(url: string, params?: Record<string, Object>): Promise<void> {
    try {
      const options: RouterOptions = {
        url,
        params: params || {},
        transition: {
          type: router.TransitionType.Push,
          duration: 300,
          curve: Curve.EaseInOut
        }
      };
      await router.replaceUrl(options);
    } catch (err) {
      console.error(`[Router] Replace ${url} failed: ${(err as Error).message}`);
      promptAction.showToast({
        message: '页面跳转失败，请稍后重试',
        duration: 2000
      });
    }
  }

  /**
   * 返回上一页
   */
  static back(): void {
    router.back();
  }

  /**
   * 返回到指定页面
   */
  static backTo(url: string): void {
    const options: RouterParams = { url };
    router.back(options);
  }
}

export default Router;
