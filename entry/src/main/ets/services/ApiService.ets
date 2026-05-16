import request from '@ohos.request';
import { Router } from '../utils/Router';
import { API_ENDPOINTS, Config } from '../constants/config';

// 错误码枚举
export enum ErrorCode {
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT = 'TIMEOUT',
  SERVER_ERROR = 'SERVER_ERROR',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  NOT_FOUND = 'NOT_FOUND',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  UNKNOWN = 'UNKNOWN'
}

// API错误接口
export interface ApiError {
  code: ErrorCode;
  message: string;
  details?: Object;
  statusCode?: number;
}

export class RequestConfigWithHeader {
  url: string = '';
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' = 'GET';
  data?: Object;
  params?: Record<string, string>;
  headers?: Record<string, string>;
  timeout?: number;
  retry?: boolean;
  requestId?: string;
  header: Record<string, string> = {};
}

// 请求配置接口
export interface RequestConfig {
  url: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  data?: Object;
  params?: Record<string, string>;
  headers?: Record<string, string>;
  timeout?: number;
  retry?: boolean;
  requestId?: string;
}

// API响应接口
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: ApiError | string;
}

// 拦截器类型定义
type RequestInterceptor = (config: RequestConfig) => RequestConfig | Promise<RequestConfig>;
type ResponseInterceptor = (response: ApiResponse<Object>) => ApiResponse<Object> | Promise<ApiResponse<Object>>;

// 取消请求接口（模拟AbortSignal）
export interface CancellableRequest {
  cancelled: boolean;
  cancel: () => void;
}

/**
 * ApiService - API 服务层
 *
 * 提供统一的 HTTP 请求封装，支持拦截器、重试机制和请求取消
 * 使用单例模式，通过 getInstance() 获取实例
 *
 * @example
 * const api = ApiService.getInstance();
 * const response = await api.get('/users/1');
 * const result = await api.post('/users', { name: '张三' });
 *
 * @since 1.0.0
 */
export class ApiService {
  private static instance: ApiService;
  private baseUrl: string;
  private token: string | null;

