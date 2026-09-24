import Foundation

// MARK: - Catalog

/// Per-level statistics exported from the live game by
/// `Tools/generate_reference_game_data.py`.
///
/// Values stay in game units (tiles, seconds, in-game movement speed);
/// `ReferenceGameData` converts them into simulator world units.
nonisolated struct ReferenceGameCatalog: Decodable {
    let source: ReferenceGameSource
    let units: [String: ReferenceUnit]
    let spells: [String: ReferenceSpell]

    static let resourceName = "ReferenceGameData"

    static func decode(from data: Data) throws -> ReferenceGameCatalog {
        try JSONDecoder().decode(ReferenceGameCatalog.self, from: data)
    }

    static func loadBundled() throws -> ReferenceGameCatalog {
        let bundle = Bundle(for: ReferenceGameBundleToken.self)
        guard let url = bundle.url(
            forResource: resourceName,
            withExtension: "json"
        ) else {
            throw ReferenceGameDataError.missingResource
        }
        return try decode(from: Data(contentsOf: url))
    }

    func unit(for kind: BattleEntityKind) -> ReferenceUnit? {
        units[kind.referenceKey]
    }

    func spell(for kind: BattleSpellKind) -> ReferenceSpell? {
        spells[kind.referenceKey]
    }
}

nonisolated enum ReferenceGameDataError: Error {
    case missingResource
}

nonisolated private final class ReferenceGameBundleToken {}

nonisolated struct ReferenceGameSource: Decodable {
    let package: String
    let version: String
}

nonisolated struct ReferenceUnit: Decodable {
    let name: String
    let range: Double?
    let attackInterval: Double?
    let movementSpeed: Double?
    let splashRadius: Double?
    let triggerRadius: Double?
    let damageRadius: Double?
    let levels: [ReferenceUnitLevel]

    /// Highest level unlocked at the given Town Hall, or the first level
    /// when the unit is not unlocked yet.
    func level(forTownHall townHall: Int) -> ReferenceUnitLevel? {
        levels.last(where: { $0.townHall <= townHall }) ?? levels.first
    }

    func level(numbered number: Int) -> ReferenceUnitLevel? {
        levels.first(where: { $0.level == number })
    }
}

nonisolated struct ReferenceUnitLevel: Decodable {
    let level: Int
    let townHall: Int
    let hitpoints: Double?
    let damagePerHit: Double?
    let wallDamageMultiplier: Double?
    let deathDamage: Double?
    let damageRadius: Double?
    let pushStrength: Double?
    let abilityHealing: Double?

    /// Inferno Tower damage per hit for its three heat stages.
    let rampDamagePerHit: [Double]?
}

nonisolated struct ReferenceSpell: Decodable {
    let name: String
    let levels: [ReferenceSpellLevel]

    func level(forTownHall townHall: Int) -> ReferenceSpellLevel? {
        levels.last(where: { $0.townHall <= townHall }) ?? levels.first
    }

    func level(numbered number: Int) -> ReferenceSpellLevel? {
        levels.first(where: { $0.level == number })
    }
}

nonisolated struct ReferenceSpellLevel: Decodable {
    let level: Int
    let townHall: Int
    let radius: Double?
    let duration: Double?
    let healingPerSecond: Double?
    let damage: Double?
    let damageIncreasePercent: Double?
    let speedIncrease: Double?
    let buildingDamagePercent: Double?
}

// MARK: - Level selection

/// Chooses which level of every unit and spell the simulation uses.
/// Levels default to the maximum unlocked at `townHall`; explicit
/// overrides win when they name an existing level.
nonisolated struct ReferenceLevelProfile: Hashable {
    var townHall: Int
    var unitLevels: [BattleEntityKind: Int] = [:]
    var spellLevels: [BattleSpellKind: Int] = [:]

    func level(
        of unit: ReferenceUnit,
        for kind: BattleEntityKind
    ) -> ReferenceUnitLevel? {
        if
            let number = unitLevels[kind],
            let level = unit.level(numbered: number)
        {
            return level
        }
        return unit.level(forTownHall: townHall)
    }

    func level(
        of spell: ReferenceSpell,
        for kind: BattleSpellKind
    ) -> ReferenceSpellLevel? {
        if
            let number = spellLevels[kind],
            let level = spell.level(numbered: number)
        {
            return level
        }
        return spell.level(forTownHall: townHall)
    }
}

