/**
 * 跨设备面试准备页面
 * 支持多设备协同准备面试
 */
import { CrossDeviceInterviewService, DeviceInfo, InterviewPrepData, DeviceType } from '../services/CrossDeviceInterviewService';
import router from '@ohos.router';
import { colors } from '../constants/colors';
import { SemanticRadius } from '../constants/design-tokens';

@Entry
@Component
struct CrossDeviceInterviewPage {
  @State devices: DeviceInfo[] = [];
  @State preps: InterviewPrepData[] = [];
  @State selectedPrep: InterviewPrepData | null = null;
  @State isLoading: boolean = false;
  @State showDeviceSheet: boolean = false;
  @State showCreateSheet: boolean = false;

  // 新建面试准备表单
  @State newCompany: string = '';
  @State newPosition: string = '';
  @State newInterviewTime: string = '';

  async aboutToAppear() {
    this.isLoading = true;

    // 初始化跨设备服务
    await CrossDeviceInterviewService.initialize();

    // 获取设备列表
    this.devices = await CrossDeviceInterviewService.getAvailableDevices();

    // 获取面试准备列表
    this.preps = await CrossDeviceInterviewService.getAllInterviewPreps();

    this.isLoading = false;
  }

  aboutToDisappear() {
    CrossDeviceInterviewService.destroy();
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .onClick(() => {
            router.back();
          })

        Text('跨设备面试准备')
          .fontSize(18)
          .fontColor(Colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })

        Blank()

