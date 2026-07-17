import Foundation
import UIKit

enum ImagePreprocessor {
    static func prepareJPEG(
        from data: Data,
        maxDimension: CGFloat = 1600,
        compressionQuality: CGFloat = 0.76
    ) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 8, image.size.height > 8 else {
            throw RecognitionError.imageUnreadable
        }

        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longest)
        let target = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let encoded = rendered.jpegData(compressionQuality: compressionQuality), !encoded.isEmpty else {
            throw RecognitionError.imageUnreadable
        }
        return encoded
    }
}

enum SampleReceiptFactory {
    static func makeJPEG() -> Data {
        let size = CGSize(width: 750, height: 1200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let card = UIBezierPath(roundedRect: CGRect(x: 54, y: 150, width: 642, height: 760), cornerRadius: 38)
            UIColor.white.setFill()
            card.fill()

            draw("支付成功", at: CGPoint(x: 270, y: 235), size: 38, weight: .semibold, color: .darkGray)
            draw("¥ 28.00", at: CGPoint(x: 222, y: 345), size: 62, weight: .bold, color: .black)
            draw("商户", at: CGPoint(x: 115, y: 520), size: 25, weight: .regular, color: .gray)
            draw("Daisy 测试咖啡", at: CGPoint(x: 355, y: 520), size: 27, weight: .medium, color: .darkGray)
            draw("付款方式", at: CGPoint(x: 115, y: 605), size: 25, weight: .regular, color: .gray)
            draw("银行卡(1234)", at: CGPoint(x: 382, y: 605), size: 27, weight: .medium, color: .darkGray)
            draw("2026-07-17 12:30", at: CGPoint(x: 255, y: 740), size: 24, weight: .regular, color: .gray)
        }
        return image.jpegData(compressionQuality: 0.82) ?? Data()
    }

    private static func draw(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor
    ) {
        text.draw(
            at: point,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color
            ]
        )
    }
}
