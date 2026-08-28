import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
///
/// Numeric combat values in this file are synthetic prototype values, not
/// official Clash of Clans statistics. Target preferences are stored
/// separately and tagged with their evidence level.
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
                canMove: true,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                )
            )

        case .barbarian:
            return CombatDefinition(
                displayName: "Barbaro",
                role: .troop,
                maxHitPoints: 380,
                movementSpeed: 140,
                attackDamage: 70,
                attackRange: 58,
                attackInterval: 0.9,
                canMove: true,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )

        case .archer:
            return CombatDefinition(
                displayName: "Arciera",
                role: .troop,
                maxHitPoints: 190,
                movementSpeed: 150,
                attackDamage: 55,
                attackRange: 200,
                attackInterval: 1.0,
                canMove: true,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
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
                canMove: false,
                targetingProfile: nil
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
                canMove: false,
                targetingProfile: nil
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
                canMove: false,
                targetingProfile: nil
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
                canMove: false,
                targetingProfile: nil
            )
        }
    }
}
