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

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition,
        hitPoints: Double = 0,
        attackCooldown: TimeInterval = 0
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.hitPoints = hitPoints
        self.attackCooldown = attackCooldown
    }

    var isAlive: Bool {
        hitPoints > 0
    }
}
