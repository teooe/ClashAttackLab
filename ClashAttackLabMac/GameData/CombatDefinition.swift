import Foundation

enum BattleEntityRole: Hashable {
    case troop
    case defense
    case building
    case wall
}

struct CombatDefinition {
    let displayName: String
    let role: BattleEntityRole
    let maxHitPoints: Double
    let movementSpeed: Double
    let attackDamage: Double
    let attackRange: Double
    let attackInterval: TimeInterval
    let canMove: Bool

    var countsForDestruction: Bool {
        role == .defense || role == .building
    }
}

protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
}
