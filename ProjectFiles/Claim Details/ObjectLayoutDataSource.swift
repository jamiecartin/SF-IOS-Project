import UIKit
import SalesforceSDKCore

protocol ObjectLayoutDataSourceDelegate: AnyObject {

	func objectLayoutDataSourceDidUpdateFields(_ dataSource: ObjectLayoutDataSource)
}

class ObjectLayoutDataSource: NSObject {

	typealias ObjectField = (label: String, value: String)

	typealias CellConfigurator = (ObjectField, UITableViewCell) -> Void

	let objectType: String

	let objectId: String

	let cellReuseIdentifier: String

	let cellConfigurator: CellConfigurator

	let fieldBlacklist = ["attributes", "Id"]

	private(set) var fields: [ObjectField] = []

	weak var delegate: ObjectLayoutDataSourceDelegate?

	init(objectType: String, objectId: String, cellReuseIdentifier: String, cellConfigurator: @escaping CellConfigurator) {
		self.objectType = objectType
		self.objectId = objectId
		self.cellReuseIdentifier = cellReuseIdentifier
		self.cellConfigurator = cellConfigurator
		super.init()
	}

	private func handleError(_ error: Error?, urlResponse: URLResponse? = nil) {
		let errorDescription: String
		if let error = error {
			errorDescription = "\(error)"
		} else {
			errorDescription = "An unknown error occurred."
		}
		SalesforceLogger.e(type(of: self), message: "Failed to successfully complete the REST request. \(errorDescription)")
	}

	private func buildRequestFromCompactLayout(forObjectType objectType: String, objectId: String, completionHandler: @escaping (_ request: RestRequest) -> Void) {
		let layoutRequest = RestRequest(method: .GET, path: "v44.0/compactLayouts", queryParams: ["q": objectType])
		layoutRequest.parseResponse = false
		RestClient.shared.send(request: layoutRequest, onFailure: handleError) { response, _ in
			guard let responseData = response as? Data else { return }
			do {

				let decodedJSON = try JSONDecoder().decode([String: CompactLayout].self, from: responseData)
				guard let layout = decodedJSON[objectType] else {
					SalesforceLogger.e(type(of: self), message: "Missing \(objectType) object type in response.")
					return
				}

				let fields = layout.fieldItems.compactMap { $0.layoutComponents.first?.value }
				let fieldList = fields.joined(separator: ", ")

				let dataRequest = RestClient.shared.requestForRetrieve(withObjectType: objectType, objectId: objectId, fieldList: fieldList)
				completionHandler(dataRequest)
			} catch {
				self.handleError(error)
			}
		}
	}

	private func retrieveData(for request: RestRequest) {
		RestClient.shared.send(request: request, onFailure: handleError) { [weak self] response, _ in
			guard let self = self else { return }
			var resultsToReturn = [ObjectField]()
			if let dictionaryResponse = response as? [String: Any] {
				resultsToReturn = self.fields(from: dictionaryResponse)
			}
			DispatchQueue.main.async {
				self.fields = resultsToReturn
				self.delegate?.objectLayoutDataSourceDidUpdateFields(self)
			}
		}
	}


	private func fields(from record: [String: Any]) -> [ObjectField] {
		let filteredRecord = record.lazy.filter { key, value in !self.fieldBlacklist.contains(key) && value is String }
		return filteredRecord.map { key, value in (label: key, value: value as! String) }
	}

	@objc func fetchData() {
		self.buildRequestFromCompactLayout(forObjectType: self.objectType, objectId: self.objectId) { request in
			self.retrieveData(for: request)
		}
	}
}

extension ObjectLayoutDataSource: UITableViewDataSource {

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fields.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
		cellConfigurator(fields[indexPath.row], cell)
		return cell
	}
}