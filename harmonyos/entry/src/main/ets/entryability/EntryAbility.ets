import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PerformanceMonitor } from '../services/PerformanceMonitor';
import { AppContextHolder } from '../common/AppContext';

const DOMAIN: number = 0xA001;
const TAG: string = 'TiXing';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    PerformanceMonitor.init();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 供 Toast 等工具类实时获取主窗口 UIContext（T041）
    AppContextHolder.setWindowStage(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    try {
      // 跟随系统深浅色模式（颜色经 base/dark 限定词资源自动适配）
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 深浅色切换（T041/FR-022）：记录配置变化；颜色资源由限定词目录自动跟随，无需代码切换。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    const mode: string = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      ? 'dark' : (newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? 'light' : `${newConfig.colorMode}`);
    hilog.info(DOMAIN, TAG, 'configuration updated, colorMode: %{public}s', mode);
    PerformanceMonitor.writeBehavior('color_mode_change', { 'mode': mode });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
