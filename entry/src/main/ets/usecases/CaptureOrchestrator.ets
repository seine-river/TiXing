import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { OcrFieldResult, OcrRecognitionResult, ImageQualityResult, ImageRegion } from '../models/Mistake';
import { ImageQualityIssue, ContentType } from '../models/Enums';
import { MediaService } from '../services/MediaService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

const CONFIDENCE_THRESHOLD: number = 0.85;
const BLUR_VARIANCE_THRESHOLD: number = 100;

export class CaptureOrchestrator {
  static async checkImageQuality(path: string): Promise<ImageQualityResult> {
    const traceStart: number = PerformanceMonitor.startTrace('image_quality_check');
    const pixelMap = await MediaService.loadScaledPixelMap(path, 512);
    if (pixelMap === undefined) {
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      return ImageQualityResult.ok();
    }
    try {
      const info = await pixelMap.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      const buffer = await MediaService.readRgbaBuffer(pixelMap, w, h);
      await pixelMap.release();
      if (buffer === undefined) {
        PerformanceMonitor.endTrace('image_quality_check', traceStart);
        return ImageQualityResult.ok();
      }
      const variance: number = computeLaplacianVariance(buffer, w, h);
      PerformanceMonitor.writeStatistic('image_quality', { 'variance': Math.round(variance) });
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      if (variance < BLUR_VARIANCE_THRESHOLD) {
        return ImageQualityResult.fail(ImageQualityIssue.BLUR);
      }
      return ImageQualityResult.ok();
    } catch (e) {
      PerformanceMonitor.writeFault('image_quality_error', { 'reason': 'exception' });
      PerformanceMonitor.endTrace('image_quality_check', traceStart);
      return ImageQualityResult.ok();
    }
  }

  static async performOcr(path: string, region: ImageRegion | undefined): Promise<OcrRecognitionResult> {
    const result = new OcrRecognitionResult();
    const traceStart: number = PerformanceMonitor.startTrace('ocr_recognize');
    const pixelMap = await MediaService.loadScaledPixelMap(path, 1280);
    if (pixelMap === undefined) {
      PerformanceMonitor.endTrace('ocr_recognize', traceStart);
      PerformanceMonitor.writeFault('ocr_no_pixelmap', { 'reason': 'decode_failed' });
      return result;
    }
    if (region !== undefined && region.width > 0 && region.height > 0) {
      try {
        await pixelMap.crop({ x: region.x, y: region.y, size: { width: region.width, height: region.height } });
      } catch (e) {
        PerformanceMonitor.warn('pixelMap crop failed');
      }
    }
    try {
      const visionInfo: textRecognition.VisionInfo = { pixelMap };
      const res: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(visionInfo);
      const text: string = res.value;
      const confidence: number = text.length > 0 ? 0.9 : 0;
      result.questionText = new OcrFieldResult(text, confidence, ContentType.PRINTED_TEXT);
      result.contentType = ContentType.PRINTED_TEXT;
      PerformanceMonitor.writeStatistic('ocr_result', { 'length': text.length });
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
