import UIKit

extension NewClaimViewController {

	func addPhoto() {
        imagePickerCtrl = UIImagePickerController()
        imagePickerCtrl.delegate = self
		
		if UIImagePickerController.isSourceTypeAvailable(.camera) {
			imagePickerCtrl.sourceType = .camera
		} else {
			
			imagePickerCtrl.sourceType = .savedPhotosAlbum
		}
		
        present(imagePickerCtrl, animated: true, completion: nil)
    }
	
	func stackViewForNewRowOfPhotos() -> UIStackView {
		let stackView = UIStackView(arrangedSubviews: [])
		stackView.axis = .horizontal
		stackView.alignment = .center
		stackView.distribution = .fillEqually
		stackView.spacing = 1
		
		for _ in 1...4 {
			stackView.addArrangedSubview(UIView())
		}
		return stackView
	}
	
	private func adjustPhotoStackViewHeight() {
		let numberOfRows = selectedImages.count / 4 + 1
		photoStackHeightConstraint.constant =  CGFloat(numberOfRows) * photoStackView.frame.width / 4
	}
	
	private func addToPhotoStack(_ photo: UIImage) {
		var rowStack: UIStackView
		if let lastRowStack = photoStackView.arrangedSubviews.last as? UIStackView,
			!(lastRowStack.arrangedSubviews.last! is UIImageView) {
			rowStack = lastRowStack
		} else {
			rowStack = stackViewForNewRowOfPhotos()
			photoStackView.addArrangedSubview(rowStack)
			adjustPhotoStackViewHeight()
		}
		
		let fillerView = rowStack.arrangedSubviews.last!
		rowStack.removeArrangedSubview(fillerView)
		fillerView.removeFromSuperview()
		
		let imageView = UIImageView(image: photo)
		imageView.clipsToBounds = true
		imageView.contentMode = .scaleAspectFill

		var nextImageViewIndex = 0
		if let lastImageViewIndex = rowStack.arrangedSubviews.lastIndex(where: { $0 is UIImageView }) {
			nextImageViewIndex = lastImageViewIndex + 1
		}
		rowStack.insertArrangedSubview(imageView, at: nextImageViewIndex)
		
	}
}

extension NewClaimViewController: UINavigationControllerDelegate {}

extension NewClaimViewController: UIImagePickerControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
		imagePickerCtrl.dismiss(animated: true, completion: nil)
		if let image = info[.originalImage] as? UIImage {
			selectedImages.append(image)
			addToPhotoStack(image)
		}
	}
}