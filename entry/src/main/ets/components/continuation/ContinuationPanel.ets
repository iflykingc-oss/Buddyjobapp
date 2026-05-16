/**
 * 跨设备流转面板组件
 * 提供设备选择、流转操作UI
 */
import { DistributedDeviceManager, DistributedDevice, DeviceType, DeviceState } from '../services/DistributedDeviceManager';
import { ContinuationManager, ContinuationState, ContinuationData, ContinuationDataBuilder } from '../services/ContinuationManager';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  BorderRadius,
  FontSize,
  FontWeight
} from '../../constants/design-tokens';

// 流转面板参数
interface ContinuationPanelProps {
  visible: boolean;
  currentPageUrl: string;
  currentPageParams?: Record<string, Object>;
  businessData?: Record<string, Object>;
  onContinuationSuccess?: (data: ContinuationData) => void;
  onContinuationFailed?: () => void;
  onClose: () => void;
}

@CustomDialog
export struct ContinuationPanel {
  controller: CustomDialogController;

  @Prop currentPageUrl: string = '';
  @Prop currentPageParams: Record<string, Object> = {};
  @Prop businessData: Record<string, Object> = ;
  
  @State devices: DistributedDevice[] = [];
  @State selectedDevice: DistributedDevice | null = null;
  @State isDiscovering: boolean = false;
  @State continuationState: ContinuationState = ContinuationState.IDLE;
  @State localDevice: DistributedDevice | null = null;

  private deviceManager: DistributedDeviceManager = DistributedDeviceManager.getInstance();
  private continuationManager: ContinuationManager = ContinuationManager.getInstance();

  aboutToAppear(): void {
    this.initializePanel();
  }

  private async initializePanel(): Promise<void> {
    // 获取本地设备信息
    this.localDevice = this.deviceManager.getLocalDeviceInfo();

    // 获取已发现设备
    this.devices = this.deviceManager.getOnlineDevices();

    // 开始设备发现
    this.isDiscovering = true;
    await this.deviceManager.startDeviceDiscovery();

    // 注册回调
    this.deviceManager.onDeviceDiscovery((devices) => {
      this.devices = devices.filter(d => d.deviceId !== this.localDevice?.deviceId);
    });

    this.continuationManager.registerCallback((state) => {
      this.continuationState = state;
    });
  }

  aboutToDisappear(): void {
    this.deviceManager.stopDeviceDiscovery();
  }

  build() {
    Column() {
      // 标题栏
      this.TitleBar();

      // 本地设备信息
      if (this.localDevice) {
        this.LocalDeviceInfo();
      }

      // 分隔线
      Divider().margin({ top: Spacing.Space3, bottom: Spacing.Space3 });

      // 设备列表
      if (this.isDiscovering && this.devices.length === 0) {
        this.DiscoveringState();
      } else if (this.devices.length === 0) {
        this.EmptyState();
      } else {
        this.DeviceList();
      }

      // 流转状态
      if (this.continuationState !== ContinuationState.IDLE) {
        this.ContinuationStatus();
      }

      // 底部按钮
      this.BottomActions();
    }
    .width('100%')
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius({ topLeft: BorderRadius.RadiusXL, topRight: BorderRadius.RadiusXL })
    .padding({ top: Spacing.Space4, bottom: Spacing.Space5 })
  }

  @Builder
  TitleBar() {
    Row() {
      Text('跨设备流转')
        .fontSize(FontSize.Size18)
        .fontWeight(FontWeight.Medium)
        .fontColor(NeutralColors.Neutral900);

      Blank();

      Image($r('app.media.media_ic_close'))
        .width(24)
        .height(24)
        .onClick(() => {
          this.controller.close();
        });
    }
    .width('100%')
    .padding({ left: Spacing.Space4, right: Spacing.Space4 });
  }

  @Builder
  LocalDeviceInfo() {
    if (!this.localDevice) {
      return;
    }
    Row() {
      Image(this.getDeviceIcon(this.localDevice.deviceType))
        .width(40)
        .height(40)
        .fillColor(BrandColors.Brand500);

      Column() {
        Text(this.localDevice.deviceName || '本机')
          .fontSize(FontSize.Size14)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral900);

        Text('当前设备')
          .fontSize(FontSize.Size12)
          .fontColor(NeutralColors.Neutral500)
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: Spacing.Space3 });

      Blank();

