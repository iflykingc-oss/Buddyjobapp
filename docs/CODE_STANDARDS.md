# 一职搭子 (BuddyJob) 编码规范

本文档定义了一职搭子 HarmonyOS 应用的编码规范，旨在保持代码一致性、可维护性和可读性。

## 目录

- [ArkTS 语言规范](#arkts-语言规范)
- [组件结构](#组件结构)
- [服务层模式](#服务层模式)
- [状态管理](#状态管理)
- [深色模式实现](#深色模式实现)
- [设计令牌](#设计令牌)
- [API 请求](#api-请求)
- [注释规范](#注释规范)

---

## ArkTS 语言规范

### 禁止使用的语法

ArkTS 是 TypeScript 的子集，以下语法在 ArkTS 中**不支持**：

| 禁止语法 | 说明 | 替代方案 |
|---------|------|---------|
| 展开运算符 (`...`) | 对象/数组展开 | 使用 `Object.assign()` 或循环 |
| `Object.keys()` | 获取对象键数组 | 使用 `for...in` 或 `Object.entries()` |
| `Object.values()` | 获取对象值数组 | 使用 `for...in` 或 `Object.entries()` |
| `Object.entries()` | 获取键值对数组 | 使用 `for...in` |
| `for...of` 循环 | 迭代数组 | 使用 `for` 或 `forEach` |
| `try...catch` (部分) | 部分错误捕获 | 使用条件判断 |

### 类型定义

```typescript
// 正确：使用 interface 定义对象类型
interface UserInfo {
  id: string;
  name: string;
  avatar?: string;
}

// 正确：使用 type 定义联合类型或别名
type RequestMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

// 正确：使用 enum 定义枚举
enum LoadingState {
  IDLE = 'idle',
  LOADING = 'loading',
  SUCCESS = 'success',
  ERROR = 'error'
}
```

### 变量声明

```typescript
// 优先使用 const，只在确实需要重新赋值时使用 let
const PI: number = 3.14159;
const API_BASE_URL: string = 'https://api.example.com';

// 避免使用 var
```

### 字符串处理

```typescript
// 正确：使用模板字符串
const welcomeMessage = `欢迎, ${userName}!`;

// 正确：字符串拼接
const fullPath = baseUrl + '/api' + endpoint;
```

### 对象操作

```typescript
// 正确：对象拷贝使用 Object.assign
const defaultConfig = { timeout: 30000, retries: 3 };
const customConfig = Object.assign({}, defaultConfig, { timeout: 50000 });

// 正确：对象合并
const merged = {};
for (const key in source) {
  if (source.hasOwnProperty(key)) {
    merged[key] = source[key];
  }
}
```

### 数组操作

```typescript
// 正确：使用 filter
const activeUsers = users.filter(user => user.isActive);

// 正确：使用 map
const userNames = users.map(user => user.name);

// 正确：使用 find
const targetUser = users.find(user => user.id === userId);

// 正确：使用 for 循环
for (let i = 0; i < items.length; i++) {
  console.log(items[i]);
}
```

---

## 组件结构

### 组件文件组织

```
components/
├── Button.ets              # 公共组件
└── profile/
    └── MemberCard.ets     # 功能性组件（按功能域组织）
```

### 组件模板

```typescript
/**
 * 组件名称 - 功能描述
 *
 * 组件用途说明、使用示例
 */
@Component
export struct MyComponent {
  // @State 装饰器 - 组件内部状态
  @State private count: number = 0;
  @State private isLoading: boolean = false;

  // @Prop 装饰器 - 父组件传入
  @Prop title: string = '';
  @Prop @Required data: DataType;

  // @Link 装饰器 - 双向绑定
  @Link currentIndex: number;

  // @StorageLink 装饰器 - AppStorage 双向绑定
  @StorageLink('theme') theme: string = 'light';

  build() {
    Column() {
      // 组件内容
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      if (this.isLoading) {
        LoadingProgress()
      } else {
        // ...
      }
    }
    .width('100%')
    .padding(16)
  }
}
```

### 组件命名

| 类型 | 命名规则 | 示例 |
|-----|---------|------|
| 页面 | PascalCase | `Chat.ets`, `ResumeAnalysis.ets` |
| 组件 | PascalCase | `ChatBubble.ets`, `MemberCard.ets` |
| 服务 | PascalCase | `ApiService.ets`, `ChatService.ets` |
| 工具函数 | camelCase | `storage.ets`, `router.ets` |

---

## 服务层模式

### 单例模式

所有服务类使用单例模式：

```typescript
export class ApiService {
  private static instance: ApiService;

  private constructor() {
    // 初始化代码
  }

  static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }
}
```

### 服务层结构

```typescript
/**
 * ServiceName - 服务描述
 *
 * 服务功能说明
 *
 * @example
 * const service = ServiceName.getInstance();
 * const result = await service.fetchData();
 */
export class ServiceName {
  private static instance: ServiceName;
  private apiService: ApiService = ApiService.getInstance();

  private constructor() {}

  static getInstance(): ServiceName {
    if (!ServiceName.instance) {
      ServiceName.instance = ServiceName();
    }
    return ServiceName.instance;
  }

  /**
   * 方法描述
   * @param paramName 参数描述
   * @returns 返回值描述
   */
  async fetchData(param: string): Promise<ResultType> {
    try {
      const response = await this.apiService.get<ResultType>('/endpoint', { param });
      if (response.success && response.data) {
        return response.data;
      }
      return this.getDefaultData();
    } catch (error) {
      console.error('[ServiceName] Fetch failed:', error);
      return this.getDefaultData();
    }
  }
}
```

---

## 状态管理

### AppStorage 使用

```typescript
// 存储值
AppStorage.setOrCreate('token', tokenValue);
AppStorage.setOrCreate('userInfo', userInfo);
AppStorage.setOrCreate('isDarkMode', false);

// 读取值
const token = AppStorage.get<string>('token');
const userInfo = AppStorage.get<UserInfo>('userInfo');

// 删除值
AppStorage.delete('token');

// 判断是否存在
const hasToken = AppStorage.has('token');
```

### @StorageLink 和 @StorageProp

```typescript
// 双向绑定
@StorageLink('theme') theme: string = 'light';

// 单向绑定（只读）
@StorageProp('userId') userId: string = '';
```

### 状态更新模式

```typescript
// 推荐：在服务层更新状态
updateUserInfo(info: UserInfo): void {
  AppStorage.setOrCreate('userInfo', info);
}

// 推荐：在页面组件中使用 @State 管理局部状态
@State private selectedTab: number = 0;
```

---

## 深色模式实现

### 颜色定义规范

```typescript
// constants/colors.ets

// 亮色模式语义颜色
export const SemanticColors = {
  Primary: '#4A90E2',
  Background: '#FFFFFF',
  Text1: '#1A1A1A',
  Text2: '#666666',
  Text3: '#999999',
  Border: '#E5E5E5',
  Surface1: '#F5F5F5',
  // ...
};

// 深色模式语义颜色
export const DarkSemanticColors = {
  Primary: '#5BA3F5',
  Background: '#1A1A1A',
  Text1: '#FFFFFF',
  Text2: '#CCCCCC',
  Text3: '#888888',
  Border: '#333333',
  Surface1: '#2A2A2A',
  // ...
};
```

### 组件中使用

```typescript
// 方式一：使用 AppStorage 中的主题状态
@StorageLink('isDarkMode') isDarkMode: boolean = false;

Column() {
  Text('Hello')
    .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
}
.backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)

// 方式二：使用自定义 hook
aboutToAppear() {
  this.isDarkMode = AppStorage.get<boolean>('isDarkMode') || false;
}
```

### 主题切换

```typescript
toggleTheme(): void {
  const current = AppStorage.get<boolean>('isDarkMode') || false;
  AppStorage.setOrCreate('isDarkMode', !current);
}
```

---

## 设计令牌

### 设计令牌结构

```typescript
// constants/design-tokens.ets

// 间距
export const SemanticSpacing = {
  Xs: 4,
  Sm: 8,
  Md: 12,
  Lg: 16,
  Xl: 20,
  Xxl: 24,
};

// 字体大小
export const SemanticFontSize = {
  Xs: 10,
  Sm: 12,
  Md: 14,
  Lg: 16,
  Xl: 18,
  Xxl: 20,
};

// 圆角
export const SemanticRadius = {
  Sm: 4,
  Md: 8,
  Lg: 12,
  Xl: 16,
  Full: 9999,
};
```

### 使用示例

```typescript
Column() {
  Text('Title')
}
.padding(SemanticSpacing.Lg)
.fontSize(SemanticFontSize.Lg)
.borderRadius(SemanticRadius.Md)
```

---

## API 请求

### 请求封装

使用 `ApiService` 提供的统一方法：

```typescript
const api = ApiService.getInstance();

// GET 请求
const response = await api.get<User[]>('/users');

// POST 请求
const response = await api.post<User>('/users', {
  name: '张三',
  email: 'zhang@example.com'
});

// PUT 请求
const response = await api.put<User>('/users/1', { name: '李四' });

// DELETE 请求
const response = await api.delete<void>('/users/1');
```

### 错误处理

```typescript
async fetchData(): Promise<Data | null> {
  try {
    const response = await this.apiService.get<Data>('/data');
    if (response.success && response.data) {
      return response.data;
    }
    return null;
  } catch (error) {
    console.error('[Service] Fetch failed:', error);
    return null;
  }
}
```

### 请求拦截器

```typescript
const api = ApiService.getInstance();

// 添加请求拦截器
api.addRequestInterceptor((config) => {
  // 添加通用请求头
  config.headers = config.headers || {};
  config.headers['X-App-Version'] = '1.0.0';
  return config;
});

// 添加响应拦截器
api.addResponseInterceptor((response) => {
  // 统一处理响应
  if (response.data?.code === 401) {
    // 处理未授权
  }
  return response;
});
```

---

## 注释规范

### JSDoc 注释

所有公开方法必须添加 JSDoc 注释：

```typescript
/**
 * 方法描述
 * @param paramName 参数描述
 * @param paramWithDefault 带默认值的参数描述
 * @returns 返回值描述
 * @throws 可能抛出的异常描述
 */
public myMethod(paramName: string, paramWithDefault: number = 10): Promise<Result> {
  // ...
}
```

### 代码注释

```typescript
// 单行注释
const PI = 3.14159; // 圆周率

// 多行注释
/*
 * 多行注释
 * 用于复杂逻辑说明
 */

// FIXME - 需要修复的问题
// TODO - 待完成的功能
// NOTE - 重要提示
// FIXME: 这里有bug，需要修复
```

### 接口和类型注释

```typescript
/**
 * 用户信息接口
 */
export interface UserInfo {
  /** 用户ID */
  id: string;

  /** 用户名 */
  name: string;

  /** 头像URL（可选） */
  avatar?: string;
}

/**
 * API 响应结构
 * @template T 数据类型
 */
export interface ApiResponse<T> {
  /** 请求是否成功 */
  success: boolean;

  /** 响应数据 */
  data?: T;

  /** 错误信息 */
  error?: string;
}
```

---

## 最佳实践

### 性能优化

1. **避免不必要的状态更新**
   ```typescript
   // 错误：每次渲染都会创建新对象
   @State private config: Config = { theme: 'light' };

   // 正确：使用 @StateLink 直接引用 AppStorage
   @StorageLink('config') config: Config;
   ```

2. **使用懒加载**
   ```typescript
   // 延迟加载大型组件
   if (this.showHeavyComponent) {
     HeavyComponent();
   }
   ```

3. **避免在 build() 中进行复杂计算**
   ```typescript
   // 正确：在 aboutToAppear 或计算属性中预处理
   aboutToAppear() {
     this.processedData = this.computeData(this.rawData);
   }
   ```

### 安全性

1. **敏感数据不存储**
   ```typescript
   // 错误：敏感信息存储在本地
   AppStorage.set('password', password);

   // 正确：仅在内存中使用
   private password: string = '';
   ```

2. **API 请求添加认证头**
   ```typescript
   api.addRequestInterceptor((config) => {
     const token = AppStorage.get<string>('token');
     if (token) {
       config.headers = config.headers || {};
       config.headers['Authorization'] = `Bearer ${token}`;
     }
     return config;
   });
   ```

---

## 工具函数

### 路由跳转

```typescript
import { Router } from '../utils/Router';

// 跳转页面
Router.push('pages/Chat');

// 带参数跳转
Router.push('pages/Detail', { id: '123' });

// 替换当前页面
Router.replace('pages/Login');

// 返回上一页
Router.back();
```

### 本地存储

```typescript
import { StorageService } from '../utils/storage';

// 保存数据
await StorageService.set('userPrefs', userPrefs);

// 读取数据
const userPrefs = await StorageService.get<UserPrefs>('userPrefs');

// 删除数据
await StorageService.delete('userPrefs');
```

---

## 参考资料

- [ArkTS 官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/)
- [HarmonyOS UI 组件](https://developer.huawei.com/consumer/cn/developer/)
- [ArkUI 组件参考](https://developer.huawei.com/consumer/cn/docs/)

---

*本文档由一职搭子开发团队维护，最后更新于 2026-05-13*
