import Foundation

enum BattleEntityRole {
    case troop
    case defense
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
}

protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
}
