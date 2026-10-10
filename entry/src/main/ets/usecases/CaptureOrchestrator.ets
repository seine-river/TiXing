import { ImageQualityResult } from '../models/Mistake';
import { ImageQualityIssue } from '../models/Enums';
import { MediaService } from '../services/MediaService';
import { PerformanceMonitor } from '../services/PerformanceMonitor';

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
