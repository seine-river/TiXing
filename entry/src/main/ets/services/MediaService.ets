import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fs from '@ohos.file.fs';
import buffer from '@ohos.buffer';
import { image } from '@kit.ImageKit';
import camera from '@ohos.multimedia.camera';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import { AppContextHolder } from '../common/AppContext';
import { generateId } from '../common/Constants';
import { PerformanceMonitor } from './PerformanceMonitor';
import { CropFracs } from '../models/Mistake';

/**
 * 媒体服务（T039/FR-020）：
 * - 全部资源获取路径 try/finally 释放（fd close / imageSource release / pixelMap release）；
 * - persistUri 失败返回 undefined，不再降级使用临时 uri；
 * - cleanupTemp 清理拍照取消/失败产生的零字节半成品文件。
 */
export class MediaService {
  static async pickFromAlbum(): Promise<string | undefined> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length === 0) {
        return undefined;
      }
      return MediaService.persistUri(result.photoUris[0]);
    } catch (e) {
      return undefined;
    }
  }

  static async capturePhoto(): Promise<string | undefined> {
    let savePath: string = '';
    try {
      const ctx = AppContextHolder.require();
      const dir: string = ctx.filesDir + '/mistakes';
      try {
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir, true);
        }
      } catch (e) {
      }
      savePath = `${dir}/cam_${generateId()}.jpg`;
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        saveUri: 'file://' + savePath
      };
      const result: cameraPicker.PickerResult = await cameraPicker.pick(ctx,
        [cameraPicker.PickerMediaType.PHOTO], profile);
      if (result.resultCode !== 0 || result.resultUri.length === 0) {
        // 拍照取消/失败：清理半成品 savePath
        MediaService.cleanupFile(savePath);
        return undefined;
      }
      if (result.resultUri.indexOf('mistakes/cam_') >= 0) {
        return result.resultUri;
      }
      const persisted: string | undefined = await MediaService.persistUri(result.resultUri);
      if (persisted === undefined) {
        MediaService.cleanupFile(savePath);
        return undefined;
      }
      return persisted;
    } catch (e) {
      if (savePath.length > 0) {
        MediaService.cleanupFile(savePath);
      }
      return undefined;
    }
  }

  /**
   * 拷贝媒体 URI 到本机持久目录；失败返回 undefined（不降级临时 uri）。
   */
  static async persistUri(uri: string): Promise<string | undefined> {
    let srcFile: fs.File | undefined = undefined;
    let destFile: fs.File | undefined = undefined;
    try {
      const ctx = AppContextHolder.require();
      const dir: string = ctx.filesDir + '/mistakes';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const destPath: string = `${dir}/img_${generateId()}.jpg`;
      srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.copyFile(srcFile.fd, destFile.fd);
      return destPath;
    } catch (e) {
      PerformanceMonitor.warn('persistUri failed');
      return undefined;
    } finally {
      if (destFile !== undefined) {
        try {
          fs.closeSync(destFile);
        } catch (e) {
        }
      }
      if (srcFile !== undefined) {
        try {
          fs.closeSync(srcFile);
        } catch (e) {
        }
      }
    }
  }

  /**
   * 删除本应用拥有的错题图片（T031/FR-020）：仅当路径位于 filesDir/mistakes/ 下才删除
   * （startsWith 精确前缀判断，不误删相册 URI 或其他来源路径）。
   */
  static async deleteImageIfOwned(path: string): Promise<void> {
    if (path.length === 0) {
      return;
    }
    try {
      const ctx = AppContextHolder.require();
      const ownedDir: string = ctx.filesDir + '/mistakes/';
      if (path.startsWith(ownedDir)) {
        if (fs.accessSync(path)) {
          fs.unlinkSync(path);
        }
      }
    } catch (e) {
      // 删除图片失败不阻塞错题删除流程
    }
  }

  /**
   * 临时文件清理（T039/FR-020）：移除拍照取消/失败产生的零字节 cam_ 半成品。
   */
  static async cleanupTemp(): Promise<void> {
    try {
      const ctx = AppContextHolder.get();
      if (ctx === undefined) {
        return;
      }
      const dir: string = ctx.filesDir + '/mistakes';
      if (!fs.accessSync(dir)) {
        return;
      }
      const names: string[] = fs.listFileSync(dir);
      for (const name of names) {
        if (!name.startsWith('cam_')) {
          continue;
        }
        const full: string = `${dir}/${name}`;
        try {
          const stat = fs.statSync(full);
          if (stat.size === 0) {
            fs.unlinkSync(full);
          }
        } catch (e) {
        }
      }
    } catch (e) {
      PerformanceMonitor.warn('cleanupTemp failed');
    }
  }

  private static cleanupFile(path: string): void {
    try {
      if (path.length > 0 && fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {
    }
  }

  static async loadScaledPixelMap(path: string, maxDim: number): Promise<image.PixelMap | undefined> {
    let srcFile: fs.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      srcFile = fs.openSync(path, fs.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(srcFile.fd);
      const info = await imageSource.getImageInfo();
      const w: number = info.size.width;
      const h: number = info.size.height;
      let targetW: number = w;
      let targetH: number = h;
      const largest: number = Math.max(w, h);
      if (largest > maxDim) {
        const ratio: number = maxDim / largest;
        targetW = Math.round(w * ratio);
        targetH = Math.round(h * ratio);
      }
      const decodingOpts: image.DecodingOptions = {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { width: targetW, height: targetH },
        editable: true
      };
      return await imageSource.createPixelMap(decodingOpts);
    } catch (e) {
      return undefined;
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (e) {
        }
      }
      if (srcFile !== undefined) {
        try {
          fs.closeSync(srcFile);
        } catch (e) {
        }
      }
    }
  }

  static async readRgbaBuffer(pixelMap: image.PixelMap, width: number, height: number): Promise<ArrayBuffer | undefined> {
    try {
      const rgba: ArrayBuffer = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(rgba);
      return rgba;
    } catch (e) {
      return undefined;
    }
  }

  static async readImageBase64(path: string, maxDim: number): Promise<string | undefined> {
    const pm = await MediaService.loadScaledPixelMap(path, maxDim);
    if (pm === undefined) {
      return undefined;
    }
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const data: ArrayBuffer = await packer.packing(pm, { format: 'image/jpeg', quality: 80 });
      const buf: buffer.Buffer = buffer.from(new Uint8Array(data));
      return buf.toString('base64');
    } catch (e) {
      return undefined;
    } finally {
      try {
        packer.release();
      } catch (e) {
      }
      try {
        await pm.release();
      } catch (e) {
      }
    }
  }

  static async readRegionBase64(path: string, fracs: CropFracs | undefined, maxDim: number): Promise<string | undefined> {
    const pm = await MediaService.loadScaledPixelMap(path, maxDim);
    if (pm === undefined) {
      return undefined;
    }
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      if (fracs !== undefined) {
        const info = await pm.getImageInfo();
        const w: number = info.size.width;
        const h: number = info.size.height;
        const cx: number = Math.round(fracs.leftFrac * w);
        const cy: number = Math.round(fracs.topFrac * h);
        const cw: number = Math.round((fracs.rightFrac - fracs.leftFrac) * w);
        const ch: number = Math.round((fracs.bottomFrac - fracs.topFrac) * h);
        if (cw > 0 && ch > 0) {
          await pm.crop({ x: cx, y: cy, size: { width: cw, height: ch } });
        }
      }
      const data: ArrayBuffer = await packer.packing(pm, { format: 'image/jpeg', quality: 80 });
      const buf: buffer.Buffer = buffer.from(new Uint8Array(data));
      return buf.toString('base64');
    } catch (e) {
      return undefined;
    } finally {
      try {
        packer.release();
      } catch (e) {
      }
      try {
        await pm.release();
      } catch (e) {
      }
    }
  }
}
