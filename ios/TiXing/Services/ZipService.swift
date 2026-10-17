import Foundation

struct ZipService {
    static func write(entries: [(name: String, data: Data)], to url: URL) throws {
        var output = Data()
        var central = Data()
        var entriesWritten = 0

        for entry in entries {
            let crc = crc32(entry.data)
            let offset = UInt32(output.count)
            let size = UInt32(entry.data.count)
            let nameBytes = Array(entry.name.utf8)

            output.append(contentsOf: UInt32(0x04034b50).littleEndian.bytes)
            output.append(contentsOf: UInt16(20).littleEndian.bytes)
            output.append(contentsOf: UInt16(0).littleEndian.bytes)
            output.append(contentsOf: UInt16(0).littleEndian.bytes) // stored
            output.append(contentsOf: UInt16(0).littleEndian.bytes) // time
            output.append(contentsOf: UInt16(0x2100).littleEndian.bytes) // date
            output.append(contentsOf: UInt32(crc).littleEndian.bytes)
            output.append(contentsOf: UInt32(size).littleEndian.bytes)
            output.append(contentsOf: UInt32(size).littleEndian.bytes)
            output.append(contentsOf: UInt16(nameBytes.count).littleEndian.bytes)
            output.append(contentsOf: UInt16(0).littleEndian.bytes)
            output.append(contentsOf: nameBytes)
            output.append(entry.data)

            central.append(contentsOf: UInt32(0x02014b50).littleEndian.bytes)
            central.append(contentsOf: UInt16(20).littleEndian.bytes)
            central.append(contentsOf: UInt16(20).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0x2100).littleEndian.bytes)
            central.append(contentsOf: UInt32(crc).littleEndian.bytes)
            central.append(contentsOf: UInt32(size).littleEndian.bytes)
            central.append(contentsOf: UInt32(size).littleEndian.bytes)
            central.append(contentsOf: UInt16(nameBytes.count).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt16(0).littleEndian.bytes)
            central.append(contentsOf: UInt32(0).littleEndian.bytes)
            central.append(contentsOf: UInt32(offset).littleEndian.bytes)
            central.append(contentsOf: nameBytes)
            entriesWritten += 1
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        output.append(contentsOf: UInt32(0x06054b50).littleEndian.bytes)
        output.append(contentsOf: UInt16(0).littleEndian.bytes)
        output.append(contentsOf: UInt16(0).littleEndian.bytes)
        output.append(contentsOf: UInt16(entriesWritten).littleEndian.bytes)
        output.append(contentsOf: UInt16(entriesWritten).littleEndian.bytes)
        output.append(contentsOf: UInt32(central.count).littleEndian.bytes)
        output.append(contentsOf: UInt32(centralOffset).littleEndian.bytes)
        output.append(contentsOf: UInt16(0).littleEndian.bytes)
        try output.write(to: url, options: [.atomic])
    }

    static func read(url: URL) throws -> [String: Data] {
        let data = try Data(contentsOf: url)
        guard data.count >= 22 else { throw ZipError.invalidArchive }
        var eocdOffset = -1
        let lowerBound = max(0, data.count - 66_000)
        for index in stride(from: data.count - 22, through: lowerBound, by: -1) {
            if data.readUInt32(index) == 0x06054b50 {
                eocdOffset = index
                break
            }
        }
        guard eocdOffset >= 0 else { throw ZipError.invalidArchive }
        let count = Int(data.readUInt16(eocdOffset + 10))
        var cursor = Int(data.readUInt32(eocdOffset + 16))
        var result: [String: Data] = [:]

        for _ in 0..<count {
            guard data.readUInt32(cursor) == 0x02014b50 else { throw ZipError.invalidArchive }
            let method = data.readUInt16(cursor + 10)
            let compressedSize = Int(data.readUInt32(cursor + 20))
            let nameLength = Int(data.readUInt16(cursor + 28))
            let extraLength = Int(data.readUInt16(cursor + 30))
            let commentLength = Int(data.readUInt16(cursor + 32))
            let localOffset = Int(data.readUInt32(cursor + 42))
            let nameStart = cursor + 46
            guard let name = String(data: data[nameStart..<(nameStart + nameLength)], encoding: .utf8) else {
                throw ZipError.invalidArchive
            }
            guard data.readUInt32(localOffset) == 0x04034b50 else { throw ZipError.invalidArchive }
            let localNameLength = Int(data.readUInt16(localOffset + 26))
            let localExtraLength = Int(data.readUInt16(localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            guard method == 0, dataStart + compressedSize <= data.count else { throw ZipError.unsupportedCompression }
            result[name] = data[dataStart..<(dataStart + compressedSize)]
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return result
    }

    static func crc32(_ input: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in input {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask: UInt32 = (crc & 1) != 0 ? 0xedb88320 : 0
                crc = (crc >> 1) ^ mask
            }
        }
        return ~crc
    }

    enum ZipError: LocalizedError {
        case invalidArchive, unsupportedCompression
        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "备份包结构不正确或已损坏"
            case .unsupportedCompression: return "备份包使用了不支持的压缩方式"
            }
        }
    }
}

private extension Data {
    func readUInt16(_ offset: Int) -> UInt16 {
        UInt16(self[startIndex + offset]) | (UInt16(self[startIndex + offset + 1]) << 8)
    }

    func readUInt32(_ offset: Int) -> UInt32 {
        UInt32(self[startIndex + offset])
            | (UInt32(self[startIndex + offset + 1]) << 8)
            | (UInt32(self[startIndex + offset + 2]) << 16)
            | (UInt32(self[startIndex + offset + 3]) << 24)
    }
}

private extension FixedWidthInteger {
    var bytes: [UInt8] {
        (0..<Self.bitWidth / 8).map { UInt8((self >> ($0 * 8)) & 0xff) }
    }
}
