import fs from '@ohos.file.fs';
import media from '@ohos.multimedia.media';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const LOG_DOMAIN: number = 0xA008;
const LOG_TAG: string = 'TiXingAudioPlay';

/** 原始录音回放：孩子以后可以点开听见当时的自己。 */
export class AudioPlaybackService {
  private static player: media.AVPlayer | undefined = undefined;
  private static file: fs.File | undefined = undefined;

  static get playing(): boolean {
    return AudioPlaybackService.player !== undefined;
  }

  static async play(path: string, onFinished: () => void = (): void => {
  }): Promise<void> {
    await AudioPlaybackService.stop();
    try {
      AudioPlaybackService.file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      AudioPlaybackService.player = await media.createAVPlayer();
      AudioPlaybackService.player.on('stateChange', (state: string, _reason: media.StateChangeReason) => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'player state: %{public}s', state);
        if (state === 'completed' || state === 'stopped' || state === 'idle') {
          AudioPlaybackService.stop().catch((_e: Object): void => {
          });
          onFinished();
        }
      });
      AudioPlaybackService.player.on('error', (error: BusinessError) => {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'player error: code=%{public}d, name=%{public}s, message=%{public}s',
          error.code, error.name, error.message);
        AudioPlaybackService.stop().catch((_e: Object): void => {
        });
        onFinished();
      });
      AudioPlaybackService.player.url = 'fd://' + AudioPlaybackService.file.fd;
      await AudioPlaybackService.player.prepare();
      await AudioPlaybackService.player.play();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'audio playback started: path=%{public}s', path);
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'audio playback failed: path=%{public}s, error=%{public}s',
        path, AudioPlaybackService.errorText(e));
      await AudioPlaybackService.stop();
      throw new Error('原始录音播放失败');
    }
  }

  static async stop(): Promise<void> {
    const player: media.AVPlayer | undefined = AudioPlaybackService.player;
    AudioPlaybackService.player = undefined;
    if (player !== undefined) {
      try {
        if (player.state === 'playing' || player.state === 'paused') {
          await player.stop();
        }
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'player stop failed: %{public}s', AudioPlaybackService.errorText(e));
      }
      try {
        await player.release();
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'player release failed: %{public}s', AudioPlaybackService.errorText(e));
      }
    }
    if (AudioPlaybackService.file !== undefined) {
      try {
        fs.closeSync(AudioPlaybackService.file);
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'player file close failed: %{public}s', AudioPlaybackService.errorText(e));
      }
      AudioPlaybackService.file = undefined;
    }
  }

  private static errorText(e: Object): string {
    const businessError: BusinessError = e as BusinessError;
    if (businessError.code !== undefined || businessError.message !== undefined) {
      return `code=${businessError.code}, name=${businessError.name}, message=${businessError.message}`;
    }
    if (e instanceof Error) {
      return e.message;
    }
    return `${e}`;
  }
}
