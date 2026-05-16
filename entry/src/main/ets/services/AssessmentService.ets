import { ApiService } from './ApiService';
import { HistoryService } from './HistoryService';
import { DataLoadService } from './DataLoadService';
import { DataConverter } from './DataConverter';
import { Assessment, Question, AssessmentResult, DimensionScore, DimensionDetail } from '../models/Assessment';

/**
 * AssessmentService - 测评服务层
 *
 * 提供职业性格测评、兴趣测评、竞争力评估等全方位职业测评服务
 * 使用单例模式，通过 getInstance() 获取实例
 *
 * @example
 * const service = AssessmentService.getInstance();
 * const assessments = await service.getAssessments();
 * const result = await service.submitAssessment('personality_mbti', answers);
 *
 * @since 1.0.0
 */
export class AssessmentService {
  private static instance: AssessmentService;
  private apiService: ApiService = ApiService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private dataLoadService: DataLoadService = DataLoadService.getInstance();
  private dataConverter: DataConverter = DataConverter.getInstance();
  private loadedAssessments: Assessment[] = [];

  private constructor() {}

  static getInstance(): AssessmentService {
    if (!AssessmentService.instance) {
      AssessmentService.instance = new AssessmentService();
    }
    return AssessmentService.instance;
  }

  // ==================== 数据加载 ====================

  /**
   * 初始化数据加载服务，从 rawfile JSON 文件加载测评数据
   * 加载失败时静默回退到内置默认数据，不影响应用正常运行
   * @param context 应用上下文
   */
  async initialize(context: Context): Promise<void> {
    try {
      await this.dataLoadService.initialize(context);
      console.info('[AssessmentService] DataLoadService 初始化成功');

      // 优先加载 v2 测评数据（4000题，9大类型）
      let v2Loaded = false;
      try {
        const v2Data = await this.dataLoadService.loadLocalJson<Record<string, Object>>('data/assessment_questions.json');
        if (v2Data !== null && (v2Data as Record<string, Object>)['assessments'] && ((v2Data as Record<string, Object>)['assessments'] as Object[]).length > 0) {
          const v2Assessments = this.dataConverter.convertAssessmentV2(v2Data);
          if (v2Assessments.length > 0) {
            this.loadedAssessments = this.loadedAssessments.concat(v2Assessments);
            v2Loaded = true;
            console.info(`[AssessmentService] v2测评数据加载成功，共 ${v2Assessments.length} 个测评类型`);
          }
        }
      } catch (error) {
        console.error('[AssessmentService] v2测评数据加载失败，回退到v1:', error);
      }

      // v1 回退：加载 MBTI 数据（93题标准版）
      if (!v2Loaded) {
        try {
          const mbtiData = await this.dataLoadService.loadLocalJson<Record<string, Object>>('data/mbti_questions_93.json');
          if (mbtiData !== null) {
            const mbtiAssessment = this.dataConverter.convertMBTI(mbtiData);
            this.loadedAssessments.push(mbtiAssessment);
            console.info('[AssessmentService] MBTI 数据加载成功（v1回退）');
          }
        } catch (error) {
          console.error('[AssessmentService] MBTI 数据加载失败，将使用默认数据:', error);
        }

        // 加载 Holland 数据
        try {
          const hollandData = await this.dataLoadService.loadLocalJson<Record<string, Object>>('data/holland_questions.json');
          if (hollandData !== null) {
            const hollandAssessment = this.dataConverter.convertHolland(hollandData);
            this.loadedAssessments.push(hollandAssessment);
            console.info('[AssessmentService] Holland 数据加载成功（v1回退）');
          }
        } catch (error) {
          console.error('[AssessmentService] Holland 数据加载失败，将使用默认数据:', error);
        }
      }

      console.info(`[AssessmentService] 数据加载完成，共加载 ${this.loadedAssessments.length} 个测评`);
    } catch (error) {
      console.error('[AssessmentService] 初始化失败，将使用内置默认数据:', error);
    }
  }

  // ==================== 数据获取方法 ====================

  /**
   * 获取测评列表，优先使用 rawfile 加载的数据，其次尝试 API，最后回退到本地默认数据
   */
  async getAssessments(): Promise<Assessment[]> {
    // 优先使用 rawfile 加载的数据
    if (this.loadedAssessments.length > 0) {
      return this.loadedAssessments;
    }

    try {
      const response = await this.apiService.get<Assessment[]>('/assessments/list');
      if (response.success && response.data) {
        return response.data;
      }
      return this.getDefaultAssessments();
    } catch (error) {
      return this.getDefaultAssessments();
    }
  }

  /**
   * 根据 ID 获取测评
   * @param id 测评ID
   * @returns 匹配的测评对象，未找到返回 null
   */
  getAssessmentById(id: string): Assessment | null {
    // 先从 loadedAssessments 中查找
    if (this.loadedAssessments.length > 0) {
      for (let i = 0; i < this.loadedAssessments.length; i++) {
        if (this.loadedAssessments[i].id === id) {
          return this.loadedAssessments[i];
        }
      }
    }
    // 再从默认数据中查找
    const defaults = this.getDefaultAssessments();
    for (let i = 0; i < defaults.length; i++) {
      if (defaults[i].id === id) {
        return defaults[i];
      }
    }
    return null;
  }

  /**
   * 分页/筛选搜索测评
   * 为后端预留接口，API失败时回退到本地过滤
   * @param params 搜索参数，包含 keyword、type、category、page、pageSize
   * @returns 包含测评列表和总数的对象
   */
  async searchAssessments(params: {
    keyword?: string;
    type?: string;
    category?: string;
    page?: number;
    pageSize?: number;
  }): Promise<{ items: Assessment[]; total: number }> {
    try {
      const queryParams: Record<string, string | number> = {};
      if (params.keyword) queryParams.keyword = params.keyword;
      if (params.type) queryParams.type = params.type;
      if (params.category) queryParams.category = params.category;
      if (params.page) queryParams.page = params.page;
      if (params.pageSize) queryParams.pageSize = params.pageSize;

      const response = await this.apiService.get<{ items: Assessment[]; total: number }>(
        '/assessments/search',
        queryParams
      );
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[AssessmentService] Search assessments failed:', error);
    }

    // 回退到本地过滤
    const allAssessments = this.getDefaultAssessments();
    let filtered = allAssessments;

    if (params.keyword) {
      const kw = params.keyword.toLowerCase();
      filtered = filtered.filter(a =>
        a.title.toLowerCase().includes(kw) || a.description.toLowerCase().includes(kw)
      );
    }
    if (params.type) {
      filtered = filtered.filter(a => a.type === params.type);
    }
    if (params.category) {
      filtered = filtered.filter(a => a.category === params.category);
    }

    const page = params.page || 1;
    const pageSize = params.pageSize || 10;
    const start = (page - 1) * pageSize;
    const items = filtered.slice(start, start + pageSize);

    return { items, total: filtered.length };
  }

  // ==================== 提交与计算方法 ====================

  /**
   * 提交测评答案，优先通过API提交，失败时回退到本地计算
   */
  async submitAssessment(
    assessmentId: string,
    answers: Record<string, string | string[]>
  ): Promise<AssessmentResult> {
    try {
      const response = await this.apiService.post<AssessmentResult>('/assessments/submit', {
        assessmentId,
        answers
      });

      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[AssessmentService] Submit assessment failed, fallback to local:', error);
    }

    // API失败，使用本地计算
    const assessment = this.getDefaultAssessments().find(a => a.id === assessmentId);
    if (!assessment) {
      return { assessmentId, score: 0, dimensionScores: [], suggestions: [] };
    }
    return this.calculateLocalResult(assessment, answers);
  }

