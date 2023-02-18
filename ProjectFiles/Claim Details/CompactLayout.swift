import Foundation

struct CompactLayout: Codable {
	var fieldItems: [FieldItem]
}

extension CompactLayout {
	struct FieldItem: Codable {
		var layoutComponents: [LayoutComponent]
	}
}

extension CompactLayout {
	struct LayoutComponent: Codable {
		var value: String
	}
}