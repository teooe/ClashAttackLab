import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
///
/// Numeric combat values in this file are synthetic prototype values, not
/// official Clash of Clans statistics. Target preferences and defense
/// behaviors are stored separately from those temporary numbers.
nonisolated struct PrototypeGameData: GameDataProviding {
    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        switch kind {
        case .heal:
            return SpellDefinition(
                displayName: "Cura",
                radius: 145,
                duration: 6,
                healingPerSecond: 100,
                damageMultiplier: 1,
                movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )

        case .rage:
            return SpellDefinition(
                displayName: "Furia",
                radius: 155,
                duration: 7,
                healingPerSecond: 0,
                damageMultiplier: 1.5,
                movementSpeedMultiplier: 1.35,
                attackSpeedMultiplier: 1.35,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )
        }
    }

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        switch kind {
        case .giant:
            return CombatDefinition(
                displayName: "Gigante",
                role: .troop,
                maxHitPoints: 1_050,
                movementSpeed: 100,
                attackDamage: 115,
                minimumAttackRange: 0,
                attackRange: 82,
                attackInterval: 1.2,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
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
                minimumAttackRange: 0,
                attackRange: 58,
                attackInterval: 0.9,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
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
                minimumAttackRange: 0,
                attackRange: 200,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: .arrow,
                projectileSpeed: 650,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )

        case .wallBreaker:
            return CombatDefinition(
                displayName: "Spaccamuro",
                role: .troop,
                maxHitPoints: 160,
                movementSpeed: 185,
                attackDamage: 320,
                minimumAttackRange: 0,
                attackRange: 65,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 72,
                selfDestructsOnAttack: true,
                targetingProfile: TargetingProfile(
                    preference: .walls,
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
                minimumAttackRange: 0,
                attackRange: 300,
                attackInterval: 0.9,
                canMove: false,
                projectileKind: .cannonball,
                projectileSpeed: 600,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )

        case .archerTower:
            return CombatDefinition(
                displayName: "Torre dell’Arciera",
                role: .defense,
                maxHitPoints: 560,
                movementSpeed: 0,
                attackDamage: 34,
                minimumAttackRange: 0,
                attackRange: 340,
                attackInterval: 0.75,
                canMove: false,
                projectileKind: .arrow,
                projectileSpeed: 700,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )

        case .mortar:
            return CombatDefinition(
                displayName: "Mortaio",
                role: .defense,
                maxHitPoints: 520,
                movementSpeed: 0,
                attackDamage: 120,
                minimumAttackRange: 150,
                attackRange: 440,
                attackInterval: 2.8,
                canMove: false,
                projectileKind: .mortarShell,
                projectileSpeed: 360,
                splashRadius: 95,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )

        case .townHall:
            return CombatDefinition(
                displayName: "Municipio",
                role: .building,
                maxHitPoints: 900,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )

        case .goldStorage:
            return CombatDefinition(
                displayName: "Deposito",
                role: .building,
                maxHitPoints: 620,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )

        case .wall:
            return CombatDefinition(
                displayName: "Muro",
                role: .wall,
                maxHitPoints: 280,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 0,
                attackInterval: 0,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil
            )
        }
    }
}
