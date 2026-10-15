import fs from '@ohos.file.fs';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WavAudioParser, WavInfo } from '../common/WavAudio';

const LOG_DOMAIN: number = 0xA009;
const LOG_TAG: string = 'TiXingCoreSpeech';
const CHUNK_SIZE: number = 1280;
const CHUNK_INTERVAL_MS: number = 40;
const RECOGNIZE_TIMEOUT_MS: number = 45000;

class SpeechSessionState {
  settled: boolean = false;
  started: boolean = false;
  finalText: string = '';
  intermediateText: string = '';
}

/**
 * 端侧语音转文字：
 * 输入为本应用录制的 16kHz/单声道/16 位 WAV，输出中文问题文本。
 * 原始声音仍由 AudioRecorderService 保存；GLM 只负责回答与分类。
 */
export class CoreSpeechService {
  static async transcribeAudio(audioPath: string,
    onProgress: (fedSeconds: number, totalSeconds: number) => void =
    (_fedSeconds: number, _totalSeconds: number): void => {
    }): Promise<string> {
    const startedAt: number = Date.now();
    const pcm: Uint8Array = CoreSpeechService.readPcm(audioPath);
    const sessionId: string = `tixing_${Date.now()}`;
    const state: SpeechSessionState = new SpeechSessionState();
    let engine: speechRecognizer.SpeechRecognitionEngine | undefined = undefined;
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'core speech transcribe start: path=%{public}s, pcmBytes=%{public}d, sessionId=%{public}s',
      audioPath, pcm.byteLength, sessionId);
    try {
      const extraParams: Record<string, Object> = {
        'locate': 'CN',
        'recognizerMode': 'short'
      };
      const engineParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParams
      };
      engine = await speechRecognizer.createEngine(engineParams);
      const text: string = await CoreSpeechService.recognize(engine, sessionId, pcm, state, onProgress);
      if (text.length === 0) {
        throw new Error('没有听清孩子的问题，请靠近麦克风重新录一次');
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'core speech transcribe succeeded: textLength=%{public}d, elapsedMs=%{public}d',
        text.length, Date.now() - startedAt);
      return text;
    } catch (e) {
      const diagnostic: string = `CoreSpeech完整诊断\naudioPath=${audioPath}\n` +
        `pcmBytes=${pcm.byteLength}\nsessionId=${sessionId}\nelapsedMs=${Date.now() - startedAt}\n` +
        `error=${CoreSpeechService.errorDetail(e)}`;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'core speech transcribe failed: %{public}s', diagnostic);
      throw new Error(CoreSpeechService.friendlyMessage(e));
    } finally {
      CoreSpeechService.shutdownEngine(engine);
    }
  }

  private static recognize(engine: speechRecognizer.SpeechRecognitionEngine, sessionId: string,
    pcm: Uint8Array, state: SpeechSessionState,
    onProgress: (fedSeconds: number, totalSeconds: number) => void): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void,
      reject: (reason: Error) => void): void => {
      let timerId: number = -1;
      const settleResolve = (): void => {
        if (state.settled) {
          return;
        }
        state.settled = true;
        if (timerId >= 0) {
          clearTimeout(timerId);
        }
        const text: string = (state.finalText + state.intermediateText).trim();
        hilog.info(LOG_DOMAIN, LOG_TAG, 'core speech complete: textLength=%{public}d', text.length);
        resolve(text);
      };
      const settleReject = (message: string, diagnostic: string): void => {
        if (state.settled) {
          return;
        }
        state.settled = true;
        if (timerId >= 0) {
          clearTimeout(timerId);
        }
        hilog.error(LOG_DOMAIN, LOG_TAG,
          'core speech session failed: %{public}s', diagnostic);
        reject(new Error(message));
      };

      const listener: speechRecognizer.RecognitionListener = {
        onStart: (currentSessionId: string, eventMessage: string): void => {
          state.started = true;
          hilog.info(LOG_DOMAIN, LOG_TAG,
            'core speech onStart: session=%{public}s, message=%{public}s',
            currentSessionId, eventMessage);
        },
        onEvent: (currentSessionId: string, eventCode: number, eventMessage: string): void => {
          hilog.info(LOG_DOMAIN, LOG_TAG,
            'core speech onEvent: session=%{public}s, code=%{public}d, message=%{public}s',
            currentSessionId, eventCode, eventMessage);
        },
        onResult: (currentSessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          const text: string = result.result.trim();
          hilog.info(LOG_DOMAIN, LOG_TAG,
            'core speech onResult: session=%{public}s, isFinal=%{public}b, isLast=%{public}b, textLength=%{public}d',
            currentSessionId, result.isFinal, result.isLast, text.length);
          if (result.isFinal) {
            if (text.length > 0) {
              if (text.startsWith(state.finalText)) {
                state.finalText = text;
              } else if (!state.finalText.endsWith(text)) {
                state.finalText += text;
              }
            }
            state.intermediateText = '';
          } else {
            if (state.finalText.length > 0 && text.startsWith(state.finalText)) {
              state.intermediateText = text.substring(state.finalText.length);
            } else {
              state.intermediateText = text;
            }
          }
        },
        onComplete: (currentSessionId: string, eventMessage: string): void => {
          hilog.info(LOG_DOMAIN, LOG_TAG,
            'core speech onComplete: session=%{public}s, message=%{public}s',
            currentSessionId, eventMessage);
          settleResolve();
        },
        onError: (currentSessionId: string, errorCode: number, errorMessage: string): void => {
          const diagnostic: string = `session=${currentSessionId}, code=${errorCode}, message=${errorMessage}`;
          settleReject(CoreSpeechService.friendlyCode(errorCode, errorMessage), diagnostic);
        }
      };

      try {
        engine.setListener(listener);
        const audioInfo: speechRecognizer.AudioInfo = {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        };
        const startParams: speechRecognizer.StartParams = {
          sessionId: sessionId,
          audioInfo: audioInfo
        };
        engine.startListening(startParams);
      } catch (e) {
        settleReject(CoreSpeechService.friendlyMessage(e),
          `startListening failed: ${CoreSpeechService.errorDetail(e)}`);
        return;
      }

      timerId = setTimeout((): void => {
        try {
          engine.cancel(sessionId);
        } catch (cancelError) {
          hilog.warn(LOG_DOMAIN, LOG_TAG,
            'core speech timeout cancel failed: %{public}s',
            CoreSpeechService.errorDetail(cancelError));
        }
        settleReject('语音识别超时，请重新录制或手动输入问题',
          `timeout=${RECOGNIZE_TIMEOUT_MS}ms`);
      }, RECOGNIZE_TIMEOUT_MS);

      CoreSpeechService.feedAudio(engine, sessionId, pcm, state, onProgress).then((): void => {
        if (state.settled) {
          return;
        }
        try {
          engine.finish(sessionId);
        } catch (e) {
          settleReject(CoreSpeechService.friendlyMessage(e),
            `finish failed: ${CoreSpeechService.errorDetail(e)}`);
        }
      }).catch((e: Error): void => {
        settleReject(CoreSpeechService.friendlyMessage(e),
          `write audio failed: ${CoreSpeechService.errorDetail(e)}`);
      });
    });
  }

  private static async feedAudio(engine: speechRecognizer.SpeechRecognitionEngine,
    sessionId: string, pcm: Uint8Array, state: SpeechSessionState,
    onProgress: (fedSeconds: number, totalSeconds: number) => void): Promise<void> {
    while (!state.started && !state.settled) {
      await CoreSpeechService.delay(20);
    }
    if (state.settled) {
      return;
    }
    let offset: number = 0;
    let chunkCount: number = 0;
    let reportedSeconds = 0;
    const totalSeconds: number = Math.max(1, Math.ceil(pcm.byteLength / 32000));
    while (offset < pcm.byteLength && !state.settled) {
      const remaining: number = pcm.byteLength - offset;
      const size: number = Math.min(CHUNK_SIZE, remaining);
      const chunk: Uint8Array = new Uint8Array(CHUNK_SIZE);
      for (let i: number = 0; i < size; i++) {
        chunk[i] = pcm[offset + i];
      }
      engine.writeAudio(sessionId, chunk);
      offset += size;
      chunkCount++;
      const fedSeconds: number = Math.max(1, Math.floor(offset / 32000));
      if (fedSeconds > reportedSeconds) {
        reportedSeconds = fedSeconds;
        onProgress(Math.min(reportedSeconds, totalSeconds), totalSeconds);
      }
      await CoreSpeechService.delay(CHUNK_INTERVAL_MS);
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'core speech audio fed: chunks=%{public}d, bytes=%{public}d, settled=%{public}b',
      chunkCount, offset, state.settled);
  }

  private static readPcm(audioPath: string): Uint8Array {
    try {
      const stat: fs.Stat = fs.statSync(audioPath);
      const arrayBuffer: ArrayBuffer = new ArrayBuffer(stat.size);
      const file: fs.File = fs.openSync(audioPath, fs.OpenMode.READ_ONLY);
      try {
        const readSize: number = fs.readSync(file.fd, arrayBuffer);
        const bytes: Uint8Array = new Uint8Array(arrayBuffer).slice(0, readSize);
        const info: WavInfo = WavAudioParser.parse(bytes);
        const pcm: Uint8Array = WavAudioParser.extractPcm(bytes);
        hilog.info(LOG_DOMAIN, LOG_TAG,
          'wav parsed: sampleRate=%{public}d, channels=%{public}d, sampleBit=%{public}d, pcmBytes=%{public}d',
          info.sampleRate, info.channels, info.sampleBit, pcm.byteLength);
        return pcm;
      } finally {
        fs.closeSync(file);
      }
    } catch (e) {
      hilog.error(LOG_DOMAIN, LOG_TAG,
        'wav pcm read failed: path=%{public}s, error=%{public}s',
        audioPath, CoreSpeechService.errorDetail(e));
      throw new Error('原始录音读取失败，请重新录制');
    }
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, ms);
    });
  }

  private static shutdownEngine(engine: speechRecognizer.SpeechRecognitionEngine | undefined): void {
    if (engine === undefined) {
      return;
    }
    try {
      engine.shutdown();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        'core speech shutdown failed: %{public}s', CoreSpeechService.errorDetail(e));
    }
  }

  private static friendlyMessage(e: Object): string {
    const businessError: BusinessError = e as BusinessError;
    if (businessError.code !== undefined) {
      return CoreSpeechService.friendlyCode(businessError.code, businessError.message);
    }
    if (e instanceof Error && e.message.length > 0) {
      return e.message;
    }
    return '语音转文字失败，请重新录制或手动输入问题';
  }

  private static friendlyCode(code: number, message: string): string {
    if (code === 1002200001) {
      return '本机语音识别引擎不可用，请检查系统语音服务后重试';
    }
    if (code === 1002200002 || code === 1002200010) {
      return '本机语音识别启动失败，请稍后重试';
    }
    if (code === 1002200003) {
      return '这段录音太长了，请缩短问题后重试';
    }
    if (code === 1002200006) {
      return '本机语音识别正在忙碌，请稍后再试';
    }
    if (code === 1002200007 || code === 1002200008) {
      return '本机语音识别未准备好，请稍后重试';
    }
    if (code === 1002200009) {
      return '本机语音服务异常，请稍后重试';
    }
    hilog.warn(LOG_DOMAIN, LOG_TAG,
      'core speech unknown code: code=%{public}d, message=%{public}s', code, message);
    return '语音转文字失败，请重新录制或手动输入问题';
  }

  private static errorDetail(e: Object): string {
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
