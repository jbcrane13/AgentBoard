import Foundation

public extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension Sequence where Element == String {
    func sortedCaseInsensitive() -> [String] {
        sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}
