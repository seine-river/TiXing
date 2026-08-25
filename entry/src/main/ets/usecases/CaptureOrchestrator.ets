import { textRecognition } from '@kit.CoreVisionKit';
import { OcrFieldResult, OcrRecognitionResult, ImageQualityResult, CropFracs } from '../models/Mistake';
import { ImageQualityIssue, ContentType } from '../models/Enums';
import { MediaService } from '../services/MediaService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

const CONFIDENCE_THRESHOLD: number = 0.85;
const BLUR_VARIANCE_THRESHOLD: number = 100;
const QUALITY_DECODE_FAILED: string = 'decode_failed';

export class CaptureOrchestrator {
  /**
   * 图片质检（T032/FR-015）：fail-closed —— 解码失败/异常一律不放行；
   * 仅模糊（可人工继续）作为软提示。
   */
  static async checkImageQuality(path: string): Promise<ImageQualityResult> {
    const traceStart: number = PerformanceMonitor.startTrace('image_quality_check');
    const pixelMap = await MediaService.loadScaledPixelMap(path, 512);
    if (pixelMap === undefined) {
      PerformanceMonitor.writeFault('image_quality_error', { 'reason': 'decode_failed' });
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      return ImageQualityResult.fail(QUALITY_DECODE_FAILED);
    }
    try {
      const info = await pixelMap.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      const buffer = await MediaService.readRgbaBuffer(pixelMap, w, h);
      if (buffer === undefined) {
        PerformanceMonitor.writeFault('image_quality_error', { 'reason': 'read_pixels_failed' });
        PerformanceMonitor.endTrace('image_quality_check', traceStart);
        return ImageQualityResult.fail(QUALITY_DECODE_FAILED);
      }
      const variance: number = computeLaplacianVariance(buffer, w, h);
      PerformanceMonitor.writeStatistic('image_quality', { 'variance': Math.round(variance) });
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      if (variance < BLUR_VARIANCE_THRESHOLD) {
        return ImageQualityResult.fail(ImageQualityIssue.BLUR);
      }
      return ImageQualityResult.ok();
    } catch (e) {
      // 异常路径不放行（fail-closed）
      PerformanceMonitor.writeFault('image_quality_error', { 'reason': 'exception' });
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      return ImageQualityResult.fail(QUALITY_DECODE_FAILED);
    } finally {
      try {
        await pixelMap.release();
      } catch (e) {
      }
    }
  }

  /**
   * 本地 OCR（T032/FR-015）：文本识别引擎不返回置信度，按结果文本质量真实评估
   * （可读字符占比 + 有效长度），低置信度触发"需人工核对"提示。
   */
  static async performOcr(path: string, fracs: CropFracs | undefined): Promise<OcrRecognitionResult> {
    const result = new OcrRecognitionResult();
    const traceStart: number = PerformanceMonitor.startTrace('ocr_recognize');
    const pixelMap = await MediaService.loadScaledPixelMap(path, 1280);
    if (pixelMap === undefined) {
      PerformanceMonitor.endTrace('ocr_recognize', traceStart);
      PerformanceMonitor.writeFault('ocr_no_pixelmap', { 'reason': 'decode_failed' });
      return result;
    }
    if (fracs !== undefined) {
      try {
        const info = await pixelMap.getImageInfo();
        const w: number = info.size.width;
        const h: number = info.size.height;
        const cx: number = Math.round(fracs.leftFrac * w);
        const cy: number = Math.round(fracs.topFrac * h);
        const cw: number = Math.round((fracs.rightFrac - fracs.leftFrac) * w);
        const ch: number = Math.round((fracs.bottomFrac - fracs.topFrac) * h);
        if (cw > 0 && ch > 0) {
          await pixelMap.crop({ x: cx, y: cy, size: { width: cw, height: ch } });
        }
      } catch (e) {
        PerformanceMonitor.warn('pixelMap crop failed');
      }
    }
    try {
      const visionInfo: textRecognition.VisionInfo = { pixelMap };
      const res: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(visionInfo);
      const text: string = res.value;
      const confidence: number = estimateOcrConfidence(text);
      result.questionText = new OcrFieldResult(text, confidence, ContentType.PRINTED_TEXT);
      result.contentType = ContentType.PRINTED_TEXT;
      PerformanceMonitor.writeStatistic('ocr_result', {
        'length': text.length,
        'confidence': Math.round(confidence * 100)
      });
    } catch (e) {
      PerformanceMonitor.writeFault('ocr_recognize_error', { 'reason': 'recognize_failed' });
    } finally {
      try {
        await pixelMap.release();
      } catch (e) {
      }
      PerformanceMonitor.endTrace('ocr_recognize', traceStart);
    }
    return result;
  }

