import Foundation

enum SimulationStatus {
    case ready

    var displayName: String {
        switch self {
        case .ready:
            return "pronto"
        }
    }
}
