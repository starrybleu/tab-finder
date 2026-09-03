import Foundation

struct DomainIconDescriptor: Equatable, Sendable {
    let text: String?
    let systemImageName: String?
    let hue: Double

    static func make(for urlString: String) -> DomainIconDescriptor {
        guard let host = URL(string: urlString)?.host(),
              let firstCharacter = host.first
        else {
            return DomainIconDescriptor(text: nil, systemImageName: "globe", hue: 0)
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in host.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return DomainIconDescriptor(
            text: String(firstCharacter).uppercased(),
            systemImageName: nil,
            hue: Double(hash % 360) / 360
        )
    }
}
