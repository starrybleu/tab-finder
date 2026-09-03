import SwiftUI

struct TabRowView: View {
    let tab: SafariTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            DomainIconView(urlString: tab.urlString)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(tab.urlString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if tab.isCurrentTab {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                    .help("현재 탭")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
