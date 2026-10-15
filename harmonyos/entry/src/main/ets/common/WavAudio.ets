export class WavInfo {
  dataOffset: number = 0;
  dataSize: number = 0;
  audioFormat: number = 1;
  channels: number = 1;
  sampleRate: number = 16000;
  sampleBit: number = 16;
}

/** 只负责 WAV 结构解析/构造，不依赖系统能力，方便本地单元测试。 */
export class WavAudioParser {
  static parse(bytes: Uint8Array): WavInfo {
    if (bytes.byteLength < 44 || !WavAudioParser.isAscii(bytes, 0, 'RIFF') ||
      !WavAudioParser.isAscii(bytes, 8, 'WAVE')) {
      throw new Error('不是有效的 WAV 录音文件');
    }
    const info: WavInfo = new WavInfo();
    let offset: number = 12;
    while (offset + 8 <= bytes.byteLength) {
      const chunkSize: number = WavAudioParser.readUInt32(bytes, offset + 4);
      const bodyOffset: number = offset + 8;
      if (bodyOffset + chunkSize > bytes.byteLength) {
        break;
      }
      if (WavAudioParser.isAscii(bytes, offset, 'fmt ') && chunkSize >= 16) {
        info.audioFormat = WavAudioParser.readUInt16(bytes, bodyOffset);
        info.channels = WavAudioParser.readUInt16(bytes, bodyOffset + 2);
        info.sampleRate = WavAudioParser.readUInt32(bytes, bodyOffset + 4);
        info.sampleBit = WavAudioParser.readUInt16(bytes, bodyOffset + 14);
      } else if (WavAudioParser.isAscii(bytes, offset, 'data')) {
        info.dataOffset = bodyOffset;
        info.dataSize = Math.min(chunkSize, bytes.byteLength - bodyOffset);
      }
      offset = bodyOffset + chunkSize + (chunkSize % 2);
    }
    if (info.dataOffset === 0) {
      throw new Error('WAV 录音文件缺少音频数据');
    }
    return info;
  }

  static extractPcm(bytes: Uint8Array): Uint8Array {
    const info: WavInfo = WavAudioParser.parse(bytes);
    if (info.audioFormat !== 1 || info.channels !== 1 || info.sampleRate !== 16000 ||
      info.sampleBit !== 16) {
      throw new Error('语音识别仅支持 16kHz、单声道、16 位 WAV 录音');
    }
    return bytes.slice(info.dataOffset, info.dataOffset + info.dataSize);
  }

  static createHeader(dataSize: number): ArrayBuffer {
    const header: Uint8Array = new Uint8Array(44);
    WavAudioParser.writeAscii(header, 0, 'RIFF');
    WavAudioParser.writeUInt32(header, 4, 36 + dataSize);
    WavAudioParser.writeAscii(header, 8, 'WAVE');
    WavAudioParser.writeAscii(header, 12, 'fmt ');
    WavAudioParser.writeUInt32(header, 16, 16);
    WavAudioParser.writeUInt16(header, 20, 1);
    WavAudioParser.writeUInt16(header, 22, 1);
    WavAudioParser.writeUInt32(header, 24, 16000);
    WavAudioParser.writeUInt32(header, 28, 32000);
    WavAudioParser.writeUInt16(header, 32, 2);
    WavAudioParser.writeUInt16(header, 34, 16);
    WavAudioParser.writeAscii(header, 36, 'data');
    WavAudioParser.writeUInt32(header, 40, dataSize);
    return header.buffer;
  }

  static readUInt16(bytes: Uint8Array, offset: number): number {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static readUInt32(bytes: Uint8Array, offset: number): number {
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
  }

  private static writeUInt16(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
  }

  private static writeUInt32(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  private static isAscii(bytes: Uint8Array, offset: number, value: string): boolean {
    for (let i: number = 0; i < value.length; i++) {
      if (bytes[offset + i] !== value.charCodeAt(i)) {
        return false;
      }
    }
    return true;
  }

  private static writeAscii(bytes: Uint8Array, offset: number, value: string): void {
    for (let i: number = 0; i < value.length; i++) {
      bytes[offset + i] = value.charCodeAt(i);
    }
  }
}
