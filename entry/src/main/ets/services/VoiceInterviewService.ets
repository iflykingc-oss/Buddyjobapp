/**
 * 语音面试助手服务 - 实时语音交互
 * 支持语音识别、实时反馈、语音播报
 */
import hilog from '@ohos.hilog';
import speechRecognizer from '@ohos.ai.speechRecognizer';
import textToSpeech from '@ohos.ai.textToSpeech';
import { ApiService } from './ApiService';
import { storage } from '../utils/storage';

const TAG = 'VoiceInterviewService';
const DOMAIN = 0xFF00;

/**
 * 语音识别状态
 */
export enum RecognitionState {
  IDLE = 'idle',
  LISTENING = 'listening',
  PROCESSING = 'processing',
  SPEAKING = 'speaking'
}

/**
 * 面试问题类型
 */
export enum QuestionType {
  INTRODUCTION = 'introduction',
  TECHNICAL = 'technical',
  BEHAVIORAL = 'behavioral',
  PROJECT = 'project',
  SITUATION = 'situation'
}

/**
 * 面试问题
 */
export interface InterviewQuestion {
  id: string;
  type: QuestionType;
  content: string;
  tips?: string[];
  keywords?: string[];
  followUp?: string[];
}

/**
 * 回答评估
 */
export interface AnswerEvaluation {
  score: number;
  strengths: string[];
  improvements: string[];
  keywords: {
    mentioned: string[];
    missed: string[];
  };
  suggestion: string;
}

/**
 * 语音面试会话
 */
export interface VoiceInterviewSession {
  id: string;
  company: string;
  position: string;
  questions: InterviewQuestion[];
  currentQuestionIndex: number;
  answers: {
    questionId: string;
    answer: string;
    evaluation: AnswerEvaluation;
    duration: number;
  }[];
  startTime: string;
  status: 'active' | 'paused' | 'completed';
}

/**
 * 语音助手回调
 */
export interface VoiceAssistantCallback {
  onRecognitionStart?: () => void;
  onRecognitionResult?: (text: string, isFinal: boolean) => void;
  onRecognitionError?: (error: string) => void;
  onSpeakingStart?: () => void;
  onSpeakingEnd?: () => void;
  onQuestionChange?: (question: InterviewQuestion) => void;
  onEvaluationReady?: (evaluation: AnswerEvaluation) => void;
}

export class VoiceInterviewService {
  private static recognizer: speechRecognizer.SpeechRecognizer | null = null;
  private static ttsEngine: textToSpeech.TextToSpeech | null = null;
  private static session: VoiceInterviewSession | null = null;
  private static state: RecognitionState = RecognitionState.IDLE;
  private static callback: VoiceAssistantCallback | null = null;
  private static recognitionText: string = '';
  private static questionStartTime: number = 0;

