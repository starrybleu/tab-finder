enum AppleScriptLiteral {
    static func stringExpression(for value: String) -> String {
        var components: [String] = []
        var text = ""

        func flushText() {
            guard !text.isEmpty else { return }
            components.append("\"\(text)\"")
            text = ""
        }

        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 34:
                text += "\\\""
            case 92:
                text += "\\\\"
            case 0..<32, 127:
                flushText()
                components.append("(character id \(scalar.value))")
            default:
                text.unicodeScalars.append(scalar)
            }
        }
        flushText()

        return components.isEmpty ? "\"\"" : components.joined(separator: " & ")
    }
}

enum SafariActivationScript {
    static let targetChangedErrorNumber = 19_873
    static let targetChangedErrorMessage = "Tab Finder target changed"

    static func source(for target: SafariTab) -> String {
        let expectedURL = AppleScriptLiteral.stringExpression(for: target.urlString)
        let expectedTitle = AppleScriptLiteral.stringExpression(for: target.title)

        return """
            set expectedURL to \(expectedURL)
            set expectedTitle to \(expectedTitle)
            tell application id "com.apple.Safari"
              set targetWindow to first window whose id is \(target.windowID)
              set targetTab to tab \(target.tabIndex) of targetWindow
              considering case
                if (URL of targetTab as text) is not expectedURL then error "\(targetChangedErrorMessage)" number \(targetChangedErrorNumber)
                if (name of targetTab as text) is not expectedTitle then error "\(targetChangedErrorMessage)" number \(targetChangedErrorNumber)
              end considering
              set current tab of targetWindow to targetTab
              set miniaturized of targetWindow to false
              set index of targetWindow to 1
              activate
            end tell
            """
    }
}

enum SafariAppleScriptErrorMapper {
    static func map(
        number: Int,
        message: String,
        targetSensitive: Bool
    ) -> SafariAutomationError {
        if number == -1743 {
            return .permissionDenied
        }
        if targetSensitive,
           (number == -1728
               || (number == SafariActivationScript.targetChangedErrorNumber
                   && message == SafariActivationScript.targetChangedErrorMessage))
        {
            return .targetChanged
        }
        return .scriptFailure(number: number, message: message)
    }
}
