import Foundation
import CryptoKit

extension String {
    var sha256Hash: String {
        SHA256.hash(data: Data(utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