  /**
   * 本地计算测评结果
   * @param assessment 测评对象
   * @param answers 用户答案
   * @returns 本地计算的测评结果
   */
  calculateLocalResult(
    assessment: Assessment,
    answers: Record<string, string | string[]>
  ): AssessmentResult {
    const dimensionMap: Record<string, number[]> = {};

    // 统计各维度得分
    for (let i = 0; i < assessment.questions.length; i++) {
      const question = assessment.questions[i];
      const selectedOptionId = answers[question.id] as string;
      if (!selectedOptionId) continue;

      const selectedOption = question.options?.find(o => o.id === selectedOptionId);
      if (selectedOption?.dimension) {
        if (!dimensionMap[selectedOption.dimension]) {
          dimensionMap[selectedOption.dimension] = [];
        }
        dimensionMap[selectedOption.dimension].push(selectedOption.direction || 1);
      }
    }

    // 计算各维度百分比得分
    const dimensionScores: DimensionScore[] = [];
    const dimensionDetails: DimensionDetail[] = [];
    let totalScore = 0;

    for (let i = 0; i < assessment.dimensions.length; i++) {
      const dim = assessment.dimensions[i];
      const dimKey = dim.split(' ')[0]; // 取维度代码
      const scores = dimensionMap[dimKey] || [];
      const positiveCount = scores.filter(s => s > 0).length;
      const total = scores.length || 1;
      const percentage = Math.round((positiveCount / total) * 100);

      totalScore += percentage;

      let description = '';
      let level = 'medium';
      let interpretation = '';
      let advice = '';

      if (percentage >= 70) {
        description = '优秀';
        level = 'high';
        interpretation = `您在"${dim}"方面表现突出，这是您的显著优势。`;
        advice = `继续发挥"${dim}"方面的优势，可以在简历和面试中重点展示。`;
      } else if (percentage >= 40) {
        description = '良好';
        level = 'medium';
        interpretation = `您在"${dim}"方面处于中等水平，有一定基础但仍有提升空间。`;
        advice = `建议通过针对性练习来提升"${dim}"方面的能力。`;
      } else {
        description = '待提升';
        level = 'low';
        interpretation = `您在"${dim}"方面相对薄弱，这是需要重点关注的提升方向。`;
        advice = `"${dim}"是您的短板，建议制定专项提升计划。`;
      }

      dimensionScores.push({ dimension: dim, score: percentage, description });
      dimensionDetails.push({ dimension: dim, score: percentage, level, interpretation, advice });
    }

    const avgScore = Math.round(totalScore / assessment.dimensions.length);

    // 生成建议
    const suggestions = this.generateSuggestions(assessment, dimensionScores, dimensionDetails);

    // 生成下一步行动
    const nextActions = this.generateNextActions(assessment, dimensionScores);

    // 生成类型描述和职业匹配
    const typeDescription = this.generateTypeDescription(assessment, dimensionScores);
    const careerMatch = this.generateCareerMatch(assessment, dimensionScores);

    return {
      assessmentId: assessment.id,
      score: avgScore,
      dimensionScores,
      suggestions,
      dimensionDetails,
      nextActions,
      typeDescription,
      careerMatch
    };
  }

  // ==================== 结果生成方法 ====================

  /**
   * 生成个性化建议
   */
  generateSuggestions(
    assessment: Assessment,
    scores: DimensionScore[],
    details: DimensionDetail[]
  ): string[] {
    const suggestions: string[] = [];

    // 找出弱项
    const weakDims = details.filter(d => d.level === 'low');
    const mediumDims = details.filter(d => d.level === 'medium');

    if (assessment.type === 'personality') {
      const typeDesc = this.getMBTIType(scores);
      suggestions.push(`您的性格类型倾向为${typeDesc}，适合需要${this.getMBTIStrength(typeDesc)}的工作环境。`);
      suggestions.push('建议选择与性格匹配的岗位，能显著提升工作满意度和绩效表现。');
      if (weakDims.length > 0) {
        suggestions.push(`在${weakDims.map(d => d.dimension).join('、')}维度有较大发展空间，可以通过有意识的练习来平衡。`);
      }
    } else if (assessment.type === 'career') {
      const top3 = scores.slice().sort((a, b) => b.score - a.score).slice(0, 3);
      suggestions.push(`您排名前三的兴趣类型为：${top3.map(d => d.dimension).join('、')}。`);
      suggestions.push('建议优先考虑与高兴趣类型匹配的职业方向，工作热情和持久力更强。');
      suggestions.push('兴趣可以培养，建议也关注中等兴趣类型的职业机会，拓宽选择面。');
    } else {
      if (weakDims.length > 0) {
        weakDims.forEach(d => {
          suggestions.push(`"${d.dimension}"是您的短板（得分${d.score}），${d.advice}`);
        });
      }
      if (mediumDims.length > 0) {
        suggestions.push(`${mediumDims.map(d => `"${d.dimension}"`).join('、')}处于中等水平，持续提升可转化为竞争优势。`);
      }
      const strongDims = details.filter(d => d.level === 'high');
      if (strongDims.length > 0) {
        suggestions.push(`${strongDims.map(d => `"${d.dimension}"`).join('、')}是您的核心优势，在求职中重点突出。`);
      }
    }

    return suggestions;
  }

  /**
   * 生成下一步行动建议
   * @param assessment 测评对象
   * @param scores 维度得分列表
   * @returns 行动建议列表
   */
  generateNextActions(assessment: Assessment, scores: DimensionScore[]): string[] {
    const actions: string[] = [];
    const weakDims = scores.filter(s => s.score < 40).sort((a, b) => a.score - b.score);

    if (assessment.type === 'interview_readiness') {
      actions.push('建议进行一次完整的模拟面试练习');
      if (weakDims.some(d => d.dimension.includes('简历'))) actions.push('优化简历：用STAR法则重写工作经历，增加数据量化');
      if (weakDims.some(d => d.dimension.includes('自我介绍'))) actions.push('准备3个版本的自我介绍并反复练习');
      if (weakDims.some(d => d.dimension.includes('薪资'))) actions.push('调研目标岗位市场薪资，准备薪资谈判话术');
    } else if (assessment.type === 'eq') {
      actions.push('建议阅读《情商》系列书籍，系统提升情商能力');
      actions.push('每天花5分钟进行情绪觉察练习');
      if (weakDims.some(d => d.dimension.includes('社交'))) actions.push('主动参加行业社交活动，锻炼社交感知力');
    } else if (assessment.type === 'personality' || assessment.type === 'career') {
      actions.push('建议根据测评结果，重新审视目标岗位的匹配度');
      actions.push('可以尝试进行面试准备度测评，检验实战能力');
    } else {
      actions.push('建议针对薄弱维度制定30天提升计划');
      actions.push('定期重新测评，追踪能力成长轨迹');
    }

    return actions;
  }

  /**
   * 生成性格类型描述
   */
  generateTypeDescription(assessment: Assessment, scores: DimensionScore[]): string {
    if (assessment.type === 'personality') {
      return this.getMBTIType(scores);
    } else if (assessment.type === 'career') {
      const top3 = scores.slice().sort((a, b) => b.score - a.score).slice(0, 3);
      return `您的霍兰德代码为 ${top3.map(d => d.dimension.split(' ')[0]).join('')}`;
    }
    return '';
  }

  /**
   * 生成职业匹配推荐
   * @param assessment 测评对象
   * @param scores 维度得分列表
   * @returns 匹配的职业方向列表
   */
  generateCareerMatch(assessment: Assessment, scores: DimensionScore[]): string[] {
    if (assessment.type === 'personality') {
      const mbti = this.getMBTIType(scores);
      return this.getMBTICareers(mbti);
    } else if (assessment.type === 'career') {
      const top3 = scores.slice().sort((a, b) => b.score - a.score).slice(0, 3);
      const codes = top3.map(d => d.dimension.split(' ')[0]);
      return this.getHollandCareers(codes);
    }
    return [];
  }

  // ==================== MBTI 辅助方法 ====================

  /**
   * 根据 MBTI 维度得分计算 MBTI 类型
   */
  getMBTIType(scores: DimensionScore[]): string {
    const e = scores.find(s => s.dimension.includes('E/I'));
    const sDim = scores.find(s => s.dimension.includes('S/N'));
    const t = scores.find(s => s.dimension.includes('T/F'));
    const j = scores.find(s => s.dimension.includes('J/P'));

    return `${e && e.score >= 50 ? 'E' : 'I'}${sDim && sDim.score >= 50 ? 'S' : 'N'}${t && t.score >= 50 ? 'T' : 'F'}${j && j.score >= 50 ? 'J' : 'P'}`;
  }

