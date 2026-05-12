import { storage } from '../utils/storage';

/**
 * 图片缓存服务
 * 提供内存缓存(LRU)和磁盘缓存
 */
export class ImageCacheService {
  private static instance: ImageCacheService;
  private memoryCache: Map<string, string> = new Map(); // url -> base64
  private maxMemoryCacheSize: number = 50; // 最多缓存50张图片
  private accessOrder: string[] = []; // LRU顺序

  static getInstance(): ImageCacheService {
    if (!ImageCacheService.instance) {
      ImageCacheService.instance = new ImageCacheService();
    }
    return ImageCacheService.instance;
  }

  /**
   * 获取缓存图片
   */
  async getImage(url: string): Promise<string | null> {
    // 1. 先查内存缓存
    if (this.memoryCache.has(url)) {
      this.updateAccessOrder(url);
      return this.memoryCache.get(url)!;
    }

    // 2. 查磁盘缓存
    const diskCache = await storage.get(`img_${url}`, '');
    if (diskCache) {
      this.putToMemory(url, diskCache);
      return diskCache;
    }

    return null;
  }

  /**
   * 缓存图片
   */
  async cacheImage(url: string, base64Data: string): Promise<void> {
    this.putToMemory(url, base64Data);
    await storage.set(`img_${url}`, base64Data);
  }

  /**
   * 下载并缓存图片
   */
  async downloadAndCache(url: string): Promise<string | null> {
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      const base64 = await this.blobToBase64(blob);
      await this.cacheImage(url, base64);
      return base64;
    } catch (error) {
      console.error('Download image failed:', error);
      return null;
    }
  }

  private putToMemory(url: string, data: string): void {
    // LRU淘汰
    if (this.memoryCache.size >= this.maxMemoryCacheSize && !this.memoryCache.has(url)) {
      const oldest = this.accessOrder.shift();
      if (oldest) {
        this.memoryCache.delete(oldest);
      }
    }
    
    this.memoryCache.set(url, data);
    this.updateAccessOrder(url);
  }

  private updateAccessOrder(url: string): void {
    const index = this.accessOrder.indexOf(url);
    if (index > -1) {
      this.accessOrder.splice(index, 1);
    }
    this.accessOrder.push(url);
  }

  private blobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }
}

export default ImageCacheService;
