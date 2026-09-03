protocol SafariAutomating: Sendable {
    func listTabs() async throws -> [SafariTab]
    func activate(_ target: SafariTab) async throws
}

enum SafariAutomationError: Error, Equatable {
    case safariNotRunning
    case permissionDenied
    case targetChanged
    case malformedResponse
    case scriptFailure(number: Int, message: String)
}
