import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let shortcutManager: GlobalShortcutManager
    let launchAtLoginController: LaunchAtLoginController

    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("전역 단축키") {
                Toggle("단축키 사용", isOn: shortcutEnabledBinding)

                HStack {
                    Text("단축키")
                    Spacer()
                    ShortcutRecorderView(
                        shortcut: store.shortcut,
                        onRecord: applyShortcut,
                        onError: { errorMessage = $0 }
                    )
                }

                Button("기본값으로 복원 (⌘⇧')") {
                    applyShortcut(.default)
                }
            }

            Section("일반") {
                Toggle("로그인 시 Tab Finder 열기", isOn: launchAtLoginBinding)
            }

            if let visibleError = errorMessage ?? store.runtimeShortcutError {
                Text(visibleError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 420, height: 290)
    }

    private var shortcutEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.shortcutEnabled },
            set: { enabled in
                do {
                    if enabled {
                        try shortcutManager.apply(store.shortcut)
                    } else {
                        shortcutManager.disable()
                    }
                    store.shortcutEnabled = enabled
                    errorMessage = nil
                    store.runtimeShortcutError = nil
                } catch {
                    errorMessage = shortcutErrorMessage(error)
                }
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.launchAtLogin },
            set: { enabled in
                do {
                    try launchAtLoginController.setEnabled(enabled)
                    store.launchAtLogin = enabled
                    errorMessage = nil
                } catch {
                    errorMessage = "로그인 시 실행 설정을 바꾸지 못했습니다: \(error.localizedDescription)"
                }
            }
        )
    }

    private func applyShortcut(_ shortcut: KeyboardShortcut) {
        do {
            if store.shortcutEnabled {
                try shortcutManager.apply(shortcut)
            }
            store.shortcut = shortcut
            errorMessage = nil
            store.runtimeShortcutError = nil
        } catch {
            errorMessage = shortcutErrorMessage(error)
        }
    }

    private func shortcutErrorMessage(_ error: Error) -> String {
        if case let GlobalShortcutError.registrationFailed(status) = error {
            return "이 단축키를 등록할 수 없습니다 (오류 \(status)). 다른 조합을 사용해 주세요."
        }
        if case GlobalShortcutError.rollbackFailed = error {
            return "이전 단축키도 다시 등록하지 못했습니다. 다른 조합을 선택해 주세요."
        }
        return "단축키를 변경하지 못했습니다: \(error.localizedDescription)"
    }
}
