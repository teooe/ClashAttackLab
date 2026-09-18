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

nonisolated enum BattleTimelineEventKind: String, Codable {
    case deployment
    case spellCast
    case heroAbility
    case trapTriggered
    case structureDestroyed
    case troopDefeated
    case siegePayloadReleased
    case battleFinished
}

/// Compact, ordered event stream for explaining one deterministic battle.
nonisolated struct BattleTimelineEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let kind: BattleTimelineEventKind
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        kind: BattleTimelineEventKind,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
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
    let timeline: [BattleTimelineEvent]

    init(
        winner: BattleWinner,
        elapsedTime: TimeInterval,
        timeExpired: Bool,
        finishReason: SimulationFinishReason,
        deployedTroops: Int,
        survivingTroops: Int,
        survivingDefenses: Int,
        troopAttackCount: Int,
        defenseAttackCount: Int,
        score: BaseScoreSnapshot,
        metrics: BattleSummaryMetrics,
        timeline: [BattleTimelineEvent] = []
    ) {
        self.winner = winner
        self.elapsedTime = elapsedTime
        self.timeExpired = timeExpired
        self.finishReason = finishReason
        self.deployedTroops = deployedTroops
        self.survivingTroops = survivingTroops
        self.survivingDefenses = survivingDefenses
        self.troopAttackCount = troopAttackCount
        self.defenseAttackCount = defenseAttackCount
        self.score = score
        self.metrics = metrics
        self.timeline = timeline
    }
}

nonisolated enum SimulationStatus {
    case ready
    case running
    case paused
    case finished(SimulationResult)
}
