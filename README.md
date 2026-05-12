# 一职搭子 HarmonyOS App

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0+-blue.svg)](https://developer.harmonyos.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 基于 AI 技术的智能求职助手鸿蒙原生应用

## 功能特性

- **AI 简历分析** - 多维度深度分析，STAR 法则评估
- **智能对话** - AI 求职搭子，实时求职建议
- **岗位测评** - 12 维度能力评估，行业百分位对比
- **模拟面试** - AI 面试官，即时点评反馈
- **求职知识库** - 精选求职攻略和面试技巧
- **鸿蒙特色** - 小艺智能体集成、跨设备流转

## 技术栈

- **框架**: HarmonyOS ArkTS / ArkUI
- **AI**: DeepSeek / OpenAI API
- **HMS**: 华为账号、推送、支付(IAP)
- **状态管理**: AppStorage / LocalStorage

## 项目结构

```
entry/src/main/ets/
├── pages/              # 页面
│   ├── Chat.ets        # AI 对话
│   ├── Resume.ets      # 简历分析
│   ├── Assessment.ets  # 岗位测评
│   ├── Knowledge.ets   # 知识库
│   ├── Interview.ets   # 模拟面试
│   ├── Profile.ets     # 个人中心
│   └── profile/        # 子页面
├── components/         # 组件
├── services/           # 服务
├── utils/              # 工具
└── constants/          # 常量
```

## 开发环境

- DevEco Studio 4.0+
- HarmonyOS SDK 4.0+
- Node.js 18+

## 安装运行

```bash
# 安装依赖
npm install

# 编译
npm run build

# 预览
npm run preview
```

## 配置说明

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用
2. 下载 `agconnect-services.json` 放入 `entry/src/main/resources/rawfile/`
3. 配置 HMS 服务（账号、推送、支付）

## 相关项目

- [BuddyJob Web](https://github.com/iflykingc-oss/BuddyJob) - Web 端应用

## License

MIT License © 2025 一职搭子 Team
