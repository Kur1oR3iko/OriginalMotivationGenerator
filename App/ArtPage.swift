import Foundation

enum ArtPage: Int, CaseIterable, Identifiable {
    case phrase, clock, once, letter

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .phrase: return "原始动机生成器"
        case .clock: return "25小时时钟"
        case .once: return "只能按一次"
        case .letter: return "信"
        }
    }
    var symbol: String {
        switch self {
        case .phrase: return "text.alignleft"
        case .clock: return "clock"
        case .once: return "circle"
        case .letter: return "envelope"
        }
    }
    func offset(by distance: Int) -> ArtPage {
        let count = Self.allCases.count
        return Self(rawValue: ((rawValue + distance) % count + count) % count)!
    }
}
