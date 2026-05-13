/**
 * 语音识别服务
 *
 * 基于 HarmonyOS 智能语音服务提供实时语音转文字功能
 * 支持流式识别、中间结果返回、多语言识别
 */
import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import speechRecognizer from '@ohos.ai.speechRecognizer';

const TAG = 'SpeechRecognitionService';
const DOMAIN = 0xFF01;

/**
 * 语音识别状态枚举
 */
export enum SpeechRecognitionState {
  IDLE = 'idle',           // 空闲状态
  LISTENING = 'listening', // 正在聆听
  PROCESSING = 'processing', // 处理中
  COMPLETED = 'completed', // 识别完成
  ERROR = 'error' // 错误状态
}

/**
 * 语音识别结果
 */
export interface RecognitionResult {
  text: string;           // 识别文本
  confidence: number;      // 置信度 0-1
  isFinal: boolean;       // 是否为最终结果
  errorCode?: string;     // 错误码
  errorMessage?: string;   // 错误信息
}

/**
 * 语音识别配置
 */
export interface SpeechRecognitionConfig {
  language?: string;           // 语言，默认 'zh-CN'
  enablePunctuation?: boolean; // 是否启用标点，默认 true
  enableInterimResults?: boolean; // 是否返回中间结果，默认 true
  audioSource?: string;        // 音频源类型
  maxSilenceDuration?: number; // 最大静默时长（秒）
}

/**
 * 语音识别服务类
 * 提供单例模式的语音识别功能
 */
export class SpeechRecognitionService {
  private static instance: SpeechRecognitionService;

  // 语音识别器实例
  private recognizer: speechRecognizer.SpeechRecognizer | null = null;

  // 当前状态
  private _state: SpeechRecognitionState = SpeechRecognitionState.IDLE;

  // 最后识别结果
  private _lastResult: RecognitionResult | null = null;

  // 是否已初始化
  private _isInitialized: boolean = false;

  // 当前配置
  private config: SpeechRecognitionConfig = {
    language: 'zh-CN',
    enablePunctuation: true,
    enableInterimResults: true
  };

  // 中间识别文本
  private interimText: string = '';

  // 事件回调
  private onResultCallback?: (result: RecognitionResult) => void;
  private onErrorCallback?: (error: RecognitionResult) => void;
  private onStateChangeCallback?: (state: SpeechRecognitionState) => void;

  /**
   * 获取单例实例
   */
  static getInstance(): SpeechRecognitionService {
    if (!SpeechRecognitionService.instance) {
      SpeechRecognitionService.instance = new SpeechRecognitionService();
    }
    return SpeechRecognitionService.instance;
  }

  /**
   * 私有构造函数
   */
  private constructor() {}

  /**
   * 获取当前状态
   */
  get state(): SpeechRecognitionState {
    return this._state;
  }

  /**
   * 获取最后识别结果
   */
  get lastResult(): RecognitionResult | null {
    return this._lastResult;
  }

  /**
   * 获取是否已初始化
   */
  get isInitialized(): boolean {
    return this._isInitialized;
  }

  /**
   * 设置识别结果回调
   */
  set onResult(callback: (result: RecognitionResult) => void) {
    this.onResultCallback = callback;
  }

  /**
   * 设置错误回调
   */
  set onError(callback: (error: RecognitionResult) => void) {
    this.onErrorCallback = callback;
  }

  /**
   * 设置状态变化回调
   */
  set onStateChange(callback: (state: SpeechRecognitionState) => void) {
    this.onStateChangeCallback = callback;
  }