  /**
   * 获取 MBTI 类型的核心优势描述
   */
  getMBTIStrength(mbti: string): string {
    const map: Record<string, string> = {
      'ESTJ': '组织管理和执行力', 'ISTJ': '细致规划和可靠性',
      'ENTJ': '战略思维和领导力', 'INTJ': '系统分析和独立思考',
      'ESFJ': '团队关怀和协调力', 'ISFJ': '耐心服务和忠诚度',
      'ENFJ': '激励他人和沟通力', 'INFJ': '洞察力和理想主义',
      'ESTP': '应变能力和行动力', 'ISTP': '动手能力和问题分析',
      'ENTP': '创新思维和辩论力', 'INTP': '逻辑推理和深度思考',
      'ESFP': '活力感染和适应力', 'ISFP': '审美敏感和和谐追求',
      'ENFP': '创意发散和热情感染', 'INFP': '价值驱动和深度共情'
    };
    return map[mbti] || '综合能力';
  }

  /**
   * 获取 MBTI 类型匹配的职业方向
   */
  getMBTICareers(mbti: string): string[] {
    const map: Record<string, string[]> = {
      'ESTJ': ['项目经理', '运营总监', '财务经理', '行政管理'],
      'ISTJ': ['数据分析师', '审计师', '质量工程师', '法律顾问'],
      'ENTJ': ['战略顾问', 'CEO/总经理', '产品总监', '投资经理'],
      'INTJ': ['架构师', '战略分析师', '科学研究员', '独立顾问'],
      'ESFJ': ['人力资源经理', '客户成功经理', '教师/培训师', '公关经理'],
      'ISFJ': ['护士/医疗', '行政助理', '图书管理员', '社会工作者'],
      'ENFJ': ['销售总监', '培训经理', '组织发展专家', '心理咨询师'],
      'INFJ': ['UX研究员', '内容策略师', '心理咨询师', '品牌策划'],
      'ESTP': ['销售代表', '应急救援人员', '运动员教练', '创业家'],
      'ISTP': ['工程师', '技术支持', '飞行员', '手工艺专家'],
      'ENTP': ['创业者', '产品经理', '咨询顾问', '营销策划'],
      'INTP': ['软件工程师', '数据科学家', '研究员', '系统分析师'],
      'ESFP': ['活动策划', '旅游顾问', '销售', '演艺人员'],
      'ISFP': ['设计师', '摄影师', '兽医', '园艺师'],
      'ENFP': ['创意总监', '记者', '公关专员', '创业者'],
      'INFP': ['作家', '平面设计师', '心理咨询师', '非营利组织管理']
    };
    return map[mbti] || ['根据您的性格特点，建议探索多个方向'];
  }

  // ==================== 霍兰德辅助方法 ====================

  /**
   * 根据霍兰德代码获取匹配的职业方向
   */
  getHollandCareers(codes: string[]): string[] {
    const careers: string[] = [];
    const careerMap: Record<string, string[]> = {
      'R': ['工程师', '技术人员', '建筑设计师', '机械师'],
      'I': ['数据科学家', '研究员', '医生', '大学教授'],
      'A': ['UI/UX设计师', '文案策划', '建筑师', '导演'],
      'S': ['教师', '人力资源', '心理咨询师', '社工'],
      'E': ['销售经理', '企业管理者', '律师', '房地产经纪人'],
      'C': ['会计师', '审计师', '行政经理', '银行职员']
    };
    codes.forEach(code => {
      if (careerMap[code]) {
        const items = careerMap[code].slice(0, 2);
        for (let i = 0; i < items.length; i++) {
          careers.push(items[i]);
        }
      }
    });
    const uniqueCareers: string[] = [];
    for (let i = 0; i < careers.length; i++) {
      if (uniqueCareers.indexOf(careers[i]) === -1) {
        uniqueCareers.push(careers[i]);
      }
    }
    return uniqueCareers.slice(0, 6);
  }

  // ==================== 历史记录方法 ====================

  /**
   * 保存测评结果到历史记录
   * @param result 测评结果
   * @param assessment 测评对象
   */
  async saveToHistory(result: AssessmentResult, assessment: Assessment): Promise<void> {
    if (result && assessment) {
      await this.historyService.addHistory({
        type: 'assessment',
        title: `测评完成 - ${assessment.title}`,
        content: `得分: ${result.score}分，${result.suggestions[0] || ''}`,
        metadata: {
          assessmentId: assessment.id,
          assessmentTitle: assessment.title,
          score: result.score,
          dimensionScores: result.dimensionScores
        }
      });
    }
  }

  // ==================== 默认测评数据（6大测评，共104题） ====================

  /**
   * 返回6个内置测评
   */
  getDefaultAssessments(): Assessment[] {
    return [
      this.getPersonalityAssessment(),
      this.getHollandAssessment(),
      this.getCompetitivenessAssessment(),
      this.getEQAssessment(),
      this.getInterviewReadinessAssessment(),
      this.getValueAssessment()
    ];
  }

