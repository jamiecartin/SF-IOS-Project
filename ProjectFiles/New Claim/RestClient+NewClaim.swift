import UIKit
import ContactsUI

import SalesforceSDKCore

extension RestClient {

	enum CaseRequestError: LocalizedError {

		case responseDataCorrupted(keyPath: String)

		var errorDescription: String? {
			switch self {
			case .responseDataCorrupted(let keyPath): return "The response dictionary did not contain the expected fields: \(keyPath)"
			}
		}
	}
	
	func sendCompositeRequest(_ compositeRequest: RestRequest, onFailure failureHandler: @escaping RestFailBlock, completionHandler: @escaping (_ ids: [String]) -> Void) {
		self.send(request: compositeRequest, onFailure: failureHandler) { response, urlResponse in
			guard let responseDictionary = response as? [String: Any],
			      let results = responseDictionary["compositeResponse"] as? [[String: Any]]
			else {
				failureHandler(CaseRequestError.responseDataCorrupted(keyPath: "compositeResponse"), urlResponse)
				return
			}
			let ids = results.compactMap { result -> String? in
				guard let resultBody = result["body"] as? [String: Any] else { return nil }
				return resultBody["id"] as? String
			}
			completionHandler(ids)
		}
	}

	func fetchMasterAccountForUser(onFailure failureHandler: @escaping RestFailBlock, completionHandler: @escaping (_ accountID: String) -> Void) {
		let accountRequest = self.request(forQuery: "SELECT Id FROM Account WHERE Master_Account__c = true LIMIT 1")
		self.send(request: accountRequest, onFailure: failureHandler) { response, urlResponse in
			guard let responseDictionary = response as? [String: Any],
			      let records = responseDictionary["records"] as? [[String: Any]],
						let accountID = records.first?["Id"] as? String
			else {
				failureHandler(CaseRequestError.responseDataCorrupted(keyPath: "records.first?[Id]"), urlResponse)
				return
			}
			completionHandler(accountID)
		}
	}

	func createCase(withFields fields: [String: Any], onFailure failureHandler: @escaping RestFailBlock, completionHandler: @escaping (_ caseID: String) -> Void) {
		let createRequest = self.requestForCreate(withObjectType: "Case", fields: fields)
		self.send(request: createRequest, onFailure: failureHandler) { response, urlResponse in
			guard let record = response as? [String: Any],
			      let caseID = record["id"] as? String
			else {
				failureHandler(CaseRequestError.responseDataCorrupted(keyPath: "id"), urlResponse)
				return
			}
			completionHandler(caseID)
		}
	}

	private func compositeRequestWithSequentialRefIDs(composedOf requests: [RestRequest]) -> RestRequest {
		let refIDs = (0..<requests.count).map { "RefID-\($0)" }
		return self.compositeRequest(requests, refIds: refIDs, allOrNone: false)
	}

	func compositeRequestForCreatingContacts(from contacts: [CNContact], relatingToAccountID accountID: String) -> RestRequest {
		let requests = contacts.map { contact -> RestRequest in
			let address = contact.postalAddresses.first
			let contactFields: [String: String] = [
				"LastName": contact.familyName,
				"FirstName": contact.givenName,
				"Phone": contact.phoneNumbers.first?.value.stringValue ?? "",
				"email": (contact.emailAddresses.first?.value as String?) ?? "",
				"MailingStreet": address?.value.street ?? "",
				"MailingCity": address?.value.city ?? "",
				"MailingState": address?.value.state ?? "",
				"MailingPostalCode": address?.value.postalCode ?? "",
				"MailingCountry": address?.value.country ?? ""
			]
			return self.requestForCreate(withObjectType: "Contact", fields: contactFields)
		}
		return self.compositeRequestWithSequentialRefIDs(composedOf: requests)
	}
	
	func requestForCreatingImageAttachment(from image: UIImage, relatingToCaseID caseID: String, fileName: String? = nil) -> RestRequest {
		let imageData = image.resizedByHalf().pngData()!
		let uploadFileName = fileName ?? UUID().uuidString + ".png"
		return self.requestForCreatingAttachment(from: imageData, withFileName: uploadFileName, relatingToCaseID: caseID)
	}

	func requestForCreatingAudioAttachment(from m4aAudioData: Data, relatingToCaseID caseID: String) -> RestRequest {
		let fileName = UUID().uuidString + ".m4a"
		return self.requestForCreatingAttachment(from: m4aAudioData, withFileName: fileName, relatingToCaseID: caseID)
	}

	private func requestForCreatingAttachment(from data: Data, withFileName fileName: String, relatingToCaseID caseID: String) -> RestRequest {
		let record = ["VersionData": data.base64EncodedString(options: .lineLength64Characters), "Title": fileName, "PathOnClient": fileName, "FirstPublishLocationId": caseID]
		return self.requestForCreate(withObjectType: "ContentVersion", fields: record)
	}

	func compositeRequestForCreatingAssociations(fromContactIDs contactIDs: [String], toCaseID caseID: String) -> RestRequest {
		let requests = contactIDs.map { contactID -> RestRequest in
			let associationFields: [String: String] = [
				"Case__c": caseID,
				"Contact__c": contactID
			]
			return self.requestForCreate(withObjectType: "CaseContact__c", fields: associationFields)
		}
		return self.compositeRequest(requests, refIds: contactIDs, allOrNone: false)
	}
}