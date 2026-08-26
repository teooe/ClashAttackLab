import Foundation

enum BattleWinner {
    case giant
    case cannon
    case draw

    var displayName: String {
        switch self {
        case .giant:
            return "Gigante"
        case .cannon:
            return "Cannone"
        case .draw:
            return "Pareggio"
        }
    }
}

struct SimulationResult {
    let winner: BattleWinner
    let elapsedTime: TimeInterval
    let giantRemainingHitPoints: Double
    let cannonRemainingHitPoints: Double
    let giantAttackCount: Int
    let cannonAttackCount: Int
}

enum SimulationStatus {
    case ready
    case running
    case finished(SimulationResult)
}
