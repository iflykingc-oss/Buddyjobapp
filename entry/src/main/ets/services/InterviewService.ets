/**
 * InterviewService - 模拟面试服务
 *
 * 提供面试问题生成、回答提交、AI点评等功能
 * 支持语音录制和语音识别
 *
 * @example
 * const service = InterviewService.getInstance();
 * const session = await service.createInterviewSession({
 *   jobPosition: '前端工程师',
 *   questionCount: 5,
 *   categories: ['behavioral', 'technical'],
 *   difficulty: 'mixed'
 * });
 *
 * @since 1.0.0
 */
import { ApiService } from './ApiService';
import { HistoryService } from './HistoryService';
import { DataLoadService } from './DataLoadService';
import { DataConverter } from './DataConverter';
import {
  SpeechRecognitionService,
  SpeechRecognitionState,
  RecognitionResult
} from './SpeechRecognitionService';
import media from '@ohos.multimedia.media';
import fileIo from '@ohos.file.fs';
import hilog from '@ohos.hilog';

const TAG = 'InterviewService';
const DOMAIN = 0xFF00;

// 面试问题类型
export interface InterviewQuestion {
  id: string;
  category: string; // 'behavioral' | 'technical' | 'situational'
  question: string;
  tips?: string; // 回答提示
  starGuide?: StarGuide; // STAR法则引导
  referenceAnswer?: string; // 参考答案
  difficulty: 'easy' | 'medium' | 'hard';
}

// STAR法则引导
export interface StarGuide {
  situation: string; // 情境描述
  task: string; // 任务说明
  action: string; // 行动建议
  result: string; // 结果展示
}

// 用户回答
export interface InterviewAnswer {
  questionId: string;
  content: string; // 回答内容（文字或语音识别结果）
  audioPath?: string; // 录音文件路径
  duration?: number; // 回答时长（秒）
  timestamp: number;
}

// AI点评结果
export interface InterviewFeedback {
  questionId: string;
  strengths: string[]; // 优点
  improvements: string[]; // 改进点
  referenceAnswer: string; // 参考答案
  score: number; // 评分 0-100
  suggestions: string[]; // 建议
  starAnalysis?: StarAnalysis; // STAR分析
}

// STAR分析
export interface StarAnalysis {
  situation: { score: number; comment: string };
  task: { score: number; comment: string };
  action: { score: number; comment: string };
  result: { score: number; comment: string };
}

// 面试会话
export interface InterviewSession {
  id: string;
  jobPosition: string; // 目标岗位
  questions: InterviewQuestion[];
  answers: InterviewAnswer[];
  feedbacks: InterviewFeedback[];
  currentQuestionIndex: number;
  status: 'preparing' | 'in_progress' | 'completed';
  startTime?: number;
  endTime?: number;
  totalScore?: number;
}

// 面试配置
export interface InterviewConfig {
  jobPosition: string;
  questionCount: number;
  categories: string[];
  difficulty: 'easy' | 'medium' | 'hard' | 'mixed';
}

export class InterviewService {
  private static instance: InterviewService;
  private apiService: ApiService = ApiService.getInstance();
  private historyService: HistoryService = HistoryService.getInstance();
  private dataLoadService: DataLoadService = DataLoadService.getInstance();
  private dataConverter: DataConverter = DataConverter.getInstance();

  // 语音识别服务
  private speechService: SpeechRecognitionService = SpeechRecognitionService.getInstance();

  // 从 rawfile 加载的面试题
  private loadedQuestions: InterviewQuestion[] = [];

  // 录音相关
  private isRecording: boolean = false;
  private recordingStartTime: number = 0;
  private audioFilePath: string = '';
  private avRecorder: media.AVRecorder | null = null;
  private audioFd: number = -1;

  // 语音识别回调
  private onRecognitionResultCallback?: (text: string, confidence: number) => void;
  private onRecognitionErrorCallback?: (error: string) => void;
  private onRecognitionStateChangeCallback?: (state: SpeechRecognitionState) => void;

  private constructor() {}

  static getInstance(): InterviewService {
    if (!InterviewService.instance) {
      InterviewService.instance = new InterviewService();
    }
    return InterviewService.instance;
  }

