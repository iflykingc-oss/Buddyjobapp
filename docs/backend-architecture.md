# BuddyJob（一职搭子）后端架构设计文档

> 版本：v1.0
> 更新日期：2026-05-13
> 文档状态：初稿

---

## 目录

1. [背景](#1-背景)
2. [系统架构总览](#2-系统架构总览)
3. [数据库设计](#3-数据库设计)
4. [API 设计](#4-api-设计)
5. [爬虫系统设计](#5-爬虫系统设计)
6. [AI 质量增强流程](#6-ai-质量增强流程)
7. [管理后台功能](#7-管理后台功能)
8. [部署方案](#8-部署方案)
9. [分阶段实施计划](#9-分阶段实施计划)

---

## 1. 背景

### 1.1 项目概述

BuddyJob（一职搭子）是一款面向求职者的智能职业助手，提供岗位测评、面试模拟、简历优化、知识库查询等功能。系统需要管理海量内容数据，并通过 AI 技术持续提升内容质量。

### 1.2 内容规模需求

| 内容类型 | 目标数量 | 覆盖范围 |
|---------|---------|---------|
| 测评题库 | 10,000+ 题 | 100+ 岗位，覆盖国内外 |
| 面试题库 | 10,000+ 题 | 技术岗、产品岗、运营岗等 |
| 知识库文章 | 10,000+ 篇 | 岗位介绍、行业分析、求职技巧 |

### 1.3 核心能力要求

- **全网内容爬取**：自动从招聘网站、技术博客、面试题库网站等平台抓取最新内容
- **AI 质量增强**：通过管理员配置的 AI 模型（盘古/OpenAI/其他）对内容进行改写、翻译、标签匹配
- **管理后台**：管理员通过 Web 后台管理所有内容、爬虫任务、AI 模型配置
- **多端部署**：鸿蒙 App（HarmonyOS NEXT）和 Web 用户端

### 1.4 技术栈选型

| 层级 | 技术方案 | 说明 |
|------|---------|------|
| 后端部署 | 华为云托管 (Cloud Hosting) | Serverless 容器化部署 |
| 数据库 | AGC Cloud DB | 华为云数据库服务 |
| API 层 | AGC Cloud Functions | Serverless 函数计算 |
| 管理后台 | Vue3 / React | Web 端 SPA 应用 |
| 数据位置 | 中国（默认）+ 新加坡 | 多区域数据同步 |

---

## 2. 系统架构总览

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         前端层 (Client Layer)                       │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  鸿蒙 App     │  │  Web 用户端   │  │  Web 管理后台            │  │
│  │  (HarmonyOS) │  │  (Next.js)   │  │  (Vue3 / React)         │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘  │
│         │                 │                      │                  │
└─────────┼─────────────────┼──────────────────────┼──────────────────┘
          │                 │                      │
          ▼                 ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API 网关层 (API Gateway Layer)                    │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              AGC Cloud Functions (Serverless API)             │  │
│  │                                                              │  │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐   │  │
│  │  │ 认证鉴权 │ │ 限流控制  │ │ 日志记录  │ │ CORS / 安全   │   │  │
│  │  └─────────┘ └──────────┘ └──────────┘ └───────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    业务逻辑层 (Business Logic Layer)                 │
│                                                                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────────┐  │
│  │ 内容管理    │ │ 爬虫调度    │ │ AI 增强    │ │ 用户服务      │  │
│  │ Service    │ │ Service    │ │ Service    │ │ Service       │  │
│  └────────────┘ └────────────┘ └────────────┘ └───────────────┘  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────────┐  │
│  │ 测评服务    │ │ 面试服务    │ │ 支付服务    │ │ 会员服务      │  │
│  │ Service    │ │ Service    │ │ Service    │ │ Service       │  │
│  └────────────┘ └────────────┘ └────────────┘ └───────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      数据层 (Data Layer)                            │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────────┐  │
│  │  AGC Cloud DB   │  │ AGC Cloud       │  │  向量数据库        │  │
│  │  (主数据库)      │  │ Storage         │  │  (ChromaDB)       │  │
│  │                 │  │ (文件/媒体存储)   │  │  (语义搜索)       │  │
│  └─────────────────┘  └─────────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    外部服务层 (External Services)                    │
│                                                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐              │
│  │ 盘古大模型     │ │ OpenAI API   │ │ 其他 AI 模型  │              │
│  │ (华为云)      │ │              │ │ (DeepSeek等) │              │
│  └──────────────┘ └──────────────┘ └──────────────┘              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐              │
│  │ 爬虫目标网站   │ │ RSSHub       │ │ 华为支付      │              │
│  │ (各招聘平台)   │ │ (RSS 聚合)   │ │ (IAP)        │              │
│  └──────────────┘ └──────────────┘ └──────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 各层职责说明

#### 前端层

| 客户端 | 技术方案 | 职责 |
|--------|---------|------|
| 鸿蒙 App | ArkTS / ArkUI | 用户端核心功能：测评、面试、知识库、简历分析 |
| Web 用户端 | Next.js (React) | 与鸿蒙 App 功能对齐的 Web 版本 |
| Web 管理后台 | Vue3 / React | 内容管理、爬虫管理、AI 模型配置、数据统计 |

#### API 网关层

- **AGC Cloud Functions** 作为 Serverless API 层，按需扩缩容
- 统一处理认证鉴权（JWT）、请求限流、日志记录、CORS 策略
- 所有请求通过 HTTPS 加密传输

#### 业务逻辑层

- 采用模块化 Service 设计，每个业务域独立 Service
- Service 之间通过依赖注入解耦
- 支持事务管理，保证数据一致性

#### 数据层

- **AGC Cloud DB**：主数据库，存储结构化数据（题库、文章、用户记录等）
- **AGC Cloud Storage**：存储非结构化数据（文件、图片、媒体资源）
- **ChromaDB**：向量数据库，用于知识库语义搜索和 RAG 检索增强生成

#### 外部服务层

- **AI 模型**：支持盘古（华为云）、OpenAI、DeepSeek、Claude 等多模型切换
- **爬虫服务**：对接各招聘网站、技术博客、RSSHub 等数据源
- **支付服务**：华为应用内支付（IAP）

---

## 3. 数据库设计

### 3.1 数据模型总览

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Category   │────<│   Position   │────<│  Assessment  │
│  (岗位分类)  │     │  (岗位信息)   │     │  (测评题库)   │
└─────────────┘     └──────────────┘     └──────┬───────┘
                                                │
                    ┌──────────────┐     ┌──────┴───────┐
                    │  Interview   │     │   Question   │
                    │  (面试题库)   │     │  (题目明细)   │
                    └──────────────┘     └──────┬───────┘
                                                │
                    ┌──────────────┐     ┌──────┴───────┐
                    │  Knowledge   │     │   Option     │
                    │  (知识库)     │     │  (选项明细)   │
                    └──────────────┘     └──────────────┘

┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   User      │────<│ UserAssess   │     │ CrawlerTask  │
│  (用户表)    │     │  Record      │     │  (爬虫任务)   │
└─────────────┘     └──────────────┘     └──────────────┘
       │
       ├────< UserInterviewRecord
       ├────< ContentReview
       └────< OperationLog
```

### 3.2 测评题库表

#### assessments（测评套题表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| positionId | String | 关联岗位 ID |
| title | String | 测评标题，如"前端开发能力测评" |
| description | String | 测评描述 |
| difficulty | String | 难度等级：junior/mid/senior |
| locale | String | 语言：zh/en |
| questionCount | Int | 题目数量 |
| duration | Int | 建议时长（分钟） |
| status | String | 状态：draft/published/archived |
| version | Int | 版本号 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

#### questions（测评题目表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| assessmentId | String | 关联测评 ID |
| type | String | 题型：single_choice/multiple_choice/true_false/scale |
| content | String | 题目内容 |
| category | String | 题目分类：hard_skill/soft_skill/personality/situation |
| difficulty | Int | 难度 1-5 |
| sortOrder | Int | 排序序号 |
| explanation | String | 答案解析 |
| aiEnhanced | Boolean | 是否经过 AI 增强 |
| createdAt | DateTime | 创建时间 |

#### options（选项表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| questionId | String | 关联题目 ID |
| content | String | 选项内容 |
| score | Float | 分值权重 |
| isCorrect | Boolean | 是否为正确答案（适用于判断题） |
| sortOrder | Int | 排序序号 |

### 3.3 面试题库表

#### interview_questions（面试题表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| positionId | String | 关联岗位 ID |
| type | String | 题型：technical/behavioral/case/system_design/coding |
| category | String | 分类：algorithm/database/network/architecture/project 等 |
| question | String | 题目内容 |
| answer | String | 参考答案 |
| followUps | String | 追问列表（JSON 数组） |
| difficulty | String | 难度：easy/medium/hard |
| frequency | Int | 面试出现频率 1-100 |
| source | String | 来源：manual/crawler/ai_generated |
| sourceUrl | String | 原始链接 |
| tags | String | 标签（逗号分隔） |
| locale | String | 语言：zh/en |
| status | String | 状态：draft/published/archived |
| aiEnhanced | Boolean | 是否经过 AI 增强 |
| viewCount | Int | 浏览次数 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 3.4 知识库表

#### knowledge_articles（知识库文章表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| positionId | String | 关联岗位 ID（可为空，表示通用文章） |
| title | String | 文章标题 |
| summary | String | 摘要（200字以内） |
| content | String | 文章正文（Markdown 格式） |
| category | String | 分类：job_intro/industry_analysis/interview_tips/resume_guide/salary_analysis |
| tags | String | 标签（逗号分隔） |
| source | String | 来源：manual/crawler/ai_generated/user_submitted |
| sourceUrl | String | 原始链接 |
| author | String | 作者 |
| coverImage | String | 封面图 URL |
| locale | String | 语言：zh/en |
| status | String | 状态：draft/review/published/archived |
| aiEnhanced | Boolean | 是否经过 AI 增强 |
| qualityScore | Float | AI 质量评分 0-100 |
| viewCount | Int | 浏览次数 |
| likeCount | Int | 点赞次数 |
| publishedAt | DateTime | 发布时间 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 3.5 岗位分类表

#### categories（岗位分类表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| name | String | 分类名称，如"技术"、"产品"、"设计" |
| nameEn | String | 英文名称 |
| icon | String | 图标标识 |
| description | String | 分类描述 |
| sortOrder | Int | 排序序号 |
| status | String | 状态：active/disabled |

#### positions（岗位信息表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| categoryId | String | 关联分类 ID |
| name | String | 岗位名称，如"前端开发工程师" |
| nameEn | String | 英文名称 |
| aliases | String | 别名（JSON 数组），如["前端","Web开发","FE"] |
| description | String | 岗位描述 |
| locale | String | 语言：zh/en |
| plainDesc | String | 通俗描述 |
| officialJD | String | 标准 JD |
| realWork | String | 真实工作内容 |
| hardSkills | String | 硬技能要求（JSON） |
| softSkills | String | 软技能要求（JSON） |
| entryBarrier | String | 入行门槛 |
| salary | String | 薪资范围（JSON） |
| pros | String | 优势（JSON） |
| cons | String | 劣势（JSON） |
| pitfalls | String | 避坑指南 |
| fitPeople | String | 适合人群 |
| unfitPeople | String | 不适合人群 |
| assessmentCount | Int | 关联测评数量 |
| interviewCount | Int | 关联面试题数量 |
| knowledgeCount | Int | 关联知识文章数量 |
| status | String | 状态：active/disabled |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 3.6 用户记录表

#### user_assessment_records（用户测评记录表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| userId | String | 用户 ID |
| assessmentId | String | 测评 ID |
| positionId | String | 岗位 ID |
| answers | String | 用户答案（JSON） |
| score | Float | 总分 |
| maxScore | Float | 满分 |
| results | String | 详细结果（JSON） |
| duration | Int | 实际用时（秒） |
| completedAt | DateTime | 完成时间 |
| createdAt | DateTime | 创建时间 |

#### user_interview_records（用户面试记录表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| userId | String | 用户 ID |
| positionId | String | 岗位 ID |
| mode | String | 模式：text/voice/cross_device |
| questions | String | 使用的面试题（JSON） |
| answers | String | 用户回答（JSON） |
| aiFeedback | String | AI 反馈（JSON） |
| overallScore | Float | 综合评分 |
| duration | Int | 总时长（秒） |
| completedAt | DateTime | 完成时间 |
| createdAt | DateTime | 创建时间 |

### 3.7 爬虫任务表

#### crawler_tasks（爬虫任务表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| name | String | 任务名称 |
| platform | String | 目标平台：boss/lagou/zhihu/juejin/glassdoor/linkedin 等 |
| type | String | 类型：assessment/interview/knowledge |
| config | String | 爬取配置（JSON）：URL 模板、选择器、分页规则等 |
| keyword | String | 搜索关键词 |
| schedule | String | 定时规则：cron 表达式 |
| enabled | Boolean | 是否启用 |
| status | String | 状态：idle/running/success/failed/paused |
| lastRunAt | DateTime | 上次运行时间 |
| lastRunStatus | String | 上次运行状态 |
| lastRunCount | Int | 上次获取条数 |
| totalRunCount | Int | 累计运行次数 |
| totalFetched | Int | 累计获取条数 |
| errorCount | Int | 连续失败次数 |
| lastError | String | 最近错误信息 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

#### data_sources（数据源表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| name | String | 数据源名称 |
| type | String | 类型：rss/rsshub/search_api/custom_api |
| platform | String | 平台标识 |
| config | String | 配置（JSON） |
| keyword | String | 关联关键词 |
| enabled | Boolean | 是否启用 |
| autoFetch | Boolean | 是否自动获取 |
| fetchInterval | Int | 获取间隔（小时） |
| lastFetchedAt | DateTime | 上次获取时间 |
| lastFetchStatus | String | 上次获取状态 |
| lastFetchCount | Int | 上次获取条数 |
| totalFetched | Int | 累计获取条数 |
| status | String | 状态：active/disabled/error |

#### fetch_records（获取记录表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| dataSourceId | String | 数据源 ID |
| platform | String | 平台 |
| keyword | String | 关键词 |
| status | String | 状态：success/partial/failed |
| totalFetched | Int | 本次获取总数 |
| newCount | Int | 新增条数 |
| duplicateCount | Int | 重复条数 |
| errorCount | Int | 失败条数 |
| errorMsg | String | 错误信息 |
| duration | Int | 耗时（毫秒） |
| triggeredBy | String | 触发方式：manual/auto/batch |
| createdAt | DateTime | 创建时间 |

### 3.8 内容审核表

#### content_review（内容审核表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (cuid) | 主键 |
| contentType | String | 内容类型：assessment/interview/knowledge |
| contentId | String | 内容 ID |
| title | String | 内容标题（冗余） |
| reviewType | String | 审核类型：new_import/ai_enhanced/user_report |
| status | String | 状态：pending/approved/rejected/needs_revision |
| reviewerId | String | 审核人 ID |
| reviewNote | String | 审核备注 |
| qualityScore | Float | 质量评分 |
| reviewedAt | DateTime | 审核时间 |
| createdAt | DateTime | 创建时间 |

### 3.9 现有数据表（已实现）

以下数据表已在当前系统中实现（基于 Prisma + SQLite），在迁移至 AGC Cloud DB 时需要重新设计：

| 数据表 | 说明 | 迁移优先级 |
|--------|------|-----------|
| User | 用户表 | P0 |
| ChatSession / ChatMessage | 聊天会话和消息 | P0 |
| Assessment | 测评记录（需扩展为完整题库） | P0 |
| ResumeAnalysis | 简历分析记录 | P0 |
| Job | 岗位知识库（需扩展） | P0 |
| ModelConfig | AI 模型配置 | P0 |
| AgentConfig | 智能体配置 | P1 |
| MembershipBenefit | 会员权益配置 | P1 |
| PaymentRecord | 支付记录 | P1 |
| OperationLog | 操作日志 | P1 |
| UgcContent | UGC 采集内容 | P1 |
| SystemConfig | 系统配置 | P1 |
| DataSource / FetchRecord | 数据源和获取记录 | P1 |

---

## 4. API 设计

### 4.1 API 设计原则

- **RESTful 风格**：资源导向的 URL 设计
- **统一响应格式**：所有接口返回统一的 JSON 结构
- **分页标准化**：所有列表接口支持统一的分页参数
- **版本管理**：API 路径包含版本号 `/api/v1/`
- **权限分级**：公开接口、用户接口、管理员接口三级权限

#### 统一响应格式

```json
{
  "success": true,
  "data": {},
  "message": "操作成功",
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### 4.2 内容管理 API

#### 测评题库 API

```
POST   /api/v1/admin/assessments              # 创建测评套题
GET    /api/v1/admin/assessments              # 获取测评列表（分页/搜索/筛选）
GET    /api/v1/admin/assessments/:id          # 获取测评详情
PUT    /api/v1/admin/assessments/:id          # 更新测评
DELETE /api/v1/admin/assessments/:id          # 删除测评
PATCH  /api/v1/admin/assessments/:id/status   # 更新测评状态

POST   /api/v1/admin/assessments/:id/questions        # 添加题目
PUT    /api/v1/admin/assessments/:id/questions/:qId   # 更新题目
DELETE /api/v1/admin/assessments/:id/questions/:qId   # 删除题目
POST   /api/v1/admin/assessments/:id/questions/reorder # 题目排序

POST   /api/v1/admin/assessments/batch/import   # 批量导入（CSV/JSON）
POST   /api/v1/admin/assessments/batch/export   # 批量导出
POST   /api/v1/admin/assessments/batch/delete   # 批量删除
POST   /api/v1/admin/assessments/batch/update   # 批量更新
```

#### 面试题库 API

```
POST   /api/v1/admin/interviews              # 创建面试题
GET    /api/v1/admin/interviews              # 获取面试题列表
GET    /api/v1/admin/interviews/:id          # 获取面试题详情
PUT    /api/v1/admin/interviews/:id          # 更新面试题
DELETE /api/v1/admin/interviews/:id          # 删除面试题
PATCH  /api/v1/admin/interviews/:id/status   # 更新状态

POST   /api/v1/admin/interviews/batch/import   # 批量导入
POST   /api/v1/admin/interviews/batch/export   # 批量导出
POST   /api/v1/admin/interviews/batch/delete   # 批量删除
```

#### 知识库 API

```
POST   /api/v1/admin/knowledge              # 创建知识文章
GET    /api/v1/admin/knowledge              # 获取文章列表
GET    /api/v1/admin/knowledge/:id          # 获取文章详情
PUT    /api/v1/admin/knowledge/:id          # 更新文章
DELETE /api/v1/admin/knowledge/:id          # 删除文章
PATCH  /api/v1/admin/knowledge/:id/status   # 更新状态

POST   /api/v1/admin/knowledge/batch/import   # 批量导入
POST   /api/v1/admin/knowledge/batch/export   # 批量导出
```

### 4.3 分页 / 搜索 / 筛选 API

所有列表接口统一支持以下查询参数：

```
GET /api/v1/admin/{resource}?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc
                                  &search=关键词
                                  &filters[positionId]=xxx
                                  &filters[difficulty]=medium
                                  &filters[status]=published
                                  &filters[locale]=zh
                                  &filters[category]=technical
                                  &filters[dateFrom]=2026-01-01
                                  &filters[dateTo]=2026-05-13
```

| 参数 | 类型 | 说明 |
|------|------|------|
| page | Int | 页码，默认 1 |
| pageSize | Int | 每页数量，默认 20，最大 100 |
| sortBy | String | 排序字段 |
| sortOrder | String | 排序方向：asc/desc |
| search | String | 全文搜索关键词 |
| filters[*] | String | 各维度筛选条件 |

### 4.4 爬虫管理 API

```
# 爬虫任务管理
POST   /api/v1/admin/crawler/tasks              # 创建爬虫任务
GET    /api/v1/admin/crawler/tasks              # 获取任务列表
GET    /api/v1/admin/crawler/tasks/:id          # 获取任务详情
PUT    /api/v1/admin/crawler/tasks/:id          # 更新任务配置
DELETE /api/v1/admin/crawler/tasks/:id          # 删除任务
POST   /api/v1/admin/crawler/tasks/:id/run      # 手动触发执行
POST   /api/v1/admin/crawler/tasks/:id/pause    # 暂停任务
POST   /api/v1/admin/crawler/tasks/:id/resume   # 恢复任务

# 数据源管理
POST   /api/v1/admin/crawler/datasources              # 创建数据源
GET    /api/v1/admin/crawler/datasources              # 获取数据源列表
GET    /api/v1/admin/crawler/datasources/:id          # 获取数据源详情
PUT    /api/v1/admin/crawler/datasources/:id          # 更新数据源
DELETE /api/v1/admin/crawler/datasources/:id          # 删除数据源
POST   /api/v1/admin/crawler/datasources/:id/fetch    # 手动触发获取
POST   /api/v1/admin/crawler/datasources/:id/toggle   # 启用/禁用
POST   /api/v1/admin/crawler/datasources/validate     # 验证配置
GET    /api/v1/admin/crawler/datasources/templates    # 获取内置模板

# 获取记录
GET    /api/v1/admin/crawler/records            # 获取获取记录列表
GET    /api/v1/admin/crawler/stats              # 获取爬虫统计数据
```

### 4.5 AI 质量增强 API

```
# AI 模型配置
POST   /api/v1/admin/ai/models              # 创建模型配置
GET    /api/v1/admin/ai/models              # 获取模型列表
PUT    /api/v1/admin/ai/models/:id          # 更新模型配置
DELETE /api/v1/admin/ai/models/:id          # 删除模型配置
POST   /api/v1/admin/ai/models/:id/test     # 测试模型连接
POST   /api/v1/admin/ai/models/:id/activate # 激活模型

# AI 增强操作
POST   /api/v1/admin/ai/enhance/assessments       # AI 增强测评题目
POST   /api/v1/admin/ai/enhance/interviews        # AI 增强面试题
POST   /api/v1/admin/ai/enhance/knowledge         # AI 增强知识文章
POST   /api/v1/admin/ai/enhance/batch             # 批量 AI 增强
POST   /api/v1/admin/ai/translate                 # 多语言翻译
POST   /api/v1/admin/ai/tag                       # 自动标签匹配
POST   /api/v1/admin/ai/difficulty                # 难度等级标注
POST   /api/v1/admin/ai/quality-score             # 内容质量评分
```

### 4.6 用户记录 API

```
# 用户端接口
GET    /api/v1/assessments                     # 获取可用测评列表
GET    /api/v1/assessments/:id                 # 获取测评详情
POST   /api/v1/assessments/:id/submit          # 提交测评结果
GET    /api/v1/user/assessments                # 获取用户测评历史

GET    /api/v1/interviews                      # 获取面试题列表（按岗位）
GET    /api/v1/interviews/random               # 随机获取面试题
POST   /api/v1/interviews/submit               # 提交面试记录
GET    /api/v1/user/interviews                 # 获取用户面试历史

GET    /api/v1/knowledge                       # 获取知识文章列表
GET    /api/v1/knowledge/:id                   # 获取文章详情
GET    /api/v1/knowledge/search                # 搜索知识文章
POST   /api/v1/knowledge/:id/like              # 点赞文章
```

### 4.7 管理后台 API

```
# 岗位管理
POST   /api/v1/admin/positions              # 创建岗位
GET    /api/v1/admin/positions              # 获取岗位列表
PUT    /api/v1/admin/positions/:id          # 更新岗位
DELETE /api/v1/admin/positions/:id          # 删除岗位

# 分类管理
POST   /api/v1/admin/categories             # 创建分类
GET    /api/v1/admin/categories             # 获取分类列表
PUT    /api/v1/admin/categories/:id         # 更新分类
DELETE /api/v1/admin/categories/:id         # 删除分类

# 内容审核
GET    /api/v1/admin/reviews                # 获取待审核列表
POST   /api/v1/admin/reviews/:id/approve    # 审核通过
POST   /api/v1/admin/reviews/:id/reject     # 审核拒绝
POST   /api/v1/admin/reviews/batch/approve  # 批量审核通过

# 数据统计
GET    /api/v1/admin/stats/overview         # 总览统计
GET    /api/v1/admin/stats/content          # 内容统计
GET    /api/v1/admin/stats/crawler          # 爬虫统计
GET    /api/v1/admin/stats/users            # 用户统计
GET    /api/v1/admin/stats/ai               # AI 使用统计

# 用户管理
GET    /api/v1/admin/users                  # 获取用户列表
GET    /api/v1/admin/users/:id              # 获取用户详情
PATCH  /api/v1/admin/users/:id/status       # 更新用户状态
GET    /api/v1/admin/users/:id/logs         # 获取用户操作日志

# 系统配置
GET    /api/v1/admin/config                 # 获取系统配置
PUT    /api/v1/admin/config                 # 更新系统配置

# 操作日志
GET    /api/v1/admin/logs                   # 获取操作日志列表
GET    /api/v1/admin/logs/export            # 导出操作日志
```

---

## 5. 爬虫系统设计

### 5.1 系统架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       爬虫调度中心                                │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  定时调度器    │  │  任务队列     │  │  失败重试机制         │  │
│  │  (Cron)      │  │  (Queue)     │  │  (Retry Policy)      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
└─────────┼─────────────────┼──────────────────────┼──────────────┘
          │                 │                      │
          ▼                 ▼                      ▼
┌──────────────────────────────────────────────────────────────────┐
│                       爬虫执行引擎                                │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Playwright  │  │  RSS/RSSHub  │  │  Search API          │  │
│  │  (动态渲染)   │  │  (静态订阅)   │  │  (搜索接口)          │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
└─────────┼─────────────────┼──────────────────────┼──────────────┘
          │                 │                      │
          ▼                 ▼                      ▼
┌──────────────────────────────────────────────────────────────────┐
│                      内容处理流水线                                │
│                                                                  │
│  原始内容 → 去重 → 清洗 → AI分类 → AI摘要 → 质量评分 → 入库     │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 支持的爬取源

#### 招聘与求职平台

| 平台 | 爬取方式 | 内容类型 | 优先级 |
|------|---------|---------|--------|
| BOSS 直聘 | Playwright | JD、面试经验、薪资 | P0 |
| 拉勾网 | Playwright | JD、面试题 | P0 |
| 猎聘 | Playwright | JD、行业分析 | P1 |
| LinkedIn | API / RSSHub | 国际岗位 JD | P1 |
| Glassdoor | Playwright | 面试题、薪资、公司评价 | P1 |

#### 技术社区与博客

| 平台 | 爬取方式 | 内容类型 | 优先级 |
|------|---------|---------|--------|
| 知乎 | RSSHub | 面试经验、岗位讨论 | P0 |
| 掘金 | RSSHub | 技术文章、面试题 | P0 |
| CSDN | RSSHub | 技术文章 | P1 |
| 博客园 | RSSHub | 技术文章 | P1 |
| V2EX | RSSHub | 技术讨论 | P2 |
| GitHub | RSSHub | 开源项目、技术趋势 | P2 |
| Hacker News | RSS | 国际技术动态 | P2 |

#### 社交与内容平台

| 平台 | 爬取方式 | 内容类型 | 优先级 |
|------|---------|---------|--------|
| 小红书 | Playwright | 岗位体验、面试经验 | P0 |
| 脉脉 | Playwright | 职场讨论、薪资 | P0 |
| 微博 | RSSHub | 热点话题 | P2 |
| Twitter/X | RSSHub | 国际行业动态 | P2 |

### 5.3 爬取策略

#### 定时爬取

- 通过 Cloud Functions 的定时触发器（Cron Trigger）实现
- 不同数据源配置不同的爬取频率：
  - 热门数据源：每 6 小时一次
  - 常规数据源：每 24 小时一次
  - 冷门数据源：每 72 小时一次

#### 增量更新

- 基于时间戳的增量爬取：只爬取 `lastFetchedAt` 之后的新内容
- 基于 URL 去重：数据库中已存在的 URL 跳过
- 基于内容指纹去重：计算内容前 100 字符的相似度，超过 80% 视为重复

#### 反爬策略

- 请求间隔随机化：每次请求间隔 2-8 秒
- User-Agent 轮换：维护 User-Agent 池
- IP 代理池：通过代理服务轮换 IP（可选）
- 请求频率限制：单域名每分钟不超过 10 次请求
- 失败退避：连续失败时指数退避，最大等待 5 分钟

#### 失败重试

```
最大重试次数：3
重试间隔：30s → 60s → 120s（指数退避）
连续失败阈值：5 次 → 自动暂停任务并通知管理员
```

### 5.4 内容清洗和结构化

#### 清洗流程

```
原始内容
  │
  ├─ 1. 移除 HTML 标签和特殊字符
  ├─ 2. 移除广告和推广内容（基于关键词库过滤）
  ├─ 3. 移除垃圾内容（过短、重复字符、过多链接）
  ├─ 4. 统一编码格式（UTF-8）
  ├─ 5. 内容长度限制（最大 10,000 字符）
  ├─ 6. 标准化空白字符
  └─ 7. 提取结构化元数据（作者、发布时间、标签等）
```

#### 结构化输出

爬取的原始内容经过清洗后，统一转换为以下结构：

```json
{
  "title": "标题",
  "content": "正文内容",
  "summary": "AI 生成的摘要",
  "category": "AI 分类结果",
  "tags": ["标签1", "标签2"],
  "source": "来源平台",
  "sourceUrl": "原始链接",
  "author": "作者",
  "publishTime": "2026-05-13T00:00:00Z",
  "qualityScore": 85,
  "locale": "zh"
}
```

### 5.5 自动入库流程

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  爬取内容  │ →  │  URL去重  │ →  │  内容清洗  │ →  │  AI分类   │ →  │  质量评分  │
│  (Raw)    │    │  (Dedup) │    │  (Clean) │    │  (Class) │    │  (Score) │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └────┬─────┘
                                                                    │
                    ┌───────────────────────────────────────────────┘
                    │
                    ▼
              ┌──────────┐    ┌──────────┐    ┌──────────┐
              │  AI摘要   │ →  │  标签匹配  │ →  │  写入DB   │
              │ (Summary)│    │  (Tag)   │    │  (Save)  │
              └──────────┘    └──────────┘    └──────────┘
                                                    │
                                                    ▼
                                            ┌──────────────┐
                                            │  进入审核队列  │
                                            │  (Review)    │
                                            └──────────────┘
```

---

## 6. AI 质量增强流程

### 6.1 AI 模型配置

系统支持管理员在后台配置多个 AI 模型，并按场景分配：

| 场景 (scene) | 推荐模型 | Temperature | 说明 |
|-------------|---------|-------------|------|
| chat | 盘古/OpenAI | 0.7 | 通用对话 |
| resume | 盘古/OpenAI | 0.3 | 简历分析，精确稳定 |
| assessment | 盘古/OpenAI | 0.5 | 测评结果，鼓励性 |
| classification | 盘古/OpenAI | 0.3 | 内容分类，低随机性 |
| enhancement | 盘古/OpenAI | 0.5 | 内容增强，平衡创意与准确 |
| translation | 盘古/OpenAI | 0.3 | 翻译，忠实原文 |

#### 模型切换策略

```
1. 管理员在后台配置多个模型（盘古/OpenAI/DeepSeek/Claude 等）
2. 每个场景可绑定一个主模型和一个备用模型
3. 主模型调用失败时自动切换到备用模型
4. 所有模型不可用时降级为 Mock 响应
5. 记录每个模型的调用次数、延迟、成功率等指标
```

### 6.2 内容质量评估

对每条内容进行 0-100 分的质量评分，评分维度：

| 维度 | 权重 | 评估标准 |
|------|------|---------|
| 内容完整性 | 25% | 是否包含完整的题目/答案/解析 |
| 准确性 | 25% | 技术内容是否正确、时效性 |
| 可读性 | 20% | 语言表达是否清晰、结构是否合理 |
| 实用性 | 15% | 对求职者是否有实际帮助 |
| 原创性 | 15% | 内容是否独特、非简单复制 |

评分流程：

```
内容 → AI 分析 → 多维度打分 → 加权计算 → 质量评分
```

AI Prompt 示例：

```
请对以下内容进行质量评估，从完整性、准确性、可读性、实用性、原创性五个维度
分别打分（0-100），并给出综合评分。

内容：{content}

请按以下 JSON 格式返回：
{
  "completeness": 85,
  "accuracy": 90,
  "readability": 80,
  "practicality": 75,
  "originality": 70,
  "overallScore": 80,
  "suggestions": "改进建议"
}
```

### 6.3 AI 改写和优化

针对不同内容类型的改写策略：

#### 测评题目改写

```
原始题目 → AI 改写 → 优化后的题目
                      ├─ 题目描述更清晰
                      ├─ 选项无歧义
                      ├─ 增加解析说明
                      └─ 标注难度等级
```

#### 面试题改写

```
原始面试题 → AI 改写 → 优化后的面试题
                        ├─ 题目表述更专业
                        ├─ 补充参考答案
                        ├─ 添加追问建议
                        ├─ 标注考察维度
                        └─ 关联岗位标签
```

#### 知识文章改写

```
原始文章 → AI 改写 → 优化后的文章
                      ├─ 结构化排版
                      ├─ 补充缺失信息
                      ├─ 更新过时内容
                      ├─ 添加总结和要点
                      └─ 生成摘要
```

### 6.4 多语言翻译

支持中文和英文之间的双向翻译：

```
翻译流程：
1. 检测源语言
2. AI 翻译（保持专业术语准确性）
3. 人工审核（可选）
4. 关联原文和译文（contentId + locale）
```

翻译策略：

| 场景 | 策略 |
|------|------|
| 技术术语 | 保持英文原文，括号注释中文 |
| 岗位名称 | 使用目标语言的标准表述 |
| 薪资信息 | 转换货币单位并标注 |
| 文化相关内容 | 适当本地化解释 |
| 代码示例 | 不翻译，保持原样 |

### 6.5 岗位标签自动匹配

通过 AI 自动为内容匹配岗位标签：

```
内容 → AI 分析 → 提取关键技能/概念 → 匹配岗位库 → 输出岗位标签
```

匹配规则：

1. **精确匹配**：内容明确提到岗位名称
2. **技能匹配**：内容涉及的核心技能与岗位技能要求匹配
3. **语义匹配**：通过向量相似度计算内容与岗位描述的语义关联度
4. **置信度阈值**：匹配置信度 > 0.7 才添加标签

### 6.6 难度等级自动标注

```
难度等级定义：
- easy (初级)：入门级知识，0-1 年经验
- medium (中级)：进阶知识，1-3 年经验
- hard (高级)：深入知识，3-5 年经验
- expert (专家)：专家级知识，5+ 年经验
```

标注依据：

| 维度 | easy | medium | hard | expert |
|------|------|--------|------|--------|
| 概念深度 | 基础概念 | 原理理解 | 源码级/架构级 | 前沿研究 |
| 实践要求 | 了解即可 | 能独立完成 | 能设计优化 | 能创新引领 |
| 知识广度 | 单一知识点 | 多知识点关联 | 跨领域综合 | 系统性思维 |
| 面试频率 | 偶尔出现 | 经常出现 | 高频重点 | 顶级公司专属 |

---

## 7. 管理后台功能

### 7.1 功能模块总览

```
┌─────────────────────────────────────────────────────────────┐
│                      管理后台功能模块                          │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │
│  │  内容管理     │ │  爬虫管理     │ │  AI 模型配置         │  │
│  │             │ │             │ │                     │  │
│  │ · 测评题库   │ │ · 任务管理   │ │ · 模型列表          │  │
│  │ · 面试题库   │ │ · 数据源管理 │ │ · 模型测试          │  │
│  │ · 知识库     │ │ · 获取记录   │ │ · 场景分配          │  │
│  │ · 岗位管理   │ │ · 统计报表   │ │ · 调用统计          │  │
│  │ · 分类管理   │ │ · 内置模板   │ │ · API Key 管理     │  │
│  └─────────────┘ └─────────────┘ └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐  │
│  │  AI 增强     │ │  数据统计     │ │  系统管理            │  │
│  │             │ │             │ │                     │  │
│  │ · 批量增强   │ │ · 内容统计   │ │ · 用户管理          │  │
│  │ · 质量评分   │ │ · 用户统计   │ │ · 操作日志          │  │
│  │ · 翻译管理   │ │ · 增长趋势   │ │ · 系统配置          │  │
│  │ · 标签管理   │ │ · 爬虫报表   │ │ · 权限管理          │  │
│  │ · 审核队列   │ │ · AI 报表    │ │ · 数据备份          │  │
│  └─────────────┘ └─────────────┘ └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 内容管理

#### 增删改查

- **创建**：支持单条创建和表单式录入
- **查看**：列表视图 + 详情视图，支持 Markdown 实时预览
- **编辑**：富文本编辑器，支持 Markdown 和可视化编辑
- **删除**：软删除，支持恢复

#### 批量导入导出

| 操作 | 支持格式 | 说明 |
|------|---------|------|
| 导入 | CSV, JSON, Excel | 支持模板下载，字段映射 |
| 导出 | CSV, JSON, Excel | 支持筛选条件导出 |
| 批量删除 | - | 支持按条件批量删除 |
| 批量更新 | JSON | 支持批量修改字段值 |

#### 内容审核

- 爬虫自动采集的内容进入审核队列
- AI 增强后的内容进入审核队列
- 管理员可批量审核（通过/拒绝/退回修改）
- 审核支持添加备注和评分

### 7.3 爬虫任务管理

#### 任务配置

- 配置爬取目标平台、关键词、频率
- 配置内容类型筛选（测评/面试/知识）
- 配置爬取规则（最大条数、质量阈值）

#### 任务监控

- 实时查看任务运行状态
- 查看历史运行记录和统计数据
- 异常告警（连续失败通知）

#### 数据源管理

- 内置数据源模板（一键添加常用数据源）
- 自定义数据源（RSS、API）
- 数据源健康检查
- 获取记录查看和统计

### 7.4 AI 模型配置

#### 模型管理

- 添加/编辑/删除 AI 模型配置
- 支持的模型类型：
  - **盘古大模型**（华为云）：`pangu` provider
  - **OpenAI**：`openai` provider
  - **DeepSeek**：`deepseek` provider
  - **Claude**：`claude` provider
  - **自定义模型**：任意 OpenAI 兼容 API

#### 模型配置项

```json
{
  "name": "盘古-Chat",
  "provider": "pangu",
  "apiUrl": "https://pangu.cn-north-4.myhuaweicloud.com/v1",
  "apiKey": "***",
  "model": "pangu-chat",
  "maxTokens": 4096,
  "temperature": 0.7,
  "scene": "chat",
  "weight": 1.0,
  "dailyLimit": 10000,
  "status": "active"
}
```

#### 场景分配

- 每个场景可配置主模型和备用模型
- 按权重分配请求（支持 A/B 测试）
- 模型故障自动切换

### 7.5 数据统计和报表

#### 内容统计

- 各类内容总量和增长趋势
- 内容质量分布（按评分区间）
- 内容覆盖度（按岗位、分类）
- AI 增强覆盖率

#### 用户统计

- DAU/MAU、注册量、留存率
- 功能使用分布（测评/面试/知识库）
- 会员转化率
- 用户活跃时段分析

#### 爬虫报表

- 各数据源获取量统计
- 获取成功率趋势
- 内容入库率
- 异常告警统计

#### AI 使用报表

- 各模型调用量和成本
- Token 消耗统计
- 增强任务完成率
- 翻译任务统计

### 7.6 用户管理

- 用户列表查看（支持搜索和筛选）
- 用户详情查看（使用记录、会员状态）
- 用户状态管理（启用/禁用）
- 用户操作日志查看

---

## 8. 部署方案

### 8.1 AGC Cloud Hosting 部署

#### 架构设计

```
┌──────────────────────────────────────────────────────────┐
│                  AGC Cloud Hosting                        │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Cloud Functions (API 层)               │  │
│  │                                                    │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │  │
│  │  │ auth-fn  │ │ content  │ │ crawler-scheduler │   │  │
│  │  │ (认证)    │ │ -fn      │ │ -fn (定时触发)    │   │  │
│  │  │          │ │ (内容API) │ │                  │   │  │
│  │  └──────────┘ └──────────┘ └──────────────────┘   │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │  │
│  │  │ ai-enhance│ │ user-fn  │ │ payment-fn       │   │  │
│  │  │ -fn      │ │ (用户API) │ │ (支付回调)        │   │  │
│  │  │ (AI增强)  │ │          │ │                  │   │  │
│  │  └──────────┘ └──────────┘ └──────────────────┘   │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Cloud DB (数据库层)                     │  │
│  │                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐               │  │
│  │  │  中国区       │  │  新加坡区     │               │  │
│  │  │  (cn-north)  │  │  (ap-southeast)│              │  │
│  │  └──────┬───────┘  └──────┬───────┘               │  │
│  │         │    数据同步      │                        │  │
│  │         └────────┬────────┘                        │  │
│  └──────────────────┼─────────────────────────────────┘  │
│                     │                                    │
│  ┌──────────────────┼─────────────────────────────────┐  │
│  │              Cloud Storage                          │  │
│  │              (文件/媒体存储)                          │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

#### Cloud Functions 设计

| 函数名 | 触发方式 | 职责 | 内存配置 |
|--------|---------|------|---------|
| auth-fn | HTTP | 用户认证、JWT 管理 | 256MB |
| content-fn | HTTP | 内容 CRUD API | 512MB |
| ai-enhance-fn | HTTP | AI 增强任务 | 1024MB |
| user-fn | HTTP | 用户服务 API | 256MB |
| payment-fn | HTTP | 支付回调处理 | 256MB |
| crawler-scheduler-fn | Cron | 爬虫定时调度 | 512MB |
| crawler-executor-fn | HTTP | 爬虫执行引擎 | 1024MB |
| data-sync-fn | Cron | 跨区域数据同步 | 512MB |
| stats-fn | Cron | 统计数据聚合 | 256MB |

### 8.2 中国区 + 新加坡区数据同步

#### 数据分区策略

```
┌─────────────────────────────────────────────────────────┐
│                    数据分区策略                            │
│                                                         │
│  用户数据：按注册区域存储，不跨区同步                       │
│  内容数据：主数据存储在中国区，同步至新加坡区（只读副本）      │
│  配置数据：全量同步                                       │
│  日志数据：各区域独立存储                                  │
└─────────────────────────────────────────────────────────┘
```

#### 同步机制

```
中国区 (主)                    新加坡区 (从)
┌──────────┐                  ┌──────────┐
│ Cloud DB │ ──── 实时同步 ──→ │ Cloud DB │
│ (读写)    │                  │ (只读)    │
└──────────┘                  └──────────┘
       │                              │
       │     同步延迟: < 5 秒          │
       │     同步内容: 内容+配置        │
       │     冲突策略: 主库优先         │
       └──────────────────────────────┘
```

#### 区域路由规则

```
用户请求 → 检测用户区域
  ├─ 中国用户 → 路由至中国区（读写）
  ├─ 东南亚用户 → 路由至新加坡区（读），写入转发至中国区
  └─ 其他用户 → 默认路由至中国区
```

### 8.3 CI/CD 流程

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  代码提交  │ →  │  自动测试  │ →  │  构建部署  │ →  │  验证发布  │
│  (Git)    │    │  (Test)   │    │  (Build)  │    │  (Verify) │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     ▼               ▼               ▼               ▼
  开发分支         单元测试         自动部署到       灰度发布
  feature/*       集成测试         staging 环境     生产环境
  main 分支       E2E 测试        自动部署到       全量发布
                                 production
```

#### 部署流程详细说明

1. **代码提交**：开发者提交代码到 Git 仓库
2. **自动测试**：
   - 单元测试（Jest）：覆盖率 > 80%
   - 类型检查（TypeScript）：零错误
   - 代码风格检查（ESLint）：零警告
3. **构建部署**：
   - TypeScript 编译
   - Cloud Functions 打包
   - 自动部署到 AGC Cloud Hosting
4. **验证发布**：
   - 健康检查
   - 冒烟测试
   - 灰度发布（可选）

#### 环境配置

| 环境 | 用途 | 数据库 | 部署区域 |
|------|------|--------|---------|
| development | 本地开发 | SQLite | 本地 |
| staging | 预发布测试 | Cloud DB | 中国区 |
| production | 生产环境 | Cloud DB | 中国区 + 新加坡区 |

---

## 9. 分阶段实施计划

### Phase 1：基础 API + 数据库 + 管理后台框架

**目标**：搭建基础架构，实现核心内容管理功能

**时间**：4 周

#### 数据库

- [ ] 设计并创建 AGC Cloud DB 数据表
- [ ] 迁移现有 Prisma 数据模型
- [ ] 建立索引策略

#### API 开发

- [ ] 搭建 Cloud Functions 基础框架
- [ ] 实现认证鉴权中间件
- [ ] 实现统一响应格式和错误处理
- [ ] 内容管理 CRUD API（测评/面试/知识库）
- [ ] 岗位和分类管理 API
- [ ] 分页/搜索/筛选 API

#### 管理后台

- [ ] 搭建管理后台框架（Vue3 / React）
- [ ] 实现登录和权限管理
- [ ] 实现内容管理页面（列表/详情/编辑）
- [ ] 实现岗位和分类管理页面

#### 交付物

- 基础 API 服务上线
- 管理后台 MVP 版本
- 数据库 schema 文档

---

### Phase 2：内容批量导入 + 爬虫基础版

**目标**：实现内容批量管理和基础爬虫能力

**时间**：4 周

#### 批量导入导出

- [ ] 实现 CSV/JSON/Excel 导入功能
- [ ] 实现批量导出功能
- [ ] 实现批量删除和更新
- [ ] 设计导入模板和字段映射

#### 爬虫系统

- [ ] 搭建爬虫调度框架
- [ ] 实现 RSS/RSSHub 数据源对接
- [ ] 实现 Playwright 动态爬虫基础框架
- [ ] 实现内容清洗和去重
- [ ] 实现自动入库流程
- [ ] 搭建数据源管理页面

#### 内容审核

- [ ] 实现审核队列
- [ ] 实现批量审核功能
- [ ] 实现审核统计

#### 交付物

- 批量导入导出功能
- 爬虫基础版（支持 RSS + 2-3 个动态爬虫）
- 内容审核流程

---

### Phase 3：AI 质量增强 + 自动标签

**目标**：集成 AI 能力，实现内容质量自动提升

**时间**：4 周

#### AI 模型集成

- [ ] 实现多模型配置管理
- [ ] 实现盘古大模型对接
- [ ] 实现 OpenAI 对接
- [ ] 实现模型自动切换和降级

#### AI 增强

- [ ] 实现内容质量评估
- [ ] 实现测评题目 AI 改写
- [ ] 实现面试题 AI 改写
- [ ] 实现知识文章 AI 改写
- [ ] 实现批量 AI 增强

#### 自动标签

- [ ] 实现岗位标签自动匹配
- [ ] 实现难度等级自动标注
- [ ] 实现内容自动分类

#### 多语言翻译

- [ ] 实现中英文双向翻译
- [ ] 实现批量翻译
- [ ] 实现翻译审核流程

#### 交付物

- AI 增强功能上线
- 自动标签和分类
- 多语言支持基础版

---

### Phase 4：国际化 + 多区域部署

**目标**：实现国际化部署和新加坡区域支持

**时间**：4 周

#### 国际化

- [ ] 管理后台多语言支持
- [ ] API 多语言响应
- [ ] 内容多语言管理

#### 多区域部署

- [ ] 新加坡区 Cloud DB 部署
- [ ] 实现跨区域数据同步
- [ ] 实现区域路由策略
- [ ] 新加坡区 Cloud Functions 部署

#### 监控和运维

- [ ] 实现系统监控和告警
- [ ] 实现日志聚合和分析
- [ ] 实现数据备份和恢复
- [ ] 编写运维文档

#### 性能优化

- [ ] API 响应缓存
- [ ] 数据库查询优化
- [ ] CDN 加速静态资源
- [ ] 大数据量分页优化

#### 交付物

- 国际化版本上线
- 新加坡区域部署完成
- 监控和运维体系建立
- 完整运维文档

---

## 附录

### A. 术语表

| 术语 | 说明 |
|------|------|
| AGC | AppGallery Connect，华为应用服务 |
| Cloud DB | AGC 云数据库服务 |
| Cloud Functions | AGC 云函数服务 |
| Cloud Hosting | AGC 云托管服务 |
| Cloud Storage | AGC 云存储服务 |
| 盘古 | 华为盘古大模型 |
| RSSHub | 开源 RSS 聚合工具 |
| Playwright | 微软开源的浏览器自动化工具 |
| RAG | 检索增强生成 (Retrieval-Augmented Generation) |
| ChromaDB | 开源向量数据库 |

### B. 参考文档

- [AGC Cloud Functions 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-cloudfunction-introduction-V5)
- [AGC Cloud DB 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-clouddb-introduction-V5)
- [AGC Cloud Hosting 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-cloudhosting-introduction-V5)
- [盘古大模型 API 文档](https://support.huaweicloud.com/pangu/)
- [RSSHub 文档](https://docs.rsshub.app/)
- [Playwright 文档](https://playwright.dev/)
