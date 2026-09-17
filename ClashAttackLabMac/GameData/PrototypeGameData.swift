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
                instantDamage: 0,
                damageMultiplier: 1,
                movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1,
                disablesDefenses: false,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )

        case .rage:
            return SpellDefinition(
                displayName: "Furia",
                radius: 155,
                duration: 7,
                healingPerSecond: 0,
                instantDamage: 0,
                damageMultiplier: 1.5,
                movementSpeedMultiplier: 1.35,
                attackSpeedMultiplier: 1.35,
                disablesDefenses: false,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )

        case .freeze:
            return SpellDefinition(
                displayName: "Gelo",
                radius: 135,
                duration: 4,
                healingPerSecond: 0,
                instantDamage: 0,
                damageMultiplier: 1,
                movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1,
                disablesDefenses: true,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )
        case .lightning:
            return SpellDefinition(
                displayName: "Fulmine", radius: 125, duration: 0,
                healingPerSecond: 0, instantDamage: 320,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
        case .earthquake:
            return SpellDefinition(
                displayName: "Terremoto", radius: 150, duration: 0,
                healingPerSecond: 0, instantDamage: 180,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .approximation, tuningEvidence: .prototype
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

        case .wizard:
            return CombatDefinition(
                displayName: "Mago",
                role: .troop,
                maxHitPoints: 260,
                movementSpeed: 125,
                attackDamage: 95,
                minimumAttackRange: 0,
                attackRange: 180,
                attackInterval: 1.35,
                canMove: true,
                projectileKind: .fireball,
                projectileSpeed: 520,
                splashRadius: 65,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .approximation
                )
            )

        case .balloon:
            return CombatDefinition(
                displayName: "Mongolfiera",
                role: .troop,
                maxHitPoints: 520,
                movementSpeed: 115,
                attackDamage: 185,
                minimumAttackRange: 0,
                attackRange: 88,
                attackInterval: 2.0,
                canMove: true,
                projectileKind: .bomb,
                projectileSpeed: 380,
                splashRadius: 70,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .prototype
                )
            )

        case .dragon:
            return CombatDefinition(
                displayName: "Drago",
                role: .troop,
                maxHitPoints: 920,
                movementSpeed: 120,
                attackDamage: 120,
                minimumAttackRange: 0,
                attackRange: 175,
                attackInterval: 1.45,
                canMove: true,
                projectileKind: .dragonFire,
                projectileSpeed: 500,
                splashRadius: 68,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .prototype
                )
            )

        case .barbarianKing:
            return CombatDefinition(
                displayName: "Re barbaro",
                role: .troop,
                maxHitPoints: 1_600,
                movementSpeed: 125,
                attackDamage: 180,
                minimumAttackRange: 0,
                attackRange: 76,
                attackInterval: 1.05,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .prototype
                ),
                heroAbility: HeroAbilityDefinition(
                    displayName: "Pugno di ferro",
                    activationHealthFraction: 0.45,
                    duration: 6,
                    instantHealing: 240,
                    damageMultiplier: 1.55,
                    movementSpeedMultiplier: 1.22,
                    attackSpeedMultiplier: 1.32,
                    attackRangeMultiplier: 1,
                    behaviorEvidence: .prototype,
                    tuningEvidence: .prototype
                )
            )

        case .archerQueen:
            return CombatDefinition(
                displayName: "Regina degli arcieri",
                role: .troop,
                maxHitPoints: 1_150,
                movementSpeed: 118,
                attackDamage: 145,
                minimumAttackRange: 0,
                attackRange: 245,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: .arrow,
                projectileSpeed: 720,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .prototype
                ),
                heroAbility: HeroAbilityDefinition(
                    displayName: "Manto reale",
                    activationHealthFraction: 0.42,
                    duration: 5,
                    instantHealing: 210,
                    damageMultiplier: 1.45,
                    movementSpeedMultiplier: 1.18,
                    attackSpeedMultiplier: 1.28,
                    attackRangeMultiplier: 1.35,
                    behaviorEvidence: .prototype,
                    tuningEvidence: .prototype
                )
            )

        case .wallWrecker:
            return CombatDefinition(
                displayName: "Ariete da guerra",
                role: .troop,
                maxHitPoints: 2_200,
                movementSpeed: 72,
                attackDamage: 125,
                damageMultiplierAgainstWalls: 8,
                minimumAttackRange: 0,
                attackRange: 68,
                attackInterval: 1.25,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .townHall,
                    evidence: .prototype
                ),
                siegePayload: [
                    .giant,
                    .barbarian,
                    .barbarian
                ]
            )

        case .stoneSlammer:
            return CombatDefinition(
                displayName: "Schiantapietre",
                role: .troop,
                maxHitPoints: 1_850,
                movementSpeed: 92,
                attackDamage: 165,
                minimumAttackRange: 0,
                attackRange: 150,
                attackInterval: 1.6,
                canMove: true,
                projectileKind: .mortarShell,
                projectileSpeed: 420,
                splashRadius: 78,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .prototype
                ),
                siegePayload: [
                    .balloon,
                    .balloon
                ]
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
                attackTargetLayer: .ground,
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
                attackTargetLayer: .ground,
                targetingProfile: nil
            )

        case .wizardTower:
            return CombatDefinition(
                displayName: "Torre dello Stregone",
                role: .defense,
                maxHitPoints: 600,
                movementSpeed: 0,
                attackDamage: 68,
                minimumAttackRange: 0,
                attackRange: 280,
                attackInterval: 1.4,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 620,
                splashRadius: 78,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .infernoTower:
            return CombatDefinition(
                displayName: "Torre Infernale",
                role: .defense,
                maxHitPoints: 780,
                movementSpeed: 0,
                attackDamage: 18,
                minimumAttackRange: 0,
                attackRange: 350,
                attackInterval: 0.5,
                canMove: false,
                projectileKind: .fireball,
                projectileSpeed: 900,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                damageRampMultipliers: [1, 1.4, 2.2, 3.2],
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .airDefense:
            return CombatDefinition(
                displayName: "Difesa aerea",
                role: .defense,
                maxHitPoints: 650,
                movementSpeed: 0,
                attackDamage: 56,
                minimumAttackRange: 0,
                attackRange: 370,
                attackInterval: 1.05,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 720,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .air,
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
