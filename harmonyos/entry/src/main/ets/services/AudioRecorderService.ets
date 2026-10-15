import fs from '@ohos.file.fs';
import audio from '@ohos.multimedia.audio';
import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContext';
import { generateId } from '../common/Constants';
import { WavAudioParser } from '../common/WavAudio';

const LOG_DOMAIN: number = 0xA007;
const LOG_TAG: string = 'TiXingAudioRecord';
const MAX_RECORD_BYTES: number = 1024 * 1024;

export class RecordedAudio {
  path: string = '';
  durationSeconds: number = 0;
  fileSize: number = 0;
}

/**
 * 原始声音保管员：
 * - 直接采集 Core Speech Kit 要求的 16kHz/单声道/16 位 PCM；
 * - 写成标准 WAV 保存到 filesDir/voice_asks，长期保留原始声音；
 * - 只有用户主动点击录音时才申请麦克风权限。
 */
export class AudioRecorderService {
  private static capturer: audio.AudioCapturer | undefined = undefined;
  private static outputFile: fs.File | undefined = undefined;
  private static currentPath: string = '';
  private static totalBytes: number = 0;
  private static recordStartedAt: number = 0;

  static async ensurePermission(): Promise<boolean> {
    try {
      const ctx: common.Context | undefined = AppContextHolder.get();
      if (ctx === undefined) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'microphone permission request skipped: context missing');
        return false;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(ctx, permissions);
      const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'microphone permission requested: granted=%{public}b, results=%{public}s',
        granted, JSON.stringify(result.authResults));
      return granted;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'microphone permission request failed: %{public}s', AudioRecorderService.errorText(e));
      return false;
    }
  }

  static get recording(): boolean {
    return AudioRecorderService.capturer !== undefined;
  }

  static async start(): Promise<string> {
    if (AudioRecorderService.capturer !== undefined) {
      throw new Error('正在录音中');
    }
    const granted: boolean = await AudioRecorderService.ensurePermission();
    if (!granted) {
      throw new Error('未获得麦克风权限，无法问一问');
    }

    const ctx: common.Context = AppContextHolder.require();
    const dir: string = ctx.filesDir + '/voice_asks';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const path: string = `${dir}/ask_${generateId()}.wav`;
    AudioRecorderService.currentPath = path;
    AudioRecorderService.totalBytes = 0;
    AudioRecorderService.outputFile = fs.openSync(path,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);

    try {
      fs.writeSync(AudioRecorderService.outputFile.fd, WavAudioParser.createHeader(0));
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
        capturerFlags: 0
      };
      const options: audio.AudioCapturerOptions = {
        streamInfo: streamInfo,
        capturerInfo: capturerInfo
      };
      const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options);
      AudioRecorderService.capturer = capturer;
      capturer.on('readData', (data: ArrayBuffer): void => {
        AudioRecorderService.writePcmChunk(data);
      });
      await capturer.start();
      AudioRecorderService.recordStartedAt = Date.now();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'pcm recording started: path=%{public}s', path);
      return path;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'pcm recording start failed: path=%{public}s, error=%{public}s',
        path, AudioRecorderService.errorText(e));
      await AudioRecorderService.cleanupCapturer();
      AudioRecorderService.closeAndCleanupFile();
      throw new Error('录音启动失败，请重试');
    }
  }

  static async stop(): Promise<RecordedAudio> {
    const capturer: audio.AudioCapturer | undefined = AudioRecorderService.capturer;
    if (capturer === undefined || AudioRecorderService.outputFile === undefined) {
      throw new Error('当前没有正在录音');
    }
    try {
      AudioRecorderService.capturer = undefined;
      try {
        capturer.off('readData');
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'pcm read listener off failed: %{public}s', AudioRecorderService.errorText(e));
      }
      await capturer.stop();
      await capturer.release();
      AudioRecorderService.closeFile();
      AudioRecorderService.patchWavHeader();

      const result: RecordedAudio = new RecordedAudio();
      result.path = AudioRecorderService.currentPath;
      result.durationSeconds = Math.max(1, Math.round(AudioRecorderService.totalBytes / 32000));
      result.fileSize = 44 + AudioRecorderService.totalBytes;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'pcm recording stopped: path=%{public}s, duration=%{public}d, pcmBytes=%{public}d, elapsed=%{public}d',
        result.path, result.durationSeconds, AudioRecorderService.totalBytes,
        Date.now() - AudioRecorderService.recordStartedAt);
      AudioRecorderService.currentPath = '';
      return result;
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'pcm recording stop failed: %{public}s', AudioRecorderService.errorText(e));
      await AudioRecorderService.releaseCapturer(capturer);
      AudioRecorderService.closeAndCleanupFile();
      throw new Error('录音保存失败，请重新录制');
    }
  }

  static async cancel(): Promise<void> {
    await AudioRecorderService.cleanupCapturer();
    AudioRecorderService.closeAndCleanupFile();
  }

  private static writePcmChunk(data: ArrayBuffer): void {
    const file: fs.File | undefined = AudioRecorderService.outputFile;
    if (file === undefined || data.byteLength === 0 ||
      AudioRecorderService.totalBytes + data.byteLength > MAX_RECORD_BYTES) {
      return;
    }
    try {
      const written: number = fs.writeSync(file.fd, data);
      AudioRecorderService.totalBytes += written;
      if (written !== data.byteLength) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'pcm write incomplete: expected=%{public}d, written=%{public}d',
          data.byteLength, written);
      }
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'pcm write failed: %{public}s', AudioRecorderService.errorText(e));
    }
  }

  private static patchWavHeader(): void {
    const path: string = AudioRecorderService.currentPath;
    if (path.length === 0 || !fs.accessSync(path)) {
      throw new Error('录音文件保存失败');
    }
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE);
    try {
      fs.writeSync(file.fd, WavAudioParser.createHeader(AudioRecorderService.totalBytes));
    } finally {
      fs.closeSync(file);
    }
  }

  private static async cleanupCapturer(): Promise<void> {
    const capturer: audio.AudioCapturer | undefined = AudioRecorderService.capturer;
    AudioRecorderService.capturer = undefined;
    if (capturer !== undefined) {
      try {
        capturer.off('readData');
      } catch (_e) {
        // 释放阶段忽略监听器异常。
      }
      await AudioRecorderService.releaseCapturer(capturer);
    }
  }

  private static async releaseCapturer(capturer: audio.AudioCapturer): Promise<void> {
    try {
      if (capturer.state === audio.AudioState.STATE_RUNNING ||
        capturer.state === audio.AudioState.STATE_PAUSED) {
        await capturer.stop();
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'pcm capturer stop failed: %{public}s', AudioRecorderService.errorText(e));
    }
    try {
      await capturer.release();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'pcm capturer release failed: %{public}s', AudioRecorderService.errorText(e));
    }
  }

  private static closeFile(): void {
    if (AudioRecorderService.outputFile !== undefined) {
      try {
        fs.closeSync(AudioRecorderService.outputFile);
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'record file close failed: %{public}s', AudioRecorderService.errorText(e));
      }
      AudioRecorderService.outputFile = undefined;
    }
  }

  private static closeAndCleanupFile(): void {
    AudioRecorderService.closeFile();
    if (AudioRecorderService.currentPath.length > 0) {
      try {
        if (fs.accessSync(AudioRecorderService.currentPath)) {
          fs.unlinkSync(AudioRecorderService.currentPath);
        }
      } catch (e) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          'record file cleanup failed: %{public}s', AudioRecorderService.errorText(e));
      }
    }
    AudioRecorderService.currentPath = '';
    AudioRecorderService.totalBytes = 0;
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
