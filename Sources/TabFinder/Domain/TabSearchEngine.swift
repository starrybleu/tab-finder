import Foundation

struct TabSearchEngine: Sendable {
    func results(for query: String, in tabs: [SafariTab]) -> [SafariTab] {
        let tokens = Self.normalized(query)
            .split(whereSeparator: \ .isWhitespace)
            .map(String.init)

        guard !tokens.isEmpty else {
            return tabs.sorted(by: Self.tabOrder)
        }

        return tabs.compactMap { tab -> (tab: SafariTab, score: Int)? in
            let title = Self.normalized(tab.title)
            let hostname = Self.normalized(tab.hostname)
            let url = Self.normalized(tab.urlString)
            var score = 0

            for token in tokens {
                if title.hasPrefix(token) {
                    score += 400
                } else if title.contains(token) {
                    score += 300
                } else if hostname.contains(token) {
                    score += 200
                } else if url.contains(token) {
                    score += 100
                } else {
                    return nil
                }
            }

            if tab.isCurrentWindow { score += 10 }
            if tab.isCurrentTab { score += 1 }
            return (tab, score)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return Self.tabOrder(lhs.tab, rhs.tab)
        }
        .map(\.tab)
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    private static func tabOrder(_ lhs: SafariTab, _ rhs: SafariTab) -> Bool {
        if lhs.windowOrder != rhs.windowOrder {
            return lhs.windowOrder < rhs.windowOrder
        }
        return lhs.tabIndex < rhs.tabIndex
    }
}
