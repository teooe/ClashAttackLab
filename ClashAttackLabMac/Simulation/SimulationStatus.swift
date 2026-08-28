import Foundation

nonisolated enum BattleWinner {
    case attackers
    case defenses

    var displayName: String {
        switch self {
        case .attackers:
            return "Attaccanti"
        case .defenses:
            return "Difese"
        }
    }
}

nonisolated struct SimulationResult {
    let winner: BattleWinner
    let elapsedTime: TimeInterval
    let timeExpired: Bool
    let deployedTroops: Int
    let survivingTroops: Int
    let survivingDefenses: Int
    let troopAttackCount: Int
    let defenseAttackCount: Int
    let score: BaseScoreSnapshot
}

nonisolated enum SimulationStatus {
    case ready
    case running
    case paused
    case finished(SimulationResult)
}
