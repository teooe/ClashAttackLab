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

nonisolated enum SimulationFinishReason: Hashable {
    case totalDestruction
    case armyEliminated
    case timeExpired

    var displayName: String {
        switch self {
        case .totalDestruction:
            return "Distruzione completa"
        case .armyEliminated:
            return "Esercito eliminato"
        case .timeExpired:
            return "Tempo scaduto"
        }
    }
}

nonisolated struct BattleSummaryMetrics {
    let damageToBase: Double
    let hitPointsLostByArmy: Double
    let troopsLost: Int
    let destroyedWalls: Int
    let spellsCast: Int
}

nonisolated struct SimulationResult {
    let winner: BattleWinner
    let elapsedTime: TimeInterval
    let timeExpired: Bool
    let finishReason: SimulationFinishReason
    let deployedTroops: Int
    let survivingTroops: Int
    let survivingDefenses: Int
    let troopAttackCount: Int
    let defenseAttackCount: Int
    let score: BaseScoreSnapshot
    let metrics: BattleSummaryMetrics
}

nonisolated enum SimulationStatus {
    case ready
    case running
    case paused
    case finished(SimulationResult)
}
