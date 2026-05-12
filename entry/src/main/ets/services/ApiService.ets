import request from '@ohos.request';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { API_ENDPOINTS, Config } from '../constants/config';

export class ApiService {
  private static instance: ApiService;
  private baseUrl: string;
  private token: string | null;

  private constructor() {
    this.baseUrl = AppStorage.get<string>('baseUrl') || Config.API_BASE_URL;
    this.token = AppStorage.get<string>('token');
  }

  static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }

  setToken(token: string) {
    this.token = token;
    AppStorage.setOrCreate('token', token);
  }

  clearToken() {
    this.token = null;
    AppStorage.delete('token');
  }

  async request<T>(config: RequestConfig): Promise<ApiResponse<T>> {
    const url = config.url.startsWith('http')
      ? config.url
      : `${this.baseUrl}/${config.url}`;

    const header: Record<string, string> = {
      'Content-Type': 'application/json',
      ...config.headers
    };

    if (this.token) {
      header['Authorization'] = `Bearer ${this.token}`;
    }

    try {
      const response = await request.httpRequest({
        url: url,
        method: this.mapMethod(config.method),
        header: header,
        extraData: config.data,
        connectTimeout: Config.REQUEST_TIMEOUT,
        readTimeout: Config.REQUEST_TIMEOUT
      });

      if (response.code === 200) {
        const result = JSON.parse(response.result as string);
        return {
          success: true,
          data: result.data,
          message: result.message
        };
      }

      // 处理 401 未授权 - 清除 token 并跳转登录页
      if (response.code === 401) {
        // 清除本地 token
        AppStorage.setOrCreate('token', '');
        AppStorage.setOrCreate('userInfo', null);
        // 跳转到登录页
        router.replaceUrl({ url: 'pages/Login' });
        return { success: false, data: null as T, error: '登录已过期，请重新登录' };
      }

      // 处理其他错误码
      if (response.code !== 200 && response.code !== 401) {
        let resultData: Record<string, string> | null = null;
        try {
          resultData = JSON.parse(response.result as string);
        } catch (e) {
          // ignore parse error
        }
        const errorMsg = resultData?.message || resultData?.error || `请求失败(${response.code})`;
        return { success: false, data: null as T, error: errorMsg };
      }
    } catch (error) {
      console.error('[ApiService] Request failed:', error);
      return {
        success: false,
        error: '网络请求失败'
      };
    }
  }

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

  // 便捷方法
  async get<T>(url: string, params?: object): Promise<ApiResponse<T>> {
    return this.request<T>({
      url: params ? `${url}?${this.buildQuery(params)}` : url,
      method: 'GET'
    });
  }

  async post<T>(url: string, data?: object): Promise<ApiResponse<T>> {
    return this.request<T>({
      url,
      method: 'POST',
      data
    });
  }

  async put<T>(url: string, data?: object): Promise<ApiResponse<T>> {
    return this.request<T>({
      url,
      method: 'PUT',
      data
    });
  }

  async delete<T>(url: string): Promise<ApiResponse<T>> {
    return this.request<T>({
      url,
      method: 'DELETE'
    });
  }

  private buildQuery(params: object): string {
    return Object.entries(params)
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&');
  }
}

interface RequestConfig {
  url: string;
  method: string;
  headers?: Record<string, string>;
  data?: object;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: any;
}