  /**
   * 初始化语音服务
   */
  static async initialize(): Promise<boolean> {
    try {
      // 初始化语音识别
      this.recognizer = speechRecognizer.createSpeechRecognizer('com.buddyjob.app');
      hilog.info(DOMAIN, TAG, 'Speech recognizer created');

      // 初始化语音合成
      this.ttsEngine = textToSpeech.createTextToSpeech('com.buddyjob.app');
      hilog.info(DOMAIN, TAG, 'TTS engine created');

      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${error}`);
      return false;
    }
  }

  /**
   * 开始面试会话
   */
  static async startSession(
    company: string,
    position: string,
    difficulty: 'easy' | 'medium' | 'hard' = 'medium'
  ): Promise<VoiceInterviewSession | null> {
    try {
      // 获取面试问题
      const questions = await this.generateQuestions(position, difficulty);

      this.session = {
        id: this.generateId(),
        company,
        position,
        questions,
        currentQuestionIndex: 0,
        answers: [],
        startTime: new Date().toISOString(),
        status: 'active'
      };

      // 播报欢迎语
      await this.speak(`欢迎参加${company}${position}面试。我将提出${questions.length}个问题，请准备好后开始回答。`);

      // 等待1秒后提出第一个问题
      setTimeout(() => {
        this.askCurrentQuestion();
      }, 2000);

      return this.session;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start session failed: ${error}`);
      return null;
    }
  }

  /**
   * 开始监听回答
   */
  static async startListening(callback: VoiceAssistantCallback): Promise<void> {
    this.callback = callback;
    this.state = RecognitionState.LISTENING;
    this.recognitionText = '';
    this.questionStartTime = Date.now();

    if (!this.recognizer) {
      await this.initialize();
    }

    try {
      this.recognizer!.on('start', () => {
        hilog.info(DOMAIN, TAG, 'Recognition started');
        callback.onRecognitionStart?.();
      });

      this.recognizer!.on('result', (result) => {
        this.recognitionText = result.text;
        callback.onRecognitionResult?.(result.text, result.isFinal);

        if (result.isFinal) {
          this.handleFinalResult(result.text);
        }
      });

      this.recognizer!.on('error', (error) => {
        hilog.error(DOMAIN, TAG, `Recognition error: ${error}`);
        callback.onRecognitionError?.(error.message);
        this.state = RecognitionState.IDLE;
      });

      // 开始识别
      this.recognizer!.start({
        language: 'zh-CN',
        continuous: true,
        interimResults: true
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start listening failed: ${error}`);
    }
  }

  /**
   * 停止监听
   */
  static stopListening(): void {
    if (this.recognizer && this.state === RecognitionState.LISTENING) {
      this.recognizer.stop();
      this.state = RecognitionState.PROCESSING;
    }
  }

  /**
   * 语音播报
   */
  static async speak(text: string): Promise<void> {
    if (!this.ttsEngine) {
      await this.initialize();
    }

    return new Promise((resolve, reject) => {
      this.state = RecognitionState.SPEAKING;
      this.callback?.onSpeakingStart?.();

      this.ttsEngine!.on('end', () => {
        this.state = RecognitionState.IDLE;
        this.callback?.onSpeakingEnd?.();
        resolve();
      });

      this.ttsEngine!.on('error', (error) => {
        hilog.error(DOMAIN, TAG, `TTS error: ${error}`);
        this.state = RecognitionState.IDLE;
        reject(error);
      });

      this.ttsEngine!.speak({
        text,
        language: 'zh-CN',
        rate: 1.0,
        pitch: 1.0
      });
    });
  }

  /**
   * 跳过当前问题
   */
  static async skipQuestion(): Promise<void> {
    this.stopListening();
    await this.moveToNextQuestion();
  }

  /**
   * 暂停面试
   */
  static pauseSession(): void {
    if (this.session) {
      this.session.status = 'paused';
      this.stopListening();
    }
  }

  /**
   * 恢复面试
   */
  static async resumeSession(): Promise<void> {
    if (this.session && this.session.status === 'paused') {
      this.session.status = 'active';
      await this.askCurrentQuestion();
    }
  }

  /**
   * 结束面试
   */
  static async endSession(): Promise<VoiceInterviewSession | null> {
    if (!this.session) {
      return null;
    }

    this.stopListening();
    this.session.status = 'completed';

    // 播报结束语
    await this.speak('面试结束。感谢您的参与，祝您求职顺利！');

    // 保存会话记录
    await this.saveSession(this.session);

    return this.session;
  }

  /**
   * 获取当前状态
   */
  static getState(): RecognitionState {
    return this.state;
  }

  /**
   * 获取当前会话
   */
  static getSession(): VoiceInterviewSession | null {
    return this.session;
  }

  /**
   * 处理最终识别结果
   */
  private static async handleFinalResult(text: string): Promise<void> {
    if (!this.session) {
      return;
    }

    const currentQuestion = this.session.questions[this.session.currentQuestionIndex];
    const duration = Date.now() - this.questionStartTime;

    // 评估回答
    const evaluation = await this.evaluateAnswer(currentQuestion, text);

    // 记录答案
    this.session.answers.push({
      questionId: currentQuestion.id,
      answer: text,
      evaluation,
      duration
    });

    // 回调评估结果
    this.callback?.onEvaluationReady?.(evaluation);

    // 播报反馈
    await this.speakFeedback(evaluation);

    // 移动到下一个问题
    await this.moveToNextQuestion();
  }

  /**
   * 提出当前问题
   */
  private static async askCurrentQuestion(): Promise<void> {
    if (!this.session) {
      return;
    }

    const question = this.session.questions[this.session.currentQuestionIndex];
    this.callback?.onQuestionChange?.(question);

    // 播报问题
    await this.speak(`第${this.session.currentQuestionIndex + 1}题：${question.content}`);

    // 开始监听回答
    setTimeout(() => {
      this.startListening(this.callback!);
    }, 500);
  }

  /**
   * 移动到下一个问题
   */
  private static async moveToNextQuestion(): Promise<void> {
    if (!this.session) {
      return;
    }

    this.session.currentQuestionIndex++;

    if (this.session.currentQuestionIndex >= this.session.questions.length) {
      // 面试结束
      await this.endSession();
    } else {
      // 提出下一个问题
      await this.askCurrentQuestion();
    }
  }

  /**
   * 播报反馈
   */
  private static async speakFeedback(evaluation: AnswerEvaluation): Promise<void> {
    let feedback = '';

    if (evaluation.score >= 80) {
      feedback = '回答得很好！';
    } else if (evaluation.score >= 60) {
      feedback = '回答不错，';
      if (evaluation.improvements.length > 0) {
        feedback += `建议${evaluation.improvements[0]}。`;
      }
    } else {
      feedback = '这个回答还有提升空间。';
      if (evaluation.suggestion) {
        feedback += evaluation.suggestion;
      }
    }

    await this.speak(feedback);
  }

  /**
   * 生成面试问题
   */
  private static async generateQuestions(
    position: string,
    difficulty: string
  ): Promise<InterviewQuestion[]> {
    try {
      const response = await ApiService.getInstance().post('/api/interview/generate-questions', {
        position,
        difficulty,
        count: 5
      });

      if (response.success && response.data) {
        return response.data as InterviewQuestion[];
      }

      return this.getMockQuestions();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Generate questions failed: ${error}`);
      return this.getMockQuestions();
    }
  }

  /**
   * 评估回答
   */
  private static async evaluateAnswer(
    question: InterviewQuestion,
    answer: string
  ): Promise<AnswerEvaluation> {
    try {
      const response = await ApiService.getInstance().post('/api/interview/evaluate-answer', {
        question,
        answer
      });

      if (response.success && response.data) {
        return response.data as AnswerEvaluation;
      }

      return this.getMockEvaluation();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Evaluate answer failed: ${error}`);
      return this.getMockEvaluation();
    }
  }

  /**
   * 保存会话
   */
  private static async saveSession(session: VoiceInterviewSession): Promise<void> {
    const key = `interview_session_${session.id}`;
    await storage.set(key, JSON.stringify(session));
  }

  /**
   * 生成唯一ID
   */
  private static generateId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 获取模拟问题
   */
  private static getMockQuestions(): InterviewQuestion[] {
    return [
      {
        id: '1',
        type: QuestionType.INTRODUCTION,
        content: '请简单介绍一下自己',
        tips: ['控制在1-2分钟', '突出与岗位相关的经历'],
        keywords: ['经验', '技能', '成就']
      },
      {
        id: '2',
        type: QuestionType.TECHNICAL,
        content: '请介绍一下React的生命周期',
        tips: ['从挂载、更新、卸载三个阶段说明'],
        keywords: ['componentDidMount', 'componentDidUpdate', 'componentWillUnmount']
      },
      {
        id: '3',
        type: QuestionType.PROJECT,
        content: '请介绍一个你最有成就感的项目',
        tips: ['使用STAR法则描述'],
        keywords: ['背景', '目标', '行动', '结果']
      },
      {
        id: '4',
        type: QuestionType.BEHAVIORAL,
        content: '描述一次你解决团队冲突的经历',
        tips: ['体现沟通能力和团队协作'],
        keywords: ['沟通', '协调', '解决']
      },
      {
        id: '5',
        type: QuestionType.SITUATION,
        content: '如果项目进度落后，你会怎么处理？',
        tips: ['体现问题分析和解决能力'],
        keywords: ['分析', '优先级', '沟通']
      }
    ];
  }

  /**
   * 获取模拟评估
   */
  private static getMockEvaluation(): AnswerEvaluation {
    return {
      score: 70,
      strengths: ['回答结构清晰'],
      improvements: ['可以更具体地举例说明'],
      keywords: {
        mentioned: ['经验'],
        missed: ['成就']
      },
      suggestion: '建议使用具体的数据和案例来支撑您的回答'
    };
  }

  /**
   * 销毁服务
   */
  static destroy(): void {
    if (this.recognizer) {
      this.recognizer.destroy();
      this.recognizer = null;
    }

    if (this.ttsEngine) {
      this.ttsEngine.destroy();
      this.ttsEngine = null;
    }

    this.session = null;
    this.callback = null;
    this.state = RecognitionState.IDLE;

    hilog.info(DOMAIN, TAG, 'Voice interview service destroyed');
  }
}
