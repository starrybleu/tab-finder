struct SafariTargetResolver {
    static func resolve(_ target: SafariTab, among currentTabs: [SafariTab]) throws -> SafariTab {
        let sameWindow = currentTabs.filter { $0.windowID == target.windowID }
        guard !sameWindow.isEmpty else {
            throw SafariAutomationError.targetChanged
        }

        let matchingURLs = sameWindow.filter { $0.urlString == target.urlString }
        guard !matchingURLs.isEmpty else {
            throw SafariAutomationError.targetChanged
        }

        if matchingURLs.count == 1, let onlyMatch = matchingURLs.first {
            return onlyMatch
        }

        let matchingTitles = matchingURLs.filter { $0.title == target.title }
        guard matchingTitles.count == 1, let titleMatch = matchingTitles.first else {
            throw SafariAutomationError.targetChanged
        }
        return titleMatch
    }
}
