import { BackupExtensionAbility } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';

const TAG = 'BackupExtension';
const DOMAIN = 0xFF00;

export default class BackupExtension extends BackupExtensionAbility {
  onBackup(): void {
    hilog.info(DOMAIN, TAG, 'onBackup called');
    // 系统会自动备份应用沙箱内的数据
    // 包括 dataPreferences、文件系统等
  }

  onRestore(): void {
    hilog.info(DOMAIN, TAG, 'onRestore called');
    // 系统会自动恢复应用沙箱内的数据
  }
}
