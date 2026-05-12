/**
 * 求职看板数据模型
 * Kanban 数据结构定义
 */

/**
 * 看板列状态枚举
 */
export enum KanbanColumnStatus {
  /** 待投递 */
  WISH = 'wish',
  /** 已投递 */
  APPLIED = 'applied',
  /** 简历筛选中 */
  SCREENING = 'screening',
  /** 面试中 */
  INTERVIEWING = 'interviewing',
  /** 已录用 */
  OFFER = 'offer',
  /** 已拒绝 */
  REJECTED = 'rejected'
}

/**
 * 看板列配置
 */
export interface KanbanColumn {
  /** 列状态 */
  status: KanbanColumnStatus;
  /** 列标题 */
  title: string;
  /** 列图标资源名 */
  icon: string;
  /** 列主题色 */
  color: string;
  /** 排序序号 */
  order: number;
}

/**
 * 求职卡片优先级
 */
export enum CardPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high'
}

/**
 * 求职卡片数据
 */
export interface JobCard {
  /** 唯一ID */
  id: string;
  /** 公司名 */
  company: string;
  /** 职位名称 */
  position: string;
  /** 所在城市 */
  location: string;
  /** 薪资范围 */
  salary: string;
  /** 优先级 */
  priority: CardPriority;
  /** 当前所在列 */
  columnStatus: KanbanColumnStatus;
  /** 公司Logo URL（可选） */
  companyLogo?: string;
  /** 来源平台（如 BOSS直聘、拉勾等） */
  source?: string;
  /** 备注 */
  note?: string;
  /** 标签列表 */
  tags: string[];
  /** 创建时间 */
  createdAt: string;
  /** 更新时间 */
  updatedAt: string;
  /** 排序权重（同列内排序用） */
  sortWeight: number;
}

/**
 * 看板完整数据
 */
export interface KanbanData {
  /** 列配置 */
  columns: KanbanColumn[];
  /** 所有卡片 */
  cards: JobCard[];
}

/**
 * 默认列模板
 */
export const DEFAULT_COLUMNS: KanbanColumn[] = [
  {
    status: KanbanColumnStatus.WISH,
    title: '待投递',
    icon: 'ic_star',
    color: '#E8A838',
    order: 0
  },
  {
    status: KanbanColumnStatus.APPLIED,
    title: '已投递',
    icon: 'ic_send',
    color: '#4A90D9',
    order: 1
  },
  {
    status: KanbanColumnStatus.SCREENING,
    title: '筛选中',
    icon: 'ic_search',
    color: '#7B68EE',
    order: 2
  },
  {
    status: KanbanColumnStatus.INTERVIEWING,
    title: '面试中',
    icon: 'ic_interview',
    color: '#F5A623',
    order: 3
  },
  {
    status: KanbanColumnStatus.OFFER,
    title: '已录用',
    icon: 'ic_offer',
    color: '#4CD964',
    order: 4
  },
  {
    status: KanbanColumnStatus.REJECTED,
    title: '已拒绝',
    icon: 'ic_reject',
    color: '#FF6B6B',
    order: 5
  }
];

/**
 * 常用标签模板
 */
export const DEFAULT_TAGS: string[] = [
  '远程', ' onsite', '外企', '国企', '创业公司',
  '大厂', '急招', '内推', '校招', '社招',
  'Java', '前端', '后端', '产品', '设计',
  '数据分析', 'AI', '运维', '测试'
];

/**
 * 常用来源平台
 */
export const DEFAULT_SOURCES: string[] = [
  'BOSS直聘', '拉勾', '猎聘', '智联招聘', '前程无忧',
  '脉脉', '内推', '官网', '其他'
];
