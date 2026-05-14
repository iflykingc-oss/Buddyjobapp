/**
 * 简历创建引导页面
 * 5步引导用户完成完整简历创建
 * 
 * 步骤：
 * 1. 基本信息 - 姓名、联系方式等
 * 2. 教育经历 - 学校、专业、时间等
 * 3. 工作经历 - 公司、职位、工作内容等
 * 4. 项目经验 - 项目名称、描述、成果等
 * 5. 技能证书 - 技能列表、证书等
 * 
 * 设计规范：
 * - 使用鸿蒙设计令牌
 * - 支持暗黑模式
 * - 步骤进度指示器
 * - 草稿自动保存
 */

import promptAction from '@ohos.promptAction';
import { Router } from '../utils/Router';
import { Storage } from '../utils/storage';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  DarkSemanticColors,
  SuccessColors,
  WarningColors,
  ErrorColors,
  Spacing,
  SemanticSpacing,
  SemanticRadius,
  FontSize,
  FontWeight,
  Duration
} from '../constants/design-tokens';

// 简历草稿接口
export interface ResumeDraft {
  id: string;
  basicInfo: BasicInfo;
  education: Education[];
  workExperience: WorkExperience[];
  projects: Project[];
  skills: Skill[];
  updatedAt: number;
  createdAt: number;
}

// 基本信息
export interface BasicInfo {
  name: string;
  gender: string;
  age: string;
  phone: string;
  email: string;
  location: string;
  summary: string;
}

// 教育经历
export interface Education {
  id: string;
  school: string;
  major: string;
  degree: string;
  startDate: string;
  endDate: string;
  gpa: string;
  honors: string;
}

// 工作经历
export interface WorkExperience {
  id: string;
  company: string;
  position: string;
  startDate: string;
  endDate: string;
  description: string;
  achievements: string;
}

// 项目经验
export interface Project {
  id: string;
  name: string;
  role: string;
  startDate: string;
  endDate: string;
  description: string;
  results: string;
  technologies: string;
}

// 技能
export interface Skill {
  id: string;
  name: string;
  level: string;
  category: string;
}

// 步骤配置
interface StepConfig {
  title: string;
  subtitle: string;
  icon: string;
  exampleText: string;
}

// 步骤配置数组
const STEP_CONFIGS: StepConfig[] = [
  {
    title: '基本信息',
    subtitle: '填写您的个人基本信息',
    icon: 'ic_user',
    exampleText: '示例：张三 | 25岁 | 138xxxx8888 | zhangsan@email.com\n毕业于XX大学计算机专业，3年前端开发经验...'
  },
  {
    title: '教育经历',
    subtitle: '填写您的教育背景',
    icon: 'ic_education',
    exampleText: '示例：\n北京大学 | 计算机科学与技术 | 硕士 | 2019-2022\nGPA: 3.8/4.0 | 获国家奖学金、省优秀毕业生'
  },
  {
    title: '工作经历',
    subtitle: '描述您的工作经历',
    icon: 'ic_work',
    exampleText: '示例：\n字节跳动 | 前端开发工程师 | 2022.06-至今\n- 负责抖音直播后台前端架构设计与开发\n- 使用React+TypeScript，月活提升40%'
  },
  {
    title: '项目经验',
    subtitle: '展示您的项目经历',
    icon: 'ic_project',
    exampleText: '示例：\n电商平台重构 | 技术负责人 | 2023.01-2023.06\n- 主导微服务拆分，系统QPS提升5倍\n- 技术栈：Vue3+Node.js+Redis'
  },
  {
    title: '技能证书',
    subtitle: '列举您的技能和证书',
    icon: 'ic_skill',
    exampleText: '示例：\n技能：React、Vue、TypeScript、Node.js、Python\n证书：PMP、CPA、英语六级'
  }
];

// 存储键名
const STORAGE_KEY = 'resume_draft';

@Component
export struct ResumeGuide {
  // 当前步骤
  @State private currentStep: number = 0;
  // 简历草稿
  @State private draft: ResumeDraft = this.getEmptyDraft();
  // 是否展开示例
  @State private showExample: boolean = false;
  // 暗黑模式
  @StorageProp('isDarkMode') isDarkMode: boolean = false;
  // 保存状态
  @State private isSaving: boolean = false;
  // 输入框控制器
  private textControllers: Map<string, TextInputController> = new Map();