      // 本机标识
      Text('本机')
        .fontSize(FontSize.Size12)
        .fontColor(BrandColors.Brand500)
        .backgroundColor(BrandColors.Brand50)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(BorderRadius.RadiusSM);
    }
    .width('100%')
    .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space3 });
  }

  @Builder
  DiscoveringState() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(BrandColors.Brand500);

      Text('正在搜索附近设备...')
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral500)
        .margin({ top: Spacing.Space3 });

      Text('请确保其他设备已登录同一华为账号')
        .fontSize(FontSize.Size12)
        .fontColor(NeutralColors.Neutral400)
        .margin({ top: Spacing.Space2 });
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyState() {
    Column() {
      Image($r('app.media.media_ic_no_devices'))
        .width(80)
        .height(80)
        .fillColor(NeutralColors.Neutral300);

      Text('未发现其他设备')
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral500)
        .margin({ top: Spacing.Space3 });

      Text('请确保其他设备已开启蓝牙并登录同一华为账号')
        .fontSize(FontSize.Size12)
        .fontColor(NeutralColors.Neutral400)
        .margin({ top: Spacing.Space2 })
        .textAlign(TextAlign.Center)
        .width('80%');
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  DeviceList() {
    Column() {
      Row() {
        Text('可流转设备')
          .fontSize(FontSize.Size12)
          .fontColor(NeutralColors.Neutral500);

        Blank();

        if (this.isDiscovering) {
          Row() {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(BrandColors.Brand500);
            Text('搜索中')
              .fontSize(FontSize.Size12)
              .fontColor(BrandColors.Brand500)
              .margin({ left: 4 });
          }
        }
      }
      .width('100%')
      .padding({ left: Spacing.Space4, right: Spacing.Space4 });

      List() {
        ForEach(this.devices, (device: DistributedDevice) => {
          ListItem() {
            this.DeviceItem(device);
          }
        });
      }
      .width('100%')
      .height(200)
      .margin({ top: Spacing.Space2 });
    }
  }

  @Builder
  DeviceItem(device: DistributedDevice) {
    Row() {
      Image(this.getDeviceIcon(device.deviceType))
        .width(40)
        .height(40)
        .fillColor(this.selectedDevice?.deviceId === device.deviceId 
          ? BrandColors.Brand500 
          : NeutralColors.Neutral400);

      Column() {
        Text(device.deviceName)
          .fontSize(FontSize.Size14)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral900);

        Text(this.getDeviceTypeLabel(device.deviceType))
          .fontSize(FontSize.Size12)
          .fontColor(NeutralColors.Neutral500)
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: Spacing.Space3 });

      Blank();

      // 在线状态
      Circle()
        .width(8)
        .height(8)
        .fill(device.isOnline ? SemanticColors.Success.Success500 : NeutralColors.Neutral300);
    }
    .width('100%')
    .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space3, bottom: Spacing.Space3 })
    .backgroundColor(this.selectedDevice?.deviceId === device.deviceId 
      ? BrandColors.Brand50 
      : NeutralColors.Neutral0)
    .borderRadius(BorderRadius.RadiusMD)
    .onClick(() => {
      this.selectedDevice = device;
    });
  }

  @Builder
  ContinuationStatus() {
    Row() {
      if (this.continuationState === ContinuationState.PREPARING || 
          this.continuationState === ContinuationState.TRANSFERRING) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(BrandColors.Brand500);
        Text('正在流转...')
          .fontSize(FontSize.Size12)
          .fontColor(BrandColors.Brand500)
          .margin({ left: 8 });
      } else if (this.continuationState === ContinuationState.COMPLETED) {
        Image($r('app.media.media_ic_success'))
          .width(16)
          .height(16)
          .fillColor(SemanticColors.Success.Success500);
        Text('流转成功')
          .fontSize(FontSize.Size12)
          .fontColor(SemanticColors.Success.Success500)
          .margin({ left: 8 });
      } else if (this.continuationState === ContinuationState.FAILED) {
        Image($r('app.media.media_ic_error'))
          .width(16)
          .height(16)
          .fillColor(SemanticColors.Error.Error500);
        Text('流转失败')
          .fontSize(FontSize.Size12)
          .fontColor(SemanticColors.Error.Error500)
          .margin({ left: 8 });
      }
    }
    .width('100%')
    .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space3 });
  }

  @Builder
  BottomActions() {
    Row() {
      Button('取消')
        .width('40%')
        .height(44)
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral700)
        .backgroundColor(NeutralColors.Neutral100)
        .borderRadius(BorderRadius.RadiusLg)
        .onClick(() => {
          this.controller.close();
        });

      Button('开始流转')
        .width('55%')
        .height(44)
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral0)
        .backgroundColor(this.selectedDevice ? BrandColors.Brand500 : NeutralColors.Neutral300)
        .borderRadius(BorderRadius.RadiusLg)
        .enabled(this.selectedDevice !== null && 
                 this.continuationState === ContinuationState.IDLE)
        .onClick(async () => {
          if (this.selectedDevice) {
            const data = new ContinuationDataBuilder()
              .setPageUrl(this.currentPageUrl)
              .setPageParams(this.currentPageParams)
              .setBusinessData(this.businessData)
              .build();

            await this.continuationManager.startContinuation(this.selectedDevice, data);
          }
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space4 });
  }

  private getDeviceIcon(type: DeviceType): Resource {
    switch (type) {
      case DeviceType.PHONE:
        return $r('app.media.media_ic_phone');
      case DeviceType.TABLET:
        return $r('app.media.media_ic_tablet');
      case DeviceType.WATCH:
        return $r('app.media.media_ic_watch');
      case DeviceType.TV:
        return $r('app.media.media_ic_tv');
      case DeviceType.PC:
        return $r('app.media.media_ic_pc');
      default:
        return $r('app.media.media_ic_device');
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
      case DeviceType.PC:
        return '电脑';
      default:
        return '设备';
    }
  }
}