  // ==================== 1. 职业性格测评 (MBTI简化版) - 20题 ====================
  private getPersonalityAssessment(): Assessment {
    return {
      id: 'personality_mbti',
      title: '职业性格测评',
      description: '基于MBTI简化版，从4个维度分析您的职业性格类型，帮助找到最适合的工作环境与岗位方向',
      type: 'personality',
      icon: '🧠',
      duration: 15,
      category: '性格测评',
      dimensions: ['E/I 外向/内向', 'S/N 感觉/直觉', 'T/F 思考/情感', 'J/P 判断/感知'],
      status: 'not_started',
      questions: [
        // E/I 维度 (5题)
        { id: 'mbti_ei_1', type: 'single', title: '参加一场行业交流会后，你通常的感受是？', required: true, options: [
          { id: 'a', text: '精力充沛，认识了很多新朋友，期待下次参加', dimension: 'EI', direction: 1 },
          { id: 'b', text: '有些疲惫，需要独处来恢复精力，但收获了一些有价值的见解', dimension: 'EI', direction: -1 }
        ]},
        { id: 'mbti_ei_2', type: 'single', title: '面对一个复杂的工作问题，你更倾向于？', required: true, options: [
          { id: 'a', text: '立即找人讨论，通过头脑风暴激发灵感', dimension: 'EI', direction: 1 },
          { id: 'b', text: '先独自思考，理清思路后再与人交流', dimension: 'EI', direction: -1 }
        ]},
        { id: 'mbti_ei_3', type: 'single', title: '在团队中，你更享受哪种角色？', required: true, options: [
          { id: 'a', text: '活跃的沟通者和协调者，推动团队讨论', dimension: 'EI', direction: 1 },
          { id: 'b', text: '深入的思考者和执行者，专注完成任务', dimension: 'EI', direction: -1 }
        ]},
        { id: 'mbti_ei_4', type: 'single', title: '周末理想的放松方式是？', required: true, options: [
          { id: 'a', text: '和朋友聚餐、参加社交活动或户外运动', dimension: 'EI', direction: 1 },
          { id: 'b', text: '在家看书、看电影或做一些个人爱好', dimension: 'EI', direction: -1 }
        ]},
        { id: 'mbti_ei_5', type: 'single', title: '当你需要做一个重要决定时，你会？', required: true, options: [
          { id: 'a', text: '广泛征求他人意见，通过讨论来做决定', dimension: 'EI', direction: 1 },
          { id: 'b', text: '安静地分析利弊，依靠自己的判断做决定', dimension: 'EI', direction: -1 }
        ]},
        // S/N 维度 (5题)
        { id: 'mbti_sn_1', type: 'single', title: '在工作中，你更关注？', required: true, options: [
          { id: 'a', text: '具体的事实、数据和实际操作细节', dimension: 'SN', direction: 1 },
          { id: 'b', text: '整体的趋势、可能性和创新方向', dimension: 'SN', direction: -1 }
        ]},
        { id: 'mbti_sn_2', type: 'single', title: '阅读一份项目报告时，你更看重？', required: true, options: [
          { id: 'a', text: '具体的数据指标、执行步骤和实际成果', dimension: 'SN', direction: 1 },
          { id: 'b', text: '报告背后的战略思路、未来趋势和潜在影响', dimension: 'SN', direction: -1 }
        ]},
        { id: 'mbti_sn_3', type: 'single', title: '学习新知识时，你更喜欢？', required: true, options: [
          { id: 'a', text: '从具体的案例和实操练习入手，循序渐进', dimension: 'SN', direction: 1 },
          { id: 'b', text: '先理解底层原理和整体框架，再深入细节', dimension: 'SN', direction: -1 }
        ]},
        { id: 'mbti_sn_4', type: 'single', title: '描述一个项目经验时，你更倾向于？', required: true, options: [
          { id: 'a', text: '按时间线详细描述做了什么、怎么做的', dimension: 'SN', direction: 1 },
          { id: 'b', text: '提炼核心洞察和创新点，强调意义和启发', dimension: 'SN', direction: -1 }
        ]},
        { id: 'mbti_sn_5', type: 'single', title: '面对一个新项目，你首先会？', required: true, options: [
          { id: 'a', text: '收集已有的参考资料和成功案例，借鉴经验', dimension: 'SN', direction: 1 },
          { id: 'b', text: '构思全新的方案，探索前所未有的可能性', dimension: 'SN', direction: -1 }
        ]},
        // T/F 维度 (5题)
        { id: 'mbti_tf_1', type: 'single', title: '当同事在工作中犯错时，你的第一反应是？', required: true, options: [
          { id: 'a', text: '直接指出问题，分析原因并给出改进建议', dimension: 'TF', direction: 1 },
          { id: 'b', text: '先关心对方的感受，委婉地提醒并提供帮助', dimension: 'TF', direction: -1 }
        ]},
        { id: 'mbti_tf_2', type: 'single', title: '做决策时，你更依赖？', required: true, options: [
          { id: 'a', text: '客观数据和逻辑分析，即使结论不讨喜', dimension: 'TF', direction: 1 },
          { id: 'b', text: '对人的影响和价值观考量，追求和谐共识', dimension: 'TF', direction: -1 }
        ]},
        { id: 'mbti_tf_3', type: 'single', title: '评价一个项目方案时，你更看重？', required: true, options: [
          { id: 'a', text: '方案的可行性、效率和预期回报', dimension: 'TF', direction: 1 },
          { id: 'b', text: '方案对团队成员的影响和大家的接受度', dimension: 'TF', direction: -1 }
        ]},
        { id: 'mbti_tf_4', type: 'single', title: '在绩效评估中，你认为最重要的是？', required: true, options: [
          { id: 'a', text: '客观的业绩指标和可量化的成果', dimension: 'TF', direction: 1 },
          { id: 'b', text: '个人的成长进步和团队贡献精神', dimension: 'TF', direction: -1 }
        ]},
        { id: 'mbti_tf_5', type: 'single', title: '处理客户投诉时，你会优先？', required: true, options: [
          { id: 'a', text: '快速定位问题根因，给出合理的解决方案', dimension: 'TF', direction: 1 },
          { id: 'b', text: '先安抚客户情绪，让对方感到被理解和重视', dimension: 'TF', direction: -1 }
        ]},
        // J/P 维度 (5题)
        { id: 'mbti_jp_1', type: 'single', title: '对于日常工作安排，你更倾向于？', required: true, options: [
          { id: 'a', text: '提前制定详细的计划和时间表，严格执行', dimension: 'JP', direction: 1 },
          { id: 'b', text: '保持灵活，根据实际情况随时调整', dimension: 'JP', direction: -1 }
        ]},
        { id: 'mbti_jp_2', type: 'single', title: '面对一个截止日期，你通常会？', required: true, options: [
          { id: 'a', text: '提前完成，留出充足的缓冲时间', dimension: 'JP', direction: 1 },
          { id: 'b', text: '在截止日期前集中精力高效完成', dimension: 'JP', direction: -1 }
        ]},
        { id: 'mbti_jp_3', type: 'single', title: '你的工作桌面/电脑桌面通常是？', required: true, options: [
          { id: 'a', text: '整洁有序，文件分类清晰，随时可以找到需要的东西', dimension: 'JP', direction: 1 },
          { id: 'b', text: '看起来有些乱，但我知道每样东西在哪里', dimension: 'JP', direction: -1 }
        ]},
        { id: 'mbti_jp_4', type: 'single', title: '当计划突然发生变化时，你的反应是？', required: true, options: [
          { id: 'a', text: '感到不安，需要时间重新规划', dimension: 'JP', direction: 1 },
          { id: 'b', text: '比较适应，觉得变化可能带来新的机会', dimension: 'JP', direction: -1 }
        ]},
        { id: 'mbti_jp_5', type: 'single', title: '旅行时，你更喜欢？', required: true, options: [
          { id: 'a', text: '提前规划好行程和住宿，按计划执行', dimension: 'JP', direction: 1 },
          { id: 'b', text: '只定大方向，到了目的地再随性探索', dimension: 'JP', direction: -1 }
        ]}
      ]
    };
  }