  // 获取空草稿
  private getEmptyDraft(): ResumeDraft {
    return {
      id: this.generateId(),
      basicInfo: {
        name: '',
        gender: '',
        age: '',
        phone: '',
        email: '',
        location: '',
        summary: ''
      },
      education: [{
        id: this.generateId(),
        school: '',
        major: '',
        degree: '',
        startDate: '',
        endDate: '',
        gpa: '',
        honors: ''
      }],
      workExperience: [{
        id: this.generateId(),
        company: '',
        position: '',
        startDate: '',
        endDate: '',
        description: '',
        achievements: ''
      }],
      projects: [{
        id: this.generateId(),
        name: '',
        role: '',
        startDate: '',
        endDate: '',
        description: '',
        results: '',
        technologies: ''
      }],
      skills: [{
        id: this.generateId(),
        name: '',
        level: '熟练',
        category: '专业技能'
      }],
      updatedAt: Date.now(),
      createdAt: Date.now()
    };
  }

  // 生成唯一ID
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substring(2);
  }

  aboutToAppear() {
    // 注册当前页面
    AppStorage.setOrCreate('currentPage', 'pages/ResumeGuide');
    // 加载草稿
    this.loadDraft();
  }

  // 加载草稿
  private async loadDraft(): Promise<void> {
    try {
      const savedDraft = await Storage.getInstance().getObject<ResumeDraft>(STORAGE_KEY);
      if (savedDraft) {
        this.draft = savedDraft;
      }
    } catch (error) {
      console.error('[ResumeGuide] Load draft failed:', error);
    }
  }

  // 保存草稿
  private async saveDraft(): Promise<void> {
    this.isSaving = true;
    try {
      this.draft.updatedAt = Date.now();
      await Storage.getInstance().setObject(STORAGE_KEY, this.draft);
      promptAction.showToast({
        message: '草稿已保存',
        duration: 1500
      });
    } catch (error) {
      console.error('[ResumeGuide] Save draft failed:', error);
      promptAction.showToast({
        message: '保存失败，请重试',
        duration: 1500
      });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      this.buildTitleBar()

      // 步骤指示器
      this.buildStepIndicator()

      // 步骤内容
      Scroll() {
        Column() {
          // 步骤标题和描述
          this.buildStepHeader()

          // 示例文本（可展开）
          this.buildExampleSection()

          // 输入表单
          this.buildFormContent()

          // 底部间距
          Column().height(100)
        }
        .width('100%')
        .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部按钮
      this.buildBottomButtons()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Background : SemanticColors.Background)
  }

  /**
   * 构建标题栏
   */
  @Builder
  buildTitleBar() {
    Row() {
      // 返回按钮
      Button() {
        Image($r('app.media.media_ic_back'))
          .width(24)
          .height(24)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
      }
      .backgroundColor('transparent')
      .width(40)
      .height(40)
      .onClick(() => {
        this.handleBack();
      })

      Text('创建简历')
        .fontSize(FontSize.Xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 保存草稿按钮
      Button() {
        if (this.isSaving) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(BrandColors.Brand500)
        } else {
          Text('保存')
            .fontSize(FontSize.Sm)
            .fontColor(BrandColors.Brand500)
        }
      }
      .backgroundColor('transparent')
      .width(50)
      .height(40)
      .onClick(() => {
        this.saveDraft();
      })
    }
    .width('100%')
    .height(56)
    .padding({ top: AppStorage.get<number>('topSafeArea') || 0, left: SemanticSpacing.Sm, right: SemanticSpacing.Sm })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 构建步骤指示器
   */
  @Builder
  buildStepIndicator() {
    Row() {
      ForEach(STEP_CONFIGS, (config: StepConfig, index: number) => {
        // 步骤点
        Column() {
          // 图标
          Stack() {
            // 背景圆
            Circle()
              .width(36)
              .height(36)
              .fill(this.getStepBgColor(index))

            // 数字或完成图标
            if (index < this.currentStep) {
              Image($r('app.media.media_ic_check'))
                .width(18)
                .height(18)
                .fillColor(NeutralColors.Neutral0)
            } else {
              Text(`${index + 1}`)
                .fontSize(FontSize.Base)
                .fontWeight(FontWeight.Bold)
                .fontColor(index === this.currentStep ? NeutralColors.Neutral0 : this.getStepTextColor(index))
            }
          }
          .width(36)
          .height(36)

          // 步骤名称
          Text(config.title)
            .fontSize(FontSize.Xs)
            .fontColor(index === this.currentStep ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3))
            .margin({ top: Spacing.Space2 })
        }

        // 连接线
        if (index < STEP_CONFIGS.length - 1) {
          Column()
            .width(24)
            .height(2)
            .backgroundColor(index < this.currentStep ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Border : NeutralColors.Neutral200))
            .margin({ bottom: 24 })
        }
      })
    }
    .width('100%')
    .padding({ top: SemanticSpacing.Lg, bottom: SemanticSpacing.Lg, left: SemanticSpacing.Xl, right: SemanticSpacing.Xl })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 获取步骤背景颜色
   */
  private getStepBgColor(index: number): string {
    if (index <= this.currentStep) {
      return BrandColors.Brand500;
    }
    return this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral200;
  }

  /**
   * 获取步骤文字颜色
   */
  private getStepTextColor(index: number): string {
    return this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3;
  }

  /**
   * 构建步骤头部
   */
  @Builder
  buildStepHeader() {
    Column() {
      // 步骤标题
      Text(STEP_CONFIGS[this.currentStep].title)
        .fontSize(FontSize.Xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .width('100%')

      // 步骤描述
      Text(STEP_CONFIGS[this.currentStep].subtitle)
        .fontSize(FontSize.Base)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ top: Spacing.Space2 })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: SemanticSpacing.Xl, bottom: SemanticSpacing.Lg })
  }

  /**
   * 构建示例区域
   */
  @Builder
  buildExampleSection() {
    Column() {
      // 示例标题行
      Row() {
        Image($r('app.media.media_ic_tip'))
          .width(16)
          .height(16)
          .fillColor(BrandColors.Brand500)

        Text('示例参考')
          .fontSize(FontSize.Sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(BrandColors.Brand500)
          .margin({ left: Spacing.Space2 })

        Blank()

        // 展开/收起按钮
        Image(this.showExample ? $r('app.media.media_ic_arrow_up') : $r('app.media.media_ic_arrow_down'))
          .width(16)
          .height(16)
          .fillColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .onClick(() => {
            animateTo({
              duration: Duration.Normal,
              curve: Curve.EaseInOut
            }, () => {
              this.showExample = !this.showExample;
            })
          })
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md, top: Spacing.Space3, bottom: Spacing.Space3 })
      .backgroundColor(BrandColors.Brand50)
      .borderRadius({ topLeft: SemanticRadius.Control, topRight: SemanticRadius.Control })
      .onClick(() => {
        animateTo({
          duration: Duration.Normal,
          curve: Curve.EaseInOut
        }, () => {
          this.showExample = !this.showExample;
        })
      })

      // 示例内容
      if (this.showExample) {
        Text(STEP_CONFIGS[this.currentStep].exampleText)
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .lineHeight(22)
          .width('100%')
          .padding(SemanticSpacing.Md)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius({ bottomLeft: SemanticRadius.Control, bottomRight: SemanticRadius.Control })
          .animation({
            duration: Duration.Normal,
            curve: Curve.EaseInOut
          })
      }
    }
    .width('100%')
    .margin({ bottom: SemanticSpacing.Lg })
  }

  /**
   * 构建表单内容
   */
  @Builder
  buildFormContent() {
    Column() {
      if (this.currentStep === 0) {
        this.buildBasicInfoForm()
      } else if (this.currentStep === 1) {
        this.buildEducationForm()
      } else if (this.currentStep === 2) {
        this.buildWorkExperienceForm()
      } else if (this.currentStep === 3) {
        this.buildProjectForm()
      } else if (this.currentStep === 4) {
        this.buildSkillsForm()
      }
    }
    .width('100%')
  }

  /**
   * 构建基本信息表单
   */
  @Builder
  buildBasicInfoForm() {
    Column() {
      // 姓名
      this.buildInputField('姓名', this.draft.basicInfo.name, (value) => {
        this.draft.basicInfo.name = value;
      }, '请输入姓名')

      // 性别
      this.buildGenderSelector()

      // 年龄
      this.buildInputField('年龄', this.draft.basicInfo.age, (value) => {
        this.draft.basicInfo.age = value;
      }, '请输入年龄')

      // 手机号
      this.buildInputField('手机号', this.draft.basicInfo.phone, (value) => {
        this.draft.basicInfo.phone = value;
      }, '请输入手机号')

      // 邮箱
      this.buildInputField('邮箱', this.draft.basicInfo.email, (value) => {
        this.draft.basicInfo.email = value;
      }, '请输入邮箱')

      // 所在地
      this.buildInputField('所在地', this.draft.basicInfo.location, (value) => {
        this.draft.basicInfo.location = value;
      }, '如：北京、上海')

      // 个人简介
      this.buildTextAreaField('个人简介', this.draft.basicInfo.summary, (value) => {
        this.draft.basicInfo.summary = value;
      }, '简要描述您的职业背景和优势')
    }
    .width('100%')
  }

  /**
   * 构建性别选择器
   */
  @Builder
  buildGenderSelector() {
    Column() {
      Text('性别')
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ bottom: Spacing.Space2 })

      Row() {
        ForEach(['男', '女', '保密'], (gender: string) => {
          Column() {
            Text(gender)
              .fontSize(FontSize.Base)
              .fontColor(this.draft.basicInfo.gender === gender ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1))
          }
          .padding({ left: Spacing.Space6, right: Spacing.Space6, top: Spacing.Space3, bottom: Spacing.Space3 })
          .backgroundColor(this.draft.basicInfo.gender === gender ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
          .borderRadius(SemanticRadius.Pill)
          .onClick(() => {
            this.draft.basicInfo.gender = gender;
          })
        })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: SemanticSpacing.Md })
  }

  /**
   * 构建教育经历表单
   */
  @Builder
  buildEducationForm() {
    Column() {
      ForEach(this.draft.education, (edu: Education, index: number) => {
        Column() {
          // 学校名称
          this.buildInputField('学校名称', edu.school, (value) => {
            this.draft.education[index].school = value;
          }, '请输入学校名称')

          // 专业
          this.buildInputField('专业', edu.major, (value) => {
            this.draft.education[index].major = value;
          }, '请输入专业')

          // 学历
          this.buildDegreeSelector(index)

          // 时间范围
          Row() {
            this.buildDateInput('开始时间', edu.startDate, (value) => {
              this.draft.education[index].startDate = value;
            }, true)
            Text('-')
              .fontSize(FontSize.Lg)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3, right: Spacing.Space3 })
            this.buildDateInput('结束时间', edu.endDate, (value) => {
              this.draft.education[index].endDate = value;
            }, false)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Md })

          // GPA
          this.buildInputField('GPA', edu.gpa, (value) => {
            this.draft.education[index].gpa = value;
          }, '如：3.8/4.0')

          // 荣誉奖项
          this.buildTextAreaField('荣誉奖项', edu.honors, (value) => {
            this.draft.education[index].honors = value;
          }, '如：国家奖学金、省优秀毕业生')

          // 添加更多按钮
          if (index === this.draft.education.length - 1) {
            Button() {
              Row() {
                Image($r('app.media.media_ic_add'))
                  .width(16)
                  .height(16)
                  .fillColor(BrandColors.Brand500)
                Text('添加更多教育经历')
                  .fontSize(FontSize.Sm)
                  .fontColor(BrandColors.Brand500)
                  .margin({ left: Spacing.Space2 })
              }
            }
            .backgroundColor('transparent')
            .margin({ top: SemanticSpacing.Md })
            .onClick(() => {
              this.draft.education.push({
                id: this.generateId(),
                school: '',
                major: '',
                degree: '',
                startDate: '',
                endDate: '',
                gpa: '',
                honors: ''
              });
            })
          }
        }
        .width('100%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ bottom: SemanticSpacing.Md })
      })
    }
    .width('100%')
  }

  /**
   * 构建学历选择器
   */
  @Builder
  buildDegreeSelector(index: number) {
    Column() {
      Text('学历')
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ bottom: Spacing.Space2 })

      Row() {
        ForEach(['博士', '硕士', '本科', '大专', '其他'], (degree: string) => {
          Column() {
            Text(degree)
              .fontSize(FontSize.Sm)
              .fontColor(this.draft.education[index].degree === degree ? NeutralColors.Neutral0 : (this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2))
          }
          .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
          .backgroundColor(this.draft.education[index].degree === degree ? BrandColors.Brand500 : (this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100))
          .borderRadius(SemanticRadius.Pill)
          .margin({ right: Spacing.Space2 })
          .onClick(() => {
            this.draft.education[index].degree = degree;
          })
        })
      }
      .width('100%')
      .margin({ bottom: SemanticSpacing.Md })
    }
    .width('100%')
  }

  /**
   * 构建工作经历表单
   */
  @Builder
  buildWorkExperienceForm() {
    Column() {
      ForEach(this.draft.workExperience, (work: WorkExperience, index: number) => {
        Column() {
          // 公司名称
          this.buildInputField('公司名称', work.company, (value) => {
            this.draft.workExperience[index].company = value;
          }, '请输入公司名称')

          // 职位
          this.buildInputField('职位', work.position, (value) => {
            this.draft.workExperience[index].position = value;
          }, '请输入职位名称')

          // 时间范围
          Row() {
            this.buildDateInput('开始时间', work.startDate, (value) => {
              this.draft.workExperience[index].startDate = value;
            }, true)
            Text('-')
              .fontSize(FontSize.Lg)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3, right: Spacing.Space3 })
            this.buildDateInput('结束时间', work.endDate, (value) => {
              this.draft.workExperience[index].endDate = value;
            }, false)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Md })

          // 工作描述
          this.buildTextAreaField('工作描述', work.description, (value) => {
            this.draft.workExperience[index].description = value;
          }, '描述您的主要工作内容和职责')

          // 工作成果
          this.buildTextAreaField('工作成果', work.achievements, (value) => {
            this.draft.workExperience[index].achievements = value;
          }, '量化您的成果，如：提升效率30%')

          // 添加更多按钮
          if (index === this.draft.workExperience.length - 1) {
            Button() {
              Row() {
                Image($r('app.media.media_ic_add'))
                  .width(16)
                  .height(16)
                  .fillColor(BrandColors.Brand500)
                Text('添加更多工作经历')
                  .fontSize(FontSize.Sm)
                  .fontColor(BrandColors.Brand500)
                  .margin({ left: Spacing.Space2 })
              }
            }
            .backgroundColor('transparent')
            .margin({ top: SemanticSpacing.Md })
            .onClick(() => {
              this.draft.workExperience.push({
                id: this.generateId(),
                company: '',
                position: '',
                startDate: '',
                endDate: '',
                description: '',
                achievements: ''
              });
            })
          }
        }
        .width('100%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ bottom: SemanticSpacing.Md })
      })
    }
    .width('100%')
  }

  /**
   * 构建项目经验表单
   */
  @Builder
  buildProjectForm() {
    Column() {
      ForEach(this.draft.projects, (project: Project, index: number) => {
        Column() {
          // 项目名称
          this.buildInputField('项目名称', project.name, (value) => {
            this.draft.projects[index].name = value;
          }, '请输入项目名称')

          // 项目角色
          this.buildInputField('项目角色', project.role, (value) => {
            this.draft.projects[index].role = value;
          }, '如：技术负责人、前端开发')

          // 时间范围
          Row() {
            this.buildDateInput('开始时间', project.startDate, (value) => {
              this.draft.projects[index].startDate = value;
            }, true)
            Text('-')
              .fontSize(FontSize.Lg)
              .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
              .margin({ left: Spacing.Space3, right: Spacing.Space3 })
            this.buildDateInput('结束时间', project.endDate, (value) => {
              this.draft.projects[index].endDate = value;
            }, false)
          }
          .width('100%')
          .margin({ bottom: SemanticSpacing.Md })

          // 项目描述
          this.buildTextAreaField('项目描述', project.description, (value) => {
            this.draft.projects[index].description = value;
          }, '描述项目背景和您的职责')

          // 项目成果
          this.buildTextAreaField('项目成果', project.results, (value) => {
            this.draft.projects[index].results = value;
          }, '量化项目成果，如：系统性能提升50%')

          // 技术栈
          this.buildInputField('技术栈', project.technologies, (value) => {
            this.draft.projects[index].technologies = value;
          }, '如：React、Node.js、MySQL')

          // 添加更多按钮
          if (index === this.draft.projects.length - 1) {
            Button() {
              Row() {
                Image($r('app.media.media_ic_add'))
                  .width(16)
                  .height(16)
                  .fillColor(BrandColors.Brand500)
                Text('添加更多项目')
                  .fontSize(FontSize.Sm)
                  .fontColor(BrandColors.Brand500)
                  .margin({ left: Spacing.Space2 })
              }
            }
            .backgroundColor('transparent')
            .margin({ top: SemanticSpacing.Md })
            .onClick(() => {
              this.draft.projects.push({
                id: this.generateId(),
                name: '',
                role: '',
                startDate: '',
                endDate: '',
                description: '',
                results: '',
                technologies: ''
              });
            })
          }
        }
        .width('100%')
        .padding(SemanticSpacing.Lg)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
        .borderRadius(SemanticRadius.Component)
        .margin({ bottom: SemanticSpacing.Md })
      })
    }
    .width('100%')
  }

  /**
   * 构建技能表单
   */
  @Builder
  buildSkillsForm() {
    Column() {
      // 技能标签输入
      Column() {
        Text('专业技能')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ bottom: Spacing.Space2 })

        Text('输入技能名称，按回车添加')
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ bottom: Spacing.Space3 })

        // 技能标签
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.draft.skills.filter(s => s.category === '专业技能'), (skill: Skill, index: number) => {
            Row() {
              Text(skill.name)
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)

              Image($r('app.media.media_ic_close'))
                .width(12)
                .height(12)
                .fillColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
                .onClick(() => {
                  this.draft.skills = this.draft.skills.filter(s => s.id !== skill.id);
                })
            }
            .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
            .backgroundColor(BrandColors.Brand500)
            .borderRadius(SemanticRadius.Pill)
            .margin({ right: Spacing.Space2, bottom: Spacing.Space2 })
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(SemanticSpacing.Lg)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius(SemanticRadius.Component)
      .margin({ bottom: SemanticSpacing.Md })

      // 证书
      Column() {
        Text('证书资质')
          .fontSize(FontSize.Sm)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
          .margin({ bottom: Spacing.Space2 })

        Text('输入证书名称，按回车添加')
          .fontSize(FontSize.Xs)
          .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
          .margin({ bottom: Spacing.Space3 })

        // 证书标签
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.draft.skills.filter(s => s.category === '证书资质'), (skill: Skill, index: number) => {
            Row() {
              Text(skill.name)
                .fontSize(FontSize.Sm)
                .fontColor(NeutralColors.Neutral0)

              Image($r('app.media.media_ic_close'))
                .width(12)
                .height(12)
                .fillColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
                .onClick(() => {
                  this.draft.skills = this.draft.skills.filter(s => s.id !== skill.id);
                })
            }
            .padding({ left: Spacing.Space3, right: Spacing.Space3, top: Spacing.Space2, bottom: Spacing.Space2 })
            .backgroundColor(SuccessColors.Success500)
            .borderRadius(SemanticRadius.Pill)
            .margin({ right: Spacing.Space2, bottom: Spacing.Space2 })
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(SemanticSpacing.Lg)
      .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
      .borderRadius(SemanticRadius.Component)
    }
    .width('100%')
  }

  /**
   * 构建输入字段
   */
  @Builder
  buildInputField(
    label: string,
    value: string,
    onChange: (value: string) => void,
    placeholder: string
  ) {
    Column() {
      Text(label)
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ bottom: Spacing.Space2 })

      TextInput({ placeholder: placeholder, text: value })
        .fontSize(FontSize.Base)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .placeholderColor(this.isDarkMode ? DarkSemanticColors.Text4 : NeutralColors.Neutral400)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
        .borderRadius(SemanticRadius.Control)
        .height(44)
        .width('100%')
        .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md })
        .onChange((newValue: string) => {
          onChange(newValue);
        })
    }
    .width('100%')
    .margin({ bottom: SemanticSpacing.Md })
  }

  /**
   * 构建日期输入
   */
  @Builder
  buildDateInput(
    label: string,
    value: string,
    onChange: (value: string) => void,
    isStart: boolean
  ) {
    Column() {
      Text(label)
        .fontSize(FontSize.Xs)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text3 : SemanticColors.Text3)
        .margin({ bottom: Spacing.Space1 })

      TextInput({ placeholder: isStart ? '开始时间' : '至今', text: value })
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .placeholderColor(this.isDarkMode ? DarkSemanticColors.Text4 : NeutralColors.Neutral400)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
        .borderRadius(SemanticRadius.Control)
        .height(40)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: Spacing.Space3, right: Spacing.Space3 })
        .onChange((newValue: string) => {
          onChange(newValue);
        })
    }
    .layoutWeight(1)
  }

  /**
   * 构建多行文本域
   */
  @Builder
  buildTextAreaField(
    label: string,
    value: string,
    onChange: (value: string) => void,
    placeholder: string
  ) {
    Column() {
      Text(label)
        .fontSize(FontSize.Sm)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text2 : SemanticColors.Text2)
        .margin({ bottom: Spacing.Space2 })

      TextArea({ placeholder: placeholder, text: value })
        .fontSize(FontSize.Base)
        .fontColor(this.isDarkMode ? DarkSemanticColors.Text1 : SemanticColors.Text1)
        .placeholderColor(this.isDarkMode ? DarkSemanticColors.Text4 : NeutralColors.Neutral400)
        .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface2 : NeutralColors.Neutral100)
        .borderRadius(SemanticRadius.Control)
        .height(88)
        .width('100%')
        .padding({ left: SemanticSpacing.Md, right: SemanticSpacing.Md, top: Spacing.Space3 })
        .onChange((newValue: string) => {
          onChange(newValue);
        })
    }
    .width('100%')
    .margin({ bottom: SemanticSpacing.Md })
  }

  /**
   * 构建底部按钮
   */
  @Builder
  buildBottomButtons() {
    Column() {
      Row() {
        // 上一步按钮
        if (this.currentStep > 0) {
          Button() {
            Row() {
              Image($r('app.media.media_ic_arrow_left'))
                .width(16)
                .height(16)
                .fillColor(BrandColors.Brand500)
              Text('上一步')
                .fontSize(FontSize.Base)
                .fontColor(BrandColors.Brand500)
                .margin({ left: Spacing.Space2 })
            }
          }
          .backgroundColor('transparent')
          .border({ width: 1, color: BrandColors.Brand500 })
          .borderRadius(SemanticRadius.Pill)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.goToPrevStep();
          })
        }

        if (this.currentStep > 0) {
          Blank().width(Spacing.Space4)
        }

        // 下一步/完成按钮
        if (this.currentStep < STEP_CONFIGS.length - 1) {
          Button() {
            Row() {
              Text('下一步')
                .fontSize(FontSize.Base)
                .fontColor(NeutralColors.Neutral0)
              Image($r('app.media.media_ic_arrow_right'))
                .width(16)
                .height(16)
                .fillColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
            }
          }
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(SemanticRadius.Pill)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.goToNextStep();
          })
        } else {
          Button() {
            Row() {
              Text('完成创建')
                .fontSize(FontSize.Base)
                .fontColor(NeutralColors.Neutral0)
              Image($r('app.media.media_ic_check'))
                .width(16)
                .height(16)
                .fillColor(NeutralColors.Neutral0)
                .margin({ left: Spacing.Space2 })
            }
          }
          .backgroundColor(SuccessColors.Success500)
          .borderRadius(SemanticRadius.Pill)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.handleComplete();
          })
        }
      }
      .width('100%')
      .padding({ left: SemanticSpacing.Lg, right: SemanticSpacing.Lg })
    }
    .width('100%')
    .padding({ top: Spacing.Space4, bottom: Spacing.Space4 })
    .backgroundColor(this.isDarkMode ? DarkSemanticColors.Surface1 : SemanticColors.Surface1)
  }

  /**
   * 下一步
   */
  private goToNextStep(): void {
    if (this.currentStep < STEP_CONFIGS.length - 1) {
      animateTo({
        duration: Duration.Normal,
        curve: Curve.EaseInOut
      }, () => {
        this.currentStep++;
      })
    }
  }

  /**
   * 上一步
   */
  private goToPrevStep(): void {
    if (this.currentStep > 0) {
      animateTo({
        duration: Duration.Normal,
        curve: Curve.EaseInOut
      }, () => {
        this.currentStep--;
      })
    }
  }

  /**
   * 处理返回
   */
  private handleBack(): void {
    if (this.currentStep > 0) {
      // 先保存草稿再返回
      this.saveDraft();
    }
    Router.back();
  }

  /**
   * 处理完成
   */
  private async handleComplete(): Promise<void> {
    // 保存最终草稿
    await this.saveDraft();

    // 显示成功提示
    promptAction.showToast({
      message: '简历创建成功',
      duration: 2000
    });

    // 返回简历页面
    Router.back();
  }
}

export default ResumeGuide;