  /**
   * 初始化数据加载服务，从 rawfile JSON 文件加载面试题数据
   * 加载失败时静默回退到内置默认数据，不影响应用正常运行
   * @param context 应用上下文
   */
  async initialize(context: Context): Promise<void> {
    try {
      await this.dataLoadService.initialize(context);
      hilog.info(DOMAIN, TAG, 'DataLoadService 初始化成功');

      // 优先加载 v2 面试题数据（4000题，15岗位）
      let v2Loaded = false;
      try {
        const v2Data = await this.dataLoadService.loadLocalJson<Object>('data/interview_questions_v2.json');
        if (v2Data !== null && (v2Data as Record<string, Object>)['questions'] && ((v2Data as Record<string, Object>)['questions'] as Object[]).length > 0) {
          this.loadedQuestions = this.dataConverter.convertInterviewQuestionsV2(v2Data);
          if (this.loadedQuestions.length > 0) {
            v2Loaded = true;
            hilog.info(DOMAIN, TAG, `v2面试题数据加载成功，共 ${this.loadedQuestions.length} 道题目`);
          }
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, `v2面试题数据加载失败，回退到v1: ${error}`);
      }

      // v1 回退：加载旧版面试题数据
      if (!v2Loaded) {
        try {
          const rawData = await this.dataLoadService.loadLocalJson<Object>('data/interview_questions.json');
          if (rawData !== null) {
            this.loadedQuestions = this.dataConverter.convertInterviewQuestions(rawData);
            hilog.info(DOMAIN, TAG, `面试题数据加载成功（v1回退），共 ${this.loadedQuestions.length} 道题目`);
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, `面试题数据加载失败，将使用默认数据: ${error}`);
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `初始化失败，将使用内置默认数据: ${error}`);
    }
  }

  /**
   * 设置语音识别回调
   */
  setSpeechRecognitionCallbacks(
    onResult?: (text: string, confidence: number) => void,
    onError?: (error: string) => void,
    onStateChange?: (state: SpeechRecognitionState) => void
  ): void {
    this.onRecognitionResultCallback = onResult;
    this.onRecognitionErrorCallback = onError;
    this.onRecognitionStateChangeCallback = onStateChange;
  }

  /**
   * 初始化语音识别服务
   * @returns 初始化是否成功
   * @throws 初始化失败时可能抛出异常
   */
  async initializeSpeechRecognition(): Promise<boolean> {
    try {
      const success = await this.speechService.initialize();
      if (success) {
        hilog.info(DOMAIN, TAG, 'Speech recognition initialized');

        // 设置回调
        this.speechService.onResult = (result: RecognitionResult) => {
          hilog.info(DOMAIN, TAG, `Recognition result: ${result.text}, isFinal: ${result.isFinal}`);
          this.onRecognitionResultCallback?.(result.text, result.confidence);
        };

        this.speechService.onError = (error: RecognitionResult) => {
          hilog.error(DOMAIN, TAG, `Recognition error: ${error.errorMessage}`);
          this.onRecognitionErrorCallback?.(error.errorMessage || '识别错误');
        };

        this.speechService.onStateChange = (state: SpeechRecognitionState) => {
          hilog.info(DOMAIN, TAG, `Recognition state changed: ${state}`);
          this.onRecognitionStateChangeCallback?.(state);
        };
      }
      return success;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize speech recognition failed: ${error}`);
      return false;
    }
  }

  /**
   * 检查语音识别是否可用
   */
  async isSpeechRecognitionAvailable(): Promise<boolean> {
    return await this.speechService.isAvailable();
  }

  /**
   * 设置识别语言
   * @param language 语言代码，如 'zh-CN'、'en-US'
   */
  setRecognitionLanguage(language: string): void {
    this.speechService.setLanguage(language);
  }

  /**
   * 创建面试会话
   * @param config 面试配置，包含岗位、题目数量、分类、难度等
   * @returns 面试会话对象，包含生成的题目列表
   * @throws API请求失败时使用本地默认数据创建会话
   */
  async createInterviewSession(config: InterviewConfig): Promise<InterviewSession> {
    try {
      const response = await this.apiService.post<InterviewSession>('/interview/create', config);
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Create session failed:', error);
    }

    // 使用默认数据
    return this.generateDefaultSession(config);
  }

  /**
   * 生成默认面试会话
   */
  private generateDefaultSession(config: InterviewConfig): InterviewSession {
    let questions: InterviewQuestion[];

    // 优先使用 rawfile 加载的面试题
    if (this.loadedQuestions.length > 0) {
      let filtered = this.loadedQuestions;
      if (config.categories.length > 0) {
        filtered = filtered.filter(q => config.categories.includes(q.category));
      }
      if (config.difficulty !== 'mixed') {
        filtered = filtered.filter(q => q.difficulty === config.difficulty);
      }
      const shuffled = filtered.sort(() => Math.random() - 0.5);
      questions = shuffled.slice(0, config.questionCount);
    } else {
      questions = this.generateQuestions(config);
    }

    return {
      id: Date.now().toString(),
      jobPosition: config.jobPosition,
      questions: questions,
      answers: [],
      feedbacks: [],
      currentQuestionIndex: 0,
      status: 'preparing'
    };
  }

  /**
   * 生成面试问题（完整题库：5大类60+题）
   */
  private generateQuestions(config: InterviewConfig): InterviewQuestion[] {
    const allQuestions: InterviewQuestion[] = [
      // ==================== 1. 自我介绍类 (8题) - 难度: 简单 ====================
      {
        id: 'self_1', category: 'self_intro', question: '请做一下自我介绍。',
        tips: '控制在2分钟内，突出与岗位相关的核心优势和亮点。',
        starGuide: { situation: '简要说明你的教育背景和工作经历', task: '说明你为什么适合这个岗位', action: '用1-2个关键成就来支撑你的能力', result: '表达你对这个机会的热情和期待' },
        referenceAnswer: '您好，我叫XX，有X年XX领域的工作经验。在上一家公司，我主要负责XX，期间主导了XX项目，实现了XX%的业务增长。我擅长XX和XX，与贵公司的岗位需求非常匹配。我对贵公司的XX方向非常感兴趣，希望能有机会为团队做出贡献。',
        difficulty: 'easy'
      },
      {
        id: 'self_2', category: 'self_intro', question: '用3个词形容你自己，并说明原因。',
        tips: '选择与岗位需求相关的特质，每个词配一个简短的事例。',
        starGuide: { situation: '说明选择这3个词的考量', task: '每个词对应一个具体场景', action: '用事例证明这些特质', result: '总结这些特质如何帮助你胜任工作' },
        referenceAnswer: '我会用"结果导向"、"持续学习"和"团队协作"来形容自己。结果导向体现在我每次接手项目都会先明确目标和衡量标准；持续学习表现在我利用业余时间考取了XX认证；团队协作方面，我在跨部门项目中主动担任协调角色，推动了项目顺利交付。',
        difficulty: 'easy'
      },
      {
        id: 'self_3', category: 'self_intro', question: '你最大的优点和缺点是什么？',
        tips: '优点要具体且有证据，缺点要真诚且有改进计划。避免说"太追求完美"这类套路。',
        starGuide: { situation: '客观分析自己的优势和不足', task: '选择与岗位相关的优点和可控的缺点', action: '用事例说明优点，用改进计划说明缺点', result: '展示自我认知的深度和成长意愿' },
        referenceAnswer: '我最大的优点是快速学习能力，比如在上一份工作中，我用两周时间掌握了新技术并成功应用到项目中。我的缺点是有时候过于关注细节，导致时间分配不够合理。为此我开始使用时间管理工具，设定每个任务的时限，目前已经有明显改善。',
        difficulty: 'easy'
      },
      {
        id: 'self_4', category: 'self_intro', question: '你为什么想来我们公司？',
        tips: '展示你对公司的深入了解，将个人发展与公司方向结合。',
        starGuide: { situation: '说明你了解公司的渠道和深度', task: '找到个人目标与公司方向的契合点', action: '具体说明你能为公司带来的价值', result: '表达长期发展的意愿' },
        referenceAnswer: '我关注贵公司已经有一段时间了，特别欣赏贵公司在XX领域的创新。我了解到贵公司最近推出了XX产品，这与我的专业背景和职业发展方向高度契合。我相信我的XX经验可以为团队带来价值，同时也希望在这个平台上实现个人的成长。',
        difficulty: 'easy'
      },
      {
        id: 'self_5', category: 'self_intro', question: '你的职业规划是什么？',
        tips: '展示清晰的职业目标，同时体现与公司发展的结合。',
        starGuide: { situation: '说明你的长期职业愿景', task: '分解为短期和中期的具体目标', action: '说明你正在采取的行动', result: '展示这个规划与应聘岗位的关联' },
        referenceAnswer: '短期1-2年内，我希望在XX领域深耕，成为团队中的核心骨干。中期3-5年，我期望能带领一个小团队，在XX方向做出有影响力的成果。长期来看，我希望成为XX领域的专家。这个岗位恰好能提供我需要的成长平台和实践机会。',
        difficulty: 'easy'
      },
      {
        id: 'self_6', category: 'self_intro', question: '你从上一份工作中学到了什么？',
        tips: '聚焦于可迁移的能力和经验，避免抱怨前公司。',
        starGuide: { situation: '简要说明上一份工作的核心内容', task: '提炼出最有价值的成长和收获', action: '说明这些收获如何应用到新岗位', result: '展示你的反思能力和成长型思维' },
        referenceAnswer: '上一份工作让我在三个方面有了显著成长：一是XX能力，通过XX项目积累了丰富的实战经验；二是跨部门协作能力，学会了如何与不同背景的人有效沟通；三是项目管理能力，从0到1推动了XX项目的落地。这些经验让我更有信心胜任贵公司的这个岗位。',
        difficulty: 'easy'
      },
      {
        id: 'self_7', category: 'self_intro', question: '你如何看待加班？',
        tips: '展现专业态度，既不盲目迎合也不直接拒绝，强调效率和结果导向。',
        starGuide: { situation: '说明你对工作效率的重视', task: '区分必要加班和非必要加班', action: '展示你提高效率的方法', result: '表达对项目的责任心和灵活性' },
        referenceAnswer: '我认为加班应该是阶段性、有目的的，而不是常态。我更注重在规定时间内高效完成任务，通过合理的时间管理和优先级排序来减少不必要的加班。当然，遇到项目关键节点或紧急情况，我完全愿意投入额外时间确保交付质量。',
        difficulty: 'easy'
      },
      {
        id: 'self_8', category: 'self_intro', question: '你有什么想问我们的？',
        tips: '准备3-5个高质量问题，展示你对岗位的兴趣和思考深度。',
        starGuide: { situation: '基于前期调研准备问题', task: '问出能展示你专业度的问题', action: '围绕团队、文化、发展等维度提问', result: '通过提问进一步了解岗位是否匹配' },
        referenceAnswer: '我有三个问题想了解：第一，这个岗位目前面临的最大挑战是什么？第二，团队目前的规模和分工是怎样的？第三，公司对这个岗位在第一年的期望是什么？这些问题能帮我更好地了解岗位需求，也能判断我是否能很好地胜任。',
        difficulty: 'easy'
      },

      // ==================== 2. 行为面试类 (STAR) (15题) - 难度: 中等 ====================
      {
        id: 'b1', category: 'behavioral', question: '请讲一个你解决困难问题的经历。',
        tips: '重点展示你的分析思路和解决过程，突出你的个人贡献。',
        starGuide: { situation: '描述问题的背景和复杂程度', task: '说明你在解决问题中的角色和责任', action: '详细描述你采取的分析和解决步骤', result: '展示解决方案的效果和你的收获' },
        referenceAnswer: '在XX项目中，我们遇到了一个严重的性能瓶颈，系统响应时间从200ms飙升至3秒。我首先通过性能分析工具定位到是数据库查询的问题，然后设计了分库分表方案，并引入了缓存层。经过两周的改造，系统响应时间恢复到150ms，比优化前还提升了25%。',
        difficulty: 'medium'
      },
      {
        id: 'b2', category: 'behavioral', question: '描述一次你与团队成员意见不合的经历。',
        tips: '展示你的沟通技巧和求同存异的能力，不要把对方描述成"错的"。',
        starGuide: { situation: '客观描述分歧的背景和双方的观点', task: '说明你在达成共识中的努力', action: '描述你如何倾听、沟通和寻找折中方案', result: '展示最终的结果和双方的关系变化' },
        referenceAnswer: '在XX项目中，我和同事对技术选型有不同意见。我主张用方案A，他倾向于方案B。我没有直接否定他，而是提议双方各做一个原型进行对比。通过一周的验证，方案A在性能上更优，但方案B在开发效率上更好。最终我们融合了两个方案的优点，取得了很好的效果。',
        difficulty: 'medium'
      },
      {
        id: 'b3', category: 'behavioral', question: '讲一个你带领团队完成目标的经历。',
        tips: '展示你的领导力和团队管理能力，突出目标设定和过程管理。',
        starGuide: { situation: '描述团队面临的挑战和目标', task: '说明你如何设定方向和分配任务', action: '描述你如何激励团队和解决过程中的问题', result: '展示最终成果和团队的成长' },
        referenceAnswer: '去年Q4，我带领5人团队负责XX产品的改版项目，时间紧任务重。我将大目标拆解为每周的里程碑，每天进行15分钟站会同步进度。当团队遇到技术难点时，我协调了资深同事进行指导。最终项目按时上线，用户满意度提升了20%，团队成员也在过程中得到了成长。',
        difficulty: 'medium'
      },
      {
        id: 'b4', category: 'behavioral', question: '描述一次你失败的经历，你从中学到了什么？',
        tips: '选择一个真实的失败经历，重点放在反思和成长上，展示你的韧性。',
        starGuide: { situation: '如实描述失败的场景和原因', task: '分析失败的根本原因', action: '说明你从失败中学到了什么并如何改进', result: '展示你在后续工作中如何避免类似问题' },
        referenceAnswer: '在负责XX项目时，由于我对需求理解不够深入，导致开发到一半才发现方向偏差，最终项目延期了两周。这次失败让我深刻认识到需求确认的重要性。之后我建立了一套需求评审流程，在每个项目启动前都与产品和客户进行充分沟通，再也没有发生过类似问题。',
        difficulty: 'medium'
      },
      {
        id: 'b5', category: 'behavioral', question: '讲一个你主动承担额外责任的经历。',
        tips: '展示你的主动性和责任心，以及你如何平衡额外任务与日常工作。',
        starGuide: { situation: '描述发现需要承担额外责任的场景', task: '说明你为什么选择主动承担', action: '描述你如何规划和执行', result: '展示你的成果和对团队的影响' },
        referenceAnswer: '在一次项目中，原定的测试负责人突然离职，项目面临无人测试的困境。虽然我的主要职责是开发，但我主动请缨承担了测试工作。我利用下班时间学习自动化测试工具，编写了测试用例，并在不影响开发进度的前提下完成了测试任务。最终产品质量得到了保障，我也因此掌握了测试技能。',
        difficulty: 'medium'
      },
      {
        id: 'b6', category: 'behavioral', question: '描述一次你创新解决问题的经历。',
        tips: '展示你的创造力和实践能力，说明创新带来的实际价值。',
        starGuide: { situation: '描述面临的问题和常规解决方案的局限', task: '说明你的创新思路来源', action: '描述创新方案的设计和实施过程', result: '展示创新方案的效果和可推广性' },
        referenceAnswer: '团队每月的数据报表生成需要耗费2天时间，人工操作容易出错。我利用周末时间开发了一个自动化报表工具，通过连接数据库自动生成可视化报表。这个工具将报表生成时间缩短到10分钟，准确率提升到100%，后来被其他团队也采纳使用。',
        difficulty: 'medium'
      },
      {
        id: 'b7', category: 'behavioral', question: '讲一个你处理客户投诉的经历。',
        tips: '展示你的客户服务意识和问题解决能力，体现同理心和专业度。',
        starGuide: { situation: '描述客户投诉的内容和严重程度', task: '说明你处理投诉的思路和优先级', action: '描述你如何安抚客户并解决问题', result: '展示处理结果和客户关系的改善' },
        referenceAnswer: '一位重要客户对我们产品的XX功能非常不满，威胁要解约。我第一时间联系客户，认真倾听了他的诉求，并承诺在48小时内给出解决方案。我协调了产品和研发团队，快速推出了一个临时方案，并在一周内完成了正式修复。客户对我们的响应速度非常满意，不仅续约还增加了合作。',
        difficulty: 'medium'
      },
      {
        id: 'b8', category: 'behavioral', question: '描述一次你在压力下完成任务的经过。',
        tips: '展示你的抗压能力和时间管理技巧，突出在压力下的决策质量。',
        starGuide: { situation: '描述压力的来源和强度', task: '说明任务的关键要求和约束条件', action: '描述你如何分解任务、管理时间和保持效率', result: '展示任务成果和个人成长' },
        referenceAnswer: '公司年度大会前一周，演讲系统突然出现严重bug。作为主要负责人，我承受着巨大的压力。我冷静分析了问题，将修复工作分为3个优先级，先解决影响最大的核心问题。同时协调了2名同事支援，连续3天工作到凌晨。最终系统在大会前2小时修复完毕，大会顺利进行。',
        difficulty: 'medium'
      },
      {
        id: 'b9', category: 'behavioral', question: '讲一个你帮助同事成长的经历。',
        tips: '展示你的团队精神和领导潜质，说明你如何因材施教。',
        starGuide: { situation: '描述同事遇到的困难或成长需求', task: '说明你为什么决定帮助以及如何帮助', action: '描述具体的帮助方式和过程', result: '展示同事的成长和你们的合作关系变化' },
        referenceAnswer: '团队新来一位应届生，对业务不熟悉，工作效率较低。我主动提出做他的导师，制定了为期一个月的培训计划。每天花30分钟进行一对一答疑，并让他参与实际项目边做边学。一个月后，他已经能独立完成常规任务，半年后成为了团队的核心成员。',
        difficulty: 'medium'
      },
      {
        id: 'b10', category: 'behavioral', question: '描述一次你推动变革的经历。',
        tips: '展示你的变革管理能力和影响力，说明如何克服阻力。',
        starGuide: { situation: '描述需要变革的原因和现状', task: '说明你的变革方案和预期效果', action: '描述你如何说服利益相关者和推进实施', result: '展示变革的成果和经验总结' },
        referenceAnswer: '我发现团队的代码审查流程效率很低，每次审查平均需要3天。我提出了改进方案：引入自动化审查工具+分批审查机制。起初部分同事有抵触情绪，我通过一次试点项目展示了新流程的效率提升（审查时间缩短到1天），最终说服了全团队采纳。半年后，代码质量提升了30%。',
        difficulty: 'medium'
      },
      {
        id: 'b11', category: 'behavioral', question: '讲一个你跨部门协作的经历。',
        tips: '展示你的沟通协调能力和大局观，突出解决跨部门问题的方法。',
        starGuide: { situation: '描述跨部门协作的背景和挑战', task: '说明你在协作中的角色和目标', action: '描述你如何建立沟通机制和解决冲突', result: '展示协作成果和对后续工作的影响' },
        referenceAnswer: 'XX项目需要协调产品、开发、设计和市场4个部门。我主动担任了项目协调人，建立了每周一次的跨部门同步会议，并创建了共享项目看板。当设计和开发出现分歧时，我组织了一次设计评审会，让双方充分沟通。最终项目在3个月内顺利上线，各部门对协作效率都很满意。',
        difficulty: 'medium'
      },
      {
        id: 'b12', category: 'behavioral', question: '描述一次你做出艰难决定的经历。',
        tips: '展示你的决策能力和担当精神，说明决策的思考过程。',
        starGuide: { situation: '描述面临的困境和各方的利益冲突', task: '说明你的决策标准和优先级', action: '描述决策过程和如何应对不同意见', result: '评估决策的结果和反思' },
        referenceAnswer: '在XX项目中，测试发现了一个严重bug，修复需要延期一周，但不修复可能影响用户体验。经过权衡，我决定先上线核心功能，将bug修复安排在下一个迭代中优先处理。虽然这个决定有风险，但通过充分的用户沟通和快速跟进修复，最终用户反馈良好。',
        difficulty: 'medium'
      },
      {
        id: 'b13', category: 'behavioral', question: '讲一个你快速学习新技能的经历。',
        tips: '展示你的学习方法和效率，强调学以致用的能力。',
        starGuide: { situation: '说明学习新技能的背景和紧迫性', task: '描述学习目标和时间约束', action: '详细说明你的学习方法和实践过程', result: '展示学习成果和在实际工作中的应用' },
        referenceAnswer: '公司决定将数据分析工具从Excel迁移到Python，我之前没有Python基础。我利用每天下班后的2小时学习，通过在线课程+实战练习的方式，两周内掌握了Pandas和Matplotlib。随后我主动将团队的3个分析报告迁移到Python，效率提升了5倍。',
        difficulty: 'medium'
      },
      {
        id: 'b14', category: 'behavioral', question: '描述一次你处理多任务的经历。',
        tips: '展示你的优先级管理能力和时间管理技巧。',
        starGuide: { situation: '描述同时面临的多个任务和各自的紧迫性', task: '说明你的优先级判断标准', action: '描述你如何分配时间和切换任务', result: '展示所有任务的完成情况和质量' },
        referenceAnswer: '上个月我同时负责3个项目：A项目处于开发阶段，B项目需要紧急修复线上问题，C项目需要准备方案评审。我使用四象限法则进行分类：B项目最紧急优先处理，A项目每天固定时间推进，C项目利用碎片时间准备。最终3个项目都按时完成，质量也得到了保证。',
        difficulty: 'medium'
      },
      {
        id: 'b15', category: 'behavioral', question: '讲一个你获得意外成功的经历。',
        tips: '展示你的洞察力和执行力，说明成功背后的思考和努力。',
        starGuide: { situation: '描述看似普通的事情如何发展成意外成功', task: '说明你在这个过程中做了什么不同寻常的事', action: '描述你的思考和行动', result: '展示成功的结果和你的反思' },
        referenceAnswer: '我注意到用户反馈中反复提到一个"小问题"，虽然优先级不高，但我决定利用周末时间研究一下。结果发现这个问题的根因涉及一个架构层面的缺陷，修复后不仅解决了用户反馈的问题，还提升了系统整体稳定性。这个经历让我明白，用户的反馈中往往隐藏着重要的改进机会。',
        difficulty: 'medium'
      },

      // ==================== 3. 技术/专业面试类 (15题) - 难度: 困难 ====================
      {
        id: 't1', category: 'technical', question: '你如何评估一个项目的技术方案？',
        tips: '展示你的技术判断力和系统思维，从多个维度进行评估。',
        starGuide: { situation: '说明评估的背景和约束条件', task: '列出你的评估维度和标准', action: '描述具体的评估方法和工具', result: '给出评估结论和决策建议' },
        referenceAnswer: '我会从5个维度评估技术方案：可行性（技术是否成熟）、可扩展性（能否支撑业务增长）、性能（是否满足性能要求）、安全性（是否存在安全风险）、成本（开发和维护成本）。通常我会制作一个评估矩阵，对每个维度打分，然后综合权衡做出决策。',
        difficulty: 'hard'
      },
      {
        id: 't2', category: 'technical', question: '描述你解决过的最复杂的技术问题。',
        tips: '选择一个真正有技术深度的问题，展示你的分析和解决能力。',
        starGuide: { situation: '描述问题的复杂性和影响范围', task: '说明你的分析思路和排查过程', action: '详细描述解决方案的设计和实施', result: '展示解决方案的效果和可复用性' },
        referenceAnswer: '我遇到过一个分布式系统中的数据一致性问题：在高峰期，部分用户的数据出现不一致。经过深入分析，发现是分布式事务的时序问题。我设计了一套基于消息队列的最终一致性方案，引入了补偿机制和重试策略。方案上线后，数据一致性从99.5%提升到99.99%。',
        difficulty: 'hard'
      },
      {
        id: 't3', category: 'technical', question: '你如何保证代码质量？',
        tips: '从编码规范、测试、审查等多个层面说明你的质量保障体系。',
        starGuide: { situation: '说明代码质量对项目的重要性', task: '描述你的质量保障体系', action: '列举具体的措施和工具', result: '展示质量改进的数据和效果' },
        referenceAnswer: '我建立了三层质量保障体系：第一层是编码阶段，遵循SOLID原则和团队编码规范，使用ESLint进行静态检查；第二层是测试阶段，要求核心逻辑的单元测试覆盖率达到80%以上；第三层是审查阶段，所有代码必须经过至少一位同事的Review。通过这套体系，团队的线上bug率降低了60%。',
        difficulty: 'hard'
      },
      {
        id: 't4', category: 'technical', question: '你如何进行技术选型？',
        tips: '展示你的技术视野和决策能力，强调选型的系统方法。',
        starGuide: { situation: '描述技术选型的背景和需求', task: '说明你的选型标准和评估方法', action: '描述候选方案的对比过程', result: '给出最终选择和理由' },
        referenceAnswer: '技术选型我会遵循"需求驱动"原则。首先明确业务需求和技术约束，然后列出候选方案，从性能、生态、学习曲线、社区活跃度、团队熟悉度等维度进行对比评估。通常我会做一个小的POC（概念验证）来验证关键假设，最后基于数据和团队实际情况做出决策。',
        difficulty: 'hard'
      },
      {
        id: 't5', category: 'technical', question: '描述你做过的性能优化。',
        tips: '展示你的性能分析能力和优化策略，用数据说话。',
        starGuide: { situation: '描述性能问题的表现和影响', task: '说明你的性能分析方法和工具', action: '描述优化方案的设计和实施步骤', result: '展示优化前后的对比数据' },
        referenceAnswer: '我们的首页加载时间一度达到5秒，严重影响用户体验。我通过Chrome DevTools和Lighthouse进行分析，发现主要瓶颈在3个方面：图片未压缩、JS bundle过大、接口串行请求。我实施了图片懒加载和WebP格式转换、代码分割和Tree Shaking、接口并行请求。优化后首页加载时间降至1.2秒。',
        difficulty: 'hard'
      },
      {
        id: 't6', category: 'technical', question: '你如何设计一个高可用系统？',
        tips: '展示你的架构设计能力和对高可用模式的理解。',
        starGuide: { situation: '描述系统的可用性需求和约束', task: '说明你的架构设计原则', action: '描述关键的高可用策略和实现', result: '评估系统的可用性指标' },
        referenceAnswer: '设计高可用系统，我会从几个关键策略入手：冗余设计（多副本、多机房部署）、故障隔离（熔断、限流、降级）、自动恢复（健康检查、自动重启）、数据备份（主从复制、定期备份）。目标是实现99.99%的可用性，即全年宕机时间不超过52分钟。',
        difficulty: 'hard'
      },
      {
        id: 't7', category: 'technical', question: '你如何处理线上故障？',
        tips: '展示你的应急处理能力和事后复盘习惯，强调流程化应对。',
        starGuide: { situation: '描述故障的严重程度和影响范围', task: '说明你的应急响应流程', action: '描述排查、修复和恢复的步骤', result: '展示故障处理结果和后续改进措施' },
        referenceAnswer: '处理线上故障我遵循"快速恢复优先"原则。首先评估影响范围并通知相关方，然后快速定位问题（通过日志、监控、链路追踪），如果是新代码导致的问题，优先回滚恢复服务。故障解决后，我会组织复盘会议，分析根因，制定改进措施并落实到代码和流程中，防止同类问题再次发生。',
        difficulty: 'hard'
      },
      {
        id: 't8', category: 'technical', question: '描述你的系统架构设计经验。',
        tips: '选择一个你主导或深度参与的架构设计项目，展示全局视野。',
        starGuide: { situation: '描述业务场景和架构需求', task: '说明你的架构设计思路和原则', action: '描述架构的关键组件和交互方式', result: '评估架构的效果和演进方向' },
        referenceAnswer: '我主导设计了公司的订单系统架构。采用微服务架构，将订单服务拆分为创建、支付、物流、售后4个子服务，通过消息队列实现异步通信。引入了分库分表策略应对数据增长，使用Redis缓存热点数据。系统上线后支撑了日均100万订单的处理能力，且具备良好的水平扩展能力。',
        difficulty: 'hard'
      },
      {
        id: 't9', category: 'technical', question: '你如何进行代码审查？',
        tips: '展示你对代码质量的重视和审查方法论，强调建设性反馈。',
        starGuide: { situation: '说明代码审查在团队中的重要性', task: '描述你的审查标准和关注点', action: '说明你如何给出建设性的反馈', result: '展示代码审查对团队质量的提升效果' },
        referenceAnswer: '代码审查我关注4个层面：正确性（逻辑是否正确）、可读性（是否易于理解）、可维护性（是否方便后续修改）、性能（是否存在性能问题）。我会先理解代码的意图，然后从这4个角度提出具体的改进建议，同时也会指出代码中的亮点。我坚持"对事不对人"的原则，确保审查过程是建设性的。',
        difficulty: 'hard'
      },
      {
        id: 't10', category: 'technical', question: '你如何管理技术债务？',
        tips: '展示你的技术管理能力和平衡短期交付与长期质量的能力。',
        starGuide: { situation: '描述技术债务产生的原因和现状', task: '说明你的技术债务管理策略', action: '描述你如何分类、排优先级和逐步偿还', result: '展示技术债务管理的成效' },
        referenceAnswer: '我会将技术债务分为4类：架构债务、代码债务、测试债务、文档债务。每个迭代预留15%-20%的时间用于偿还技术债务。对于影响开发效率的高优先级债务，我会制定专项计划集中处理。同时建立技术债务看板，定期评审和更新，确保团队对技术债务有清晰的认知。',
        difficulty: 'hard'
      },
      {
        id: 't11', category: 'technical', question: '描述你的自动化测试经验。',
        tips: '展示你的测试金字塔理解和自动化测试实践能力。',
        starGuide: { situation: '说明项目中的测试需求和挑战', task: '描述你的自动化测试策略', action: '列举测试框架、工具和具体实践', result: '展示自动化测试的覆盖率和效果' },
        referenceAnswer: '我推行了测试金字塔策略：底层是单元测试，覆盖核心业务逻辑，使用JUnit/Mockito；中间是集成测试，验证模块间交互，使用TestContainers；顶层是端到端测试，验证关键用户流程，使用Selenium。通过CI/CD集成，每次提交自动运行测试套件。目前单元测试覆盖率达到85%，集成测试覆盖核心场景的90%。',
        difficulty: 'hard'
      },
      {
        id: 't12', category: 'technical', question: '你如何做技术方案评审？',
        tips: '展示你的技术沟通能力和方案评审经验。',
        starGuide: { situation: '描述技术方案评审的背景和目标', task: '说明你的评审流程和标准', action: '描述你如何组织评审会议和收集反馈', result: '展示评审对方案质量的提升' },
        referenceAnswer: '技术方案评审我分为3个阶段：评审前，要求方案提交者提前2天发送文档，参会者提前阅读并准备问题；评审中，先由提交者讲解方案（15分钟），然后围绕架构合理性、边界条件、风险点进行讨论（30分钟）；评审后，整理评审意见并跟踪改进。这个流程确保了评审的高效性和建设性。',
        difficulty: 'hard'
      },
      {
        id: 't13', category: 'technical', question: '你如何处理安全漏洞？',
        tips: '展示你的安全意识和应急处理能力。',
        starGuide: { situation: '描述安全漏洞的类型和严重程度', task: '说明你的应急响应流程', action: '描述修复方案和安全加固措施', result: '展示处理结果和安全改进' },
        referenceAnswer: '发现安全漏洞后，我首先评估漏洞等级和影响范围，高危漏洞立即启动应急响应。修复流程包括：临时缓解措施（如关闭相关功能）、根因分析和永久修复、安全扫描验证。修复后进行安全复盘，完善安全开发规范，并引入SAST/DAST工具到CI流程中，实现安全左移。',
        difficulty: 'hard'
      },
      {
        id: 't14', category: 'technical', question: '描述你的CI/CD实践经验。',
        tips: '展示你的DevOps实践能力和工具链经验。',
        starGuide: { situation: '描述团队的CI/CD需求和现状', task: '说明你的CI/CD架构和工具选择', action: '描述流水线的设计和优化过程', result: '展示CI/CD的效率和可靠性指标' },
        referenceAnswer: '我为团队搭建了完整的CI/CD流水线：代码提交后自动触发构建和单元测试，通过后执行集成测试和代码质量扫描，最后自动部署到预发环境。使用Jenkins+Docker+K8s技术栈，实现了从代码提交到部署的全程自动化。部署频率从每月1次提升到每天多次，部署回滚时间从30分钟缩短到2分钟。',
        difficulty: 'hard'
      },
      {
        id: 't15', category: 'technical', question: '你如何做容量规划？',
        tips: '展示你的系统规划和资源管理能力。',
        starGuide: { situation: '描述业务增长趋势和系统现状', task: '说明你的容量评估方法和模型', action: '描述容量规划和资源调配方案', result: '展示规划执行的效果和调整策略' },
        referenceAnswer: '容量规划我遵循"预测-监控-调整"的循环。首先基于历史数据和业务增长预测未来3-6个月的资源需求，然后设定70%的利用率告警阈值。通过Prometheus+Grafana进行实时监控，定期进行压测验证容量。当利用率接近阈值时，提前进行扩容。过去一年，我们成功支撑了3倍的业务增长而没有出现容量问题。',
        difficulty: 'hard'
      },

      // ==================== 4. 情景面试类 (12题) - 难度: 中等 ====================
      {
        id: 's1', category: 'situational', question: '如果项目截止日期提前，你会怎么做？',
        tips: '展示你的应变能力和资源协调能力，强调沟通和优先级管理。',
        starGuide: { situation: '评估时间缩短的影响和可行性', task: '重新规划项目范围和优先级', action: '与相关方沟通并协调资源', result: '制定可行的加速方案' },
        referenceAnswer: '首先我会评估提前的时间量和对项目范围的影响。然后与产品经理沟通，看是否可以缩减非核心功能，聚焦MVP。同时评估是否需要增加人手或调整其他项目资源。在团队内部，我会重新排优先级，确保关键路径上的任务优先完成，并适当增加并行度。',
        difficulty: 'medium'
      },
      {
        id: 's2', category: 'situational', question: '如果你的方案被领导否决了，你怎么办？',
        tips: '展示你的成熟度和学习能力，避免情绪化反应。',
        starGuide: { situation: '控制情绪，理解领导否决的原因', task: '从反馈中学习和改进', action: '根据反馈调整方案或接受决策', result: '展示积极的态度和后续行动' },
        referenceAnswer: '我会先控制情绪，然后主动找领导沟通，了解否决的具体原因。如果是方案本身的问题，我会虚心接受并改进；如果是信息不对称导致的误解，我会补充相关数据和论据再次沟通；如果领导有更全面的考量，我会尊重决策并全力执行。无论如何，这都是一次学习和成长的机会。',
        difficulty: 'medium'
      },
      {
        id: 's3', category: 'situational', question: '如果你发现同事在项目中偷懒，你会怎么做？',
        tips: '展示你的团队责任感和处理人际问题的智慧。',
        starGuide: { situation: '客观评估情况，避免主观判断', task: '选择合适的沟通方式和时机', action: '先私下沟通了解原因，必要时向上反馈', result: '展示解决问题的方法和团队关系的维护' },
        referenceAnswer: '我会先观察确认是否真的存在偷懒的情况，也许对方有其他困难。然后选择合适的时机私下沟通，了解对方的情况。如果是工作量分配不均，我会建议调整；如果是个人问题，我会提供帮助。如果沟通后没有改善且影响了项目进度，我会与上级沟通，客观描述事实而非主观评价。',
        difficulty: 'medium'
      },
      {
        id: 's4', category: 'situational', question: '如果客户提出不合理需求，你怎么处理？',
        tips: '展示你的客户管理能力和专业判断力。',
        starGuide: { situation: '理解客户需求背后的真实意图', task: '评估需求的合理性和可行性', action: '提供替代方案并管理客户期望', result: '达成双方满意的解决方案' },
        referenceAnswer: '首先我会认真倾听，理解客户提出这个需求背后的真正诉求。然后评估需求的技术可行性和对项目的影响。如果确实不合理，我不会直接拒绝，而是会提供替代方案，说明为什么替代方案能更好地满足他们的核心需求。同时用数据和案例来支持我的建议，让客户理解我们的专业判断。',
        difficulty: 'medium'
      },
      {
        id: 's5', category: 'situational', question: '如果你同时收到两个重要任务，怎么安排？',
        tips: '展示你的优先级管理能力和沟通协调能力。',
        starGuide: { situation: '评估两个任务的紧急性和重要性', task: '制定优先级和时间分配方案', action: '与相关方沟通确认优先级', result: '展示高效完成两个任务的方法' },
        referenceAnswer: '我会用四象限法则来评估：两个任务分别属于哪个象限？然后与两位任务发起人沟通，确认他们的真实时间要求和优先级。如果确实无法同时完成，我会建议调整其中一个的截止日期或寻求同事协助。在执行过程中，我会使用时间块管理法，确保每个任务都有专注的时间。',
        difficulty: 'medium'
      },
      {
        id: 's6', category: 'situational', question: '如果你的团队士气低落，你怎么提升？',
        tips: '展示你的领导力和团队管理能力，强调同理心和行动力。',
        starGuide: { situation: '了解士气低落的原因', task: '制定提振士气的策略', action: '实施具体措施并持续关注', result: '展示团队士气的改善和成果' },
        referenceAnswer: '首先我会通过一对一沟通了解士气低落的根本原因：是工作压力大、方向不明确还是其他问题？然后对症下药：如果是方向问题，我会组织一次团队会议明确愿景和近期目标；如果是压力问题，我会争取资源支持并合理调整工作量；同时，我会及时认可和表扬团队成员的贡献，创造积极的团队氛围。',
        difficulty: 'medium'
      },
      {
        id: 's7', category: 'situational', question: '如果项目需求频繁变更，你怎么应对？',
        tips: '展示你的灵活性和项目管理能力，强调流程建设。',
        starGuide: { situation: '分析需求变更的频率和原因', task: '建立需求变更管理流程', action: '评估每次变更的影响并与相关方确认', result: '展示变更管理的效果' },
        referenceAnswer: '适度的需求变更是正常的，但频繁变更需要建立管理机制。我会推动建立需求变更流程：所有变更需要提交变更申请，评估对进度、成本和质量的影响，由产品负责人审批。同时建议产品团队进行更充分的需求调研，减少不必要的变更。对于已批准的变更，及时调整计划和通知相关方。',
        difficulty: 'medium'
      },
      {
        id: 's8', category: 'situational', question: '如果你和上级意见不合，你怎么处理？',
        tips: '展示你的专业素养和向上管理能力。',
        starGuide: { situation: '理解上级的立场和考量因素', task: '准备充分的数据和论据', action: '选择合适的时机和方式进行沟通', result: '达成共识或尊重决策' },
        referenceAnswer: '我会先换位思考，理解上级的顾虑和考量因素。然后准备充分的数据和案例来支持我的观点，选择一个合适的时机进行一对一沟通。在沟通中，我会先表达对上级意见的理解，然后陈述我的观点和依据，最后提出一个折中方案。如果上级最终坚持原有决定，我会尊重并全力执行。',
        difficulty: 'medium'
      },
      {
        id: 's9', category: 'situational', question: '如果面试官质疑你的能力，你怎么回应？',
        tips: '保持冷静自信，用事实和数据回应质疑，不要有防御心理。',
        starGuide: { situation: '保持冷静，理解质疑的具体点', task: '用具体事例和数据来回应', action: '展示你的学习能力和成长意愿', result: '将质疑转化为展示能力的机会' },
        referenceAnswer: '感谢您的提问，这说明您对这个岗位的要求很高。关于您提到的XX方面，虽然我之前没有直接经验，但我在YY方面的经验可以迁移。比如在ZZ项目中，我运用了类似的思路和方法取得了XX成果。而且我学习能力强，入职后可以快速补齐这方面的短板。如果您愿意，我可以详细说明我的学习计划。',
        difficulty: 'medium'
      },
      {
        id: 's10', category: 'situational', question: '如果薪资低于预期，你怎么谈判？',
        tips: '展示你的谈判技巧和职业成熟度，强调综合价值。',
        starGuide: { situation: '了解薪资构成的全部信息', task: '评估offer的综合价值', action: '用市场数据和自身价值来谈判', result: '达成双方接受的方案' },
        referenceAnswer: '首先我会全面了解薪资构成，包括基本工资、绩效奖金、股票期权、福利等，评估综合价值。如果确实低于市场水平，我会用行业薪资调研数据和我能带来的价值来沟通。同时表达对公司的热情，提出一个合理的期望范围。如果薪资空间有限，我会尝试谈判其他方面，如更多的年假、远程办公等。',
        difficulty: 'medium'
      },
      {
        id: 's11', category: 'situational', question: '如果你被分配到不喜欢的项目，怎么办？',
        tips: '展示你的职业素养和积极心态，强调在任何情况下都能创造价值。',
        starGuide: { situation: '理解分配的原因和项目的需求', task: '找到项目中可以学习和贡献的点', action: '积极投入并寻找转机', result: '展示在任何项目中都能成长的态度' },
        referenceAnswer: '首先我会尊重公司的安排，理解这个分配背后的考量。然后我会尝试找到这个项目中与我的兴趣和发展方向相关的部分，主动承担这类工作。同时，我会把这不喜欢的项目当作拓展能力边界的机会。如果在项目中做出了成绩，后续申请调岗也会更有说服力。',
        difficulty: 'medium'
      },
      {
        id: 's12', category: 'situational', question: '如果公司要求你转岗，你怎么考虑？',
        tips: '展示你的开放心态和职业规划意识。',
        starGuide: { situation: '了解转岗的原因和新岗位的要求', task: '评估转岗对个人发展的影响', action: '与上级沟通了解公司的考量', result: '做出理性的决定' },
        referenceAnswer: '我会从几个方面来考虑：新岗位是否与我的职业发展方向一致？是否能带来新的学习和成长机会？公司的考量是什么？如果新岗位能帮助我拓展技能和视野，我会积极考虑。如果有顾虑，我会与上级坦诚沟通，了解更多信息后再做决定。无论如何，我会以开放的心态来评估这个机会。',
        difficulty: 'medium'
      },

      // ==================== 5. 薪资谈判类 (10题) - 难度: 中等 ====================
      {
        id: 'sal_1', category: 'salary', question: '你的期望薪资是多少？',
        tips: '给出一个有理有据的范围，不要说出底线，留出谈判空间。',
        starGuide: { situation: '基于市场调研确定期望范围', task: '考虑自身价值和公司预算', action: '给出范围并说明依据', result: '引导对方先出价' },
        referenceAnswer: '基于我对市场的调研和我的经验背景，我的期望范围是XX到XX。这个范围考虑了当前市场行情、我的专业能力和能为公司带来的价值。当然，薪资只是我考虑的一个因素，我也非常看重公司的发展平台和成长空间。请问贵公司这个岗位的薪资预算范围是多少？',
        difficulty: 'medium'
      },
      {
        id: 'sal_2', category: 'salary', question: '你如何看待薪资与成长的关系？',
        tips: '展示你的成熟价值观，强调薪资与能力的匹配。',
        starGuide: { situation: '说明你对薪资的基本态度', task: '平衡短期薪资和长期成长', action: '展示你对自身价值的认知', result: '表达对合理回报的期望' },
        referenceAnswer: '我认为薪资和能力应该是匹配的。在职业早期，我更看重成长机会和学习空间，愿意用一定的薪资来换取快速成长。但随着能力的提升，我期望薪资能相应增长。我追求的是"值得"的薪资，即我的产出能超过公司对我的投入。我相信在贵公司这样的平台上，我能创造更大的价值。',
        difficulty: 'medium'
      },
      {
        id: 'sal_3', category: 'salary', question: '如果给你低于预期的offer，你怎么考虑？',
        tips: '展示你的谈判策略和决策框架，不要急于拒绝或接受。',
        starGuide: { situation: '全面评估offer的综合价值', task: '区分核心诉求和可妥协项', action: '尝试谈判或获取更多信息', result: '做出理性的决策' },
        referenceAnswer: '我会先全面评估这个offer的综合价值，包括薪资、奖金、股票、福利、发展空间等。如果薪资低于预期但其他方面很好，我会尝试谈判。我会用市场数据和我的价值来沟通，看是否有调整空间。如果薪资差距较大且无法调整，我会权衡这个平台对我的长期价值，做出理性的决定。',
        difficulty: 'medium'
      },
      {
        id: 'sal_4', category: 'salary', question: '你如何评估一个offer的综合价值？',
        tips: '展示你的全面思考能力，不只是看基本工资。',
        starGuide: { situation: '列出offer的所有组成部分', task: '对每个维度进行权重分配', action: '量化评估每个维度的价值', result: '做出综合判断' },
        referenceAnswer: '我会从6个维度评估offer：基本工资（权重30%）、绩效奖金（15%）、股票/期权（15%）、福利保障（10%）、职业发展空间（20%）、工作生活平衡（10%）。我会将每个维度量化打分，然后加权计算总分。这样能避免只看薪资而忽略其他重要因素，做出更全面的判断。',
        difficulty: 'medium'
      },
      {
        id: 'sal_5', category: 'salary', question: '你现在的薪资是多少？',
        tips: '可以给出范围而非精确数字，强调期望而非过去。',
        starGuide: { situation: '了解公司的意图', task: '决定是否透露及透露多少', action: '将话题引导到期望薪资', result: '避免被过去薪资锚定' },
        referenceAnswer: '我目前的总包（包括基本工资、奖金和福利）大约在XX到XX的范围。不过，我认为过去的薪资更多反映的是之前岗位的市场价值，而我更希望基于这个岗位的要求和我的能力来讨论合理的薪资。我对贵公司这个岗位的期望是XX到XX，您觉得这个范围合理吗？',
        difficulty: 'medium'
      },
      {
        id: 'sal_6', category: 'salary', question: '你如何准备薪资谈判？',
        tips: '展示你的准备充分性和谈判策略。',
        starGuide: { situation: '进行市场调研和自我评估', task: '确定谈判策略和底线', action: '准备数据和论据', result: '展示你的专业性和谈判能力' },
        referenceAnswer: '我从3个方面准备薪资谈判：一是市场调研，通过招聘网站、行业报告和同行交流了解目标岗位的薪资范围；二是自我评估，梳理我的核心竞争力和能带来的独特价值；三是确定谈判策略，包括我的期望值、可接受底线和可以用来交换的筹码。充分的准备让我在谈判中更有底气。',
        difficulty: 'medium'
      },
      {
        id: 'sal_7', category: 'salary', question: '除了薪资，你最看重什么？',
        tips: '展示你的职业价值观，同时暗示你可以灵活考虑薪资。',
        starGuide: { situation: '说明你的核心职业诉求', task: '列举你看重的其他因素', action: '展示你的综合考量', result: '为谈判创造更多空间' },
        referenceAnswer: '除了薪资，我最看重三个方面：一是成长空间，公司是否有清晰的晋升通道和学习机会；二是团队和文化，与优秀的人一起工作能让我成长更快；三是工作内容本身，是否能让我发挥专长并有成就感。当然，合理的薪资是基础，但以上因素决定了我的长期满意度和贡献度。',
        difficulty: 'medium'
      },
      {
        id: 'sal_8', category: 'salary', question: '你如何回应"你的要求太高了"？',
        tips: '保持自信，用数据和价值来支撑你的要求，不要轻易降价。',
        starGuide: { situation: '保持冷静和自信', task: '用数据和案例支撑你的要求', action: '询问对方的预算范围', result: '寻找双方都能接受的方案' },
        referenceAnswer: '我理解公司的预算考量。我的期望是基于市场调研和我能为公司带来的价值来设定的。在上一份工作中，我通过XX项目为公司创造了XX的价值。我相信在贵公司，我也能产出超出这个薪资的贡献。请问贵公司这个岗位的预算范围是多少？也许我们能在其他方面找到平衡。',
        difficulty: 'medium'
      },
      {
        id: 'sal_9', category: 'salary', question: '你如何比较多个offer？',
        tips: '展示你的决策框架和理性分析能力。',
        starGuide: { situation: '列出所有待比较的offer', task: '建立统一的评估维度和权重', action: '逐一打分并计算综合得分', result: '做出基于数据的决策' },
        referenceAnswer: '我会建立一个评估矩阵，维度包括：薪资福利（30%）、发展空间（25%）、团队质量（15%）、公司前景（15%）、通勤和生活方式（15%）。每个维度1-10分打分，加权计算总分。同时我也会考虑直觉感受，毕竟每天的工作体验很重要。最终选择综合得分最高且让我最兴奋的offer。',
        difficulty: 'medium'
      },
      {
        id: 'sal_10', category: 'salary', question: '你如何谈涨薪？',
        tips: '展示你的价值证明能力和谈判技巧。',
        starGuide: { situation: '梳理你在公司的贡献和成长', task: '准备数据和具体案例', action: '选择合适的时机和方式提出', result: '展示你的专业性和对公司的价值' },
        referenceAnswer: '谈涨薪我会做充分准备：首先梳理过去一年的核心贡献，用量化数据展示我的价值增长；其次了解市场薪资水平，确认我的薪资是否低于市场；然后选择绩效评估或完成重要项目后的时机提出。在沟通中，我会聚焦于我的贡献和市场价值，而不是个人需求或同事的薪资。',
        difficulty: 'medium'
      }
    ];

    // 根据配置筛选问题
    let filteredQuestions = allQuestions;
    if (config.categories.length > 0) {
      filteredQuestions = allQuestions.filter(q => config.categories.includes(q.category));
    }

    // 根据难度筛选
    if (config.difficulty !== 'mixed') {
      filteredQuestions = filteredQuestions.filter(q => q.difficulty === config.difficulty);
    }

    // 随机选择指定数量的问题
    const shuffled = filteredQuestions.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, config.questionCount);
  }

  /**
   * 提交回答并获取AI点评
   */
  async submitAnswer(
    sessionId: string,
    answer: InterviewAnswer
  ): Promise<InterviewFeedback> {
    try {
      const response = await this.apiService.post<InterviewFeedback>('/interview/submit', {
        sessionId,
        answer
      });
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Submit answer failed:', error);
    }

    // API 失败，抛出错误而非返回模拟点评
    throw new Error('AI点评服务暂时不可用，请检查网络后重试');
  }

  /**
   * 生成模拟AI点评
   * [仅用于开发调试] @deprecated 审核期间禁用，API 失败时应抛出错误
   */
  /*
  private generateMockFeedback(answer: InterviewAnswer): InterviewFeedback {
    const content = answer.content;
    const wordCount = content.length;

    // 基于回答内容生成点评
    const hasSituation = content.includes('在') || content.includes('当时') || content.includes('项目');
    const hasAction = content.includes('我') && (content.includes('做') || content.includes('采取') || content.includes('完成'));
    const hasResult = content.includes('结果') || content.includes('成功') || content.includes('完成') || content.includes('提升');

    const strengths: string[] = [];
    const improvements: string[] = [];

    if (wordCount > 100) {
      strengths.push('回答内容充实，提供了足够的细节');
    } else {
      improvements.push('建议提供更多具体细节，让回答更有说服力');
    }

    if (hasSituation) {
      strengths.push('清晰地描述了情境背景');
    } else {
      improvements.push('建议先描述情境背景，让面试官理解上下文');
    }

    if (hasAction) {
      strengths.push('明确说明了自己的行动和贡献');
    } else {
      improvements.push('需要更清晰地说明你采取的具体行动');
    }

    if (hasResult) {
      strengths.push('展示了行动的结果和成效');
    } else {
      improvements.push('建议补充行动的结果，用数据或具体成果来支撑');
    }

    // 计算分数
    let score = 60;
    if (wordCount > 100) score += 10;
    if (wordCount > 200) score += 5;
    if (hasSituation) score += 8;
    if (hasAction) score += 10;
    if (hasResult) score += 7;
    score = Math.min(score, 95);

    return {
      questionId: answer.questionId,
      strengths: strengths.length > 0 ? strengths : ['回答态度认真'],
      improvements: improvements.length > 0 ? improvements : ['继续保持，可以尝试更深入的分析'],
      referenceAnswer: '这是一个参考答案示例，展示了如何运用STAR法则组织回答。',
      score: score,
      suggestions: [
        '使用STAR法则组织回答结构',
        '提供具体的数据和成果',
        '突出个人贡献和成长'
      ],
      starAnalysis: {
        situation: {
          score: hasSituation ? 80 : 50,
          comment: hasSituation ? '情境描述清晰' : '需要补充情境描述'
        },
        task: {
          score: 70,
          comment: '任务说明可以更明确'
        },
        action: {
          score: hasAction ? 85 : 55,
          comment: hasAction ? '行动描述详细' : '需要说明具体行动'
        },
        result: {
          score: hasResult ? 80 : 45,
          comment: hasResult ? '结果展示到位' : '需要补充结果展示'
        }
      }
    };
  }
  */

  /**
   * 完成面试会话
   */
  async completeInterview(session: InterviewSession): Promise<InterviewSession> {
    // 计算总分
    const totalScore = session.feedbacks.length === 0 ? 0 : session.feedbacks.reduce((sum, f) => sum + f.score, 0) / session.feedbacks.length;

    const completedSession: InterviewSession = {
      id: session.id,
      jobPosition: session.jobPosition,
      questions: session.questions,
      answers: session.answers,
      feedbacks: session.feedbacks,
      currentQuestionIndex: session.currentQuestionIndex,
      status: 'completed',
      startTime: session.startTime,
      endTime: Date.now(),
      totalScore: Math.round(totalScore)
    };

    // 保存到历史记录
    await this.historyService.addHistory({
      type: 'interview',
      title: `模拟面试 - ${session.jobPosition}`,
      content: `完成${session.questions.length}道题目，平均得分${Math.round(totalScore)}分`,
      metadata: {
        sessionId: session.id,
        jobPosition: session.jobPosition,
        questionCount: session.questions.length,
        totalScore: totalScore
      }
    });

    try {
      await this.apiService.post('/interview/complete', {
        sessionId: session.id,
        totalScore
      });
    } catch (error) {
      console.error('[InterviewService] Complete interview failed:', error);
    }

    return completedSession;
  }

  /**
   * 开始录音
   * 使用 AVRecorder 进行录音，同时初始化语音识别服务
   * @returns 是否成功开始录音
   * @throws 录音初始化失败时返回 false 并释放资源
   */
  async startRecording(): Promise<boolean> {
    if (this.isRecording) {
      return false;
    }

    try {
      // 初始化语音识别服务
      if (!this.speechService.isInitialized) {
        await this.initializeSpeechRecognition();
      }

      // 生成录音文件路径
      this.audioFilePath = `/data/local/tmp/interview_${Date.now()}.m4a`;
      this.recordingStartTime = Date.now();

      // 创建音频文件并获取文件描述符
      const file = fileIo.openSync(this.audioFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      this.audioFd = file.fd;

      // 创建 AVRecorder 实例
      this.avRecorder = await media.createAVRecorder();

      // 配置录音参数
      const avConfig: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.MIC,
        profile: {
          audioBitrate: 128000,
          audioChannels: 2,
          audioCodec: media.CodecMimeType.AUDIO_AAC_LC,
          audioSampleRate: 48000,
          fileFormat: media.ContainerFormatType.M4A,
        },
        url: `fd://${this.audioFd}`,
      };

      // 设置 fdCallback 以传递文件描述符
      this.avRecorder.fdCallback = (err, fd) => {
        if (err) {
          console.error('[InterviewService] fdCallback error:', err);
          return;
        }
        console.log('[InterviewService] fdCallback fd:', fd);
      };

      await this.avRecorder.prepare(avConfig);
      await this.avRecorder.start();

      this.isRecording = true;
      console.log('[InterviewService] Recording started');
      return true;
    } catch (error) {
      console.error('[InterviewService] Start recording failed:', error);
      this.isRecording = false;
      // 出错时释放资源
      await this.releaseRecorder();
      return false;
    }
  }