// MARK: - Provider

/// Game data built from real per-level statistics.
///
/// Numbers (hit points, damage, attack speed, ranges, speeds, spell
/// strength) come from the catalog. Behaviour the catalog does not
/// describe — projectiles, target preferences, hero ability shape, siege
/// payloads, troop splash radii — falls back to the prototype definition.
nonisolated struct ReferenceGameData: GameDataProviding {
    /// World units per tile. Matches the prototype navigation grid cells.
    static let defaultTileSize = 40.0

    /// In-game movement speed 8 equals one tile per second.
    static let movementSpeedPerTileSecond = 8.0

    /// Game ranges are measured from the target's edge, while the engine
    /// measures centre to centre on one-cell buildings. Half a cell for
    /// the target plus half a cell for the troop keeps melee troops able
    /// to reach buildings and walls from the neighbouring cell.
    static let troopContactPadding = 1.0

    /// Mortar blind spot in tiles; not part of the exported catalog.
    static let mortarMinimumRange = 4.0

    /// Wall Breakers deal 40× damage to walls.
    static let wallBreakerWallMultiplier = 40.0

    /// Inferno Tower heat stages begin after these many seconds.
    static let infernoStageStartTimes: [TimeInterval] = [0, 1.5, 5]

    let catalog: ReferenceGameCatalog
    let profile: ReferenceLevelProfile
    let fallback: any GameDataProviding
    let tileSize: Double

    init(
        catalog: ReferenceGameCatalog,
        profile: ReferenceLevelProfile,
        fallback: any GameDataProviding = PrototypeGameData(),
        tileSize: Double = ReferenceGameData.defaultTileSize
    ) {
        self.catalog = catalog
        self.profile = profile
        self.fallback = fallback
        self.tileSize = tileSize
    }

    func level(for kind: BattleEntityKind) -> Int? {
        catalog.unit(for: kind).flatMap {
            profile.level(of: $0, for: kind)?.level
        }
    }

    func spellLevel(for kind: BattleSpellKind) -> Int? {
        catalog.spell(for: kind).flatMap {
            profile.level(of: $0, for: kind)?.level
        }
    }

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        let base = fallback.definition(for: kind)
        guard
            let unit = catalog.unit(for: kind),
            let level = profile.level(of: unit, for: kind)
        else {
            return base
        }

        var attackDamage = level.damagePerHit ?? base.attackDamage
        var rampMultipliers = base.damageRampMultipliers
        var attackRange = base.attackRange
        var minimumAttackRange = base.minimumAttackRange
        var splashRadius = base.splashRadius
        var destructionDamage = base.destructionDamage
        var destructionRadius = base.destructionRadius
        var activationRange = base.activationRange
        var pushbackDistance = base.pushbackDistance
        var wallMultiplier = base.damageMultiplierAgainstWalls
        var heroAbility = base.heroAbility
        let attackInterval = unit.attackInterval ?? base.attackInterval

        let movementSpeed = unit.movementSpeed.map {
            $0 / Self.movementSpeedPerTileSecond * tileSize
        } ?? base.movementSpeed

        switch base.role {
        case .troop:
            if let range = unit.range {
                attackRange = (range + Self.troopContactPadding) * tileSize
            }
            if kind == .wallBreaker {
                wallMultiplier = Self.wallBreakerWallMultiplier
            }
            if let multiplier = level.wallDamageMultiplier {
                wallMultiplier = multiplier
            }
            if let ability = base.heroAbility, let healing = level.abilityHealing {
                heroAbility = HeroAbilityDefinition(
                    displayName: ability.displayName,
                    activationHealthFraction: ability.activationHealthFraction,
                    duration: ability.duration,
                    instantHealing: healing,
                    damageMultiplier: ability.damageMultiplier,
                    movementSpeedMultiplier: ability.movementSpeedMultiplier,
                    attackSpeedMultiplier: ability.attackSpeedMultiplier,
                    attackRangeMultiplier: ability.attackRangeMultiplier,
                    behaviorEvidence: ability.behaviorEvidence,
                    tuningEvidence: .documented
                )
            }

        case .defense:
            if let range = unit.range {
                attackRange = range * tileSize
            }
            if kind == .mortar {
                minimumAttackRange = Self.mortarMinimumRange * tileSize
            }
            if let splash = unit.splashRadius {
                splashRadius = splash * tileSize
            }
            if let trigger = unit.triggerRadius {
                activationRange = trigger * tileSize
            }
            if let deathDamage = level.deathDamage {
                destructionDamage = deathDamage
            }
            if let push = level.pushStrength {
                pushbackDistance = push * tileSize
            }
            if let stages = level.rampDamagePerHit, let first = stages.first, first > 0 {
                attackDamage = first
                rampMultipliers = Self.rampMultipliers(
                    stageDamage: stages,
                    attackInterval: attackInterval
                )
            }

        case .trap:
            attackDamage = 0
            if let damage = level.damagePerHit {
                destructionDamage = damage
            }
            if let radius = level.damageRadius ?? unit.damageRadius {
                destructionRadius = radius * tileSize
            }
            if let trigger = unit.triggerRadius {
                activationRange = trigger * tileSize
            }

        case .building, .wall:
            break
        }

        return CombatDefinition(
            displayName: base.displayName,
            role: base.role,
            maxHitPoints: level.hitpoints ?? base.maxHitPoints,
            movementSpeed: movementSpeed,
            attackDamage: attackDamage,
            damageMultiplierAgainstWalls: wallMultiplier,
            minimumAttackRange: minimumAttackRange,
            attackRange: attackRange,
            attackInterval: attackInterval,
            canMove: base.canMove,
            projectileKind: base.projectileKind,
            projectileSpeed: base.projectileSpeed,
            splashRadius: splashRadius,
            selfDestructsOnAttack: base.selfDestructsOnAttack,
            damageRampMultipliers: rampMultipliers,
            destructionDamage: destructionDamage,
            destructionRadius: destructionRadius,
            destructionTargetLayer: base.destructionTargetLayer,
            startsHidden: base.startsHidden,
            activationRange: activationRange,
            pushbackDistance: pushbackDistance,
            movementDomain: base.movementDomain,
            attackTargetLayer: base.attackTargetLayer,
            targetingProfile: base.targetingProfile,
            heroAbility: heroAbility,
            siegePayload: base.siegePayload
        )
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        let base = fallback.spellDefinition(for: kind)
        guard
            let spell = catalog.spell(for: kind),
            let level = profile.level(of: spell, for: kind)
        else {
            return base
        }

        let radius = level.radius.map { $0 * tileSize } ?? base.radius
        let duration = level.duration ?? base.duration
        var healingPerSecond = base.healingPerSecond
        var instantDamage = base.instantDamage
        var damageMultiplier = base.damageMultiplier
        var movementSpeedMultiplier = base.movementSpeedMultiplier
        var attackSpeedMultiplier = base.attackSpeedMultiplier
        var movementSpeedBonus = base.movementSpeedBonus
        var hitPointFraction = base.maxHitPointDamageFraction
        var tuningEvidence = MechanicEvidence.documented

        switch kind {
        case .heal:
            healingPerSecond = level.healingPerSecond ?? healingPerSecond
        case .rage:
            // Rage adds a flat speed bonus and does not change attack rate.
            damageMultiplier = 1 + (level.damageIncreasePercent ?? 0) / 100
            movementSpeedMultiplier = 1
            attackSpeedMultiplier = 1
            movementSpeedBonus = (level.speedIncrease ?? 0) /
                Self.movementSpeedPerTileSecond * tileSize
        case .freeze:
            break
        case .lightning:
            instantDamage = level.damage ?? instantDamage
        case .earthquake:
            // Damage scales with each target's maximum hit points.
            instantDamage = 0
            hitPointFraction = (level.buildingDamagePercent ?? 0) / 100
            tuningEvidence = .approximation
        }

        return SpellDefinition(
            displayName: base.displayName,
            radius: radius,
            duration: duration,
            healingPerSecond: healingPerSecond,
            instantDamage: instantDamage,
            damageMultiplier: damageMultiplier,
            movementSpeedMultiplier: movementSpeedMultiplier,
            attackSpeedMultiplier: attackSpeedMultiplier,
            disablesDefenses: base.disablesDefenses,
            behaviorEvidence: base.behaviorEvidence,
            tuningEvidence: tuningEvidence,
            maxHitPointDamageFraction: hitPointFraction,
            movementSpeedBonus: movementSpeedBonus
        )
    }

    /// Expands heat stages into one multiplier per consecutive attack,
    /// relative to the first stage's damage.
    static func rampMultipliers(
        stageDamage: [Double],
        attackInterval: TimeInterval
    ) -> [Double] {
        guard let first = stageDamage.first, first > 0, attackInterval > 0 else {
            return [1]
        }

        var multipliers: [Double] = []
        for (index, damage) in stageDamage.enumerated() {
            let multiplier = damage / first
            guard index + 1 < stageDamage.count,
                  index + 1 < infernoStageStartTimes.count
            else {
                multipliers.append(multiplier)
                break
            }
            let stageEnd = infernoStageStartTimes[index + 1]
            let attacksBeforeStageEnd = Int(
                (stageEnd / attackInterval).rounded(.up)
            )
            let count = max(attacksBeforeStageEnd - multipliers.count, 0)
            multipliers.append(
                contentsOf: Array(repeating: multiplier, count: count)
            )
        }
        return multipliers.isEmpty ? [1] : multipliers
    }
}