  /**
   * 初始化语音识别服务
   * @param config 识别配置
   * @returns 初始化是否成功
   */
  async initialize(config?: SpeechRecognitionConfig): Promise<boolean> {
    if (this._isInitialized && this.recognizer) {
      hilog.info(DOMAIN, TAG, 'SpeechRecognitionService already initialized');
      return true;
    }

    try {
      // 更新配置
      if (config) {
        this.config = { ...this.config, ...config };
      }

      // 创建语音识别器
      this.recognizer = await speechRecognizer.createSpeechRecognizer();

      if (!this.recognizer) {
        throw new Error('Failed to create speech recognizer');
      }

      this._isInitialized = true;
      hilog.info(DOMAIN, TAG, 'SpeechRecognitionService initialized successfully');

      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(error)}`);
      this._state = SpeechRecognitionState.ERROR;
      return false;
    }
  }

  /**
   * 配置语音识别参数
   */
  private getRecognitionParams(): speechRecognizer.RecognitionParams {
    return {
      language: this.config.language || 'zh-CN',
      enablePunctuation: this.config.enablePunctuation ?? true,
      interimResults: this.config.enableInterimResults ?? true,
      maxSilenceDuration: this.config.maxSilenceDuration
    };
  }

  /**
   * 开始聆听
   * @returns 是否成功开始聆听
   */
  async startListening(): Promise<boolean> {
    // 如果已经在聆听，先停止
    if (this._state === SpeechRecognitionState.LISTENING) {
      hilog.warn(DOMAIN, TAG, 'Already listening, stopping first');
      await this.stopListening();
    }

    // 确保已初始化
    if (!this._isInitialized || !this.recognizer) {
      const initSuccess = await this.initialize();
      if (!initSuccess) {
        this.notifyError('初始化失败', '1001');
        return false;
      }
    }

    try {
      this._state = SpeechRecognitionState.LISTENING;
      this.interimText = '';
      this.notifyStateChange(SpeechRecognitionState.LISTENING);

      hilog.info(DOMAIN, TAG, 'Starting speech recognition...');

      // 设置识别事件监听
      this.setupRecognitionListeners();

      // 开始识别
      await this.recognizer!.start({
        language: this.config.language || 'zh-CN',
        enablePunctuation: this.config.enablePunctuation ?? true,
        interimResults: this.config.enableInterimResults ?? true
      });

      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Start listening failed: ${JSON.stringify(error)}`);
      this._state = SpeechRecognitionState.ERROR;
      this.notifyError(`启动聆听失败: ${error}`, '1002');
      return false;
    }
  }

  /**
   * 设置识别事件监听器
   */
  private setupRecognitionListeners(): void {
    if (!this.recognizer) {
      return;
    }

    // 识别开始事件
    this.recognizer.on('begin', () => {
      hilog.info(DOMAIN, TAG, 'Speech recognition began');
      promptAction.showToast({ message: '开始聆听...' });
    });

    // 识别结果事件
    this.recognizer.on('result', (result: speechRecognizer.SpeechRecognitionResult) => {
      hilog.info(DOMAIN, TAG, `Recognition result: ${result.text}, isFinal: ${result.isFinal}`);

      const recognitionResult: RecognitionResult = {
        text: result.text || '',
        confidence: result.confidence || 0,
        isFinal: result.isFinal || false
      };

      // 如果不是最终结果，更新中间文本
      if (!result.isFinal) {
        this.interimText = result.text || '';
      }

      this._lastResult = recognitionResult;
      this.notifyResult(recognitionResult);

      // 如果是最终结果，切换到处理状态
      if (result.isFinal) {
        this._state = SpeechRecognitionState.PROCESSING;
        this.notifyStateChange(SpeechRecognitionState.PROCESSING);
      }
    });

    // 识别结束事件
    this.recognizer.on('end', () => {
      hilog.info(DOMAIN, TAG, 'Speech recognition ended');
      if (this._state !== SpeechRecognitionState.ERROR) {
        this._state = SpeechRecognitionState.COMPLETED;
        this.notifyStateChange(SpeechRecognitionState.COMPLETED);
      }
    });

    // 识别错误事件
    this.recognizer.on('error', (error: speechRecognizer.SpeechRecognitionError) => {
      hilog.error(DOMAIN, TAG, `Recognition error: ${JSON.stringify(error)}`);
      this._state = SpeechRecognitionState.ERROR;
      this.notifyError(error.message || '识别错误', error.code?.toString() || '9999');
    });
  }

  /**
   * 停止聆听并获取识别结果
   * @returns 识别结果
   */
  async stopListening(): Promise<RecognitionResult | null> {
    if (!this.recognizer || this._state !== SpeechRecognitionState.LISTENING) {
      hilog.warn(DOMAIN, TAG, 'Not currently listening');
      return this._lastResult;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Stopping speech recognition...');

      // 停止识别
      await this.recognizer.stop();

      this._state = SpeechRecognitionState.PROCESSING;
      this.notifyStateChange(SpeechRecognitionState.PROCESSING);

      // 返回最后的结果
      return this._lastResult;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Stop listening failed: ${JSON.stringify(error)}`);
      this._state = SpeechRecognitionState.ERROR;
      this.notifyError(`停止聆听失败: ${error}`, '1003');
      return null;
    }
  }

  /**
   * 取消识别
   */
  async cancel(): Promise<void> {
    if (!this.recognizer) {
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Cancelling speech recognition');

      await this.recognizer.cancel();

      this._state = SpeechRecognitionState.IDLE;
      this._lastResult = null;
      this.interimText = '';
      this.notifyStateChange(SpeechRecognitionState.IDLE);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Cancel failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 获取中间识别文本（用于实时显示）
   * @returns 中间识别文本
   */
  getInterimText(): string {
    return this.interimText;
  }

  /**
   * 检查语音识别是否可用
   * @returns 是否可用
   */
  async isAvailable(): Promise<boolean> {
    try {
      // 尝试创建识别器来检查可用性
      const testRecognizer = await speechRecognizer.createSpeechRecognizer();
      if (testRecognizer) {
        hilog.info(DOMAIN, TAG, 'Speech recognition is available');
        return true;
      }
      return false;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `Speech recognition not available: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 设置识别语言
   * @param language 语言代码，如 'zh-CN', 'en-US'
   */
  setLanguage(language: string): void {
    this.config.language = language;
    hilog.info(DOMAIN, TAG, `Language set to: ${language}`);
  }

  /**
   * 获取当前语言
   * @returns 当前语言代码
   */
  getLanguage(): string {
    return this.config.language || 'zh-CN';
  }

  /**
   * 释放资源
   */
  release(): void {
    if (this.recognizer) {
      try {
        this.recognizer.cancel();
        hilog.info(DOMAIN, TAG, 'Speech recognizer released');
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Release error: ${JSON.stringify(error)}`);
      }
      this.recognizer = null;
    }

    this._isInitialized = false;
    this._state = SpeechRecognitionState.IDLE;
    this._lastResult = null;
    this.interimText = '';
  }

  /**
   * 通知识别结果
   */
  private notifyResult(result: RecognitionResult): void {
    if (this.onResultCallback) {
      this.onResultCallback(result);
    }
  }

  /**
   * 通知错误
   */
  private notifyError(message: string, code: string): void {
    const errorResult: RecognitionResult = {
      text: '',
      confidence: 0,
      isFinal: false,
      errorCode: code,
      errorMessage: message
    };

    this._lastResult = errorResult;

    if (this.onErrorCallback) {
      this.onErrorCallback(errorResult);
    }

    // 显示错误提示
    promptAction.showToast({ message: message });
  }

  /**
   * 通知状态变化
   */
  private notifyStateChange(state: SpeechRecognitionState): void {
    if (this.onStateChangeCallback) {
      this.onStateChangeCallback(state);
    }
  }
}
