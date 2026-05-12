import router from '@ohos.router';

/**
 * 路由跳转工具
 * 统一管理路由跳转和转场动画
 */
export class Router {
  /**
   * 跳转到新页面
   */
  static push(url: string, params?: Record<string, Object>): void {
    router.pushUrl({
      url,
      params: params || {},
      transition: {
        type: router.TransitionType.Push,
        duration: 300,
        curve: Curve.EaseInOut
      }
    }).catch((err: Error) => {
      console.error(`[Router] Push ${url} failed: ${err.message}`);
    });
  }

  /**
   * 替换当前页面
   */
  static replace(url: string, params?: Record<string, Object>): void {
    router.replaceUrl({
      url,
      params: params || {},
      transition: {
        type: router.TransitionType.Push,
        duration: 300,
        curve: Curve.EaseInOut
      }
    }).catch((err: Error) => {
      console.error(`[Router] Replace ${url} failed: ${err.message}`);
    });
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
    router.back({ url });
  }
}

export default Router;