        // 设备列表按钮
        Badge({ count: this.devices.length, position: BadgePosition.RightTop }) {
          Image($r('app.media.ic_devices'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.showDeviceSheet = true;
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // 同步状态
      this.SyncStatusBar()

      // 内容区域
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(Colors.primary)

          Text('加载中...')
            .fontSize(14)
            .fontColor(Colors.textSecondary)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.preps.length === 0) {
        this.EmptyState()
      } else {
        this.PrepList()
      }

      // 底部新建按钮
      Row() {
        Button('新建面试准备')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor(Colors.surface)
          .backgroundColor(Colors.primary)
          .borderRadius(SemanticRadius.lg)
          .onClick(() => {
            this.showCreateSheet = true;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.background)
    .bindSheet($$this.showDeviceSheet, this.DeviceSheet(), {
      height: '50%',
      dragBar: true,
      backgroundColor: Colors.surface
    })
    .bindSheet($$this.showCreateSheet, this.CreatePrepSheet(), {
      height: '60%',
      dragBar: true,
      backgroundColor: Colors.surface
    })
  }

  @Builder
  SyncStatusBar() {
    Row() {
      Image($r('app.media.ic_sync'))
        .width(16)
        .height(16)
        .fontColor(Colors.textSecondary)

      Text(`已连接 ${this.devices.length} 台设备`)
        .fontSize(12)
        .fontColor(Colors.textSecondary)
        .margin({ left: 6 })

      Blank()

      Text('点击同步')
        .fontSize(12)
        .fontColor(Colors.primary)
        .onClick(async () => {
          // 手动同步
          for (const device of this.devices) {
            await CrossDeviceInterviewService.requestSyncFromDevice(device.deviceId);
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Colors.surfaceSecondary)
  }

  @Builder
  EmptyState() {
    Column() {
      Image($r('app.media.ic_empty_interview'))
        .width(120)
        .height(120)

      Text('暂无面试准备')
        .fontSize(16)
        .fontColor(Colors.textPrimary)
        .margin({ top: 16 })

      Text('创建面试准备，在多设备间同步')
        .fontSize(14)
        .fontColor(Colors.textSecondary)
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  PrepList() {
    List() {
      ForEach(this.preps, (prep: InterviewPrepData) => {
        ListItem() {
          this.PrepCard(prep)
        }
        .margin({ bottom: 12 })
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 12 })
  }

  @Builder
  PrepCard(prep: InterviewPrepData) {
    Column() {
      // 公司和职位
      Row() {
        Column() {
          Text(prep.company)
            .fontSize(16)
            .fontColor(Colors.textPrimary)
            .fontWeight(FontWeight.Medium)

          Text(prep.position)
            .fontSize(14)
            .fontColor(Colors.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 同步状态图标
        Image($r('app.media.ic_synced'))
          .width(20)
          .height(20)
          .fontColor(Colors.success)
      }
      .width('100%')

      // 面试时间
      Row() {
        Image($r('app.media.ic_time'))
          .width(16)
          .height(16)
          .fontColor(Colors.textSecondary)

        Text(prep.interviewTime)
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .margin({ left: 6 })
      }
      .margin({ top: 12 })

      // 检查清单进度
      Row() {
        Text('准备进度')
          .fontSize(12)
          .fontColor(Colors.textSecondary)

        Blank()

        Text(`${this.getCompletedCount(prep)}/${prep.checklist.length}`)
          .fontSize(12)
          .fontColor(Colors.primary)
      }
      .width('100%')
      .margin({ top: 12 })

      // 进度条
      Progress({
        value: this.getCompletedCount(prep),
        total: prep.checklist.length || 1,
        type: ProgressType.Linear
      })
        .width('100%')
        .color(Colors.primary)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.surface)
    .borderRadius(SemanticRadius.md)
    .onClick(() => {
      this.selectedPrep = prep;
      // 跳转到详情页
    })
  }

  @Builder
  DeviceSheet() {
    Column() {
      Text('已连接设备')
        .fontSize(18)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 16, bottom: 16 })

      if (this.devices.length === 0) {
        Column() {
          Text('暂无其他设备连接')
            .fontSize(14)
            .fontColor(Colors.textSecondary)

          Text('请确保其他设备已登录同一华为账号')
            .fontSize(12)
            .fontColor(Colors.textTertiary)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(32)
      } else {
        List() {
          ForEach(this.devices, (device: DeviceInfo) => {
            ListItem() {
              this.DeviceItem(device)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  DeviceItem(device: DeviceInfo) {
    Row() {
      // 设备图标
      Image(this.getDeviceIcon(device.deviceType))
        .width(40)
        .height(40)
        .fontColor(Colors.textSecondary)

      Column() {
        Text(device.deviceName)
          .fontSize(14)
          .fontColor(Colors.textPrimary)

        Text(this.getDeviceTypeLabel(device.deviceType))
          .fontSize(12)
          .fontColor(Colors.textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Blank()

      // 在线状态
      Circle()
        .width(8)
        .height(8)
        .fill(device.isOnline ? Colors.success : Colors.textTertiary)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  CreatePrepSheet() {
    Column() {
      Text('新建面试准备')
        .fontSize(18)
        .fontColor(Colors.textPrimary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .padding({ left: 16, bottom: 16 })

      // 公司输入
      Column() {
        Text('公司名称')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        TextInput({ placeholder: '请输入公司名称' })
          .width('100%')
          .height(44)
          .margin({ top: 8 })
          .onChange((value) => {
            this.newCompany = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      // 职位输入
      Column() {
        Text('应聘职位')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        TextInput({ placeholder: '请输入应聘职位' })
          .width('100%')
          .height(44)
          .margin({ top: 8 })
          .onChange((value) => {
            this.newPosition = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      // 面试时间
      Column() {
        Text('面试时间')
          .fontSize(14)
          .fontColor(Colors.textSecondary)
          .width('100%')

        TextInput({ placeholder: '请选择面试时间' })
          .width('100%')
          .height(44)
          .margin({ top: 8 })
          .onChange((value) => {
            this.newInterviewTime = value;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })

      Blank()

      // 创建按钮
      Button('创建并同步')
        .width('90%')
        .height(48)
        .fontSize(16)
        .fontColor(Colors.surface)
        .backgroundColor(Colors.primary)
        .borderRadius(SemanticRadius.lg)
        .enabled(this.newCompany.length > 0 && this.newPosition.length > 0)
        .onClick(async () => {
          const prep = await CrossDeviceInterviewService.createInterviewPrep({
            company: this.newCompany,
            position: this.newPosition,
            interviewTime: this.newInterviewTime,
            preparationNotes: [],
            keyQuestions: [],
            companyResearch: {
              overview: '',
              products: [],
              culture: '',
              recentNews: [],
              interviewExperiences: []
            },
            selfIntroduction: '',
            questionsToAsk: [],
            checklist: this.getDefaultChecklist()
          });

          if (prep) {
            this.preps = await CrossDeviceInterviewService.getAllInterviewPrep();
            this.showCreateSheet = false;
            this.newCompany = '';
            this.newPosition = '';
            this.newInterviewTime = '';
          }
        })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 24 })
  }

  private getCompletedCount(prep: InterviewPrepData): number {
    return prep.checklist.filter(item => item.completed).length;
  }

  private getDeviceIcon(type: DeviceType): Resource {
    switch (type) {
      case DeviceType.PHONE:
        return $r('app.media.ic_phone');
      case DeviceType.TABLET:
        return $r('app.media.ic_tablet');
      case DeviceType.WATCH:
        return $r('app.media.ic_watch');
      default:
        return $r('app.media.ic_device');
    }
  }

  private getDeviceTypeLabel(type: DeviceType): string {
    switch (type) {
      case DeviceType.PHONE:
        return '手机';
      case DeviceType.TABLET:
        return '平板';
      case DeviceType.WATCH:
        return '手表';
      case DeviceType.TV:
        return '电视';
      default:
        return '设备';
    }
  }

  private getDefaultChecklist(): any[] {
    return [
      { id: '1', content: '准备简历打印件', completed: false, category: 'document' },
      { id: '2', content: '准备作品集', completed: false, category: 'document' },
      { id: '3', content: '准备正装', completed: false, category: 'appearance' },
      { id: '4', content: '了解公司背景', completed: false, category: 'knowledge' },
      { id: '5', content: '准备自我介绍', completed: false, category: 'knowledge' },
      { id: '6', content: '准备提问问题', completed: false, category: 'knowledge' },
      { id: '7', content: '确认面试地点', completed: false, category: 'logistics' },
      { id: '8', content: '规划出行路线', completed: false, category: 'logistics' }
    ];
  }
}
