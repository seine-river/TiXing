import AbilityStage from '@ohos.app.ability.AbilityStage';
import { TelemetryRouter } from '../services/telemetry/TelemetryRouter';

export default class EntryAbilityStage extends AbilityStage {
  onCreate(): void {
    // 友盟官方要求 preInit 尽早执行；真正 init 与 Bugly 启动等待用户同意后执行。
    TelemetryRouter.preInitialize(this.context);
  }
}
