import Foundation

struct SafariTab: Identifiable, Equatable, Sendable {
    let windowID: Int
    let tabIndex: Int
    let windowOrder: Int
    let title: String
    let urlString: String
    let isCurrentWindow: Bool
    let isCurrentTab: Bool

    var id: String {
        "\(windowID):\(tabIndex)"
    }

    var hostname: String {
        URL(string: urlString)?.host() ?? ""
    }
}
