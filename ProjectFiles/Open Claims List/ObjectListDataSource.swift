import UIKit
import SalesforceSDKCore

protocol ObjectListDataSourceDelegate: AnyObject {

	func objectListDataSourceDidUpdateRecords(_ dataSource: ObjectListDataSource)
}

class ObjectListDataSource: NSObject {

	typealias SFRecord = [String: Any]

	typealias CellConfigurator = (SFRecord, UITableViewCell) -> Void

	let soqlQuery: String

	let cellReuseIdentifier: String

	let cellConfigurator: CellConfigurator

	private(set) var records: [SFRecord] = []

	weak var delegate: ObjectListDataSourceDelegate?


	init(soqlQuery: String, cellReuseIdentifier: String, cellConfigurator: @escaping CellConfigurator) {
		self.soqlQuery = soqlQuery
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

	@objc func fetchData() {
		guard !soqlQuery.isEmpty else { return }
		let request = RestClient.shared.request(forQuery: soqlQuery)
		RestClient.shared.send(request: request, onFailure: handleError) { [weak self] response, _ in
			guard let self = self else { return }
			var resultsToReturn = [SFRecord]()
			if let dictionaryResponse = response as? [String: Any],
			   let records = dictionaryResponse["records"] as? [SFRecord] {
				resultsToReturn = records
			}
			DispatchQueue.main.async {
				self.records = resultsToReturn
				self.delegate?.objectListDataSourceDidUpdateRecords(self)
			}
		}
	}
}

extension ObjectListDataSource: UITableViewDataSource {

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return records.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
		cellConfigurator(records[indexPath.row], cell)
		return cell
	}
}