  // ==================== 2. 职业兴趣测评 (霍兰德简化版) - 18题 ====================
  private getHollandAssessment(): Assessment {
    return {
      id: 'holland_interest',
      title: '职业兴趣测评',
      description: '基于霍兰德职业兴趣理论，识别您的职业兴趣类型，发现最适合的职业方向',
      type: 'career',
      icon: '🎯',
      duration: 12,
      category: '兴趣测评',
      dimensions: ['R 实用型', 'I 研究型', 'A 艺术型', 'S 社会型', 'E 企业型', 'C 常规型'],
      status: 'not_started',
      questions: [
        // R 实用型 (3题)
        { id: 'holland_r_1', type: 'single', title: '以下哪种活动最吸引你？', required: true, options: [
          { id: 'a', text: '动手组装一台电脑或修理一件家具', dimension: 'R', direction: 1 },
          { id: 'b', text: '策划一场社区公益活动', dimension: 'S', direction: 1 }
        ]},
        { id: 'holland_r_2', type: 'single', title: '你更享受哪种工作体验？', required: true, options: [
          { id: 'a', text: '在工厂或工场中操作设备、制作产品', dimension: 'R', direction: 1 },
          { id: 'b', text: '在办公室中分析数据、撰写报告', dimension: 'C', direction: 1 }
        ]},
        { id: 'holland_r_3', type: 'single', title: '选择一个业余爱好，你更倾向于？', required: true, options: [
          { id: 'a', text: '木工、烹饪、园艺等需要动手操作的活动', dimension: 'R', direction: 1 },
          { id: 'b', text: '摄影、绘画、写作等创意表达活动', dimension: 'A', direction: 1 }
        ]},
        // I 研究型 (3题)
        { id: 'holland_i_1', type: 'single', title: '面对一个不熟悉的现象，你的第一反应是？', required: true, options: [
          { id: 'a', text: '深入研究其原理和机制，查阅相关资料', dimension: 'I', direction: 1 },
          { id: 'b', text: '想想这个现象能如何应用到实际中', dimension: 'E', direction: 1 }
        ]},
        { id: 'holland_i_2', type: 'single', title: '以下哪种工作内容更让你有成就感？', required: true, options: [
          { id: 'a', text: '通过实验和数据分析发现新的规律', dimension: 'I', direction: 1 },
          { id: 'b', text: '设计出一套美观且实用的产品界面', dimension: 'A', direction: 1 }
        ]},
        { id: 'holland_i_3', type: 'single', title: '你更喜欢阅读哪类内容？', required: true, options: [
          { id: 'a', text: '科技前沿、学术研究、深度分析文章', dimension: 'I', direction: 1 },
          { id: 'b', text: '人物传记、心理学、社会学类文章', dimension: 'S', direction: 1 }
        ]},
        // A 艺术型 (3题)
        { id: 'holland_a_1', type: 'single', title: '在团队项目中，你最想负责哪个环节？', required: true, options: [
          { id: 'a', text: '创意构思和视觉设计，打造独特的呈现方式', dimension: 'A', direction: 1 },
          { id: 'b', text: '制定项目计划，确保每个环节按时完成', dimension: 'C', direction: 1 }
        ]},
        { id: 'holland_a_2', type: 'single', title: '以下哪种工作环境更吸引你？', required: true, options: [
          { id: 'a', text: '充满创意的广告公司或设计工作室', dimension: 'A', direction: 1 },
          { id: 'b', text: '节奏明快的创业公司或投资机构', dimension: 'E', direction: 1 }
        ]},
        { id: 'holland_a_3', type: 'single', title: '你觉得最重要的工作特质是？', required: true, options: [
          { id: 'a', text: '能够自由表达创意，工作成果有独特性', dimension: 'A', direction: 1 },
          { id: 'b', text: '能够帮助他人解决问题，有社会价值', dimension: 'S', direction: 1 }
        ]},
        // S 社会型 (3题)
        { id: 'holland_s_1', type: 'single', title: '以下哪种场景让你最有满足感？', required: true, options: [
          { id: 'a', text: '帮助一位新人快速融入团队并成长', dimension: 'S', direction: 1 },
          { id: 'b', text: '独立攻克一个技术难题', dimension: 'I', direction: 1 }
        ]},
        { id: 'holland_s_2', type: 'single', title: '理想的职业应该具备？', required: true, options: [
          { id: 'a', text: '频繁与人交流，能够教育和帮助他人', dimension: 'S', direction: 1 },
          { id: 'b', text: '有明确的晋升通道和竞争机制', dimension: 'E', direction: 1 }
        ]},
        { id: 'holland_s_3', type: 'single', title: '在团队冲突中，你更可能？', required: true, options: [
          { id: 'a', text: '主动调解，帮助双方找到共同点', dimension: 'S', direction: 1 },
          { id: 'b', text: '用数据说话，提出客观的解决方案', dimension: 'I', direction: 1 }
        ]},
        // E 企业型 (3题)
        { id: 'holland_e_1', type: 'single', title: '以下哪种角色更吸引你？', required: true, options: [
          { id: 'a', text: '带领团队冲锋陷阵的项目负责人', dimension: 'E', direction: 1 },
          { id: 'b', text: '深入研究行业趋势的分析师', dimension: 'I', direction: 1 }
        ]},
        { id: 'holland_e_2', type: 'single', title: '面对一个商业机会，你会？', required: true, options: [
          { id: 'a', text: '果断抓住机会，迅速组建团队推进', dimension: 'E', direction: 1 },
          { id: 'b', text: '仔细评估风险和收益后再做决定', dimension: 'C', direction: 1 }
        ]},
        { id: 'holland_e_3', type: 'single', title: '你认为领导力最重要的体现是？', required: true, options: [
          { id: 'a', text: '设定愿景并激励团队达成目标', dimension: 'E', direction: 1 },
          { id: 'b', text: '关心团队成员，营造良好的工作氛围', dimension: 'S', direction: 1 }
        ]},
        // C 常规型 (3题)
        { id: 'holland_c_1', type: 'single', title: '以下哪种工作方式更让你安心？', required: true, options: [
          { id: 'a', text: '按照既定流程和标准操作，确保准确无误', dimension: 'C', direction: 1 },
          { id: 'b', text: '在不确定中探索，从错误中学习', dimension: 'I', direction: 1 }
        ]},
        { id: 'holland_c_2', type: 'single', title: '你更擅长？', required: true, options: [
          { id: 'a', text: '整理和归档信息，建立高效的文件管理系统', dimension: 'C', direction: 1 },
          { id: 'b', text: '从零开始构思一个全新的项目方案', dimension: 'A', direction: 1 }
        ]},
        { id: 'holland_c_3', type: 'single', title: '面对大量数据，你的第一反应是？', required: true, options: [
          { id: 'a', text: '建立表格和分类系统，有条理地整理', dimension: 'C', direction: 1 },
          { id: 'b', text: '寻找数据中的异常值和隐藏趋势', dimension: 'I', direction: 1 }
        ]}
      ]
    };
  }

