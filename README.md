# 一职搭子 (BuddyJob)

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0+-blue.svg)](https://developer.harmonyos.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 基于 AI 技术的智能求职助手鸿蒙原生应用

一职搭子是一款运行在 HarmonyOS 平台上的 AI 求职助手应用，通过人工智能技术帮助用户优化简历、准备面试、提升求职竞争力。

## 功能特性

### 核心功能

| 功能模块 | 描述 |
|---------|------|
| **AI 简历分析** | 多维度深度分析，STAR法则评估，个性化优化建议 |
| **智能对话** | AI 求职搭子，支持多种求职场景的实时咨询和建议 |
| **岗位测评** | 12维度能力评估，MBTI职业性格、霍兰德兴趣等测评 |
| **模拟面试** | AI 面试官，语音识别，支持STAR法则引导和即时点评 |
| **求职知识库** | 精选求职攻略、简历技巧、面试经验等文章 |
| **Offer 分析** | 多Offer对比分析，雷达图可视化，权重自定义 |

### 特色功能

- **小艺智能体集成** - 通过小艺建议卡片快速启动应用核心功能
- **跨设备流转** - 支持设备间任务接续，面试可在手机与平板间无缝切换
- **深色模式** - 支持系统级深色模式，自动跟随系统设置
- **会员体系** - 完整的VIP会员权益体系

## 技术栈

| 类别 | 技术 |
|-----|------|
| **框架** | HarmonyOS NEXT / ArkTS / ArkUI |
| **AI 服务** | DeepSeek / OpenAI API |
| **华为服务** | HMS Core (账号、推送、支付IAP) |
| **状态管理** | AppStorage / LocalStorage |
| **网络请求** | @ohos.net.http |
| **媒体服务** | @ohos.multimedia.media |

## 项目结构

```
buddyjob-harmony/
├── entry/src/main/ets/
│   ├── pages/                    # 页面
│   │   ├── Chat.ets              # AI 对话
│   │   ├── Resume.ets            # 简历分析
│   │   ├── Assessment.ets        # 岗位测评
│   │   ├── Knowledge.ets         # 知识库
│   │   ├── Interview.ets         # 模拟面试
│   │   ├── OfferAnalysis.ets     # Offer分析
│   │   ├── Kanban.ets            # 求职看板
│   │   ├── Profile.ets           # 个人中心
│   │   └── profile/              # 设置相关页面
│   ├── components/                # 公共组件
│   │   ├── chat/                 # 聊天组件
│   │   ├── interview/            # 面试组件
│   │   ├── kanban/               # 看板组件
│   │   ├── offer/                # Offer组件
│   │   └── resume/               # 简历组件
│   ├── services/                  # 服务层
│   │   ├── ApiService.ets        # HTTP请求封装
│   │   ├── AuthService.ets       # 认证服务
│   │   ├── ChatService.ets        # 聊天服务(SSE)
│   │   ├── AssessmentService.ets  # 测评服务
│   │   ├── InterviewService.ets  # 面试服务
│   │   ├── PaymentService.ets    # 支付服务
│   │   └── ...
│   ├── models/                    # 数据模型
│   ├── utils/                     # 工具函数
│   ├── constants/                  # 常量定义
│   └── stores/                    # 状态存储
├── docs/                          # 文档
│   ├── CODE_STANDARDS.md         # 编码规范
│   └── backend-architecture.md   # 后端架构文档
└── README.md
```

## 快速开始

### 环境要求

- DevEco Studio 4.0+
- HarmonyOS SDK 4.0+
- Node.js 18+

### 安装运行

```bash
# 安装依赖
npm install

# 编译构建
npm run build

# 预览调试
npm run preview
```

### 配置说明

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用
2. 下载 `agconnect-services.json` 放入 `entry/src/main/resources/rawfile/`
3. 配置 HMS 服务：
   - 认证服务（华为账号登录）
   - 推送服务（消息通知）
   - 应用内支付（VIP会员购买）

### 环境变量配置

在 `entry/src/main/ets/constants/config.ets` 中配置 API 地址：

```typescript
export class Config {
  static readonly API_BASE_URL: string = 'https://api.example.com';
  static readonly REQUEST_TIMEOUT: number = 30000;
}
```

## 模块说明

### 服务层 (services/)

| 服务 | 功能 |
|-----|------|
| `ApiService` | 统一HTTP请求封装，支持拦截器、重试、取消 |
| `AuthService` | 华为账号登录、Token管理 |
| `ChatService` | SSE流式对话、上下文记忆、场景模式 |
| `AssessmentService` | 测评获取、提交、结果计算 |
| `InterviewService` | 面试问题生成、语音录制、AI点评 |
| `KnowledgeService` | 知识库文章获取、搜索、收藏 |
| `PaymentService` | 华为IAP支付、订单管理 |
| `ResumeService` | 简历上传、解析、优化建议 |

### 状态管理

应用使用 ArkTS 的 AppStorage 进行全局状态管理：

```typescript
// 存储
AppStorage.setOrCreate('token', tokenValue);
AppStorage.setOrCreate('userInfo', userInfo);

// 读取
const token = AppStorage.get<string>('token');
const userInfo = AppStorage.get<UserInfo>('userInfo');
```

## 相关项目

- [BuddyJob Web](https://github.com/iflykingc-oss/BuddyJob) - Web 端应用
- [BuddyJob Backend](https://github.com/iflykingc-oss/BuddyJob-Backend) - 后端服务

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 开发规范

请参阅 [CODE_STANDARDS.md](./docs/CODE_STANDARDS.md) 了解项目编码规范。

## License

MIT License - 详见 [LICENSE](LICENSE) 文件

---

MIT License - 一职搭子 Team - 2025
