import Foundation

nonisolated struct WorldPosition: Equatable, Codable {
    var x: Double
    var y: Double
}

nonisolated enum BattleEntityKind: Hashable, Codable {
    case giant
    case barbarian
    case archer
    case wallBreaker
    case wizard
    case balloon
    case dragon
    case barbarianKing
    case cannon
    case archerTower
    case mortar
    case airDefense
    case townHall
    case goldStorage
    case wall
}

nonisolated struct BattleEntity: Identifiable {
    let id: UUID
    let kind: BattleEntityKind
    var position: WorldPosition
    var hitPoints: Double
    var attackCooldown: TimeInterval
    var heroAbilityRemaining: TimeInterval
    var heroAbilityUsed: Bool

    /// Main building selected through target-selection rules.
    var currentTargetID: UUID?

    /// Temporary wall that blocks the route to the main target.
    var blockingWallID: UUID?

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition,
        hitPoints: Double = 0,
        attackCooldown: TimeInterval = 0,
        heroAbilityRemaining: TimeInterval = 0,
        heroAbilityUsed: Bool = false,
        currentTargetID: UUID? = nil,
        blockingWallID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.hitPoints = hitPoints
        self.attackCooldown = attackCooldown
        self.heroAbilityRemaining = heroAbilityRemaining
        self.heroAbilityUsed = heroAbilityUsed
        self.currentTargetID = currentTargetID
        self.blockingWallID = blockingWallID
    }

    var isAlive: Bool {
        hitPoints > 0
    }

    var heroAbilityIsActive: Bool {
        heroAbilityRemaining > 0
    }
}
