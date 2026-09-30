import Foundation

public enum Cafe: String, CaseIterable, Sendable {
    case express
    case noisette
    case allonge
    case double
    case grandCreme
    case aVolonte

    public var name: String {
        switch self {
        case .express: "Express"
        case .noisette: "Noisette"
        case .allonge: "Allongé"
        case .double: "Double"
        case .grandCreme: "Grand crème"
        case .aVolonte: "À volonté"
        }
    }

    public var durationLabel: String {
        switch self {
        case .express: "15 Minutes"
        case .noisette: "30 Minutes"
        case .allonge: "1 Hour"
        case .double: "2 Hours"
        case .grandCreme: "5 Hours"
        case .aVolonte: "Indefinitely"
        }
    }

    public var seconds: TimeInterval? {
        switch self {
        case .express: 15 * 60
        case .noisette: 30 * 60
        case .allonge: 60 * 60
        case .double: 2 * 60 * 60
        case .grandCreme: 5 * 60 * 60
        case .aVolonte: nil
        }
    }
}