  /**
   * 停止录音
   * @returns 包含录音文件路径和时长的对象，未在录音时返回 null
   */
  async stopRecording(): Promise<{ path: string; duration: number } | null> {
    if (!this.isRecording) {
      return null;
    }

    try {
      const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
      this.isRecording = false;

      // 停止并释放 AVRecorder
      if (this.avRecorder) {
        await this.avRecorder.stop();
        await this.avRecorder.release();
        this.avRecorder = null;
      }

      // 关闭文件描述符
      if (this.audioFd >= 0) {
        try {
          fileIo.close(this.audioFd);
        } catch (closeError) {
          console.error('[InterviewService] Close audio fd failed:', closeError);
        }
        this.audioFd = -1;
      }

      console.log('[InterviewService] Recording stopped, duration:', duration);
      return {
        path: this.audioFilePath,
        duration: duration
      };
    } catch (error) {
      console.error('[InterviewService] Stop recording failed:', error);
      this.isRecording = false;
      // 出错时尝试释放资源
      await this.releaseRecorder();
      return null;
    }
  }

  /**
   * 语音识别
   * 使用 SpeechRecognitionService 进行语音转文字
   */
  async recognizeSpeech(audioPath: string): Promise<string> {
    try {
      hilog.info(DOMAIN, TAG, 'Recognizing speech from:', audioPath);

      // 如果服务未初始化，先初始化
      if (!this.speechService.isInitialized) {
        const success = await this.speechService.initialize();
        if (!success) {
          hilog.error(DOMAIN, TAG, 'Speech service initialization failed');
          return '';
        }
      }

      // 开始聆听获取识别结果
      const startSuccess = await this.speechService.startListening();
      if (!startSuccess) {
        hilog.error(DOMAIN, TAG, 'Start listening failed');
        return '';
      }

      // 等待识别完成（最多等待30秒）
      const result = await new Promise<RecognitionResult | null>((resolve) => {
        const timeout = setTimeout(() => {
          this.speechService.stopListening();
          resolve(null);
        }, 30000);

        // 监听结果
        this.speechService.onResult = (result: RecognitionResult) => {
          if (result.isFinal) {
            clearTimeout(timeout);
            this.speechService.stopListening();
            resolve(result);
          }
        };

        this.speechService.onError = (error: RecognitionResult) => {
          clearTimeout(timeout);
          this.speechService.stopListening();
          hilog.error(DOMAIN, TAG, `Recognition error: ${error.errorMessage}`);
          resolve(null);
        };
      });

      if (result) {
        hilog.info(DOMAIN, TAG, `Recognition result: ${result.text}`);
        return result.text;
      }

      return '';
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Speech recognition failed: ${error}`);
      return '';
    }
  }

  /**
   * 直接使用语音识别（无需录音文件）
   * 适用于实时语音识别场景
   */
  async recognizeSpeechDirect(): Promise<RecognitionResult | null> {
    try {
      // 如果服务未初始化，先初始化
      if (!this.speechService.isInitialized) {
        const success = await this.speechService.initialize();
        if (!success) {
          hilog.error(DOMAIN, TAG, 'Speech service initialization failed');
          return null;
        }
      }

      const success = await this.speechService.startListening();
      if (!success) {
        hilog.error(DOMAIN, TAG, 'Start listening failed');
        return null;
      }

      return this.speechService.lastResult;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Direct speech recognition failed: ${error}`);
      return null;
    }
  }

  /**
   * 停止语音识别
   */
  async stopSpeechRecognition(): Promise<RecognitionResult | null> {
    try {
      const result = await this.speechService.stopListening();
      return result;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Stop speech recognition failed: ${error}`);
      return null;
    }
  }

  /**
   * 取消语音识别
   */
  async cancelSpeechRecognition(): Promise<void> {
    try {
      await this.speechService.cancel();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Cancel speech recognition failed: ${error}`);
    }
  }

  /**
   * 获取当前语音识别状态
   */
  getSpeechRecognitionState(): SpeechRecognitionState {
    return this.speechService.state;
  }

  /**
   * 释放录音器资源（用于错误恢复时的清理）
   */
  async releaseRecorder(): Promise<void> {
    try {
      if (this.avRecorder) {
        try {
          await this.avRecorder.release();
        } catch (releaseError) {
          console.error('[InterviewService] Release avRecorder failed:', releaseError);
        }
        this.avRecorder = null;
      }
    } catch (error) {
      console.error('[InterviewService] Release recorder failed:', error);
    }

    try {
      if (this.audioFd >= 0) {
        fileIo.close(this.audioFd);
        this.audioFd = -1;
      }
    } catch (error) {
      console.error('[InterviewService] Close audio fd failed:', error);
    }

    this.isRecording = false;
  }

  /**
   * 释放所有资源（包括语音识别服务）
   */
  release(): void {
    // 释放录音器
    this.releaseRecorder();

    // 释放语音识别服务
    this.speechService.release();

    // 清除回调
    this.onRecognitionResultCallback = undefined;
    this.onRecognitionErrorCallback = undefined;
    this.onRecognitionStateChangeCallback = undefined;

    hilog.info(DOMAIN, TAG, 'InterviewService released all resources');
  }

  /**
   * 根据 ID 获取面试问题
   * @param id 问题ID
   * @returns 匹配的面试问题，未找到返回 null
   */
  getQuestionById(id: string): InterviewQuestion | null {
    // 先从 loadedQuestions 中查找
    if (this.loadedQuestions.length > 0) {
      for (let i = 0; i < this.loadedQuestions.length; i++) {
        if (this.loadedQuestions[i].id === id) {
          return this.loadedQuestions[i];
        }
      }
    }
    // 再从默认题库中查找
    const defaultConfig: InterviewConfig = {
      jobPosition: '',
      questionCount: 999,
      categories: [],
      difficulty: 'mixed'
    };
    const allQuestions = this.generateQuestions(defaultConfig);
    for (let i = 0; i < allQuestions.length; i++) {
      if (allQuestions[i].id === id) {
        return allQuestions[i];
      }
    }
    return null;
  }

  /**
   * 获取面试统计
   */
  getRecordingStatus(): { isRecording: boolean; duration: number } {
    return {
      isRecording: this.isRecording,
      duration: this.isRecording ? Math.floor((Date.now() - this.recordingStartTime) / 1000) : 0
    };
  }

  /**
   * 获取面试统计
   */
  async getInterviewStats(): Promise<{
    totalSessions: number;
    averageScore: number;
    recentSessions: InterviewSession[];
  }> {
    try {
      const response = await this.apiService.get<{
        totalSessions: number;
        averageScore: number;
        recentSessions: InterviewSession[];
      }>('/interview/stats');

      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Get stats failed:', error);
    }

    return {
      totalSessions: 0,
      averageScore: 0,
      recentSessions: []
    };
  }

  /**
   * 搜索面试问题（支持分页、关键词、分类、难度筛选）
   * 优先调用 API，失败时回退到本地题库过滤
   */
  async searchQuestions(params: {
    keyword?: string;
    category?: string;
    difficulty?: string;
    position?: string;
    page?: number;
    pageSize?: number;
  }): Promise<{ items: InterviewQuestion[]; total: number }> {
    const page = params.page ?? 1;
    const pageSize = params.pageSize ?? 20;

    try {
      const response = await this.apiService.post<{ items: InterviewQuestion[]; total: number }>(
        '/interview/questions/search',
        params
      );
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Search questions failed, falling back to local:', error);
    }

    // 回退：从本地默认题库中过滤
    const defaultConfig: InterviewConfig = {
      jobPosition: '',
      questionCount: 999,
      categories: [],
      difficulty: 'mixed'
    };
    const allQuestions = this.generateQuestions(defaultConfig);

    let filtered = allQuestions;

    if (params.keyword) {
      const kw = params.keyword.toLowerCase();
      filtered = filtered.filter(q => q.question.toLowerCase().includes(kw));
    }
    if (params.category) {
      filtered = filtered.filter(q => q.category === params.category);
    }
    if (params.difficulty) {
      filtered = filtered.filter(q => q.difficulty === params.difficulty);
    }

    const total = filtered.length;
    const start = (page - 1) * pageSize;
    const items = filtered.slice(start, start + pageSize);

    return { items, total };
  }

  /**
   * 按岗位获取面试问题
   * 优先调用 API，失败时返回空数组（本地数据暂无岗位标签）
   */
  async getQuestionsByPosition(position: string): Promise<InterviewQuestion[]> {
    try {
      const response = await this.apiService.get<InterviewQuestion[]>(
        `/interview/questions/position/${position}`
      );
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Get questions by position failed:', error);
    }

    // 本地数据暂无岗位标签，返回空数组
    return [];
  }

  /**
   * 获取面试历史记录（支持分页）
   * 优先调用 API，失败时返回空结果
   */
  async getInterviewHistory(
    page?: number,
    pageSize?: number
  ): Promise<{ items: any[]; total: number }> {
    try {
      const response = await this.apiService.get<{ items: any[]; total: number }>(
        '/interview/history',
        { page: page ?? 1, pageSize: pageSize ?? 20 }
      );
      if (response.success && response.data) {
        return response.data;
      }
    } catch (error) {
      console.error('[InterviewService] Get interview history failed:', error);
    }

    return { items: [], total: 0 };
  }
}
