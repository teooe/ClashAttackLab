import Foundation

/// Hero equipment modeled by the simulator. Each hero carries two pieces;
/// their stats come from the catalog's `equipment` section.
nonisolated enum HeroEquipmentKind: String, Codable, CaseIterable, Hashable {
    case rageVial
    case giantGauntlet
    case spikyBall
    case vampstache
    case giantArrow
    case frozenArrow
    case invisibilityVial
    case eternalTome
    case fireball
    case rageGem
    case healingTome
    case seekingShield
    case rocketSpear
    case electroBoots
    case royalGem
    case hasteVial
    case fireHeart
    case revengeDeck
    case healerPuppet

    var referenceKey: String {
        rawValue
    }

    var hero: BattleEntityKind {
        switch self {
        case .rageVial, .giantGauntlet, .spikyBall, .vampstache:
            return .barbarianKing
        case .giantArrow, .frozenArrow, .invisibilityVial, .healerPuppet:
            return .archerQueen
        case .eternalTome, .fireball, .rageGem, .healingTome:
            return .grandWarden
        case .seekingShield, .rocketSpear, .electroBoots, .royalGem, .hasteVial:
            return .royalChampion
        case .fireHeart, .revengeDeck:
            return .dragonDuke
        }
    }

    var displayName: String {
        switch self {
        case .rageVial: return "Fiala della furia"
        case .giantGauntlet: return "Guanto gigante"
        case .spikyBall: return "Palla chiodata"
        case .vampstache: return "Vampibaffi"
        case .giantArrow: return "Freccia gigante"
        case .frozenArrow: return "Freccia congelante"
        case .invisibilityVial: return "Fiala dell'invisibilità"
        case .eternalTome: return "Tomo eterno"
        case .fireball: return "Palla di fuoco"
        case .rageGem: return "Gemma della furia"
        case .healingTome: return "Tomo curativo"
        case .seekingShield: return "Scudo cercatore"
        case .rocketSpear: return "Lancia razzo"
        case .electroBoots: return "Stivali elettrici"
        case .royalGem: return "Gemma reale"
        case .hasteVial: return "Fiala della velocità"
        case .fireHeart: return "Cuor di fuoco"
        case .revengeDeck: return "Mazzo della vendetta"
        case .healerPuppet: return "Pupazzo del guaritore"
        }
    }

    /// Pieces a hero can wear, in menu order.
    static func available(for hero: BattleEntityKind) -> [HeroEquipmentKind] {
        allCases.filter { $0.hero == hero }
    }

    /// The player's own Town Hall 15 sets (the King's is a popular one),
    /// used until they pick others in the app.
    static let defaultLoadouts: [BattleEntityKind: [HeroEquipmentKind]] = [
        .barbarianKing: [.giantGauntlet, .spikyBall],
        .archerQueen: [.healerPuppet, .giantArrow],
        .grandWarden: [.rageGem, .eternalTome],
        .royalChampion: [.rocketSpear, .electroBoots],
        .dragonDuke: [.fireHeart, .revengeDeck]
    ]

    /// Heroes wear at most this many pieces at a time.
    static let piecesPerHero = 2
}

