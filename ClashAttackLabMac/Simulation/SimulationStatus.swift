import Foundation

enum BattleWinner {
    case attackers
    case defenses
    case draw

    var displayName: String {
        switch self {
        case .attackers:
            return "Attaccanti"
        case .defenses:
            return "Difese"
        case .draw:
            return "Pareggio"
        }
    }
}

struct SimulationResult {
    let winner: BattleWinner
    let elapsedTime: TimeInterval
    let survivingTroops: Int
    let survivingDefenses: Int
    let troopAttackCount: Int
    let defenseAttackCount: Int
}

enum SimulationStatus {
    case ready
    case running
    case finished(SimulationResult)
}
