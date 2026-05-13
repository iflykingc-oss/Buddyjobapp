/**
 * DataConverter - 数据转换服务
 *
 * 将开源格式的原始 JSON 数据转换为应用内部模型格式。
 * 支持 MBTI 测评、Holland 职业兴趣测评、面试题、知识库文章的转换。
 *
 * @example
 * const converter = DataConverter.getInstance();
 * const assessment = converter.convertMBTI(rawData);
 * const questions = converter.convertInterviewQuestions(rawQuestions);
 *
 * @since 1.0.0
 */
import { Assessment, Question, Option, AssessmentType } from '../models/Assessment';
import { InterviewQuestion } from './InterviewService';
import { KnowledgeArticle } from './KnowledgeService';

const TAG = 'DataConverter';
const DOMAIN = 0xFF00;

export class DataConverter {
  private static instance: DataConverter;

  private constructor() {
  }

  /**
   * 获取 DataConverter 单例实例
   * @returns DataConverter 实例
   */
  static getInstance(): DataConverter {
    if (!DataConverter.instance) {
      DataConverter.instance = new DataConverter();
    }
    return DataConverter.instance;
  }

  // ==================== 测评数据转换 ====================

  /**
   * 转换MBTI JSON数据为Assessment格式
   * Source: luhuadong/mbti-test 格式
   *   rawData 结构示例:
   *   {
   *     "title": "MBTI人格测试",
   *     "questions": [
   *       {
   *         "title": "在聚会中，你通常会...",
   *         "options": [
   *           { "score": "E", "text": "主动与陌生人交谈" },
   *           { "score": "I", "text": "等待别人来与你交谈" }
   *         ]
   *       }
   *     ]
   *   }
   * Target: Assessment model
   */
  convertMBTI(rawData: any): Assessment {
    try {
      const title = rawData.title || rawData.name || 'MBTI人格测试';
      const description = rawData.description || '通过93道题目探索你的MBTI人格类型';
      const rawQuestions = rawData.questions || [];

      // 收集所有维度（E/I, S/N, T/F, J/P）
      const dimensionSet: Set<string> = new Set();
      for (let i = 0; i < rawQuestions.length; i++) {
        const q = rawQuestions[i];
        const opts = q.options || q.option || [];
        for (let j = 0; j < opts.length; j++) {
          const score = opts[j].score || opts[j].dimension || '';
          // 取第一个字符作为维度标识
          if (score.length > 0) {
            dimensionSet.add(score.charAt(0).toUpperCase());
          }
        }
      }

      const dimensions: string[] = [];
      dimensionSet.forEach((dim: string) => {
        dimensions.push(dim);
      });

      // 转换问题
      const questions: Question[] = [];
      for (let i = 0; i < rawQuestions.length; i++) {
        const rq = rawQuestions[i];
        const question = this.convertMBTIQuestion(rq, i);
        questions.push(question);
      }

      const assessment: Assessment = {
        id: rawData.id || 'mbti_test',
        title: title,
        description: description,
        type: 'personality' as AssessmentType,
        icon: rawData.icon || '🧠',
        duration: rawData.duration || 30,
        category: rawData.category || '性格测评',
        dimensions: dimensions,
        questions: questions,
        status: 'not_started'
      };

      this.log(`MBTI数据转换成功，共 ${questions.length} 道题目`);
      return assessment;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`MBTI数据转换失败: ${errMsg}`);
      return this.createFallbackAssessment('mbti_test', 'MBTI人格测试', 'personality');
    }
  }

  /**
   * 转换Holland JSON数据为Assessment格式
   * Source: holland_questions.json 格式
   *   rawData 结构示例:
   *   {
   *     "title": "霍兰德职业兴趣测试",
   *     "questions": [
   *       {
   *         "id": "h001",
   *         "text": "我喜欢修理机器",
   *         "dimension": "R",
   *         "options": [
   *           { "text": "是", "score": 1 },
   *           { "text": "否", "score": 0 }
   *         ]
   *       }
   *     ],
   *     "dimensions": ["R", "I", "A", "S", "E", "C"]
   *   }
   * Target: Assessment model
   */
  convertHolland(rawData: any): Assessment {
    try {
      const title = rawData.title || rawData.name || '霍兰德职业兴趣测试';
      const description = rawData.description || '发现你的职业兴趣类型，找到最适合的职业方向';
      const rawQuestions = rawData.questions || [];

      // 收集维度
      const dimensions: string[] = rawData.dimensions || [];
      if (dimensions.length === 0) {
        const dimSet: Set<string> = new Set();
        for (let i = 0; i < rawQuestions.length; i++) {
          const dim = rawQuestions[i].dimension || rawQuestions[i].type || '';
          if (dim.length > 0) {
            dimSet.add(dim);
          }
        }
        dimSet.forEach((d: string) => {
          dimensions.push(d);
        });
      }

      // 转换问题
      const questions: Question[] = [];
      for (let i = 0; i < rawQuestions.length; i++) {
        const rq = rawQuestions[i];
        const question = this.convertHollandQuestion(rq, i);
        questions.push(question);
      }

      const assessment: Assessment = {
        id: rawData.id || 'holland_test',
        title: title,
        description: description,
        type: 'career' as AssessmentType,
        icon: rawData.icon || '🎯',
        duration: rawData.duration || 20,
        category: rawData.category || '职业测评',
        dimensions: dimensions,
        questions: questions,
        status: 'not_started'
      };

      this.log(`Holland数据转换成功，共 ${questions.length} 道题目`);
      return assessment;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`Holland数据转换失败: ${errMsg}`);
      return this.createFallbackAssessment('holland_test', '霍兰德职业兴趣测试', 'career');
    }
  }

  /**
   * 批量转换所有测评数据
   * @param mbtiData MBTI原始JSON数据
   * @param hollandData Holland原始JSON数据
   * @returns Assessment数组
   */
  convertAllAssessments(mbtiData: any, hollandData: any): Assessment[] {
    const assessments: Assessment[] = [];

    if (mbtiData !== null && mbtiData !== undefined) {
      const mbti = this.convertMBTI(mbtiData);
      assessments.push(mbti);
    }

    if (hollandData !== null && hollandData !== undefined) {
      const holland = this.convertHolland(hollandData);
      assessments.push(holland);
    }

    return assessments;
  }

  // ==================== 面试题转换 ====================

  /**
   * 转换面试题JSON为InterviewQuestion格式
   * Source: 原始面试题JSON格式
   *   rawData 结构示例（数组）:
   *   [
   *     {
   *       "id": "iq001",
   *       "category": "behavioral",
   *       "question": "请介绍一个你解决过的困难问题",
   *       "tips": "使用STAR法则回答",
   *       "difficulty": "medium",
   *       "referenceAnswer": "...",
   *       "starGuide": { "situation": "...", "task": "...", "action": "...", "result": "..." }
   *     }
   *   ]
   * Target: InterviewQuestion[]
   */
  convertInterviewQuestions(rawData: any): InterviewQuestion[] {
    try {
      if (!rawData) {
        return [];
      }

      // 兼容数组和对象格式
      const rawList: any[] = Array.isArray(rawData) ? rawData : (rawData.questions || rawData.data || []);

      const questions: InterviewQuestion[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const rq = rawList[i];
        const question: InterviewQuestion = {
          id: rq.id || `iq_${String(i).padStart(3, '0')}`,
          category: rq.category || rq.type || 'behavioral',
          question: rq.question || rq.text || rq.title || '',
          tips: rq.tips || rq.hint || undefined,
          difficulty: this.normalizeDifficulty(rq.difficulty || rq.level),
          referenceAnswer: rq.referenceAnswer || rq.answer || rq.reference_answer || undefined,
          starGuide: this.convertStarGuide(rq.starGuide || rq.star_guide || rq.star)
        };
        questions.push(question);
      }

      this.log(`面试题转换成功，共 ${questions.length} 道题目`);
      return questions;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`面试题转换失败: ${errMsg}`);
      return [];
    }
  }

  // ==================== 知识库转换 ====================

  /**
   * 转换知识库JSON为KnowledgeArticle格式
   * Source: 原始知识库JSON格式
   *   rawData 结构示例（数组）:
   *   [
   *     {
   *       "id": "ka001",
   *       "title": "面试前需要做哪些准备？",
   *       "category": "面试攻略",
   *       "summary": "面试前的准备工作至关重要...",
   *       "readCount": 1234,
   *       "updateTime": "2025-01-01",
   *       "coverImage": "https://..."
   *     }
   *   ]
   * Target: KnowledgeArticle[]
   */
  convertKnowledgeArticles(rawData: any): KnowledgeArticle[] {
    try {
      if (!rawData) {
        return [];
      }

      // 兼容数组和对象格式
      const rawList: any[] = Array.isArray(rawData) ? rawData : (rawData.articles || rawData.data || rawData.list || []);

      const articles: KnowledgeArticle[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const ra = rawList[i];
        const article: KnowledgeArticle = {
          id: ra.id || `ka_${String(i).padStart(3, '0')}`,
          title: ra.title || ra.name || '未命名文章',
          category: ra.category || ra.type || ra.tag || '未分类',
          summary: ra.summary || ra.description || ra.brief || '',
          readCount: typeof ra.readCount === 'number' ? ra.readCount :
            (typeof ra.read_count === 'number' ? ra.read_count :
              (typeof ra.views === 'number' ? ra.views : 0)),
          updateTime: ra.updateTime || ra.update_time || ra.publishTime || ra.publish_time || ra.date || '',
          coverImage: ra.coverImage || ra.cover_image || ra.cover || ra.image || undefined
        };
        articles.push(article);
      }

      this.log(`知识库文章转换成功，共 ${articles.length} 篇文章`);
      return articles;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`知识库文章转换失败: ${errMsg}`);
      return [];
    }
  }

  // ==================== v2 数据转换 ====================

  /**
   * 转换v2测评数据（4000题，9大类型）
   * v2结构: { assessments: [{ id, type, typeName, dimension, question, options: [{id, text, score}], difficulty, position, tags }] }
   * @param rawData v2测评原始JSON数据
   * @returns Assessment数组
   */
  convertAssessmentV2(rawData: any): Assessment[] {
    try {
      if (!rawData) {
        return [];
      }

      const rawList: any[] = Array.isArray(rawData) ? rawData : (rawData.assessments || rawData.data || []);

      if (rawList.length === 0) {
        this.log('v2测评数据为空');
        return [];
      }

      // 按 type 分组，每组生成一个 Assessment 对象
      const typeGroupMap: Map<string, any[]> = new Map();
      for (let i = 0; i < rawList.length; i++) {
        const item = rawList[i];
        const typeName = item.typeName || item.type || '未分类';
        if (!typeGroupMap.has(typeName)) {
          typeGroupMap.set(typeName, []);
        }
        typeGroupMap.get(typeName)!.push(item);
      }

      const assessments: Assessment[] = [];
      const typeIconMap: Map<string, string> = new Map();
      typeIconMap.set('职业性格测评', '🧠');
      typeIconMap.set('职业兴趣测评', '🎯');
      typeIconMap.set('职业价值观测评', '💎');
      typeIconMap.set('情商测评', '❤️');
      typeIconMap.set('领导力测评', '👑');
      typeIconMap.set('沟通能力测评', '💬');
      typeIconMap.set('团队协作测评', '🤝');
      typeIconMap.set('创新能力测评', '💡');
      typeIconMap.set('抗压能力测评', '💪');
      typeIconMap.set('面试准备度测评', '🎤');

      const typeCategoryMap: Map<string, string> = new Map();
      typeCategoryMap.set('职业性格测评', '性格测评');
      typeCategoryMap.set('职业兴趣测评', '兴趣测评');
      typeCategoryMap.set('职业价值观测评', '价值观测评');
      typeCategoryMap.set('情商测评', '情商测评');
      typeCategoryMap.set('领导力测评', '领导力测评');
      typeCategoryMap.set('沟通能力测评', '沟通测评');
      typeCategoryMap.set('团队协作测评', '团队测评');
      typeCategoryMap.set('创新能力测评', '创新测评');
      typeCategoryMap.set('抗压能力测评', '抗压测评');
      typeCategoryMap.set('面试准备度测评', '面试测评');

      const typeToAssessmentType: Map<string, AssessmentType> = new Map();
      typeToAssessmentType.set('职业性格测评', 'personality');
      typeToAssessmentType.set('职业兴趣测评', 'career');
      typeToAssessmentType.set('职业价值观测评', 'value');
      typeToAssessmentType.set('情商测评', 'eq');
      typeToAssessmentType.set('领导力测评', 'skill');
      typeToAssessmentType.set('沟通能力测评', 'skill');
      typeToAssessmentType.set('团队协作测评', 'skill');
      typeToAssessmentType.set('创新能力测评', 'skill');
      typeToAssessmentType.set('抗压能力测评', 'skill');
      typeToAssessmentType.set('面试准备度测评', 'interview_readiness');

      typeGroupMap.forEach((items: any[], typeName: string) => {
        // 收集维度
        const dimensionSet: Set<string> = new Set();
        for (let i = 0; i < items.length; i++) {
          const dim = items[i].dimension || '';
          if (dim.length > 0) {
            dimensionSet.add(dim);
          }
        }
        const dimensions: string[] = [];
        dimensionSet.forEach((d: string) => {
          dimensions.push(d);
        });

        // 转换问题
        const questions: Question[] = [];
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          const question = this.convertAssessmentV2Question(item, i);
          questions.push(question);
        }

        const firstItem = items[0];
        const assessmentType = typeToAssessmentType.get(typeName) || 'skill' as AssessmentType;

        const assessment: Assessment = {
          id: `assess_${firstItem.type || 'unknown'}`,
          title: typeName,
          description: firstItem.description || `${typeName}，共${questions.length}道题目`,
          type: assessmentType,
          icon: typeIconMap.get(typeName) || '📋',
          duration: Math.max(10, Math.ceil(questions.length / 5)),
          category: typeCategoryMap.get(typeName) || typeName,
          dimensions: dimensions,
          questions: questions,
          status: 'not_started'
        };
        assessments.push(assessment);
      });

      this.log(`v2测评数据转换成功，共 ${assessments.length} 个测评类型`);
      return assessments;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`v2测评数据转换失败: ${errMsg}`);
      return [];
    }
  }

  /**
   * 转换v2面试题数据（4000题，15岗位）
   * v2结构: { questions: [{ id, category, position, difficulty, question, tips, starGuide, referenceAnswer, tags, followUps }] }
   * @param rawData v2面试题原始JSON数据
   * @returns InterviewQuestion数组
   */
  convertInterviewQuestionsV2(rawData: any): InterviewQuestion[] {
    try {
      if (!rawData) {
        return [];
      }

      const rawList: any[] = Array.isArray(rawData) ? rawData : (rawData.questions || rawData.data || []);

      if (rawList.length === 0) {
        this.log('v2面试题数据为空');
        return [];
      }

      const questions: InterviewQuestion[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const rq = rawList[i];
        const question: InterviewQuestion = {
          id: rq.id || `iq_v2_${String(i).padStart(4, '0')}`,
          category: rq.category || rq.type || 'behavioral',
          question: rq.question || rq.text || rq.title || '',
          tips: rq.tips || rq.hint || undefined,
          difficulty: this.normalizeDifficulty(rq.difficulty || rq.level),
          referenceAnswer: rq.referenceAnswer || rq.answer || rq.reference_answer || undefined,
          starGuide: this.convertStarGuide(rq.starGuide || rq.star_guide || rq.star)
        };
        questions.push(question);
      }

      this.log(`v2面试题转换成功，共 ${questions.length} 道题目`);
      return questions;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`v2面试题转换失败: ${errMsg}`);
      return [];
    }
  }

  /**
   * 转换v2知识库数据（2000篇，43子分类）
   * v2结构: { articles: [{ id, category, subcategory, title, summary, author, readTime, difficulty, tags, content, position }] }
   * @param rawData v2知识库原始JSON数据
   * @returns KnowledgeArticle数组
   */
  convertKnowledgeArticlesV2(rawData: any): KnowledgeArticle[] {
    try {
      if (!rawData) {
        return [];
      }

      const rawList: any[] = Array.isArray(rawData) ? rawData : (rawData.articles || rawData.data || rawData.list || []);

      if (rawList.length === 0) {
        this.log('v2知识库数据为空');
        return [];
      }

      const articles: KnowledgeArticle[] = [];
      for (let i = 0; i < rawList.length; i++) {
        const ra = rawList[i];
        // v2的category使用子分类作为显示分类，更精确
        const displayCategory = ra.subcategory || ra.category || '未分类';
        const article: KnowledgeArticle = {
          id: ra.id || `ka_v2_${String(i).padStart(4, '0')}`,
          title: ra.title || ra.name || '未命名文章',
          category: displayCategory,
          summary: ra.summary || ra.description || ra.brief || '',
          readCount: typeof ra.readCount === 'number' ? ra.readCount :
            (typeof ra.read_count === 'number' ? ra.read_count :
              (typeof ra.views === 'number' ? ra.views : 0)),
          updateTime: ra.updateTime || ra.update_time || ra.publishTime || ra.publish_time || ra.date || '',
          coverImage: ra.coverImage || ra.cover_image || ra.cover || ra.image || undefined
        };
        articles.push(article);
      }

      this.log(`v2知识库文章转换成功，共 ${articles.length} 篇文章`);
      return articles;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      this.logError(`v2知识库文章转换失败: ${errMsg}`);
      return [];
    }
  }

  // ==================== 私有辅助方法 ====================

  /**
   * 转换v2单条测评题目
   * v2选项结构: { id, text, score: { "E": 1, "I": 2 } }
   */
  private convertAssessmentV2Question(item: any, index: number): Question {
    const rawOptions = item.options || item.option || [];

    const options: Option[] = [];
    for (let j = 0; j < rawOptions.length; j++) {
      const ro = rawOptions[j];
      const scoreObj = ro.score;
      let dimension: string | undefined = undefined;
      let score: number | undefined = undefined;

      if (typeof scoreObj === 'object' && scoreObj !== null) {
        // v2格式: score 是对象 { "E": 1, "I": 2 }
        let firstKey: string | undefined = undefined;
        for (const k in scoreObj) {
          firstKey = k;
          break;
        }
        if (firstKey !== undefined) {
          dimension = item.dimension || firstKey;
          score = typeof scoreObj[firstKey] === 'number' ? scoreObj[firstKey] : undefined;
        }
      } else if (typeof scoreObj === 'number') {
        score = scoreObj;
        dimension = item.dimension || undefined;
      }

      const option: Option = {
        id: ro.id || `opt_v2_${String(index).padStart(4, '0')}_${String(j).padStart(2, '0')}`,
        text: ro.text || ro.content || ro.label || '',
        score: score,
        dimension: dimension,
        direction: ro.direction !== undefined ? ro.direction : undefined
      };
      options.push(option);
    }

    return {
      id: item.id || `aq_v2_${String(index).padStart(4, '0')}`,
      type: 'single',
      title: item.question || item.text || item.title || '',
      options: options,
      required: true
    };
  }

  /**
   * 转换单个MBTI问题
   */
  private convertMBTIQuestion(rq: any, index: number): Question {
    const rawOptions = rq.options || rq.option || [];

    const options: Option[] = [];
    for (let j = 0; j < rawOptions.length; j++) {
      const ro = rawOptions[j];
      const scoreStr = ro.score || ro.dimension || '';
      const option: Option = {
        id: `opt_${String(index).padStart(3, '0')}_${String(j).padStart(2, '0')}`,
        text: ro.text || ro.content || ro.label || '',
        score: typeof ro.score === 'number' ? ro.score : undefined,
        dimension: scoreStr.length > 0 ? scoreStr.charAt(0).toUpperCase() : undefined,
        direction: ro.direction !== undefined ? ro.direction : undefined
      };
      options.push(option);
    }

    return {
      id: rq.id || `mq_${String(index).padStart(3, '0')}`,
      type: 'single',
      title: rq.title || rq.text || rq.question || '',
      options: options,
      required: true
    };
  }

  /**
   * 转换单个Holland问题
   */
  private convertHollandQuestion(rq: any, index: number): Question {
    const rawOptions = rq.options || rq.option || [];

    // Holland默认选项（是/否）
    let options: Option[] = [];
    if (rawOptions.length > 0) {
      for (let j = 0; j < rawOptions.length; j++) {
        const ro = rawOptions[j];
        const option: Option = {
          id: `opt_${String(index).padStart(3, '0')}_${String(j).padStart(2, '0')}`,
          text: ro.text || ro.content || ro.label || '',
          score: typeof ro.score === 'number' ? ro.score : undefined,
          dimension: rq.dimension || rq.type || undefined,
          direction: ro.direction !== undefined ? ro.direction : undefined
        };
        options.push(option);
      }
    } else {
      // 无选项时生成默认的是/否选项
      options = [
        {
          id: `opt_${String(index).padStart(3, '0')}_00`,
          text: '是',
          score: 1,
          dimension: rq.dimension || rq.type || undefined,
          direction: 1
        },
        {
          id: `opt_${String(index).padStart(3, '0')}_01`,
          text: '否',
          score: 0,
          dimension: rq.dimension || rq.type || undefined,
          direction: -1
        }
      ];
    }

    return {
      id: rq.id || `hq_${String(index).padStart(3, '0')}`,
      type: 'single',
      title: rq.text || rq.title || rq.question || '',
      options: options,
      required: true
    };
  }

  /**
   * 转换STAR法则引导数据
   */
  private convertStarGuide(raw: any): any {
    if (!raw || typeof raw !== 'object') {
      return undefined;
    }

    return {
      situation: raw.situation || '',
      task: raw.task || '',
      action: raw.action || '',
      result: raw.result || ''
    };
  }

  /**
   * 标准化难度值
   */
  private normalizeDifficulty(difficulty: string): 'easy' | 'medium' | 'hard' {
    if (!difficulty) {
      return 'medium';
    }
    const lower = difficulty.toLowerCase();
    if (lower === 'easy' || lower === '简单' || lower === '1' || lower === 'low') {
      return 'easy';
    }
    if (lower === 'hard' || lower === '困难' || lower === '3' || lower === 'high') {
      return 'hard';
    }
    return 'medium';
  }

  /**
   * 创建回退的空测评对象（转换失败时使用）
   */
  private createFallbackAssessment(id: string, title: string, type: AssessmentType): Assessment {
    return {
      id: id,
      title: title,
      description: '数据加载失败，请稍后重试',
      type: type,
      icon: '📋',
      duration: 0,
      category: '',
      dimensions: [],
      questions: [],
      status: 'not_started'
    };
  }

  // ==================== 日志方法 ====================

  private log(message: string): void {
    console.info(`[${TAG}] ${message}`);
  }

  private logError(message: string): void {
    console.error(`[${TAG}] ${message}`);
  }
}