  // ==================== 3. 求职竞争力测评 - 18题 ====================
  private getCompetitivenessAssessment(): Assessment {
    return {
      id: 'competitiveness',
      title: '求职竞争力测评',
      description: '从6个核心维度全面评估您的求职竞争力，精准定位优势与短板，获得个性化提升方案',
      type: 'skill',
      icon: '💪',
      duration: 12,
      category: '能力测评',
      dimensions: ['专业技能', '沟通表达', '团队协作', '学习能力', '抗压能力', '创新思维'],
      status: 'not_started',
      questions: [
        // 专业技能 (3题)
        { id: 'comp_skill_1', type: 'single', title: '你对自己目标岗位所需的专业技能掌握程度如何？', required: true, options: [
          { id: 'a', text: '非常精通，有丰富的实战经验和独立解决复杂问题的能力', dimension: '专业技能', direction: 1 },
          { id: 'b', text: '基本掌握，能完成常规任务但复杂场景需要求助', dimension: '专业技能', direction: -1 }
        ]},
        { id: 'comp_skill_2', type: 'single', title: '你是否有目标岗位相关的证书或资质？', required: true, options: [
          { id: 'a', text: '有相关证书，且持续学习保持技能更新', dimension: '专业技能', direction: 1 },
          { id: 'b', text: '暂时没有，主要靠工作经验积累', dimension: '专业技能', direction: -1 }
        ]},
        { id: 'comp_skill_3', type: 'single', title: '你如何保持专业领域的竞争力？', required: true, options: [
          { id: 'a', text: '定期学习新技术、参加行业会议、关注前沿动态', dimension: '专业技能', direction: 1 },
          { id: 'b', text: '主要在工作中边做边学，偶尔看看相关资讯', dimension: '专业技能', direction: -1 }
        ]},
        // 沟通表达 (3题)
        { id: 'comp_comm_1', type: 'single', title: '在面试中做自我介绍时，你通常？', required: true, options: [
          { id: 'a', text: '条理清晰、重点突出，能在2分钟内展现核心优势', dimension: '沟通表达', direction: 1 },
          { id: 'b', text: '内容较散，有时会超时或遗漏重要信息', dimension: '沟通表达', direction: -1 }
        ]},
        { id: 'comp_comm_2', type: 'single', title: '向非技术人员解释一个专业概念时，你？', required: true, options: [
          { id: 'a', text: '善于用比喻和生活中的例子来简化说明', dimension: '沟通表达', direction: 1 },
          { id: 'b', text: '倾向于使用专业术语，有时对方难以理解', dimension: '沟通表达', direction: -1 }
        ]},
        { id: 'comp_comm_3', type: 'single', title: '在书面沟通（邮件、报告）方面，你？', required: true, options: [
          { id: 'a', text: '文字简洁专业，结构清晰，读者能快速抓住重点', dimension: '沟通表达', direction: 1 },
          { id: 'b', text: '内容全面但有时偏长，需要多次修改才能定稿', dimension: '沟通表达', direction: -1 }
        ]},
        // 团队协作 (3题)
        { id: 'comp_team_1', type: 'single', title: '在跨部门合作项目中，你通常扮演什么角色？', required: true, options: [
          { id: 'a', text: '主动协调各方需求，推动项目顺利推进', dimension: '团队协作', direction: 1 },
          { id: 'b', text: '主要完成自己负责的部分，配合团队安排', dimension: '团队协作', direction: -1 }
        ]},
        { id: 'comp_team_2', type: 'single', title: '当团队意见不统一时，你会？', required: true, options: [
          { id: 'a', text: '引导大家聚焦共同目标，寻找折中方案', dimension: '团队协作', direction: 1 },
          { id: 'b', text: '表达自己的观点，然后尊重多数人的决定', dimension: '团队协作', direction: -1 }
        ]},
        { id: 'comp_team_3', type: 'single', title: '你是否经常主动帮助团队成员？', required: true, options: [
          { id: 'a', text: '经常主动分享经验和资源，帮助他人成长', dimension: '团队协作', direction: 1 },
          { id: 'b', text: '在别人求助时会帮忙，但很少主动提出', dimension: '团队协作', direction: -1 }
        ]},
        // 学习能力 (3题)
        { id: 'comp_learn_1', type: 'single', title: '面对一个全新的领域，你通常需要多久上手？', required: true, options: [
          { id: 'a', text: '能快速建立知识框架，1-2周内独立完成基础任务', dimension: '学习能力', direction: 1 },
          { id: 'b', text: '需要较长时间适应，通常1个月以上才能独立工作', dimension: '学习能力', direction: -1 }
        ]},
        { id: 'comp_learn_2', type: 'single', title: '你更倾向于哪种学习方式？', required: true, options: [
          { id: 'a', text: '多种方式结合：阅读、实践、请教他人、复盘总结', dimension: '学习能力', direction: 1 },
          { id: 'b', text: '主要通过工作实践来学习，较少系统性学习', dimension: '学习能力', direction: -1 }
        ]},
        { id: 'comp_learn_3', type: 'single', title: '你最近一次学习新技能是什么时候？', required: true, options: [
          { id: 'a', text: '最近一个月内，且已经应用到工作中', dimension: '学习能力', direction: 1 },
          { id: 'b', text: '几个月前或更久，目前没有正在学习的新技能', dimension: '学习能力', direction: -1 }
        ]},
        // 抗压能力 (3题)
        { id: 'comp_press_1', type: 'single', title: '面对紧迫的截止日期和繁重的工作量，你？', required: true, options: [
          { id: 'a', text: '能保持冷静，合理分配时间和精力，高效完成任务', dimension: '抗压能力', direction: 1 },
          { id: 'b', text: '容易焦虑，有时会影响工作质量和效率', dimension: '抗压能力', direction: -1 }
        ]},
        { id: 'comp_press_2', type: 'single', title: '当你的方案被领导或客户否定时，你？', required: true, options: [
          { id: 'a', text: '快速调整心态，虚心接受反馈并改进方案', dimension: '抗压能力', direction: 1 },
          { id: 'b', text: '会感到沮丧，需要一段时间才能重新振作', dimension: '抗压能力', direction: -1 }
        ]},
        { id: 'comp_press_3', type: 'single', title: '同时处理多个紧急任务时，你？', required: true, options: [
          { id: 'a', text: '能快速判断优先级，有条不紊地逐一推进', dimension: '抗压能力', direction: 1 },
          { id: 'b', text: '容易手忙脚乱，有时会遗漏重要事项', dimension: '抗压能力', direction: -1 }
        ]},
        // 创新思维 (3题)
        { id: 'comp_innov_1', type: 'single', title: '面对一个长期存在的业务痛点，你更可能？', required: true, options: [
          { id: 'a', text: '提出一个全新的解决方案，打破常规思路', dimension: '创新思维', direction: 1 },
          { id: 'b', text: '在现有方案基础上进行优化和改进', dimension: '创新思维', direction: -1 }
        ]},
        { id: 'comp_innov_2', type: 'single', title: '你是否有过用创新方法解决工作问题的经历？', required: true, options: [
          { id: 'a', text: '有过多次，且取得了超出预期的效果', dimension: '创新思维', direction: 1 },
          { id: 'b', text: '偶尔会有一些新想法，但很少付诸实践', dimension: '创新思维', direction: -1 }
        ]},
        { id: 'comp_innov_3', type: 'single', title: '对于行业新技术和新趋势，你的态度是？', required: true, options: [
          { id: 'a', text: '积极尝试，思考如何将其应用到当前工作中', dimension: '创新思维', direction: 1 },
          { id: 'b', text: '保持关注，但更倾向于等技术成熟后再使用', dimension: '创新思维', direction: -1 }
        ]}
      ]
    };
  }

  // ==================== 4. 职场情商测评 - 16题 ====================
  private getEQAssessment(): Assessment {
    return {
      id: 'eq_assessment',
      title: '职场情商测评',
      description: '从自我认知、自我管理、社交意识和关系管理4个维度评估您的职场情商水平',
      type: 'eq',
      icon: '❤️',
      duration: 10,
      category: '情商测评',
      dimensions: ['自我认知', '自我管理', '社交意识', '关系管理'],
      status: 'not_started',
      questions: [
        // 自我认知 (4题)
        { id: 'eq_self_1', type: 'single', title: '当你感到愤怒或沮丧时，你能多快意识到自己的情绪变化？', required: true, options: [
          { id: 'a', text: '几乎立刻就能觉察到，并能准确说出情绪的原因', dimension: '自我认知', direction: 1 },
          { id: 'b', text: '通常在情绪爆发后才意识到，或者需要别人提醒', dimension: '自我认知', direction: -1 }
        ]},
        { id: 'eq_self_2', type: 'single', title: '你是否清楚自己的核心优势和需要改进的地方？', required: true, options: [
          { id: 'a', text: '非常清楚，且能举出具体事例说明', dimension: '自我认知', direction: 1 },
          { id: 'b', text: '有一些模糊的认识，但不够系统和具体', dimension: '自我认知', direction: -1 }
        ]},
        { id: 'eq_self_3', type: 'single', title: '面对一项困难的任务，你对自己的能力评估通常？', required: true, options: [
          { id: 'a', text: '比较客观，既不盲目自信也不过度自卑', dimension: '自我认知', direction: 1 },
          { id: 'b', text: '容易走极端，要么过于乐观要么过于悲观', dimension: '自我认知', direction: -1 }
        ]},
        { id: 'eq_self_4', type: 'single', title: '你是否了解自己在压力下的行为模式？', required: true, options: [
          { id: 'a', text: '了解，知道压力下自己可能出现的反应并提前预防', dimension: '自我认知', direction: 1 },
          { id: 'b', text: '不太了解，每次压力下的反应可能不太一样', dimension: '自我认知', direction: -1 }
        ]},
        // 自我管理 (4题)
        { id: 'eq_manage_1', type: 'single', title: '当你在会议上被不公平地批评时，你会？', required: true, options: [
          { id: 'a', text: '先控制情绪，冷静后私下沟通澄清', dimension: '自我管理', direction: 1 },
          { id: 'b', text: '当场反驳，或者内心极度不满影响后续工作', dimension: '自我管理', direction: -1 }
        ]},
        { id: 'eq_manage_2', type: 'single', title: '面对一个你不喜欢但必须完成的任务，你会？', required: true, options: [
          { id: 'a', text: '调整心态，找到任务中的价值并认真完成', dimension: '自我管理', direction: 1 },
          { id: 'b', text: '拖延到最后期限，带着负面情绪敷衍了事', dimension: '自我管理', direction: -1 }
        ]},
        { id: 'eq_manage_3', type: 'single', title: '当你犯了一个明显的错误被同事发现时，你？', required: true, options: [
          { id: 'a', text: '坦然承认错误，分析原因并迅速改正', dimension: '自我管理', direction: 1 },
          { id: 'b', text: '感到尴尬，试图掩饰或找借口解释', dimension: '自我管理', direction: -1 }
        ]},
        { id: 'eq_manage_4', type: 'single', title: '你的情绪波动频率如何？', required: true, options: [
          { id: 'a', text: '比较稳定，即使在困难时期也能保持基本平稳', dimension: '自我管理', direction: 1 },
          { id: 'b', text: '波动较大，容易受外界环境和他人影响', dimension: '自我管理', direction: -1 }
        ]},
        // 社交意识 (4题)
        { id: 'eq_social_1', type: 'single', title: '在会议中，你是否能察觉到哪些人没有发言但可能有不同意见？', required: true, options: [
          { id: 'a', text: '通常能注意到，并主动邀请他们表达观点', dimension: '社交意识', direction: 1 },
          { id: 'b', text: '很少注意到，主要关注发言的人和内容', dimension: '社交意识', direction: -1 }
        ]},
        { id: 'eq_social_2', type: 'single', title: '你是否能准确判断上级的真实意图，而不仅仅是字面意思？', required: true, options: [
          { id: 'a', text: '通常能理解言外之意，并做出恰当的回应', dimension: '社交意识', direction: 1 },
          { id: 'b', text: '倾向于按字面意思理解，有时会误解意图', dimension: '社交意识', direction: -1 }
        ]},
        { id: 'eq_social_3', type: 'single', title: '新加入一个团队时，你通常需要多久了解团队的人际关系？', required: true, options: [
          { id: 'a', text: '很快就能感知到团队氛围和人际关系格局', dimension: '社交意识', direction: 1 },
          { id: 'b', text: '需要较长时间才能了解，有时会无意中踩到"雷区"', dimension: '社交意识', direction: -1 }
        ]},
        { id: 'eq_social_4', type: 'single', title: '当同事情绪低落时，你？', required: true, options: [
          { id: 'a', text: '能敏锐察觉并适时给予关心和支持', dimension: '社交意识', direction: 1 },
          { id: 'b', text: '通常不会注意到，除非对方主动表现出来', dimension: '社交意识', direction: -1 }
        ]},
        // 关系管理 (4题)
        { id: 'eq_rel_1', type: 'single', title: '与一个性格截然不同的同事合作时，你？', required: true, options: [
          { id: 'a', text: '尊重差异，找到互补的合作方式', dimension: '关系管理', direction: 1 },
          { id: 'b', text: '尽量避免深度合作，觉得沟通成本太高', dimension: '关系管理', direction: -1 }
        ]},
        { id: 'eq_rel_2', type: 'single', title: '当你需要说服他人接受你的观点时，你？', required: true, options: [
          { id: 'a', text: '先了解对方的需求和顾虑，再针对性地沟通', dimension: '关系管理', direction: 1 },
          { id: 'b', text: '直接阐述自己的理由，用逻辑和数据说服对方', dimension: '关系管理', direction: -1 }
        ]},
        { id: 'eq_rel_3', type: 'single', title: '你如何处理与上级的分歧？', required: true, options: [
          { id: 'a', text: '选择合适的时机和方式，私下进行建设性沟通', dimension: '关系管理', direction: 1 },
          { id: 'b', text: '在公开场合表达不同意见，或者沉默不语', dimension: '关系管理', direction: -1 }
        ]},
        { id: 'eq_rel_4', type: 'single', title: '你的职场人脉网络如何？', required: true, options: [
          { id: 'a', text: '有良好的人脉网络，跨部门也有不少可以合作的关系', dimension: '关系管理', direction: 1 },
          { id: 'b', text: '人脉主要集中在自己的小团队，跨部门联系较少', dimension: '关系管理', direction: -1 }
        ]}
      ]
    };
  }

