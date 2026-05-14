import hilog from '@ohos.hilog';

const DOMAIN = 0x0001;
const PREFIX = '一职搭子';

/**
 * 日志工具类
 */
export class Logger {
  private static instance: Logger;
  private domain: number;
  private prefix: string;

  private constructor(domain: number = DOMAIN, prefix: string = PREFIX) {
    this.domain = domain;
    this.prefix = prefix;
  }

  static getInstance(domain?: number, prefix?: string): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger(domain, prefix);
    }
    return Logger.instance;
  }

  /**
   * 输出调试日志
   */
  debug(message: string, ...args: Object[]): void {
    hilog.debug(this.domain, this.prefix, message, args);
  }

  /**
   * 输出信息日志
   */
  info(message: string, ...args: Object[]): void {
    hilog.info(this.domain, this.prefix, message, args);
  }

  /**
   * 输出警告日志
   */
  warn(message: string, ...args: Object[]): void {
    hilog.warn(this.domain, this.prefix, message, args);
  }

  /**
   * 输出错误日志
   */
  error(message: string, ...args: Object[]): void {
    hilog.error(this.domain, this.prefix, message, args);
  }

  /**
   * 输出致命错误日志
   */
  fatal(message: string, ...args: Object[]): void {
    hilog.fatal(this.domain, this.prefix, message, args);
  }

  /**
   * 记录方法入口
   */
  enter(methodName: string): void {
    this.debug(`[${methodName}] >>> Enter`);
  }

  /**
   * 记录方法出口
   */
  exit(methodName: string): void {
    this.debug(`[${methodName}] <<< Exit`);
  }
}

// 默认日志实例
export const logger = Logger.getInstance();
