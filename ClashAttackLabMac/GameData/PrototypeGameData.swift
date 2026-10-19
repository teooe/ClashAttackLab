import Foundation

/// Temporary tuning values used only to validate the simulator architecture.
///
/// Numeric combat values in this file are synthetic prototype values, not
/// official Clash of Clans statistics. Target preferences and defense
/// behaviors are stored separately from those temporary numbers.
nonisolated struct PrototypeGameData: GameDataProviding {
    /// Reach of the burst a Battle Blimp or a Golem leaves when it falls,
    /// in world units; not in the catalog (estimate).
    static let siegeDeathRadius = 80.0

    /// Seconds a Siege Barracks lasts on the battlefield.
    static let siegeBarracksLifetime = 30.0

    /// Tiles a Log Launcher's log rolls; not in the catalog (estimate).
    static let logRollTiles = 10.0

    /// Air troops this close keep a Baby Dragon calm, in world units;
    /// not in the catalog (estimate: 4.5 tiles).
    static let tantrumRadius = 180.0

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
        case .jump:
            var spell = SpellDefinition(
                displayName: "Salto", radius: 140, duration: 20,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.letsTroopsJumpWalls = true
            return spell
        case .invisibility:
            var spell = SpellDefinition(
                displayName: "Invisibilità", radius: 160, duration: 4,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.hidesDefenses = true
            return spell
        case .haste:
            // Speed only: unlike Rage it adds no damage.
            var spell = SpellDefinition(
                displayName: "Velocità", radius: 160, duration: 10,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.movementSpeedBonus = 140
            return spell
        case .poison:
            // Hurts and slows only the Clan Castle reinforcements.
            var spell = SpellDefinition(
                displayName: "Veleno", radius: 160, duration: 16,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.defenderDamagePerSecond = 320
            spell.defenderSpeedMultiplier = 0.52
            spell.defenderAttackSpeedMultiplier = 0.3
            spell.defenderDamageRampTime = SpellDefinition.poisonRampTime
            return spell
        case .overgrowth:
            var spell = SpellDefinition(
                displayName: "Rampicante", radius: 240, duration: 24,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.entanglesBuildings = true
            return spell
        case .iceBlock:
            var spell = SpellDefinition(
                displayName: "Blocco di ghiaccio", radius: 200, duration: 7,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.encasesTroops = true
            spell.troopDamageReduction = 0.9
            return spell
        case .skeletonSpell:
            var spell = SpellDefinition(
                displayName: "Scheletri", radius: 140, duration: 0,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.summonedTroop = .skeleton
            spell.summonCount = 19
            return spell
        case .batSpell:
            var spell = SpellDefinition(
                displayName: "Pipistrelli", radius: 140, duration: 0,
                healingPerSecond: 0, instantDamage: 0,
                damageMultiplier: 1, movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1, disablesDefenses: false,
                behaviorEvidence: .documented, tuningEvidence: .prototype
            )
            spell.summonedTroop = .bat
            spell.summonCount = 22
            return spell
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

        // Real-mode siege machines; the real catalog replaces the numbers.
        case .battleBlimp:
            // Flies straight to the Town Hall dropping bombs and bursts
            // on the buildings below when it falls.
            return CombatDefinition(
                displayName: TroopStyle.style(for: .battleBlimp).displayName,
                role: .troop,
                maxHitPoints: 3_000,
                movementSpeed: 90,
                attackDamage: 250,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 1.5,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 60,
                selfDestructsOnAttack: false,
                destructionDamage: 700,
                destructionRadius: Self.siegeDeathRadius,
                movementDomain: .air,
                attackTargetLayer: .ground,
                targetingProfile: TargetingProfile(
                    preference: .townHall,
                    evidence: .documented
                )
            )

        case .flameFlinger:
            // Lobs bursts of fire at defenses from long range and slowly
            // burns out.
            var flinger = CombatDefinition(
                displayName: TroopStyle.style(for: .flameFlinger).displayName,
                role: .troop,
                maxHitPoints: 1_500,
                movementSpeed: 30,
                attackDamage: 200,
                minimumAttackRange: 0,
                attackRange: 440,
                attackInterval: 0.2,
                canMove: true,
                projectileKind: .fireball,
                projectileSpeed: 400,
                splashRadius: 60,
                selfDestructsOnAttack: false,
                attackTargetLayer: .ground,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                )
            )
            flinger.burstShotCount = 3
            flinger.burstReloadTime = 5
            flinger.hitPointDecayPerSecond = 17
            return flinger

        case .siegeBarracks:
            // Stands where it lands and lets out a P.E.K.K.A and Wizards;
            // it then distracts defenses until it wears out.
            var barracks = CombatDefinition(
                displayName: TroopStyle.style(for: .siegeBarracks).displayName,
                role: .troop,
                maxHitPoints: 3_000,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 0,
                attackInterval: 1,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: nil,
                siegePayload: [.pekka] + Array(repeating: .wizard, count: 8)
            )
            barracks.releasesPayloadOnDeploy = true
            barracks.hitPointDecayPerSecond = 3_000 / Self.siegeBarracksLifetime
            return barracks

        case .logLauncher:
            // Rolls a log every few seconds towards the Town Hall: four
            // times the damage against walls.
            var launcher = CombatDefinition(
                displayName: TroopStyle.style(for: .logLauncher).displayName,
                role: .troop,
                maxHitPoints: 3_500,
                movementSpeed: 25,
                attackDamage: 400,
                damageMultiplierAgainstWalls: 4,
                minimumAttackRange: 0,
                attackRange: 0,
                attackInterval: 3,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .ground,
                targetingProfile: TargetingProfile(
                    preference: .townHall,
                    evidence: .documented
                )
            )
            launcher.rollingLogLength = Self.logRollTiles * 40
            launcher.rollingLogWidth = 40
            launcher.hitPointDecayPerSecond = 100
            return launcher

        case .dragonDuke:
            // Flying hero riding a dragon: heavy, close-range, hits ground
            // and air. Its equipment does the special work.
            return CombatDefinition(
                displayName: TroopStyle.style(for: .dragonDuke).displayName,
                role: .troop,
                maxHitPoints: 5_000,
                movementSpeed: 100,
                attackDamage: 200,
                minimumAttackRange: 0,
                attackRange: 50,
                attackInterval: 1.2,
                canMove: true,
                projectileKind: .dragonFire,
                projectileSpeed: 500,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                ),
                heroAbility: HeroAbilityDefinition(
                    displayName: "Furia reale",
                    activationHealthFraction: 0.45,
                    duration: 0,
                    instantHealing: 1_000,
                    damageMultiplier: 1,
                    movementSpeedMultiplier: 1,
                    attackSpeedMultiplier: 1,
                    attackRangeMultiplier: 1,
                    behaviorEvidence: .documented,
                    tuningEvidence: .prototype
                )
            )

        case .babyDragon:
            // Breathes fire on everything; alone in the sky it throws a
            // tantrum: twice the damage at one and a half times the pace.
            var baby = CombatDefinition(
                displayName: TroopStyle.style(for: .babyDragon).displayName,
                role: .troop,
                maxHitPoints: 1_200,
                movementSpeed: 100,
                attackDamage: 90,
                minimumAttackRange: 0,
                attackRange: 110,
                attackInterval: 1,
                canMove: true,
                projectileKind: .dragonFire,
                projectileSpeed: 500,
                splashRadius: 30,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )
            baby.tantrumRadius = Self.tantrumRadius
            baby.tantrumDamageMultiplier = 2
            baby.tantrumAttackSpeedMultiplier = 1.5
            return baby

        // Advanced troops: behaviours follow the game, numbers are
        // synthetic prototype values like the rest of this file.
        case .hogRider:
            var definition = CombatDefinition(
                displayName: TroopStyle.style(for: .hogRider).displayName,
                role: .troop,
                maxHitPoints: 900,
                movementSpeed: 190,
                attackDamage: 80,
                minimumAttackRange: 0,
                attackRange: 24,
                attackInterval: 1.0,
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
            definition.ignoresWalls = true
            return definition

        case .valkyrie:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .valkyrie).displayName,
                role: .troop,
                maxHitPoints: 1_000,
                movementSpeed: 150,
                attackDamage: 140,
                minimumAttackRange: 0,
                attackRange: 20,
                attackInterval: 1.8,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 40,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )

        case .golem:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .golem).displayName,
                role: .troop,
                maxHitPoints: 4_500,
                movementSpeed: 75,
                attackDamage: 60,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 2.4,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                // Bursts on the buildings around it and splits into
                // Golemites when it falls.
                destructionDamage: 400,
                destructionRadius: Self.siegeDeathRadius,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                ),
                siegePayload: [.golemite, .golemite]
            )

        case .golemite:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .golemite).displayName,
                role: .troop,
                maxHitPoints: 900,
                movementSpeed: 75,
                attackDamage: 12,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 2.4,
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

        case .bowler:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .bowler).displayName,
                role: .troop,
                maxHitPoints: 380,
                movementSpeed: 100,
                attackDamage: 95,
                minimumAttackRange: 0,
                attackRange: 120,
                attackInterval: 2.2,
                canMove: true,
                projectileKind: .bomb,
                projectileSpeed: 420,
                splashRadius: 40,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )

        case .miner:
            var definition = CombatDefinition(
                displayName: TroopStyle.style(for: .miner).displayName,
                role: .troop,
                maxHitPoints: 650,
                movementSpeed: 210,
                attackDamage: 110,
                minimumAttackRange: 0,
                attackRange: 20,
                attackInterval: 1.7,
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
            definition.ignoresWalls = true
            definition.burrowsWhileMoving = true
            return definition

        case .pekka:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .pekka).displayName,
                role: .troop,
                maxHitPoints: 3_000,
                movementSpeed: 100,
                attackDamage: 520,
                minimumAttackRange: 0,
                attackRange: 32,
                attackInterval: 1.8,
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

        case .yeti:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .yeti).displayName,
                role: .troop,
                maxHitPoints: 2_000,
                movementSpeed: 75,
                attackDamage: 170,
                minimumAttackRange: 0,
                attackRange: 32,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .prototype
                )
            )

        case .rootRider:
            var definition = CombatDefinition(
                displayName: TroopStyle.style(for: .rootRider).displayName,
                role: .troop,
                maxHitPoints: 3_200,
                movementSpeed: 75,
                attackDamage: 110,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 2.2,
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
            definition.ignoresWalls = true
            return definition

        case .electroDragon:
            var definition = CombatDefinition(
                displayName: TroopStyle.style(for: .electroDragon).displayName,
                role: .troop,
                maxHitPoints: 2_400,
                movementSpeed: 85,
                attackDamage: 420,
                minimumAttackRange: 0,
                attackRange: 120,
                attackInterval: 3.5,
                canMove: true,
                projectileKind: .airBolt,
                projectileSpeed: 900,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )
            // Chain lightning: five buildings, each link 80% of the last.
            definition.chainTargetCount = 5
            definition.chainRange = 160
            definition.chainDamageMultiplier = 0.8
            return definition

        case .dragonRider:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .dragonRider).displayName,
                role: .troop,
                maxHitPoints: 2_200,
                movementSpeed: 125,
                attackDamage: 220,
                minimumAttackRange: 0,
                attackRange: 160,
                attackInterval: 1.2,
                canMove: true,
                projectileKind: .dragonFire,
                projectileSpeed: 600,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                )
            )

        case .lavaHound:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .lavaHound).displayName,
                role: .troop,
                maxHitPoints: 3_800,
                movementSpeed: 125,
                attackDamage: 15,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 2.0,
                canMove: true,
                projectileKind: .fireball,
                projectileSpeed: 600,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .airDefenses,
                    evidence: .documented
                ),
                // Bursts into Lava Pups when it falls.
                siegePayload: Array(repeating: .lavaPup, count: 6)
            )

        case .skeleton:
            // Stats of the summoned Skeleton, the same at every level:
            // 30 hit points plus 30 of armour, 25 damage per second.
            var skeleton = CombatDefinition(
                displayName: TroopStyle.style(for: .skeleton).displayName,
                role: .troop,
                maxHitPoints: 60,
                movementSpeed: 120,
                attackDamage: 25,
                minimumAttackRange: 0,
                attackRange: 16,
                attackInterval: 1,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .ground,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )
            skeleton.ignoresTraps = true
            return skeleton

        case .bat:
            // Summoned Bat: flies to defenses, 30 damage per second, 40% of
            // it against resource buildings.
            var bat = CombatDefinition(
                displayName: TroopStyle.style(for: .bat).displayName,
                role: .troop,
                maxHitPoints: 20,
                movementSpeed: 280,
                attackDamage: 60,
                minimumAttackRange: 0,
                attackRange: 32,
                attackInterval: 2,
                canMove: true,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                )
            )
            bat.ignoresTraps = true
            bat.resourceDamageMultiplier = 0.4
            return bat

        case .lavaPup:
            return CombatDefinition(
                displayName: TroopStyle.style(for: .lavaPup).displayName,
                role: .troop,
                maxHitPoints: 100,
                movementSpeed: 150,
                attackDamage: 35,
                minimumAttackRange: 0,
                attackRange: 40,
                attackInterval: 1.0,
                canMove: true,
                projectileKind: .fireball,
                projectileSpeed: 600,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                movementDomain: .air,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .documented
                )
            )

        case .grandWarden:
            // Eternal Tome shields every troop around the Warden.
            var tome = HeroAbilityDefinition(
                displayName: "Tomo eterno",
                activationHealthFraction: 0.45,
                duration: 5,
                instantHealing: 150,
                damageMultiplier: 1,
                movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1,
                attackRangeMultiplier: 1,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )
            tome.protectionRadius = 280
            var warden = CombatDefinition(
                displayName: TroopStyle.style(for: .grandWarden).displayName,
                role: .troop,
                maxHitPoints: 1_100,
                movementSpeed: 85,
                attackDamage: 120,
                minimumAttackRange: 0,
                attackRange: 280,
                attackInterval: 1.8,
                canMove: true,
                projectileKind: .airBolt,
                projectileSpeed: 700,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .anyBuilding,
                    evidence: .approximation
                ),
                heroAbility: tome
            )
            // Life Aura: troops around the Warden take less damage.
            warden.auraRadius = 280
            warden.auraDamageReduction = 0.2
            return warden

        case .royalChampion:
            // Seeking Shield bounces between the four closest defenses.
            var shield = HeroAbilityDefinition(
                displayName: "Scudo cercatore",
                activationHealthFraction: 0.45,
                duration: 0,
                instantHealing: 300,
                damageMultiplier: 1,
                movementSpeedMultiplier: 1,
                attackSpeedMultiplier: 1,
                attackRangeMultiplier: 1,
                behaviorEvidence: .documented,
                tuningEvidence: .prototype
            )
            shield.strikeTargetCount = 4
            shield.strikeRange = 360
            shield.strikeDamageMultiplier = 2.5
            return CombatDefinition(
                displayName: TroopStyle.style(for: .royalChampion).displayName,
                role: .troop,
                maxHitPoints: 1_400,
                movementSpeed: 125,
                attackDamage: 170,
                minimumAttackRange: 0,
                attackRange: 120,
                attackInterval: 1.2,
                canMove: true,
                projectileKind: .arrow,
                projectileSpeed: 700,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                targetingProfile: TargetingProfile(
                    preference: .defenses,
                    evidence: .documented
                ),
                heroAbility: shield
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

        case .bombTower:
            return CombatDefinition(
                displayName: "Torre Bombardiera",
                role: .defense,
                maxHitPoints: 620,
                movementSpeed: 0,
                attackDamage: 72,
                minimumAttackRange: 0,
                attackRange: 265,
                attackInterval: 1.55,
                canMove: false,
                projectileKind: .bomb,
                projectileSpeed: 500,
                splashRadius: 88,
                selfDestructsOnAttack: false,
                destructionDamage: 190,
                destructionRadius: 115,
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
                attackRange: 300,
                attackInterval: 0.72,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 820,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                startsHidden: true,
                activationRange: 155,
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
                destructionRadius: 130,
                destructionTargetLayer: .ground,
                startsHidden: true,
                activationRange: 92,
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
                destructionRadius: 120,
                destructionTargetLayer: .air,
                startsHidden: true,
                activationRange: 105,
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
                attackRange: 330,
                attackInterval: 1.9,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                pushbackDistance: 105,
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

        case .goldMine, .elixirCollector, .darkElixirDrill, .elixirStorage, .darkElixirStorage, .clanCastle, .armyCamp, .barracks, .darkBarracks, .laboratory, .spellFactory, .darkSpellFactory, .workshop, .heroHall, .petHouse, .blacksmith, .builderHut, .helperHut:
            // Non-defensive village buildings: they only count for
            // destruction and never attack.
            return CombatDefinition(
                displayName: UtilityBuildingStyle.style(for: kind).displayName,
                role: .building,
                maxHitPoints: 500,
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

        case .xBow:
            return CombatDefinition(
                displayName: "Balestra",
                role: .defense,
                maxHitPoints: 1_500,
                movementSpeed: 0,
                attackDamage: 12,
                minimumAttackRange: 0,
                attackRange: 460,
                attackInterval: 0.128,
                canMove: false,
                projectileKind: .arrow,
                projectileSpeed: 900,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .eagleArtillery:
            // Fires three shells in a row, then reloads; it stays asleep
            // until the attacker has deployed enough housing space.
            var definition = CombatDefinition(
                displayName: "Artiglieria Aquila",
                role: .defense,
                maxHitPoints: 2_000,
                movementSpeed: 0,
                attackDamage: 200,
                minimumAttackRange: 280,
                attackRange: 2_000,
                attackInterval: 0.75,
                canMove: false,
                projectileKind: .mortarShell,
                projectileSpeed: 450,
                splashRadius: 30,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )
            definition.burstShotCount = 3
            definition.burstReloadTime = 10
            definition.activationDeployedHousing = 200
            return definition

        case .scattershot:
            return CombatDefinition(
                displayName: "Lanciarocce",
                role: .defense,
                maxHitPoints: 1_800,
                movementSpeed: 0,
                attackDamage: 180,
                minimumAttackRange: 120,
                attackRange: 400,
                attackInterval: 3.2,
                canMove: false,
                projectileKind: .mortarShell,
                projectileSpeed: 500,
                // The real rocks spray a cone behind the target; a round
                // splash of 1.5 tiles approximates it.
                splashRadius: 60,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .spellTower:
            // Casts defensive spells in the game; the simulator keeps it as
            // a defense that troops target but that never attacks.
            return CombatDefinition(
                displayName: "Torre degli Incantesimi",
                role: .defense,
                maxHitPoints: 1_100,
                movementSpeed: 0,
                attackDamage: 0,
                minimumAttackRange: 0,
                attackRange: 360,
                attackInterval: 0,
                canMove: false,
                projectileKind: nil,
                projectileSpeed: 0,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )

        case .monolith:
            var definition = CombatDefinition(
                displayName: "Monolito",
                role: .defense,
                maxHitPoints: 1_800,
                movementSpeed: 0,
                attackDamage: 90,
                minimumAttackRange: 0,
                attackRange: 440,
                attackInterval: 1.5,
                canMove: false,
                projectileKind: .airBolt,
                projectileSpeed: 800,
                splashRadius: 0,
                selfDestructsOnAttack: false,
                attackTargetLayer: .both,
                targetingProfile: nil
            )
            definition.targetMaxHitPointDamageFraction = 0.12
            return definition

        case .bomb:
            return CombatDefinition(
                displayName: "Bomba",
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
                destructionDamage: 90,
                destructionRadius: 120,
                destructionTargetLayer: .ground,
                startsHidden: true,
                activationRange: 60,
                attackTargetLayer: .ground,
                targetingProfile: nil
            )

        case .springTrap:
            var definition = CombatDefinition(
                displayName: "Trappola a molla",
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
                destructionDamage: 400,
                destructionTargetLayer: .ground,
                startsHidden: true,
                activationRange: 40,
                attackTargetLayer: .ground,
                targetingProfile: nil
            )
            definition.trapEffect = .spring(capacity: 15)
            return definition

        case .seekingAirMine:
            var definition = CombatDefinition(
                displayName: "Mina aerea a ricerca",
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
                destructionDamage: 1_000,
                destructionTargetLayer: .air,
                startsHidden: true,
                activationRange: 160,
                attackTargetLayer: .air,
                targetingProfile: nil
            )
            definition.trapEffect = .strike
            return definition

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