  // ==================== 5. 面试准备度测评 - 16题 ====================
  private getInterviewReadinessAssessment(): Assessment {
    return {
      id: 'interview_readiness',
      title: '面试准备度测评',
      description: '全面评估您的面试准备情况，从简历到薪资谈判，确保您在面试中发挥最佳水平',
      type: 'interview_readiness',
      icon: '📝',
      duration: 10,
      category: '面试准备',
      dimensions: ['简历质量', '自我介绍', '常见问题准备', '专业知识', '薪资谈判', '反问能力'],
      status: 'not_started',
      questions: [
        // 简历质量 (3题)
        { id: 'intv_resume_1', type: 'single', title: '你的简历是否针对每个目标岗位进行了定制？', required: true, options: [
          { id: 'a', text: '会根据岗位JD调整关键词和经历描述的侧重点', dimension: '简历质量', direction: 1 },
          { id: 'b', text: '使用同一份简历投递所有岗位', dimension: '简历质量', direction: -1 }
        ]},
        { id: 'intv_resume_2', type: 'single', title: '你的简历中是否用数据量化了工作成果？', required: true, options: [
          { id: 'a', text: '大部分成果都有具体数据支撑（如提升了30%效率）', dimension: '简历质量', direction: 1 },
          { id: 'b', text: '主要以文字描述为主，数据较少', dimension: '简历质量', direction: -1 }
        ]},
        { id: 'intv_resume_3', type: 'single', title: '你的简历篇幅和格式如何？', required: true, options: [
          { id: 'a', text: '1-2页，排版清晰专业，重点突出', dimension: '简历质量', direction: 1 },
          { id: 'b', text: '超过2页或格式不够规范，信息密度过高', dimension: '简历质量', direction: -1 }
        ]},
        // 自我介绍 (3题)
        { id: 'intv_intro_1', type: 'single', title: '你是否准备了不同长度的自我介绍版本？', required: true, options: [
          { id: 'a', text: '准备了30秒、1分钟、3分钟三个版本', dimension: '自我介绍', direction: 1 },
          { id: 'b', text: '只有一个版本，到时根据情况临场发挥', dimension: '自我介绍', direction: -1 }
        ]},
        { id: 'intv_intro_2', type: 'single', title: '你的自我介绍是否包含与目标岗位的关联？', required: true, options: [
          { id: 'a', text: '会自然地将过往经历与目标岗位的需求联系起来', dimension: '自我介绍', direction: 1 },
          { id: 'b', text: '主要按时间线罗列经历，关联性不强', dimension: '自我介绍', direction: -1 }
        ]},
        { id: 'intv_intro_3', type: 'single', title: '你是否对着镜子或录像练习过自我介绍？', required: true, options: [
          { id: 'a', text: '练习过多次，并根据反馈不断优化', dimension: '自我介绍', direction: 1 },
          { id: 'b', text: '在脑海中想过，但没有实际练习过', dimension: '自我介绍', direction: -1 }
        ]},
        // 常见问题准备 (3题)
        { id: 'intv_common_1', type: 'single', title: '对于"你最大的缺点是什么"这类问题，你是否准备好了回答？', required: true, options: [
          { id: 'a', text: '准备了真诚且有改进计划的回答', dimension: '常见问题准备', direction: 1 },
          { id: 'b', text: '想到什么说什么，没有特别准备', dimension: '常见问题准备', direction: -1 }
        ]},
        { id: 'intv_common_2', type: 'single', title: '你是否准备了3-5个可以展示能力的STAR故事？', required: true, options: [
          { id: 'a', text: '准备了多个故事，可以灵活应对不同问题', dimension: '常见问题准备', direction: 1 },
          { id: 'b', text: '有一些经历可以讲，但没有系统地整理', dimension: '常见问题准备', direction: -1 }
        ]},
        { id: 'intv_common_3', type: 'single', title: '对于"为什么离开上一家公司"这类敏感问题，你？', required: true, options: [
          { id: 'a', text: '准备了积极正面的回答，避免负面评价前公司', dimension: '常见问题准备', direction: 1 },
          { id: 'b', text: '可能会说出对前公司的不满，没有刻意准备', dimension: '常见问题准备', direction: -1 }
        ]},
        // 专业知识 (2题)
        { id: 'intv_tech_1', type: 'single', title: '你是否复习了目标岗位的核心专业知识？', required: true, options: [
          { id: 'a', text: '系统复习了，并做了相关练习题或项目', dimension: '专业知识', direction: 1 },
          { id: 'b', text: '主要依赖以往的工作经验，没有特别复习', dimension: '专业知识', direction: -1 }
        ]},
        { id: 'intv_tech_2', type: 'single', title: '你是否了解目标公司的核心产品和技术栈？', required: true, options: [
          { id: 'a', text: '深入了解了公司的产品、技术方向和行业地位', dimension: '专业知识', direction: 1 },
          { id: 'b', text: '简单浏览了公司官网，了解基本信息', dimension: '专业知识', direction: -1 }
        ]},
        // 薪资谈判 (2题)
        { id: 'intv_salary_1', type: 'single', title: '你是否调研了目标岗位的市场薪资范围？', required: true, options: [
          { id: 'a', text: '通过多个渠道了解了市场行情，有明确的期望范围', dimension: '薪资谈判', direction: 1 },
          { id: 'b', text: '有一个大概的期望值，但没有做过系统调研', dimension: '薪资谈判', direction: -1 }
        ]},
        { id: 'intv_salary_2', type: 'single', title: '当HR问你的期望薪资时，你准备如何回答？', required: true, options: [
          { id: 'a', text: '给出一个有理有据的范围，并表达弹性', dimension: '薪资谈判', direction: 1 },
          { id: 'b', text: '直接说出一个具体数字，或表示都可以商量', dimension: '薪资谈判', direction: -1 }
        ]},
        // 反问能力 (3题)
        { id: 'intv_ask_1', type: 'single', title: '面试结束时，你是否准备了要问面试官的问题？', required: true, options: [
          { id: 'a', text: '准备了5个以上高质量问题，涵盖团队、文化、发展等', dimension: '反问能力', direction: 1 },
          { id: 'b', text: '可能临时想一两个问题，没有提前准备', dimension: '反问能力', direction: -1 }
        ]},
        { id: 'intv_ask_2', type: 'single', title: '你准备的问题是否能体现你对公司和岗位的深入了解？', required: true, options: [
          { id: 'a', text: '问题基于前期调研，能展示我的专业度和诚意', dimension: '反问能力', direction: 1 },
          { id: 'b', text: '问题比较通用，如"团队氛围怎么样"', dimension: '反问能力', direction: -1 }
        ]},
        { id: 'intv_ask_3', type: 'single', title: '你是否会通过反问来了解岗位的真实挑战？', required: true, options: [
          { id: 'a', text: '会问"这个岗位目前最大的挑战是什么"等深度问题', dimension: '反问能力', direction: 1 },
          { id: 'b', text: '主要问一些福利、加班等基本信息', dimension: '反问能力', direction: -1 }
        ]}
      ]
    };
  }

