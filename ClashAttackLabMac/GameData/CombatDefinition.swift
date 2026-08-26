import Foundation

struct CombatDefinition {
    let displayName: String
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
