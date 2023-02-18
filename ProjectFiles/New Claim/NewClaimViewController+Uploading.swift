import UIKit
import MapKit

import SalesforceSDKCore

extension NewClaimViewController {

	private func handleError(_ error: Error?, urlResponse: URLResponse? = nil) {
		let errorDescription: String
		if let error = error {
			errorDescription = "\(error)"
		} else {
			errorDescription = "An unknown error occurred."
		}
		
		if(alert.isViewLoaded){
			alert.dismiss(animated: true)
		}
		alert = UIAlertController(title: "We're sorry, an error has occured. This claim has not been saved.", message: errorDescription, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { action in self.unwindToClaims(forCaseID: nil)}))
		present(self.alert, animated: true)
		
		SalesforceLogger.e(type(of: self), message: "Failed to successfully complete the REST request. \(errorDescription)")
	}

	func uploadClaimTransaction() {
		SalesforceLogger.d(type(of: self), message: "Starting transaction")

		alert = UIAlertController(title: nil, message: "Submitting Claim", preferredStyle: .alert)
		let loadingModal = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
		loadingModal.hidesWhenStopped = true
		loadingModal.style = .gray
		loadingModal.startAnimating()
		alert.view.addSubview(loadingModal)
		present(alert, animated: true, completion: nil)

		RestClient.shared.fetchMasterAccountForUser(onFailure: handleError) { masterAccountID in
			SalesforceLogger.d(type(of: self), message: "Completed fetching the Master account ID: \(masterAccountID). Starting to create case.")
			self.createCase(withAccountID: masterAccountID)
		}
	}

	private func createCase(withAccountID accountID: String) {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .full

		var record = [String: Any]()
		record["origin"] = "Redwoods Car Insurance Mobile App"
		record["status"] = "new"
		record["accountId"] = accountID
		record["subject"] = "Incident on \(dateFormatter.string(from: Date()))"
		record["description"] = self.transcribedText
		record["type"] = "Car Insurance"
		record["Reason"] = "Vehicle Incident"
		record["Incident_Location_Txt__c"] = self.geoCodedAddressText
		record["Incident_Location__latitude__s"] = self.mapView.centerCoordinate.latitude
		record["Incident_Location__longitude__s"] = self.mapView.centerCoordinate.longitude
		
		RestClient.shared.createCase(withFields: record, onFailure: handleError) { newCaseID in
			SalesforceLogger.d(type(of: self), message: "Completed creating case with ID: \(newCaseID). Uploading Contacts.")
			self.createContacts(relatingToAccountID: accountID, forCaseID: newCaseID)
		}
	}

	private func createContacts(relatingToAccountID accountID: String, forCaseID caseID: String) {
		let contactsRequest = RestClient.shared.compositeRequestForCreatingContacts(from: contacts, relatingToAccountID: accountID)
		RestClient.shared.sendCompositeRequest(contactsRequest, onFailure: handleError) { contactIDs in
			SalesforceLogger.d(type(of: self), message: "Completed creating \(self.contacts.count) contact(s). Creating case<->contact junction object records.")
			self.createCaseContacts(withContactIDs: contactIDs, forCaseID: caseID)
		}
	}

	private func createCaseContacts(withContactIDs contactIDs:
	[String], forCaseID caseID: String) {
			  let associationRequest =
	RestClient.shared.compositeRequestForCreatingAssociations(fromContactIDs: contactIDs, toCaseID: caseID)
			   RestClient.shared.sendCompositeRequest(associationRequest,
	onFailure: handleError) { _ in
		SalesforceLogger.d(type(of: self), message: "Completed creating \(contactIDs.count) case contact record(s). Optionally uploading map image as attachment.")
					self.uploadMapImage(forCaseID: caseID)
			   }
		 }

	private func uploadMapImage(forCaseID caseID: String) {
		let options = MKMapSnapshotter.Options()
		let region = MKCoordinateRegion.init(center: mapView.centerCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
		options.region = region
		options.scale = UIScreen.main.scale
		options.size = CGSize(width: 800, height: 800)
		options.mapType = .standard

		let snapshotter = MKMapSnapshotter(options: options)
		snapshotter.start { snapshot, error in
			guard let snapshot = snapshot, error == nil else {
				return
			}
			UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
			snapshot.image.draw(at: .zero)

			let pinView = MKPinAnnotationView(annotation: nil, reuseIdentifier: nil)
			let pinImage = pinView.image

			var point = snapshot.point(for: self.mapView.centerCoordinate)
			let pinCenterOffset = pinView.centerOffset
			point.x -= pinView.bounds.size.width / 2
			point.y -= pinView.bounds.size.height / 2
			point.x += pinCenterOffset.x
			point.y += pinCenterOffset.y
			pinImage?.draw(at: point)

			let mapImage = UIGraphicsGetImageFromCurrentImageContext()!
			
			
			               let attachmentRequest = RestClient.shared.requestForCreatingImageAttachment(from: mapImage,relatingToCaseID: caseID, fileName: "MapSnapshot.png")

			UIGraphicsEndImageContext()
		
			RestClient.shared.send(request: attachmentRequest, onFailure:
			self.handleError) { _, _ in
								   SalesforceLogger.d(type(of: self), message:
			"Completed uploading map image. Now uploading photos.")
								  self.uploadPhotos (forCaseID: caseID)
								}
		}
	}

	private func uploadPhotos(forCaseID caseID: String) {
		for (index, img) in self.selectedImages.enumerated() {
			let attachmentRequest = RestClient.shared.requestForCreatingImageAttachment(from: img, relatingToCaseID: caseID)
			RestClient.shared.send(request: attachmentRequest, onFailure: self.handleError){ result, _ in
				SalesforceLogger.d(type(of: self), message: "Completed upload of photo \(index + 1) of \(self.selectedImages.count).")
			}
		}
		self.uploadAudio(forCaseID: caseID)
	}

	private func uploadAudio(forCaseID caseID: String) {
		if let audioData = audioFileAsData() {
			let attachmentRequest = RestClient.shared.requestForCreatingAudioAttachment(from: audioData, relatingToCaseID: caseID)
			RestClient.shared.send(request: attachmentRequest, onFailure: handleError) { _, _ in
				SalesforceLogger.d(type(of: self), message: "Completed uploading audio file. Transaction complete!")
				self.unwindToClaims(forCaseID: caseID)
				
			}
		} else {
			SalesforceLogger.d(type(of: self), message: "No audio file to upload. Transaction complete!")
			self.unwindToClaims(forCaseID: caseID)
		}
	}

	private func unwindToClaims(forCaseID caseID: String?) {
		wasSubmitted = true
		if let cid = caseID {
			let commentRequest = RestClient.shared.requestForCreate(withObjectType: "CaseComment", fields: ["parentId": cid, "commentBody": "navigating back to claims list view"])
			RestClient.shared.send(request:commentRequest, onFailure: handleError) {_,_ in
				SalesforceLogger.d(type(of: self), message: "Completed writing case comment")
			}
		}
		
		DispatchQueue.main.async {
			self.performSegue(withIdentifier: "unwindFromNewClaim", sender: self)
		}
	}
}