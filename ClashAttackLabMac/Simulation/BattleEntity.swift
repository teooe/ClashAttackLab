import Foundation

struct WorldPosition: Equatable {
    var x: Double
    var y: Double
}

enum BattleEntityKind: Hashable {
    case giant
    case cannon
}

struct BattleEntity: Identifiable {
    let id: UUID
    let kind: BattleEntityKind
    var position: WorldPosition
    var hitPoints: Double
    var attackCooldown: TimeInterval
    var currentTargetID: UUID?

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition,
        hitPoints: Double = 0,
        attackCooldown: TimeInterval = 0,
        currentTargetID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.hitPoints = hitPoints
        self.attackCooldown = attackCooldown
        self.currentTargetID = currentTargetID
    }

    var isAlive: Bool {
        hitPoints > 0
    }
}
