import CoreGraphics
import Foundation
import ImageIO

enum ImageQualityIssue: String, Codable, Hashable {
    case decodeFailed
    case lowResolution
    case blur
    case lowLight
    case glare
    case tilt

    var message: String {
        switch self {
        case .decodeFailed: return "图片读取失败，请重新选择清晰的图片"
        case .lowResolution: return "图片分辨率较低，可能影响 AI 识别准确度"
        case .blur: return "图片对比度较低，可能存在模糊"
        case .lowLight: return "光线较暗，建议在明亮处重拍"
        case .glare: return "图片可能存在反光，建议调整角度"
        case .tilt: return "照片可能倾斜，建议保持题目与屏幕边缘平行"
        }
    }
}

struct ImageQualityResult: Equatable {
    var issues: [ImageQualityIssue]
    var passed: Bool { !issues.contains(.decodeFailed) && !issues.contains(.lowResolution) }
    var blockingMessage: String? {
        issues.first(where: { $0 == .decodeFailed || $0 == .lowResolution })?.message
    }
    var warningMessage: String? {
        let warnings = issues.filter { $0 != .decodeFailed && $0 != .lowResolution }
        return warnings.isEmpty ? nil : warnings.map(\.message).joined(separator: "；")
    }
}

enum ImageQualityService {
    static func analyze(data: Data) -> ImageQualityResult {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return ImageQualityResult(issues: [.decodeFailed])
        }
        return analyze(image: image)
    }

    static func analyze(image: CGImage) -> ImageQualityResult {
        var issues: [ImageQualityIssue] = []
        let width = image.width
        let height = image.height
        if width < 480 || height < 480 {
            issues.append(.lowResolution)
        }
        if width > 0, height > 0 {
            let ratio = Double(max(width, height)) / Double(min(width, height))
            if ratio > 3.2 {
                issues.append(.tilt)
            }
        }

        if let statistics = luminanceStatistics(image: image) {
            if statistics.average < 0.22 {
                issues.append(.lowLight)
            }
            if statistics.average > 0.90 || statistics.brightRatio > 0.68 {
                issues.append(.glare)
            }
            if statistics.standardDeviation < 0.028 {
                issues.append(.blur)
            }
        }
        return ImageQualityResult(issues: issues)
    }

    private static func luminanceStatistics(image: CGImage) -> (average: Double,
                                                                standardDeviation: Double,
                                                                brightRatio: Double)? {
        let sampleSize = 48
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        guard let context = CGContext(
            data: &pixels,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var luminance: [Double] = []
        luminance.reserveCapacity(sampleSize * sampleSize)
        for index in 0..<(sampleSize * sampleSize) {
            let offset = index * 4
            let red = Double(pixels[offset]) / 255.0
            let green = Double(pixels[offset + 1]) / 255.0
            let blue = Double(pixels[offset + 2]) / 255.0
            luminance.append(0.299 * red + 0.587 * green + 0.114 * blue)
        }
        let average = luminance.reduce(0, +) / Double(luminance.count)
        let variance = luminance.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(luminance.count)
        let brightRatio = Double(luminance.filter { $0 > 0.93 }.count) / Double(luminance.count)
        return (average, variance.squareRoot(), brightRatio)
    }
}