/// Keeps the player's equipment choice between launches.
nonisolated enum HeroEquipmentStore {
    static let key = "ClashAttackLab.heroEquipment.v1"

    static func load(from defaults: UserDefaults = .standard) -> [BattleEntityKind: [HeroEquipmentKind]] {
        guard
            let data = defaults.data(forKey: key),
            let stored = try? JSONDecoder().decode([String: [HeroEquipmentKind]].self, from: data)
        else {
            return HeroEquipmentKind.defaultLoadouts
        }
        var loadouts: [BattleEntityKind: [HeroEquipmentKind]] = [:]
        for hero in BattleEntityKind.heroKinds {
            if let pieces = stored[hero.referenceKey] {
                loadouts[hero] = pieces.filter { $0.hero == hero }
            }
        }
        return loadouts
    }

    static func save(
        _ loadouts: [BattleEntityKind: [HeroEquipmentKind]],
        to defaults: UserDefaults = .standard
    ) {
        let stored = Dictionary(uniqueKeysWithValues: loadouts.map { ($0.key.referenceKey, $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}

/// Keeps the player's pet choice between launches.
nonisolated enum HeroPetStore {
    static let key = "ClashAttackLab.heroPets.v1"

    static func load(from defaults: UserDefaults = .standard) -> [BattleEntityKind: BattleEntityKind] {
        guard
            let data = defaults.data(forKey: key),
            let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return BattleEntityKind.defaultPets
        }
        var pets: [BattleEntityKind: BattleEntityKind] = [:]
        for hero in BattleEntityKind.heroKinds {
            if
                let name = stored[hero.referenceKey],
                let pet = BattleEntityKind.petKinds.first(where: { $0.referenceKey == name })
            {
                pets[hero] = pet
            }
        }
        return pets
    }

    static func save(
        _ pets: [BattleEntityKind: BattleEntityKind],
        to defaults: UserDefaults = .standard
    ) {
        let stored = Dictionary(uniqueKeysWithValues: pets.map {
            ($0.key.referenceKey, $0.value.referenceKey)
        })
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Catalog

nonisolated struct ReferenceEquipment: Decodable {
    let name: String
    let hero: String
    let rarity: String
    let active: Bool
    let ability: ReferenceEquipmentAbility
    let levels: [ReferenceEquipmentLevel]

    var isEpic: Bool {
        rarity == "epic"
    }

    /// Stats at `level`: fields missing from a level keep the value of
    /// the closest lower level that lists them.
    func stats(atLevel level: Int) -> ReferenceEquipmentLevel? {
        let reached = levels.filter { $0.level <= level }
        guard var merged = reached.first else {
            return nil
        }
        for next in reached.dropFirst() {
            merged = merged.overlaid(by: next)
        }
        return merged
    }
}

/// Shape of the ability shared by every level.
nonisolated struct ReferenceEquipmentAbility: Decodable {
    let abilityDuration: Double?
    let areaDamageRadius: Double?
    let numberOfTargets: Int?
    let attackRange: Double?
    let auraRadius: Double?
    let damageRadius: Double?
    let maxCounterRange: Double?
    let counterCooldown: Double?
}

nonisolated struct ReferenceEquipmentLevel: Decodable {
    var level: Int
    var blacksmith: Int?
    var hitpointIncrease: Double?
    var hpRecoveryIncrease: Double?
    var dpsIncrease: Double?
    var attackSpeedIncrease: Double?
    var abilityDuration: Double?
    var damageIncrease: Double?
    var movementSpeedIncrease: Double?
    var incomingDamageReduction: Double?
    var selfHealingPerSecond: Double?
    var projectileDamage: Double?
    var projectileDamagePerTarget: Double?
    var numberOfTargets: Int?
    var healPerHit: Double?
    var slowDown: Double?
    var slowDownDuration: Double?
    var damagePerShotIncrease: Double?
    var damageRadius: Double?
    var damageIncreasePercent: Double?
    var healingPerSecond: Double?
    var numberOfAttacks: Int?
    var auraDps: Double?
    var healthRecovery: Double?
    var speedIncrease: Double?
    var abilityAttackSpeedIncrease: Double?
    var damageOnDefeat: Double?
    var counterDamage: Double?
    var healPerCounter: Double?
    var summonedHealers: Int?

    func overlaid(by next: ReferenceEquipmentLevel) -> ReferenceEquipmentLevel {
        var merged = next
        merged.blacksmith = next.blacksmith ?? blacksmith
        merged.hitpointIncrease = next.hitpointIncrease ?? hitpointIncrease
        merged.hpRecoveryIncrease = next.hpRecoveryIncrease ?? hpRecoveryIncrease
        merged.dpsIncrease = next.dpsIncrease ?? dpsIncrease
        merged.attackSpeedIncrease = next.attackSpeedIncrease ?? attackSpeedIncrease
        merged.abilityDuration = next.abilityDuration ?? abilityDuration
        merged.damageIncrease = next.damageIncrease ?? damageIncrease
        merged.movementSpeedIncrease = next.movementSpeedIncrease ?? movementSpeedIncrease
        merged.incomingDamageReduction = next.incomingDamageReduction ?? incomingDamageReduction
        merged.selfHealingPerSecond = next.selfHealingPerSecond ?? selfHealingPerSecond
        merged.projectileDamage = next.projectileDamage ?? projectileDamage
        merged.projectileDamagePerTarget = next.projectileDamagePerTarget ?? projectileDamagePerTarget
        merged.numberOfTargets = next.numberOfTargets ?? numberOfTargets
        merged.healPerHit = next.healPerHit ?? healPerHit
        merged.slowDown = next.slowDown ?? slowDown
        merged.slowDownDuration = next.slowDownDuration ?? slowDownDuration
        merged.damagePerShotIncrease = next.damagePerShotIncrease ?? damagePerShotIncrease
        merged.damageRadius = next.damageRadius ?? damageRadius
        merged.damageIncreasePercent = next.damageIncreasePercent ?? damageIncreasePercent
        merged.healingPerSecond = next.healingPerSecond ?? healingPerSecond
        merged.numberOfAttacks = next.numberOfAttacks ?? numberOfAttacks
        merged.auraDps = next.auraDps ?? auraDps
        merged.healthRecovery = next.healthRecovery ?? healthRecovery
        merged.speedIncrease = next.speedIncrease ?? speedIncrease
        merged.abilityAttackSpeedIncrease = next.abilityAttackSpeedIncrease ?? abilityAttackSpeedIncrease
        merged.damageOnDefeat = next.damageOnDefeat ?? damageOnDefeat
        merged.counterDamage = next.counterDamage ?? counterDamage
        merged.healPerCounter = next.healPerCounter ?? healPerCounter
        merged.summonedHealers = next.summonedHealers ?? summonedHealers
        return merged
    }
}

/// Highest common and epic equipment level per Town Hall
/// (index = Town Hall − 1), set by the Blacksmith.
nonisolated struct ReferenceEquipmentCaps: Decodable {
    let common: [Int]
    let epic: [Int]

    func cap(epic isEpic: Bool, townHall: Int) -> Int {
        let values = isEpic ? epic : common
        guard !values.isEmpty else {
            return 0
        }
        return values[min(max(townHall, 1), values.count) - 1]
    }
}

// MARK: - Applying equipment

extension ReferenceGameData {
    /// Seconds-per-tile conversions and the hero's own numbers decide how
    /// each piece changes the hero.
    func equipped(
        _ hero: CombatDefinition,
        kind: BattleEntityKind
    ) -> CombatDefinition {
        let pieces = (heroEquipment[kind] ?? [])
            .filter { $0.hero == kind }
            .prefix(HeroEquipmentKind.piecesPerHero)
        guard !pieces.isEmpty else {
            return hero
        }

        var definition = hero
        var ability = definition.heroAbility ?? HeroAbilityDefinition(
            displayName: "Equipaggiamento",
            activationHealthFraction: 0.5,
            duration: 0,
            instantHealing: 0,
            damageMultiplier: 1,
            movementSpeedMultiplier: 1,
            attackSpeedMultiplier: 1,
            attackRangeMultiplier: 1,
            behaviorEvidence: .documented,
            tuningEvidence: .documented
        )
        // Equipment replaces the old built-in abilities: only the base
        // healing of the hero's level stays.
        var duration = 0.0
        var healing = ability.instantHealing
        var damageMultiplier = 1.0
        var movementBonus = 0.0
        var attackSpeedMultiplier = 1.0
        var names: [String] = []
        var strike = (count: 0, range: 0.0, damage: 0.0, splash: 0.0, buildings: false)
        var protection = (radius: 0.0, duration: 0.0)
        var bonus = (damage: 0.0, attacks: 0, range: 0.0, invisibility: 0.0)
        var damageReduction = 0.0
        var selfHealing = 0.0
        var areaHealing = (perSecond: 0.0, radius: 0.0)
        var summons: (kind: BattleEntityKind?, count: Int) = (nil, 0)
        var splash = 0.0
        let baseSpeed = hero.movementSpeed
        let baseProtectionRadius = ability.protectionRadius

        for piece in pieces {
            guard
                let entry = catalog.equipment?[piece.referenceKey],
                let stats = entry.stats(atLevel: equipmentLevel(of: piece, entry: entry))
            else {
                continue
            }

            // Passive stats.
            definition.maxHitPoints += stats.hitpointIncrease ?? 0
            definition.attackDamage += (stats.dpsIncrease ?? 0) * hero.attackInterval
            if let increase = stats.attackSpeedIncrease {
                definition.attackInterval /= 1 + increase / 100
            }
            if let heal = stats.healPerHit {
                definition.healPerHit += heal
            }
            if let slow = stats.slowDown, let slowDuration = stats.slowDownDuration {
                definition.hitSlowFraction = max(definition.hitSlowFraction, slow / 100)
                definition.hitSlowDuration = max(definition.hitSlowDuration, slowDuration)
            }
            if let auraDps = stats.auraDps {
                definition.buildingAuraDamagePerSecond += auraDps
                definition.buildingAuraRadius = max(
                    definition.buildingAuraRadius,
                    (entry.ability.auraRadius ?? 0) * tileSize
                )
            }
            if piece == .electroBoots || piece == .fireHeart, let heal = stats.selfHealingPerSecond {
                definition.passiveHealingPerSecond += heal
            }
            if let burst = stats.damageOnDefeat {
                definition.destructionDamage = max(definition.destructionDamage, burst)
                definition.destructionRadius = max(
                    definition.destructionRadius,
                    (entry.ability.damageRadius ?? 0) * tileSize
                )
            }
            if let counter = stats.counterDamage {
                definition.counterDamage += counter
                definition.counterHealing += stats.healPerCounter ?? 0
                definition.counterRange = max(
                    definition.counterRange,
                    (entry.ability.maxCounterRange ?? 0) * tileSize
                )
                definition.counterCooldown = entry.ability.counterCooldown ?? 1
            }
            if let boost = stats.damageIncreasePercent {
                definition.auraDamageBonus = max(definition.auraDamageBonus, boost / 100)
            }

            guard entry.active else {
                continue
            }

            // Active ability, fired together with the hero's other piece.
            names.append(piece.displayName)
            let pieceDuration = stats.abilityDuration ?? entry.ability.abilityDuration ?? 0
            duration = max(duration, pieceDuration)
            healing += (stats.hpRecoveryIncrease ?? 0) + (stats.healthRecovery ?? 0)
            if let increase = stats.damageIncrease {
                damageMultiplier = max(damageMultiplier, 1 + increase / 100)
            }
            let speed = stats.movementSpeedIncrease ?? stats.speedIncrease ?? 0
            movementBonus = max(movementBonus, speed / Self.movementSpeedPerTileSecond * tileSize)
            if let increase = stats.abilityAttackSpeedIncrease {
                attackSpeedMultiplier = max(attackSpeedMultiplier, 1 + increase / 100)
            }
            // Active pieces heal the hero while the ability runs.
            selfHealing += stats.selfHealingPerSecond ?? 0
            if let reduction = stats.incomingDamageReduction {
                damageReduction = max(damageReduction, reduction / 100)
                splash = max(splash, (entry.ability.areaDamageRadius ?? 0) * tileSize)
            }
            if let healers = stats.summonedHealers {
                summons = (.healer, healers)
            }

            switch piece {
            case .eternalTome:
                protection = (
                    max(baseProtectionRadius, Self.eternalTomeRadius * tileSize),
                    pieceDuration
                )
            case .spikyBall:
                strike = (
                    stats.numberOfTargets ?? 1, Self.spikyBallRange * tileSize,
                    stats.projectileDamagePerTarget ?? 0, 0, true
                )
            case .seekingShield:
                strike = (
                    entry.ability.numberOfTargets ?? 4, Self.seekingShieldRange * tileSize,
                    stats.projectileDamage ?? 0, 0, false
                )
            case .giantArrow:
                strike = (
                    Self.giantArrowTargets, Self.giantArrowRange * tileSize,
                    stats.projectileDamage ?? 0,
                    (entry.ability.damageRadius ?? 0) * tileSize, true
                )
            case .fireball:
                strike = (
                    1, Self.fireballRange * tileSize,
                    stats.projectileDamage ?? 0,
                    (stats.damageRadius ?? 0) * tileSize, true
                )
            case .rocketSpear:
                bonus.damage += stats.damagePerShotIncrease ?? 0
                bonus.attacks = max(bonus.attacks, stats.numberOfAttacks ?? 0)
                bonus.range = max(bonus.range, (entry.ability.attackRange ?? 0) * tileSize)
            case .invisibilityVial:
                bonus.damage += stats.damagePerShotIncrease ?? 0
                bonus.invisibility = max(bonus.invisibility, pieceDuration)
            case .healingTome:
                areaHealing = (
                    stats.healingPerSecond ?? 0,
                    Self.healingTomeRadius * tileSize
                )
            default:
                break
            }
        }

        guard !names.isEmpty else {
            definition.heroAbility = definition.heroAbility.map {
                withoutBuiltInEffects($0, healing: healing)
            }
            return definition
        }

        var equippedAbility = HeroAbilityDefinition(
            displayName: names.joined(separator: " + "),
            activationHealthFraction: ability.activationHealthFraction,
            duration: max(duration, bonus.invisibility),
            instantHealing: healing,
            damageMultiplier: damageMultiplier,
            movementSpeedMultiplier: baseSpeed > 0
                ? (baseSpeed + movementBonus) / baseSpeed
                : 1,
            attackSpeedMultiplier: attackSpeedMultiplier,
            attackRangeMultiplier: 1,
            behaviorEvidence: .documented,
            tuningEvidence: .approximation
        )
        equippedAbility.strikeTargetCount = strike.count
        equippedAbility.strikeRange = strike.range
        equippedAbility.strikeDamage = strike.damage
        equippedAbility.strikeSplashRadius = strike.splash
        equippedAbility.strikesAnyBuilding = strike.buildings
        equippedAbility.protectionRadius = protection.radius
        equippedAbility.protectionDuration = protection.duration
        equippedAbility.bonusDamagePerHit = bonus.damage
        equippedAbility.boostedAttackCount = bonus.attacks
        equippedAbility.boostedAttackRange = bonus.range
        equippedAbility.invisibilityDuration = bonus.invisibility
        equippedAbility.incomingDamageReduction = damageReduction
        equippedAbility.selfHealingPerSecond = selfHealing
        equippedAbility.splashRadius = splash
        equippedAbility.areaHealingPerSecond = areaHealing.perSecond
        equippedAbility.areaHealingRadius = areaHealing.radius
        equippedAbility.summonedTroop = summons.kind
        equippedAbility.summonCount = summons.count
        ability = equippedAbility
        definition.heroAbility = ability
        return definition
    }

    /// Level a piece reaches at the profile's Town Hall: the Blacksmith's
    /// cap for its rarity, or a level picked in the profile.
    func equipmentLevel(of piece: HeroEquipmentKind, entry: ReferenceEquipment) -> Int {
        let highest = entry.levels.last?.level ?? 1
        if let chosen = profile.equipmentLevels[piece] {
            return min(max(chosen, 1), highest)
        }
        let cap = catalog.equipmentLevelCaps?.cap(
            epic: entry.isEpic,
            townHall: profile.townHall
        ) ?? highest
        return min(max(cap, 1), highest)
    }

    /// A hero with only passive pieces keeps healing but loses the old
    /// built-in effects.
    private func withoutBuiltInEffects(
        _ ability: HeroAbilityDefinition,
        healing: Double
    ) -> HeroAbilityDefinition {
        HeroAbilityDefinition(
            displayName: ability.displayName,
            activationHealthFraction: ability.activationHealthFraction,
            duration: 0,
            instantHealing: healing,
            damageMultiplier: 1,
            movementSpeedMultiplier: 1,
            attackSpeedMultiplier: 1,
            attackRangeMultiplier: 1,
            behaviorEvidence: ability.behaviorEvidence,
            tuningEvidence: ability.tuningEvidence
        )
    }

    // Shapes the catalog does not list, in tiles; all estimates.
    static let eternalTomeRadius = 7.0
    static let spikyBallRange = 6.0
    static let seekingShieldRange = 9.0
    static let giantArrowTargets = 3
    static let giantArrowRange = 12.0
    static let fireballRange = 8.0
    static let healingTomeRadius = 5.0
}

// MARK: - Comparing equipment

/// Best result one pair of pieces reached against the base under attack.
nonisolated struct EquipmentComparisonEntry: Identifiable, Equatable {
    let hero: BattleEntityKind
    let pieces: [HeroEquipmentKind]
    let stars: Int
    let destruction: Double
    let isCurrent: Bool

    var id: String {
        hero.referenceKey + ":" + pieces.map(\.rawValue).joined(separator: "+")
    }

    var name: String {
        pieces.map(\.displayName).joined(separator: " + ")
    }
}

nonisolated enum HeroEquipmentComparison {
    /// Every pair of pieces the hero can wear, in menu order.
    static func pairs(for hero: BattleEntityKind) -> [[HeroEquipmentKind]] {
        let pieces = HeroEquipmentKind.available(for: hero)
        var pairs: [[HeroEquipmentKind]] = []
        for first in pieces.indices {
            for second in pieces.indices where second > first {
                pairs.append([pieces[first], pieces[second]])
            }
        }
        return pairs
    }

    /// Heroes in their usual order, each hero's pairs best first; the
    /// current pair wins ties.
    static func ranked(_ entries: [EquipmentComparisonEntry]) -> [EquipmentComparisonEntry] {
        let order = BattleEntityKind.heroKinds
        return entries.sorted { first, second in
            let firstHero = order.firstIndex(of: first.hero) ?? order.count
            let secondHero = order.firstIndex(of: second.hero) ?? order.count
            if firstHero != secondHero {
                return firstHero < secondHero
            }
            if first.stars != second.stars {
                return first.stars > second.stars
            }
            if abs(first.destruction - second.destruction) > 1e-9 {
                return first.destruction > second.destruction
            }
            if first.isCurrent != second.isCurrent {
                return first.isCurrent
            }
            return first.id < second.id
        }
    }

    /// The best pair of each hero.
    static func best(of entries: [EquipmentComparisonEntry]) -> [BattleEntityKind: [HeroEquipmentKind]] {
        var best: [BattleEntityKind: [HeroEquipmentKind]] = [:]
        for entry in ranked(entries) where best[entry.hero] == nil {
            best[entry.hero] = entry.pieces
        }
        return best
    }
}
