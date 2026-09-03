import SwiftUI

struct DomainIconView: View {
    let urlString: String

    var body: some View {
        let descriptor = DomainIconDescriptor.make(for: urlString)

        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hue: descriptor.hue, saturation: 0.48, brightness: 0.86))

            if let text = descriptor.text {
                Text(text)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else if let systemImageName = descriptor.systemImageName {
                Image(systemName: systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}
