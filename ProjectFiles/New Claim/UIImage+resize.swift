import UIKit

extension UIImage {
	func resizedByHalf() -> UIImage {
		let newSize = CGSize(width: self.size.width * 0.5, height: self.size.height * 0.5)
		let rect = CGRect(origin: .zero, size: newSize)

		UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
		self.draw(in: rect)
		let newImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()

		return newImage
	}
}