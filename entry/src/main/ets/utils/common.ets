/**
 * 生成唯一ID
 * @param prefix 前缀
 * @returns 格式: {prefix}_{timestamp}_{random}
 */
export function generateId(prefix: string = 'id'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
}

/**
 * 防抖函数
 */
export function debounce<T extends (...args: any[]) => any>(fn: T, delay: number): T {
  let timer: number = -1;
  return ((...args: any[]) => {
    if (timer >= 0) clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  }) as T;
}

/**
 * 节流函数
 */
export function throttle<T extends (...args: any[]) => any>(fn: T, delay: number): T {
  let lastTime = 0;
  return ((...args: any[]) => {
    const now = Date.now();
    if (now - lastTime >= delay) {
      lastTime = now;
      fn(...args);
    }
  }) as T;
}

/**
 * 格式化文件大小
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + units[i];
}

/**
 * 手机号脱敏
 */
export function maskPhone(phone: string): string {
  if (phone.length !== 11) return phone;
  return phone.substring(0, 3) + '****' + phone.substring(7);
}
