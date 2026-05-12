/**
 * 权限引导组件
 * 提供友好的权限申请引导界面
 */
import { PermissionManager, PermissionType, PermissionStatus, PermissionGroup } from '../services/PermissionManager';
import {
  BrandColors,
  NeutralColors,
  SemanticColors,
  Spacing,
  BorderRadius,
  FontSize,
  FontWeight
} from '../constants/design-tokens';

// 权限引导配置
interface PermissionGuideConfig {
  permissions: PermissionType[];
  title: string;
  description: string;
  icon: Resource;
  onComplete?: (allGranted: boolean) => void;
}

@CustomDialog
export struct PermissionGuideDialog {
  controller: CustomDialogController;
  
  @Prop permissions: PermissionType[] = [];
  @Prop title: string = '需要权限';
  @Prop description: string = '';
  @Prop icon: Resource = $r('app.media.ic_permission');
  @Prop onComplete?: (allGranted: boolean) => void;

  @State permissionStatuses: Map<PermissionType, PermissionStatus> = new Map();
  @State isRequesting: boolean = false;
  @State currentIndex: number = 0;

  private permissionManager: PermissionManager = PermissionManager.getInstance();

  aboutToAppear(): void {
    this.checkAllPermissions();
  }

  private async checkAllPermissions(): Promise<void> {
    this.permissionStatuses = await this.permissionManager.checkPermissions(this.permissions);
  }

  build() {
    Column() {
      // 图标
      Image(this.icon)
        .width(64)
        .height(64)
        .fillColor(BrandColors.Brand500);

      // 标题
      Text(this.title)
        .fontSize(FontSize.Size20)
        .fontWeight(FontWeight.Medium)
        .fontColor(NeutralColors.Neutral900)
        .margin({ top: Spacing.Space4 });

      // 描述
      Text(this.description)
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral500)
        .textAlign(TextAlign.Center)
        .margin({ top: Spacing.Space2 })
        .width('85%');

      // 权限列表
      Column() {
        ForEach(this.permissions, (permission: PermissionType) => {
          this.PermissionItem(permission);
        });
      }
      .width('100%')
      .margin({ top: Spacing.Space5 });

      // 按钮
      Row() {
        Button('稍后再说')
          .width('40%')
          .height(44)
          .fontSize(FontSize.Size14)
          .fontColor(NeutralColors.Neutral700)
          .backgroundColor(NeutralColors.Neutral100)
          .borderRadius(BorderRadius.RadiusLG)
          .onClick(() => {
            this.controller.close();
          });

        Button('授予权限')
          .width('55%')
          .height(44)
          .fontSize(FontSize.Size14)
          .fontColor(NeutralColors.Neutral0)
          .backgroundColor(BrandColors.Brand500)
          .borderRadius(BorderRadius.RadiusLG)
          .enabled(!this.isRequesting)
          .onClick(async () => {
            await this.requestAllPermissions();
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: Spacing.Space5 });
    }
    .width('100%')
    .padding(Spacing.Space5)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(BorderRadius.RadiusXL);
  }

  @Builder
  PermissionItem(permission: PermissionType) {
    Row() {
      Column() {
        Text(this.getPermissionLabel(permission))
          .fontSize(FontSize.Size14)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral900);

        Text(this.getPermissionReason(permission))
          .fontSize(FontSize.Size12)
          .fontColor(NeutralColors.Neutral500)
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start);

      Blank();

      // 状态图标
      if (this.permissionStatuses.get(permission)?.granted) {
        Image($r('app.media.ic_check_circle'))
          .width(24)
          .height(24)
          .fillColor(SemanticColors.Success.Success500);
      } else if (this.isRequesting) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(BrandColors.Brand500);
      } else {
        Image($r('app.media.ic_arrow_right'))
          .width(24)
          .height(24)
          .fillColor(NeutralColors.Neutral400);
      }
    }
    .width('100%')
    .padding({ top: Spacing.Space3, bottom: Spacing.Space3 });
  }

  private async requestAllPermissions(): Promise<void> {
    this.isRequesting = true;

    const results = await this.permissionManager.requestPermissions(this.permissions);
    
    // 更新状态
    await this.checkAllPermissions();
    this.isRequesting = false;

    // 检查是否全部授权
    const allGranted = Array.from(results.values()).every(granted => granted);
    
    if (this.onComplete) {
      this.onComplete(allGranted);
    }

    if (allGranted) {
      this.controller.close();
    }
  }

  private getPermissionLabel(permission: PermissionType): string {
    const config = this.permissionManager.getPermissionConfig(permission);
    return config?.label || permission;
  }

  private getPermissionReason(permission: PermissionType): string {
    const config = this.permissionManager.getPermissionConfig(permission);
    return config?.reason || '';
  }
}

/**
 * 权限状态卡片组件
 */
@Component
export struct PermissionStatusCard {
  @Prop permission: PermissionType = PermissionType.INTERNET;
  @State status: PermissionStatus | null = null;

  private permissionManager: PermissionManager = PermissionManager.getInstance();

  aboutToAppear(): void {
    this.checkStatus();
  }

  private async checkStatus(): Promise<void> {
    this.status = await this.permissionManager.checkPermission(this.permission);
  }

