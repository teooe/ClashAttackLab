import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
/// These are not official Clash of Clans statistics.
struct PrototypeGameData: GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        switch kind {
        case .giant:
            return CombatDefinition(
                displayName: "Gigante",
                role: .troop,
                maxHitPoints: 1_050,
                movementSpeed: 100,
                attackDamage: 115,
                attackRange: 82,
                attackInterval: 1.2,
                canMove: true
            )

        case .cannon:
            return CombatDefinition(
                displayName: "Cannone",
                role: .defense,
                maxHitPoints: 500,
                movementSpeed: 0,
                attackDamage: 40,
                attackRange: 300,
                attackInterval: 0.9,
                canMove: false
            )

        case .townHall:
            return CombatDefinition(
                displayName: "Municipio",
                role: .building,
                maxHitPoints: 900,
                movementSpeed: 0,
                attackDamage: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false
            )

        case .goldStorage:
            return CombatDefinition(
                displayName: "Deposito",
                role: .building,
                maxHitPoints: 620,
                movementSpeed: 0,
                attackDamage: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false
            )

        case .wall:
            return CombatDefinition(
                displayName: "Muro",
                role: .wall,
                maxHitPoints: 280,
                movementSpeed: 0,
                attackDamage: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false
            )
        }
    }
}
