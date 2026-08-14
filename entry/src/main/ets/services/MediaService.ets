import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fs from '@ohos.file.fs';
import { image } from '@kit.ImageKit';
import camera from '@ohos.multimedia.camera';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import { AppContextHolder } from '../common/AppContext';
import { generateId } from '../common/Constants';

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
    try {
      const ctx = AppContextHolder.require();
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      const result: cameraPicker.PickerResult = await cameraPicker.pick(ctx,
        [cameraPicker.PickerMediaType.PHOTO], profile);
      if (result.resultCode !== 0 || result.resultUri.length === 0) {
        return undefined;
      }
      return MediaService.persistUri(result.resultUri);
    } catch (e) {
      return undefined;
    }
  }

  static async persistUri(uri: string): Promise<string> {
    try {
      const ctx = AppContextHolder.require();
      const dir: string = ctx.filesDir + '/mistakes';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const destPath: string = `${dir}/img_${generateId()}.jpg`;
      const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.copyFile(srcFile.fd, destFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      return destPath;
    } catch (e) {
      return uri;
    }
  }

  static async loadScaledPixelMap(path: string, maxDim: number): Promise<image.PixelMap | undefined> {
    try {
      const srcFile = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const imageSource: image.ImageSource = image.createImageSource(srcFile.fd);
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
      const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodingOpts);
      fs.closeSync(srcFile);
      return pixelMap;
    } catch (e) {
      return undefined;
    }
  }

  static async readRgbaBuffer(pixelMap: image.PixelMap, width: number, height: number): Promise<ArrayBuffer | undefined> {
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(buffer);
      return buffer;
    } catch (e) {
      return undefined;
    }
  }
}
