import AppKit
import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: TabFinderViewModel
    let close: () -> Void
    let openSafari: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            header

            TextField("탭 제목 또는 URL 검색", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .accessibilityLabel("탭 검색")

            resultContent
        }
        .padding(14)
        .frame(width: AppMetadata.popoverSize.width, height: AppMetadata.popoverSize.height)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                searchFocused = true
            }
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.badge.magnifyingglass")
                .foregroundStyle(.tint)
            Text(AppMetadata.displayName)
                .font(.headline)
            Spacer()
            if case .loaded = viewModel.state {
                Text("\(viewModel.results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Menu {
                Button("새로고침") {
                    Task { await viewModel.load() }
                }
                Divider()
                Button("Tab Finder 종료") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("메뉴")
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Safari 탭을 불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .safariNotRunning:
            SearchStatusView(
                icon: "safari",
                title: "Safari가 열려 있지 않습니다",
                message: "Safari를 연 다음 다시 검색해 주세요.",
                buttonTitle: "Safari 열기",
                action: openSafari
            )
        case .permissionDenied:
            SearchStatusView(
                icon: "lock.shield",
                title: "Safari 접근 권한이 필요합니다",
                message: "시스템 설정의 개인정보 보호 및 보안 > 자동화에서 Tab Finder의 Safari 접근을 허용해 주세요.",
                buttonTitle: "다시 시도",
                action: reload
            )
        case let .failed(message):
            SearchStatusView(
                icon: "exclamationmark.triangle",
                title: "탭을 불러오지 못했습니다",
                message: message,
                buttonTitle: "다시 시도",
                action: reload
            )
        case .loaded:
            if viewModel.results.isEmpty {
                SearchStatusView(
                    icon: viewModel.query.isEmpty ? "rectangle.stack" : "magnifyingglass",
                    title: viewModel.query.isEmpty ? "열린 탭이 없습니다" : "검색 결과가 없습니다",
                    message: viewModel.query.isEmpty
                        ? "Safari에서 탭을 연 뒤 새로고침해 주세요."
                        : "다른 제목이나 URL을 입력해 보세요."
                )
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.results) { tab in
                        Button {
                            viewModel.select(tab.id)
                            activateSelection()
                        } label: {
                            TabRowView(tab: tab, isSelected: tab.id == viewModel.selectedTabID)
                        }
                        .buttonStyle(.plain)
                        .id(tab.id)
                    }
                }
            }
            .onChange(of: viewModel.selectedTabID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }

    private func activateSelection() {
        Task {
            if await viewModel.activateSelected() {
                close()
            }
        }
    }

    private func reload() {
        Task { await viewModel.load() }
    }
}
