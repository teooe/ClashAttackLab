import Foundation

/// Curated base layouts for repeatable attack experiments.
///
/// Layout geometry is a prototype input. Every option contains the same
/// objective inventory so rankings compare pathing and timing, not an easier
/// or larger base.
nonisolated enum PrototypeBaseLayout: String, CaseIterable, Identifiable {
    case fortress
    case corridor
    case doubleCore

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .fortress:
            return "Fortezza"
        case .corridor:
            return "Corridoio"
        case .doubleCore:
            return "Doppio nucleo"
        }
    }

    var summary: String {
        switch self {
        case .fortress:
            return "Parete principale e apertura laterale."
        case .corridor:
            return "Canale centrale con due linee orizzontali."
        case .doubleCore:
            return "Due compartimenti con aperture alternate."
        }
    }
}
