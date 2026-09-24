import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
///
/// Distances are expressed in tiles and speeds in tiles per second.
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
                radius: 3.625,
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
                radius: 3.875,
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
                radius: 3.375,
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
                displayName: "Fulmine", radius: 3.125, duration: 0,
                healingPerSecond: 0, instantDamage: 320,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
        case .earthquake:
            return SpellDefinition(
                displayName: "Terremoto", radius: 3.75, duration: 0,
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
                movementSpeed: 2.5,
                attackDamage: 115,
                minimumAttackRange: 0,
                attackRange: 2.05,
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
                movementSpeed: 3.5,
                attackDamage: 70,
                minimumAttackRange: 0,
                attackRange: 1.45,
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
                movementSpeed: 3.75,
                attackDamage: 55,
                minimumAttackRange: 0,
                attackRange: 5,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: .arrow,
                projectileSpeed: 16.25,
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
                movementSpeed: 4.625,
                attackDamage: 320,
                minimumAttackRange: 0,
                attackRange: 1.625,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 1.8,
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
                movementSpeed: 3.125,
                attackDamage: 95,
                minimumAttackRange: 0,
                attackRange: 4.5,
                attackInterval: 1.35,
                canMove: true,
                projectileKind: .fireball,
                projectileSpeed: 13,
                splashRadius: 1.625,
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
                movementSpeed: 2.875,
                attackDamage: 185,
                minimumAttackRange: 0,
                attackRange: 2.2,
                attackInterval: 2.0,
                canMove: true,
                projectileKind: .bomb,
                projectileSpeed: 9.5,
                splashRadius: 1.75,
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
                movementSpeed: 3,
                attackDamage: 120,
                minimumAttackRange: 0,
                attackRange: 4.375,
                attackInterval: 1.45,
                canMove: true,
                projectileKind: .dragonFire,
                projectileSpeed: 12.5,
                splashRadius: 1.7,
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
                movementSpeed: 3.125,
                attackDamage: 180,
                minimumAttackRange: 0,
                attackRange: 1.9,
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
                movementSpeed: 2.95,
                attackDamage: 145,
                minimumAttackRange: 0,
                attackRange: 6.125,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: .arrow,
                projectileSpeed: 18,
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
                movementSpeed: 1.8,
                attackDamage: 125,
                damageMultiplierAgainstWalls: 8,
                minimumAttackRange: 0,
                attackRange: 1.7,
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
                movementSpeed: 2.3,
                attackDamage: 165,
                minimumAttackRange: 0,
                attackRange: 3.75,
                attackInterval: 1.6,
                canMove: true,
                projectileKind: .mortarShell,
                projectileSpeed: 10.5,
                splashRadius: 1.95,
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
                attackRange: 7.5,
                attackInterval: 0.9,
                canMove: false,
                projectileKind: .cannonball,
                projectileSpeed: 15,
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
                attackRange: 8.5,
                attackInterval: 0.75,
                canMove: false,
                projectileKind: .arrow,
                projectileSpeed: 17.5,
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
                minimumAttackRange: 3.75,
                attackRange: 11,
                attackInterval: 2.8,
                canMove: false,
                projectileKind: .mortarShell,
                projectileSpeed: 9,
                splashRadius: 2.375,
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
                attackRange: 7,
                attackInterval: 1.4,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 15.5,
                splashRadius: 1.95,
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
                attackRange: 8.75,
                attackInterval: 0.5,
                canMove: false,
                projectileKind: .fireball,
                projectileSpeed: 22.5,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                damageRampMultipliers: [1, 1.4, 2.2, 3.2],
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .bombTower:
            return CombatDefinition(
                displayName: "Torre Bombardiera",
                role: .defense,
                maxHitPoints: 620,
                movementSpeed: 0,
                attackDamage: 72,
                minimumAttackRange: 0,
                attackRange: 6.625,
                attackInterval: 1.55,
                canMove: false,
                projectileKind: .bomb,
                projectileSpeed: 12.5,
                splashRadius: 2.2,
                selfDestructsOnAttack: false,
                destructionDamage: 190,
                destructionRadius: 2.875,
                destructionTargetLayer: .ground,
                attackTargetLayer: .ground,
                targetingProfile: nil
            )

        case .hiddenTesla:
            return CombatDefinition(
                displayName: "Tesla Occulta",
                role: .defense,
                maxHitPoints: 590,
                movementSpeed: 0,
                attackDamage: 46,
                minimumAttackRange: 0,
                attackRange: 7.5,
                attackInterval: 0.72,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 20.5,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                startsHidden: true,
                activationRange: 3.875,
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .giantBomb:
            return CombatDefinition(
                displayName: "Bomba Gigante",
                role: .trap,
                maxHitPoints: 1,
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
                destructionDamage: 310,
                destructionRadius: 3.25,
                destructionTargetLayer: .ground,
                startsHidden: true,
                activationRange: 2.3,
                attackTargetLayer: .ground,
                targetingProfile: nil
            )

        case .airBomb:
            return CombatDefinition(
                displayName: "Bomba aerea",
                role: .trap,
                maxHitPoints: 1,
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
                destructionDamage: 235,
                destructionRadius: 3,
                destructionTargetLayer: .air,
                startsHidden: true,
                activationRange: 2.625,
                attackTargetLayer: .air,
                targetingProfile: nil
            )

        case .airSweeper:
            return CombatDefinition(
                displayName: "Spazzaria",
                role: .defense,
                maxHitPoints: 640,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 8.25,
                attackInterval: 1.9,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                pushbackDistance: 2.625,
                attackTargetLayer: .air,
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
                attackRange: 9.25,
                attackInterval: 1.05,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 18,
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
