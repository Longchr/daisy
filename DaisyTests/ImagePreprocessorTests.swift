import XCTest
import UIKit
@testable import Daisy

final class ImagePreprocessorTests: XCTestCase {
    func testLargePhoneScreenshotIsDownscaledAndByteBounded() throws {
        let size = CGSize(width: 1_290, height: 2_796)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for index in 0..<120 {
                let hue = CGFloat(index % 12) / 12
                UIColor(hue: hue, saturation: 0.65, brightness: 0.85, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: CGFloat(index) * 23, width: size.width, height: 12))
            }
        }
        let source = try XCTUnwrap(image.pngData())

        let prepared = try ImagePreprocessor.prepareJPEG(from: source)
        let preparedImage = try XCTUnwrap(UIImage(data: prepared))

        XCTAssertLessThanOrEqual(prepared.count, 850_000)
        XCTAssertLessThanOrEqual(max(preparedImage.size.width, preparedImage.size.height), 1_440)
        XCTAssertEqual(preparedImage.size.width / preparedImage.size.height, size.width / size.height, accuracy: 0.01)
    }
}