  build() {
    Row() {
      Image(this.getPermissionIcon())
        .width(40)
        .height(40)
        .fillColor(this.status?.granted ? SemanticColors.Success.Success500 : NeutralColors.Neutral400);

      Column() {
        Text(this.getPermissionLabel())
          .fontSize(FontSize.Size14)
          .fontWeight(FontWeight.Medium)
          .fontColor(NeutralColors.Neutral900);

        Text(this.status?.granted ? '已授权' : '未授权')
          .fontSize(FontSize.Size12)
          .fontColor(this.status?.granted ? SemanticColors.Success.Success500 : NeutralColors.Neutral500)
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: Spacing.Space3 });

      Blank();

      if (!this.status?.granted && this.status?.canRequest) {
        Button('授权')
          .height(32)
          .fontSize(FontSize.Size12)
          .fontColor(BrandColors.Brand500)
          .backgroundColor(BrandColors.Brand50)
          .borderRadius(BorderRadius.RadiusSM)
          .onClick(async () => {
            await this.permissionManager.requestPermission(this.permission);
            await this.checkStatus();
          });
      } else if (!this.status?.granted) {
        Button('设置')
          .height(32)
          .fontSize(FontSize.Size12)
          .fontColor(NeutralColors.Neutral500)
          .backgroundColor(NeutralColors.Neutral100)
          .borderRadius(BorderRadius.RadiusSM)
          .onClick(() => {
            this.permissionManager.openPermissionSettings();
          });
      }
    }
    .width('100%')
    .padding(Spacing.Space4)
    .backgroundColor(NeutralColors.Neutral0)
    .borderRadius(BorderRadius.RadiusLG);
  }

  private getPermissionLabel(): string {
    const config = this.permissionManager.getPermissionConfig(this.permission);
    return config?.label || this.permission;
  }

  private getPermissionIcon(): Resource {
    const config = this.permissionManager.getPermissionConfig(this.permission);
    switch (config?.group) {
      case PermissionGroup.NETWORK:
        return $r('app.media.ic_permission_network');
      case PermissionGroup.STORAGE:
        return $r('app.media.ic_permission_storage');
      case PermissionGroup.MEDIA:
        return $r('app.media.ic_permission_media');
      case PermissionGroup.BIOMETRIC:
        return $r('app.media.ic_permission_biometric');
      case PermissionGroup.LOCATION:
        return $r('app.media.ic_permission_location');
      case PermissionGroup.DISTRIBUTED:
        return $r('app.media.ic_permission_distributed');
      default:
        return $r('app.media.ic_permission');
    }
  }
}

/**
 * 权限检查页面
 */
@Component
export struct PermissionCheckPage {
  @State permissionGroups: Map<PermissionGroup, PermissionType[]> = new Map();
  @State allGranted: boolean = false;

  private permissionManager: PermissionManager = PermissionManager.getInstance();

  aboutToAppear(): void {
    this.initPermissionGroups();
  }

  private initPermissionGroups(): void {
    this.permissionGroups.set(PermissionGroup.NETWORK, [
      PermissionType.INTERNET,
      PermissionType.GET_NETWORK_INFO
    ]);
    this.permissionGroups.set(PermissionGroup.STORAGE, [
      PermissionType.READ_FILE,
      PermissionType.WRITE_FILE
    ]);
    this.permissionGroups.set(PermissionGroup.MEDIA, [
      PermissionType.READ_MEDIA,
      PermissionType.WRITE_MEDIA,
      PermissionType.READ_IMAGEVIDEO,
      PermissionType.WRITE_IMAGEVIDEO
    ]);
    this.permissionGroups.set(PermissionGroup.BIOMETRIC, [
      PermissionType.ACCESS_BIOMETRIC
    ]);
    this.permissionGroups.set(PermissionGroup.DISTRIBUTED, [
      PermissionType.DISTRIBUTED_DATASYNC
    ]);
  }

  build() {
    Column() {
      // 标题
      Text('权限管理')
        .fontSize(FontSize.Size24)
        .fontWeight(FontWeight.Bold)
        .fontColor(NeutralColors.Neutral900)
        .width('100%')
        .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space5 });

      Text('管理应用所需权限，保障您的隐私安全')
        .fontSize(FontSize.Size14)
        .fontColor(NeutralColors.Neutral500)
        .width('100%')
        .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space2 });

      // 权限组列表
      List() {
        ForEach(Array.from(this.permissionGroups.keys()), (group: PermissionGroup) => {
          ListItem() {
            this.PermissionGroupSection(group);
          }
        });
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: Spacing.Space4, right: Spacing.Space4, top: Spacing.Space4 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(NeutralColors.Neutral50);
  }

  @Builder
  PermissionGroupSection(group: PermissionGroup) {
    Column() {
      // 分组标题
      Text(this.getGroupTitle(group))
        .fontSize(FontSize.Size12)
        .fontColor(NeutralColors.Neutral500)
        .width('100%')
        .margin({ bottom: Spacing.Space2 });

      // 权限项
      Column() {
        ForEach(this.permissionGroups.get(group) || [], (permission: PermissionType) => {
          PermissionStatusCard({ permission: permission });
        });
      }
      .width('100%')
      .backgroundColor(NeutralColors.Neutral0)
      .borderRadius(BorderRadius.RadiusLG)
      .padding(Spacing.Space2);
    }
    .width('100%')
    .margin({ bottom: Spacing.Space4 });
  }

  private getGroupTitle(group: PermissionGroup): string {
    switch (group) {
      case PermissionGroup.NETWORK:
        return '网络权限';
      case PermissionGroup.STORAGE:
        return '存储权限';
      case PermissionGroup.MEDIA:
        return '媒体权限';
      case PermissionGroup.BIOMETRIC:
        return '生物识别';
      case PermissionGroup.LOCATION:
        return '位置权限';
      case PermissionGroup.DISTRIBUTED:
        return '分布式权限';
      default:
        return '其他权限';
    }
  }
}
