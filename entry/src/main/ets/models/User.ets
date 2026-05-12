// 数据模型 - 用户模型
export interface User {
  id: string;
  username: string;
  phone: string;
  email?: string;
  avatar?: string;
  vipLevel: number;
  vipExpireTime?: number;
  createdAt: number;
  updatedAt: number;
}

export interface LoginParams {
  phone: string;
  code: string;
}

export interface LoginResult {
  token: string;
  userInfo: User;
}