  // 拦截器
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];

  // 重试配置
  private retryCount: number = 3;
  private retryDelay: number = 1000; // ms

  // 请求取消追踪
  private pendingRequests: Map<string, CancellableRequest> = new Map();

  // 日志开关
  private enableLogging: boolean = true;

  private constructor() {
    this.baseUrl = AppStorage.get<string>('baseUrl') || Config.API_BASE_URL;
    const storedToken: string | undefined = AppStorage.get<string>('token');
    this.token = storedToken || null;
  }

  /**
   * 获取 ApiService 单例实例
   * @returns ApiService 实例
   */
  static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }

  /**
   * 设置认证令牌
   * @param token 认证令牌字符串
   */
  setToken(token: string): void {
    this.token = token;
    AppStorage.setOrCreate('token', token);
  }

  /**
   * 清除认证令牌
   */
  clearToken(): void {
    this.token = null;
    AppStorage.delete('token');
  }

  /**
   * 检查是否已设置令牌
   * @returns 是否存在有效令牌
   */
  hasToken(): boolean {
    return !!this.token && this.token.length > 0;
  }

  // ==================== 拦截器管理 ====================

  /**
   * 添加请求拦截器
   * @param interceptor 请求拦截器函数，在请求发送前执行
   */
  addRequestInterceptor(interceptor: RequestInterceptor): void {
    this.requestInterceptors.push(interceptor);
  }

  /**
   * 添加响应拦截器
   * @param interceptor 响应拦截器函数，在响应返回后执行
   */
  addResponseInterceptor(interceptor: ResponseInterceptor): void {
    this.responseInterceptors.push(interceptor);
  }

  /**
   * 移除所有请求拦截器
   */
  clearRequestInterceptors(): void {
    this.requestInterceptors = [];
  }

  /**
   * 移除所有响应拦截器
   */
  clearResponseInterceptors(): void {
    this.responseInterceptors = [];
  }

  // ==================== 重试配置 ====================

  /**
   * 设置重试次数
   * @param count 重试次数，默认3次
   */
  setRetryCount(count: number): void {
    this.retryCount = Math.max(0, count);
  }

  /**
   * 设置重试延迟
   * @param delay 延迟毫秒数，默认1000ms
   */
  setRetryDelay(delay: number): void {
    this.retryDelay = Math.max(0, delay);
  }

  // ==================== 请求取消 ====================

  /**
   * 取消指定请求
   * @param requestId 请求ID
   */
  cancelRequest(requestId: string): void {
    const cancellable = this.pendingRequests.get(requestId);
    if (cancellable) {
      cancellable.cancelled = true;
      cancellable.cancel();
      this.pendingRequests.delete(requestId);
      this.log(`[ApiService] Request cancelled: ${requestId}`);
    }
  }

  /**
   * 取消所有待处理的请求
   */
  cancelAllRequests(): void {
    this.pendingRequests.forEach((cancellable, requestId) => {
      cancellable.cancelled = true;
      cancellable.cancel();
    });
    this.pendingRequests.clear();
    this.log('[ApiService] All requests cancelled');
  }

  /**
   * 创建可取消的请求对象
   * @param requestId 请求唯一标识
   * @returns 可取消请求对象
   */
  private createCancellable(requestId: string): CancellableRequest {
    const cancellable: CancellableRequest = {
      cancelled: false,
      cancel: () => {}
    };
    this.pendingRequests.set(requestId, cancellable);
    return cancellable;
  }

  /**
   * 检查请求是否已取消
   * @param requestId 请求唯一标识
   * @returns 是否已取消
   */
  private isRequestCancelled(requestId: string): boolean {
    const cancellable = this.pendingRequests.get(requestId);
    return cancellable?.cancelled ?? false;
  }

  // ==================== 日志功能 ====================

  /**
   * 设置日志开关
   * @param enable 是否启用日志
   */
  setLogging(enable: boolean): void {
    this.enableLogging = enable;
  }

  /**
   * 记录请求日志
   * @param config 请求配置
   */
  private logRequest(config: RequestConfig): void {
    if (!this.enableLogging) return;
    const timestamp = new Date().toISOString();
    console.info(`[${timestamp}] [ApiService] --> ${config.method} ${config.url}`);
    if (config.params) {
      console.info(`[${timestamp}] [ApiService] Query params:`, JSON.stringify(config.params));
    }
    if (config.data) {
      console.info(`[${timestamp}] [ApiService] Request body:`, JSON.stringify(config.data));
    }
  }

  /**
   * 记录响应日志
   * @param response 响应对象
   * @param requestId 请求ID（可选）
   */
  private logResponse(response: ApiResponse<Object>, requestId?: string): void {
    if (!this.enableLogging) return;
    const timestamp = new Date().toISOString();
    const idTag = requestId ? ` [${requestId}]` : '';
    if (response.success) {
      console.info(`[${timestamp}] [ApiService] <-- SUCCESS${idTag}`, response.message || '');
    } else {
      console.warn(`[${timestamp}] [ApiService] <-- ERROR${idTag}`, response.error);
    }
  }

  /**
   * 记录错误日志
   * @param error API错误对象
   * @param requestId 请求ID（可选）
   */
  private logError(error: ApiError, requestId?: string): void {
    if (!this.enableLogging) return;
    const timestamp = new Date().toISOString();
    const idTag = requestId ? ` [${requestId}]` : '';
    console.error(`[${timestamp}] [ApiService] ERROR${idTag}:`, JSON.stringify(error));
  }

  /**
   * 通用日志方法
   * @param message 日志消息
   */
  private log(message: string): void {
    if (!this.enableLogging) return;
    console.info(`[ApiService] ${message}`);
  }

  // ==================== 错误处理 ====================

  /**
   * 根据HTTP状态码获取错误码
   * @param statusCode HTTP状态码
   * @returns 对应的错误码枚举
   */
  private getErrorCode(statusCode: number): ErrorCode {
    switch (statusCode) {
      case 400:
        return ErrorCode.VALIDATION_ERROR;
      case 401:
        return ErrorCode.UNAUTHORIZED;
      case 403:
        return ErrorCode.FORBIDDEN;
      case 404:
        return ErrorCode.NOT_FOUND;
      case 408:
        return ErrorCode.TIMEOUT;
      default:
        if (statusCode >= 500) {
          return ErrorCode.SERVER_ERROR;
        }
        return ErrorCode.UNKNOWN;
    }
  }

  /**
   * 创建ApiError对象
   * @param code 错误码
   * @param message 错误消息
   * @param details 错误详情（可选）
   * @param statusCode HTTP状态码（可选）
   * @returns ApiError对象
   */
  private createApiError(code: ErrorCode, message: string, details?: Object, statusCode?: number): ApiError {
    return {
      code,
      message,
      details,
      statusCode
    };
  }

  /**
   * 判断是否应该重试
   * @param error 错误对象
   * @param attempt 当前尝试次数
   * @returns 是否应该重试
   */
  private shouldRetry(error: Record<string, Object>, attempt: number): boolean {
    if (attempt >= this.retryCount) {
      return false;
    }

    // 网络错误应该重试
    const errCode = error['code'];
    if (errCode === -1 || errCode === 'NETWORK_ERROR') {
      return true;
    }

    // 超时错误应该重试
    if (errCode === 0 || errCode === 'TIMEOUT') {
      return true;
    }

    // 服务器错误应该重试 (5xx)
    if (typeof errCode === 'number' && errCode >= 500 && errCode < 600) {
      return true;
    }

    return false;
  }

  /**
   * 计算指数退避延迟
   * @param attempt 当前尝试次数
   * @returns 延迟毫秒数
   */
  private calculateRetryDelay(attempt: number): number {
    // 指数退避: delay = retryDelay * 2^attempt
    // 添加随机抖动避免惊群效应
    const baseDelay = this.retryDelay * Math.pow(2, attempt);
    const jitter = Math.random() * 0.3 * baseDelay; // 0-30% 随机抖动
    return Math.floor(baseDelay + jitter);
  }

  // ==================== 拦截器执行 ====================

  /**
   * 执行请求拦截器链
   * @param config 请求配置
   * @returns 处理后的请求配置
   */
  private async executeRequestInterceptors(config: RequestConfig): Promise<RequestConfig> {
    let processedConfig: RequestConfig = {
      url: config.url,
      method: config.method,
      data: config.data,
      params: config.params,
      headers: config.headers,
      timeout: config.timeout,
      retry: config.retry,
      requestId: config.requestId
    };

    for (let i = 0; i < this.requestInterceptors.length; i++) {
      const interceptor = this.requestInterceptors[i];
      processedConfig = await interceptor(processedConfig);
    }

    return processedConfig;
  }

  /**
   * 执行响应拦截器链
   * @param response 响应对象
   * @returns 处理后的响应对象
   */
  private async executeResponseInterceptors(response: ApiResponse<Object>): Promise<ApiResponse<Object>> {
    let processedResponse: ApiResponse<Object> = {
      success: response.success,
      data: response.data,
      message: response.message,
      error: response.error
    };

    for (let i = 0; i < this.responseInterceptors.length; i++) {
      const interceptor = this.responseInterceptors[i];
      processedResponse = await interceptor(processedResponse);
    }

    return processedResponse;
  }

  // ==================== 核心请求方法 ====================

  /**
   * 发起 HTTP 请求
   * @param config 请求配置
   * @returns API响应结果
   */
  async request<T>(config: RequestConfig): Promise<ApiResponse<T>> {
    // 生成请求ID
    const requestId = config.requestId || `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // 创建可取消请求对象
    const cancellable = this.createCancellable(requestId);

    // 应用请求拦截器
    let processedConfig = config;
    try {
      processedConfig = await this.executeRequestInterceptors(config);
    } catch (interceptorError) {
      const ie = interceptorError as Object;
      this.logError(this.createApiError(ErrorCode.UNKNOWN, 'Request interceptor error', ie), requestId);
      return {
        success: false,
        error: this.createApiError(ErrorCode.UNKNOWN, 'Request interceptor error', ie)
      };
    }

    // 构建URL
    let url = processedConfig.url;
    let hasParams = false;
    if (processedConfig.params) {
      const paramKeys: string[] = Object.keys(processedConfig.params);
      for (let i = 0; i < paramKeys.length; i++) {
        const key: string = paramKeys[i];
        if (processedConfig.params[key] !== undefined) {
          hasParams = true;
          break;
        }
      }
    }
    if (processedConfig.params && hasParams) {
      const queryString = this.buildQuery(processedConfig.params);
      url = url.includes('?') ? `${url}&${queryString}` : `${url}?${queryString}`;
    }

    url = url.startsWith('http') ? url : `${this.baseUrl}/${url}`;

    // 构建请求头
    const header: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (processedConfig.headers) {
      const extraHeaders = processedConfig.headers;
      const headerKeys: string[] = Object.keys(extraHeaders);
      for (let i = 0; i < headerKeys.length; i++) {
        const key: string = headerKeys[i];
        header[key] = extraHeaders[key];
      }
    }

    if (this.token) {
      header['Authorization'] = `Bearer ${this.token}`;
    }

    // 使用拦截器处理后的URL
    const finalUrl = url;

    // 记录请求
    this.logRequest({ url: finalUrl, method: processedConfig.method, data: processedConfig.data, params: processedConfig.params, headers: processedConfig.headers, timeout: processedConfig.timeout, retry: processedConfig.retry, requestId: processedConfig.requestId });

    // 执行带重试的请求
    const shouldRetryRequest = processedConfig.retry !== false; // 默认启用重试
    let lastError: Record<string, Object> | undefined = undefined;
    let attempt = 0;

    while (true) {
      // 检查是否已取消
      if (this.isRequestCancelled(requestId)) {
        this.pendingRequests.delete(requestId);
        return {
          success: false,
          error: this.createApiError(ErrorCode.UNKNOWN, 'Request cancelled', undefined, undefined)
        };
      }

      try {
        const requestConfigWithHeader = new RequestConfigWithHeader();
        requestConfigWithHeader.url = finalUrl;
        requestConfigWithHeader.method = processedConfig.method;
        requestConfigWithHeader.data = processedConfig.data;
        requestConfigWithHeader.params = processedConfig.params;
        requestConfigWithHeader.headers = header;
        requestConfigWithHeader.timeout = processedConfig.timeout;
        requestConfigWithHeader.retry = processedConfig.retry;
        requestConfigWithHeader.requestId = processedConfig.requestId;
        requestConfigWithHeader.header = header;

        const response = await this.executeRequest<T>(requestConfigWithHeader, requestId);

        // 移除待处理请求
        this.pendingRequests.delete(requestId);

        // 应用响应拦截器
        let processedResponse: ApiResponse<T> = response;
        try {
          const interceptedResponse: ApiResponse<Object> = await this.executeResponseInterceptors(response as ApiResponse<Object>);
          processedResponse = interceptedResponse as ApiResponse<T>;
        } catch (interceptorError) {
          this.logError(this.createApiError(ErrorCode.UNKNOWN, 'Response interceptor error', interceptorError as Object), requestId);
        }

        // 记录响应
        this.logResponse(processedResponse as ApiResponse<Object>, requestId);

        return processedResponse;

      } catch (error) {
        lastError = error as Record<string, Object>;
        const errMsg = lastError ? (lastError['message'] as string) || 'Network error' : 'Network error';
        const errCode = lastError ? (lastError['code'] as number) : undefined;

        // 记录错误
        this.logError(this.createApiError(
          ErrorCode.NETWORK_ERROR,
          errMsg,
          lastError,
          errCode
        ), requestId);

        // 检查是否应该重试
        if (shouldRetryRequest && this.shouldRetry(lastError ?? {}, attempt)) {
          attempt++;
          const delay = this.calculateRetryDelay(attempt - 1);
          this.log(`[ApiService] Retrying request (attempt ${attempt}/${this.retryCount}) after ${delay}ms...`);

          // 等待延迟
          await this.delay(delay);
          continue;
        }

        // 不再重试或已达最大重试次数
        break;
      }
    }

    // 移除待处理请求
    this.pendingRequests.delete(requestId);

    // 返回错误响应
    const lastCode = lastError ? (lastError['code'] as number) || 0 : 0;
    const lastMsg = lastError ? (lastError['message'] as string) || 'Request failed' : 'Request failed';
    const errorResponse: ApiResponse<T> = {
      success: false,
      data: null as T,
      error: this.createApiError(
        this.getErrorCode(lastCode),
        lastMsg,
        lastError ?? undefined
      )
    };

    this.logResponse(errorResponse as ApiResponse<Object>, requestId);
    return errorResponse;
  }

  /**
   * 执行单个HTTP请求
   * @param config 请求配置（包含header）
   * @param requestId 请求唯一标识
   * @returns API响应结果
   */
  private async executeRequest<T>(
    config: RequestConfigWithHeader,
    requestId: string
  ): Promise<ApiResponse<T>> {
    const timeout = config.timeout || Config.REQUEST_TIMEOUT;

    try {
      const response: request.HttpResponse = await request.httpRequest({
        url: config.url,
        method: this.mapMethod(config.method),
        header: config.header,
        extraData: config.data,
        connectTimeout: timeout,
        readTimeout: timeout
      });

      // 处理HTTP状态码
      if (response.code === 200) {
        const result = JSON.parse(response.result as string) as Record<string, Object>;
        return {
          success: true,
          data: result['data'] as T,
          message: result['message'] as string
        };
      }

      // 处理401未授权 - 清除token并跳转登录页
      if (response.code === 401) {
        AppStorage.delete('token');
        AppStorage.delete('userInfo');
        Router.replace('pages/Login');
        return {
          success: false,
          data: undefined as T,
          error: this.createApiError(
            ErrorCode.UNAUTHORIZED,
            '登录已过期，请重新登录',
            undefined,
            401
          )
        };
      }

      // 处理其他错误码
      let resultData: Record<string, Object> | undefined = undefined;
      try {
        resultData = JSON.parse(response.result as string);
      } catch (e) {
        // ignore parse error
      }

      const errorMsg = (resultData?.['message'] as string) || (resultData?.['error'] as string) || `请求失败(${response.code})`;

      return {
        success: false,
        data: undefined as T,
        error: this.createApiError(
          this.getErrorCode(response.code),
          errorMsg,
          resultData,
          response.code
        )
      };

    } catch (error) {
      // 包装错误信息
      const err = error as Record<string, Object>;
      const errorMessage = (err?.['message'] as string) || '网络请求失败';

      // 判断是否为超时错误
      const isTimeout = errorMessage.includes('timeout') ||
                        errorMessage.includes('Timeout') ||
                        err['code'] === 0;

      return {
        success: false,
        data: null as T,
        error: this.createApiError(
          isTimeout ? ErrorCode.TIMEOUT : ErrorCode.NETWORK_ERROR,
          errorMessage,
          err
        )
      };
    }
  }

  /**
   * 延迟函数
   * @param ms 延迟毫秒数
   * @returns Promise
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 映射HTTP方法字符串到请求方法枚举
   * @param method HTTP方法字符串
   * @returns 请求方法枚举
   */
  private mapMethod(method: string): request.RequestMethod {
    switch (method.toUpperCase()) {
      case 'GET':
        return request.RequestMethod.GET;
      case 'POST':
        return request.RequestMethod.POST;
      case 'PUT':
        return request.RequestMethod.PUT;
      case 'DELETE':
        return request.RequestMethod.DELETE;
      default:
        return request.RequestMethod.GET;
    }
  }

  // ==================== 便捷方法 ====================

  /**
   * 发起 GET 请求
   * @param url 请求URL
   * @param params 查询参数（可选）
   * @returns API响应结果
   */
  async get<T>(url: string, params?: Record<string, string>): Promise<ApiResponse<T>> {
    return this.request<T>({
      url,
      method: 'GET',
      params
    });
  }

  /**
   * 发起 POST 请求
   * @param url 请求URL
   * @param data 请求数据（可选）
   * @param config 其他请求配置（可选）
   * @returns API响应结果
   */
  async post<T>(url: string, data?: Object, config?: Partial<RequestConfig>): Promise<ApiResponse<T>> {
    const reqConfig: RequestConfig = {
      url,
      method: 'POST',
      data,
      params: config?.params,
      headers: config?.headers,
      timeout: config?.timeout,
      retry: config?.retry,
      requestId: config?.requestId
    };
    return this.request<T>(reqConfig);
  }

  /**
   * 发起 PUT 请求
   * @param url 请求URL
   * @param data 请求数据（可选）
   * @param config 其他请求配置（可选）
   * @returns API响应结果
   */
  async put<T>(url: string, data?: Object, config?: Partial<RequestConfig>): Promise<ApiResponse<T>> {
    const reqConfig: RequestConfig = {
      url,
      method: 'PUT',
      data,
      params: config?.params,
      headers: config?.headers,
      timeout: config?.timeout,
      retry: config?.retry,
      requestId: config?.requestId
    };
    return this.request<T>(reqConfig);
  }

  /**
   * 发起 DELETE 请求
   * @param url 请求URL
   * @param config 其他请求配置（可选）
   * @returns API响应结果
   */
  async delete<T>(url: string, config?: Partial<RequestConfig>): Promise<ApiResponse<T>> {
    const reqConfig: RequestConfig = {
      url,
      method: 'DELETE',
      params: config?.params,
      headers: config?.headers,
      timeout: config?.timeout,
      retry: config?.retry,
      requestId: config?.requestId
    };
    return this.request<T>(reqConfig);
  }

  /**
   * 构建查询参数字符串
   * @param params 参数对象
   * @returns URL编码的查询参数字符串
   */
  private buildQuery(params: Record<string, string>): string {
    const parts: string[] = [];
    const keys = Object.keys(params);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = params[key];
      if (value !== null && value !== undefined) {
        parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
      }
    }
    return parts.join('&');
  }
}

// 导出类型供外部使用
export type { RequestConfig as ApiRequestConfig, ApiResponse as ApiResponseType };
