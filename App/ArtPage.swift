import Foundation

enum ArtPage: Int, CaseIterable, Identifiable {
    case phrase, clock, once, application, death, breath, notTaken, dormancy

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .phrase: return L("原始动机生成器")
        case .clock: return L("25小时时钟")
        case .once: return L("只能按一次")
        case .application: return L("申请")
        case .death: return L("死之钟")
        case .breath: return L("呼吸")
        case .notTaken: return L("没有拍下")
        case .dormancy: return L("休眠")
        }
    }
    var symbol: String {
        switch self {
        case .phrase: return "text.alignleft"
        case .clock: return "clock"
        case .once: return "circle"
        case .application: return "doc.text"
        case .death: return "hourglass"
        case .breath: return "wind"
        case .notTaken: return "camera"
        case .dormancy: return "leaf"
        }
    }
    func offset(by distance: Int) -> ArtPage {
        let count = Self.allCases.count
        return Self(rawValue: ((rawValue + distance) % count + count) % count)!
    }
}