// MARK: - Data source selection

/// Which statistics the lab simulates with.
nonisolated enum GameDataSource: Hashable, Identifiable {
    case prototype
    case reference(townHall: Int)

    static let referenceTownHalls = Array(7...18)

    var id: String {
        switch self {
        case .prototype:
            return "prototype"
        case .reference(let townHall):
            return "reference-\(townHall)"
        }
    }

    var title: String {
        switch self {
        case .prototype:
            return "Prototipo"
        case .reference(let townHall):
            return "Reali · Municipio \(townHall)"
        }
    }

    func makeGameData(
        catalog: () throws -> ReferenceGameCatalog = ReferenceGameCatalog.loadBundled
    ) throws -> any GameDataProviding {
        switch self {
        case .prototype:
            return PrototypeGameData()
        case .reference(let townHall):
            return ReferenceGameData(
                catalog: try catalog(),
                profile: ReferenceLevelProfile(townHall: townHall)
            )
        }
    }
}

// MARK: - Catalog keys

extension BattleEntityKind {
    /// Key of this entity in `ReferenceGameData.json`.
    nonisolated var referenceKey: String {
        switch self {
        case .giant: return "giant"
        case .barbarian: return "barbarian"
        case .archer: return "archer"
        case .wallBreaker: return "wallBreaker"
        case .wizard: return "wizard"
        case .balloon: return "balloon"
        case .dragon: return "dragon"
        case .barbarianKing: return "barbarianKing"
        case .archerQueen: return "archerQueen"
        case .wallWrecker: return "wallWrecker"
        case .stoneSlammer: return "stoneSlammer"
        case .cannon: return "cannon"
        case .archerTower: return "archerTower"
        case .mortar: return "mortar"
        case .wizardTower: return "wizardTower"
        case .infernoTower: return "infernoTower"
        case .bombTower: return "bombTower"
        case .hiddenTesla: return "hiddenTesla"
        case .giantBomb: return "giantBomb"
        case .airBomb: return "airBomb"
        case .airSweeper: return "airSweeper"
        case .airDefense: return "airDefense"
        case .townHall: return "townHall"
        case .goldStorage: return "goldStorage"
        case .wall: return "wall"
        }
    }
}

extension BattleSpellKind {
    /// Key of this spell in `ReferenceGameData.json`.
    nonisolated var referenceKey: String {
        switch self {
        case .heal: return "heal"
        case .rage: return "rage"
        case .freeze: return "freeze"
        case .lightning: return "lightning"
        case .earthquake: return "earthquake"
        }
    }
}
