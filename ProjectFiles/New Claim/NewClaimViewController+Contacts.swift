import UIKit
import Contacts
import ContactsUI

extension NewClaimViewController: CNContactViewControllerDelegate, CNContactPickerDelegate {

	func presentContactPicker() {
		contactPicker.delegate = self
		self.present(contactPicker, animated: true, completion: nil)
	}

	func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
		contactPicker.dismiss(animated: true)
		self.contacts = contacts
		
		for view in partiesInvolvedStackView.arrangedSubviews {
			partiesInvolvedStackView.removeArrangedSubview(view)
			view.removeFromSuperview()
		}
		
		for contact in contacts {
			partiesInvolvedStackView.addArrangedSubview(contactStackView(for: contact))
		}
	}
	
	func contactStackView(for contact: CNContact) -> UIStackView {
		let contactNamelabel = UILabel()
		contactNamelabel.font = UIFont.preferredFont(forTextStyle: .headline)
		contactNamelabel.text = CNContactFormatter.string(from: contact, style: .fullName)
		
		let contactEmailLabel = UILabel()
		contactEmailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
		contactEmailLabel.text = (contact.emailAddresses.first?.value ?? "") as String
	
		let separator = UIView()
		separator.backgroundColor = UIColor(named: "separator")
		separator.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
		
		let contactStackView = UIStackView(arrangedSubviews: [contactNamelabel, contactEmailLabel, separator])
		contactStackView.axis = .vertical
		contactStackView.spacing = 4
		return contactStackView
	}

	func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
		viewController.dismiss(animated: true, completion: nil)
	}

	func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
		return true
	}
}