  // ==================== 6. 职业价值观测评 - 16题 ====================
  private getValueAssessment(): Assessment {
    return {
      id: 'value_assessment',
      title: '职业价值观测评',
      description: '探索您内心最看重的职业因素，帮助您做出更符合价值观的职业选择',
      type: 'value',
      icon: '⭐',
      duration: 10,
      category: '价值观测评',
      dimensions: ['薪酬福利', '工作生活平衡', '职业发展', '工作环境', '社会价值', '创新自由'],
      status: 'not_started',
      questions: [
        // 薪酬福利 (3题)
        { id: 'val_salary_1', type: 'single', title: '在两份工作之间选择，以下哪个因素最能影响你的决定？', required: true, options: [
          { id: 'a', text: '薪资高出30%，但工作强度较大', dimension: '薪酬福利', direction: 1 },
          { id: 'b', text: '薪资一般，但每天准时下班，周末不加班', dimension: '工作生活平衡', direction: 1 }
        ]},
        { id: 'val_salary_2', type: 'single', title: '你认为理想的薪资结构是？', required: true, options: [
          { id: 'a', text: '高底薪+绩效奖金，收入与能力直接挂钩', dimension: '薪酬福利', direction: 1 },
          { id: 'b', text: '稳定底薪+良好福利，追求长期保障', dimension: '工作生活平衡', direction: 1 }
        ]},
        { id: 'val_salary_3', type: 'single', title: '你对股票期权/股权激励的看法是？', required: true, options: [
          { id: 'a', text: '非常看重，愿意为此接受较低的现金薪酬', dimension: '薪酬福利', direction: 1 },
          { id: 'b', text: '锦上添花，但不会因此降低对现金薪酬的要求', dimension: '工作生活平衡', direction: 1 }
        ]},
        // 工作生活平衡 (3题)
        { id: 'val_balance_1', type: 'single', title: '以下哪种工作安排更符合你的期望？', required: true, options: [
          { id: 'a', text: '每周工作40小时，固定时间上下班', dimension: '工作生活平衡', direction: 1 },
          { id: 'b', text: '工作时间灵活，但需要时可以加班赶项目', dimension: '职业发展', direction: 1 }
        ]},
        { id: 'val_balance_2', type: 'single', title: '对于远程办公，你的态度是？', required: true, options: [
          { id: 'a', text: '非常希望有远程办公的选项，灵活性很重要', dimension: '工作生活平衡', direction: 1 },
          { id: 'b', text: '更倾向于在办公室工作，便于协作和交流', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_balance_3', type: 'single', title: '你认为理想的年假天数是？', required: true, options: [
          { id: 'a', text: '15天以上，充足的休息时间对长期发展很重要', dimension: '工作生活平衡', direction: 1 },
          { id: 'b', text: '10天左右即可，更看重工作本身的成长性', dimension: '职业发展', direction: 1 }
        ]},
        // 职业发展 (3题)
        { id: 'val_growth_1', type: 'single', title: '选择工作时，你最看重？', required: true, options: [
          { id: 'a', text: '清晰的晋升通道和快速成长的机会', dimension: '职业发展', direction: 1 },
          { id: 'b', text: '稳定的工作环境和可靠的福利保障', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_growth_2', type: 'single', title: '你更倾向于哪种公司阶段？', required: true, options: [
          { id: 'a', text: '快速成长的创业公司，承担更多责任', dimension: '职业发展', direction: 1 },
          { id: 'b', text: '成熟稳定的大公司，有完善的培训体系', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_growth_3', type: 'single', title: '关于职业规划，你更认同？', required: true, options: [
          { id: 'a', text: '定期挑战舒适区，3-5年争取职级跃升', dimension: '职业发展', direction: 1 },
          { id: 'b', text: '稳扎稳打，在专业领域持续深耕', dimension: '创新自由', direction: 1 }
        ]},
        // 工作环境 (2题)
        { id: 'val_env_1', type: 'single', title: '你理想的工作氛围是？', required: true, options: [
          { id: 'a', text: '扁平化管理，同事之间平等交流', dimension: '工作环境', direction: 1 },
          { id: 'b', text: '层级分明，有清晰的汇报线和决策流程', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_env_2', type: 'single', title: '关于公司文化，你更看重？', required: true, options: [
          { id: 'a', text: '开放包容，鼓励多元观点和尝试', dimension: '创新自由', direction: 1 },
          { id: 'b', text: '协作互助，团队氛围融洽', dimension: '工作环境', direction: 1 }
        ]},
        // 社会价值 (2题)
        { id: 'val_social_1', type: 'single', title: '你认为工作的意义主要在于？', required: true, options: [
          { id: 'a', text: '为社会创造价值，帮助他人解决问题', dimension: '社会价值', direction: 1 },
          { id: 'b', text: '实现个人价值，获得成就感和经济回报', dimension: '薪酬福利', direction: 1 }
        ]},
        { id: 'val_social_2', type: 'single', title: '如果两份工作薪资相同，以下哪个让你更倾向？', required: true, options: [
          { id: 'a', text: '在教育、医疗等有社会意义的行业', dimension: '社会价值', direction: 1 },
          { id: 'b', text: '在科技、金融等高增长潜力的行业', dimension: '职业发展', direction: 1 }
        ]},
        // 创新自由 (3题)
        { id: 'val_freedom_1', type: 'single', title: '关于工作方式，你更倾向于？', required: true, options: [
          { id: 'a', text: '有充分的自主权，可以自己决定如何完成工作', dimension: '创新自由', direction: 1 },
          { id: 'b', text: '有明确的流程和规范，按标准执行即可', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_freedom_2', type: 'single', title: '你更希望公司如何对待创新？', required: true, options: [
          { id: 'a', text: '鼓励试错，为创新项目提供资源和支持', dimension: '创新自由', direction: 1 },
          { id: 'b', text: '稳健创新，在可控范围内逐步尝试新方法', dimension: '工作环境', direction: 1 }
        ]},
        { id: 'val_freedom_3', type: 'single', title: '关于技术/方法选择，你更倾向于？', required: true, options: [
          { id: 'a', text: '可以自由选择最适合的技术方案和工具', dimension: '创新自由', direction: 1 },
          { id: 'b', text: '使用公司统一的技术栈和工具，便于协作', dimension: '工作环境', direction: 1 }
        ]}
      ]
    };
  }
}
