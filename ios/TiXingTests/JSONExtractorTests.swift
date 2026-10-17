import XCTest
@testable import TiXing

final class JSONExtractorTests: XCTestCase {
    func testExtractsJSONFromMarkdownFence() {
        let raw = """
        ```json
        {"answerText":"好的"}
        ```
        """
        XCTAssertEqual(JSONExtractor.firstJSON(in: raw), "{\"answerText\":\"好的\"}")
    }
}
