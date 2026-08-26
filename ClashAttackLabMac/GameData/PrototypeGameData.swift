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
                maxHitPoints: 1_000,
                movementSpeed: 100,
                attackDamage: 110,
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
                attackDamage: 45,
                attackRange: 300,
                attackInterval: 0.9,
                canMove: false
            )
        }
    }
}
