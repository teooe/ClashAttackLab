import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
/// These are not official Clash of Clans statistics.
struct PrototypeGameData: GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        switch kind {
        case .giant:
            return CombatDefinition(
                displayName: "Gigante",
                maxHitPoints: 900,
                movementSpeed: 95,
                attackDamage: 95,
                attackRange: 82,
                attackInterval: 1.2,
                canMove: true
            )

        case .cannon:
            return CombatDefinition(
                displayName: "Cannone",
                maxHitPoints: 600,
                movementSpeed: 0,
                attackDamage: 60,
                attackRange: 300,
                attackInterval: 0.8,
                canMove: false
            )
        }
    }
}