  static isLowConfidence(field: OcrFieldResult): boolean {
    return field.confidence < CONFIDENCE_THRESHOLD && field.text.length > 0;
  }

  static getConfidenceThreshold(): number {
    return CONFIDENCE_THRESHOLD;
  }
}

/**
 * OCR 置信度按文本质量真实评估：
 * 有效字符（文字/数字/常见符号）占比 0.25 + 有效长度 0.18 + 基础分 0.55，上限 0.97。
 * 乱码/极短文本自然落入低置信度区间（< 0.85）。
 */
function estimateOcrConfidence(text: string): number {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return 0;
  }
  let meaningful: number = 0;
  for (let i: number = 0; i < trimmed.length; i++) {
    if (isMeaningfulChar(trimmed.charCodeAt(i))) {
      meaningful++;
    }
  }
  const ratio: number = meaningful / trimmed.length;
  const lengthScore: number = Math.min(trimmed.length / 40, 1);
  const score: number = 0.55 + ratio * 0.25 + lengthScore * 0.18;
  return Math.min(score, 0.97);
}

function isMeaningfulChar(c: number): boolean {
  if (c >= 0x4e00 && c <= 0x9fff) {
    return true; // CJK
  }
  if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
    return true; // latin
  }
  if (c >= 48 && c <= 57) {
    return true; // digit
  }
  if (c === 32 || c === 0x3000) {
    return true; // space
  }
  // 常见标点与运算符（含全角）
  const punct: string = '，。、；：？！（）《》〈〉【】…—·+-*/=<>%()[]{},.;:?!#&_~^$@\\|';
  return punct.indexOf(String.fromCharCode(c)) >= 0 || c === 0x201C || c === 0x201D ||
    c === 0x2018 || c === 0x2019;
}

function computeLaplacianVariance(buffer: ArrayBuffer, width: number, height: number): number {
  const data: Uint8Array = new Uint8Array(buffer);
  const gray: Float32Array = new Float32Array(width * height);
  for (let i: number = 0; i < width * height; i++) {
    const r: number = data[i * 4];
    const g: number = data[i * 4 + 1];
    const b: number = data[i * 4 + 2];
    gray[i] = 0.299 * r + 0.587 * g + 0.114 * b;
  }
  let sum: number = 0;
  let count: number = 0;
  const laplacian: Float32Array = new Float32Array(width * height);
  for (let y: number = 1; y < height - 1; y++) {
    for (let x: number = 1; x < width - 1; x++) {
      const idx: number = y * width + x;
      const val: number = 4 * gray[idx] - gray[idx - 1] - gray[idx + 1] - gray[idx - width] - gray[idx + width];
      laplacian[idx] = val;
      sum += val;
      count++;
    }
  }
  const mean: number = count > 0 ? sum / count : 0;
  let sqSum: number = 0;
  for (let y: number = 1; y < height - 1; y++) {
    for (let x: number = 1; x < width - 1; x++) {
      const idx: number = y * width + x;
      const diff: number = laplacian[idx] - mean;
      sqSum += diff * diff;
    }
  }
  return count > 0 ? sqSum / count : 0;
}
