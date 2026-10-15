import Foundation

nonisolated enum BattleEntityRole: Hashable {
    case troop
    case defense
    case building
    case wall
    case trap
}

nonisolated enum MovementDomain: Hashable {
    case ground
    case air
}

nonisolated enum AttackTargetLayer: Hashable {
    case ground
    case air
    case both

    func accepts(_ domain: MovementDomain) -> Bool {
        switch (self, domain) {
        case (.both, _), (.ground, .ground), (.air, .air):
            return true
        case (.ground, .air), (.air, .ground):
            return false
        }
    }
}

nonisolated enum MechanicEvidence: String, Hashable {
    case documented
    case observed
    case approximation
    case prototype
}

nonisolated enum TargetPreference: Hashable {
    case defenses
    case anyBuilding
    case walls
    case townHall

    /// Air Defenses first, then any building (Lava Hound).
    case airDefenses
}

/// How a trap hurts troops once it goes off.
nonisolated enum TrapEffect: Hashable {
    /// Splash damage around the trap (`destructionDamage` within
    /// `destructionRadius`).
    case explosion

    /// `destructionDamage` to the single nearest troop it can hit.
    case strike

    /// Throws the nearest troops off the battlefield until their housing
    /// space fills `capacity`; heroes are immune and troops too large to
    /// throw take `destructionDamage` instead.
    case spring(capacity: Int)
}

nonisolated struct TargetingProfile {
    let preference: TargetPreference
    let evidence: MechanicEvidence
}

nonisolated enum HeroAbilityState: Equatable {
    case notDeployed
    case ready
    case active
    case used
    case defeated
}

nonisolated struct HeroAbilityDefinition {
    let displayName: String
    let activationHealthFraction: Double
    let duration: TimeInterval
    let instantHealing: Double
    let damageMultiplier: Double
    let movementSpeedMultiplier: Double
    let attackSpeedMultiplier: Double
    let attackRangeMultiplier: Double
    let behaviorEvidence: MechanicEvidence
    let tuningEvidence: MechanicEvidence

    /// Strikes up to this many defenses within `strikeRange` of the hero,
    /// each for `strikeDamageMultiplier` times its attack damage
    /// (Seeking Shield).
    var strikeTargetCount = 0
    var strikeRange: Double = 0
    var strikeDamageMultiplier: Double = 0

    /// Troops within this radius, the hero included, take no damage for
    /// `protectionDuration` seconds, or the ability's duration when that
    /// is 0 (Eternal Tome).
    var protectionRadius: Double = 0
    var protectionDuration: TimeInterval = 0

    /// Flat damage of each strike, replacing `strikeDamageMultiplier`
    /// when above 0; strikes may hit any building, not only defenses, and
    /// splash `strikeSplashRadius` around each target (Spiky Ball, Giant
    /// Arrow, Fireball).
    var strikeDamage: Double = 0
    var strikeSplashRadius: Double = 0
    var strikesAnyBuilding = false

    /// Extra damage per hit for the next `boostedAttackCount` attacks,
    /// which reach `boostedAttackRange` (Rocket Spear), or while the hero
    /// is invisible (Invisibility Vial).
    var bonusDamagePerHit: Double = 0
    var boostedAttackCount = 0
    var boostedAttackRange: Double = 0

    /// Seconds defenses cannot see the hero (Invisibility Vial).
    var invisibilityDuration: TimeInterval = 0

    /// While active: less damage taken, healing every second and splash
    /// attacks (Giant Gauntlet).
    var incomingDamageReduction: Double = 0
    var selfHealingPerSecond: Double = 0
    var splashRadius: Double = 0

    /// While active, troops within `areaHealingRadius` heal this much per
    /// second (Healing Tome).
    var areaHealingPerSecond: Double = 0
    var areaHealingRadius: Double = 0
}

nonisolated struct CombatDefinition {
    let displayName: String
    let role: BattleEntityRole
    var maxHitPoints: Double
    let movementSpeed: Double
    var attackDamage: Double
    let damageMultiplierAgainstWalls: Double
    let minimumAttackRange: Double
    let attackRange: Double
    var attackInterval: TimeInterval
    let canMove: Bool
    let projectileKind: ProjectileKind?
    let projectileSpeed: Double
    let splashRadius: Double
    let selfDestructsOnAttack: Bool

    /// Multipliers applied to repeated attacks against the same target.
    /// A one-element array keeps ordinary attacks constant.
    let damageRampMultipliers: [Double]

    /// Optional damage emitted when this entity is destroyed.
    let destructionDamage: Double
    let destructionRadius: Double
    let destructionTargetLayer: AttackTargetLayer

    /// Hidden defenses become targetable inside this radius.
    let startsHidden: Bool
    let activationRange: Double

    /// Non-damaging displacement applied on every successful attack.
    let pushbackDistance: Double

    /// Ground troops navigate with A*. Air troops fly directly over walls.
    let movementDomain: MovementDomain

    /// Defines which troop movement domains a defense can acquire.
    let attackTargetLayer: AttackTargetLayer

    /// Nil for entities that do not choose offensive building targets.
    let targetingProfile: TargetingProfile?

    /// Nil for ordinary troops and all defensive structures.
    var heroAbility: HeroAbilityDefinition?

    /// Troops released when a siege machine is destroyed.
    let siegePayload: [BattleEntityKind]

    /// Side of the square footprint in world units. Zero keeps the entity
    /// a point, so attack ranges are measured centre to centre.
    let footprintSize: Double

    /// Army camp space of a troop. Heroes count 25, as they do towards
    /// waking the Eagle Artillery.
    var housingSpace = 0

    /// Shots fired back to back before pausing `burstReloadTime` seconds.
    /// One shot keeps the ordinary steady attack rhythm.
    var burstShotCount = 1
    var burstReloadTime: TimeInterval = 0

    /// Housing space the attacker must deploy before this defense wakes up.
    var activationDeployedHousing = 0

    /// Extra damage per hit, as a fraction of the target's maximum hit
    /// points (Monolith).
    var targetMaxHitPointDamageFraction: Double = 0

    var trapEffect: TrapEffect = .explosion

    /// Ground troops that cross walls without breaking them (Hog Rider,
    /// Miner, Root Rider) move straight to their target like air troops.
    var ignoresWalls = false

    /// Travels underground: defenses and traps ignore the troop until it
    /// surfaces to attack (Miner).
    var burrowsWhileMoving = false

    /// Chain attacks hit up to `chainTargetCount` buildings in total, each
    /// within `chainRange` of the previous one, every link dealing
    /// `chainDamageMultiplier` times the damage of the link before.
    var chainTargetCount = 1
    var chainRange: Double = 0
    var chainDamageMultiplier: Double = 1

    /// Other troops within `auraRadius` take `auraDamageReduction` less
    /// damage (Grand Warden's Life Aura, modeled as damage reduction).
    var auraRadius: Double = 0
    var auraDamageReduction: Double = 0

    /// Defending troops that come out of a Clan Castle once an attacker
    /// walks within `garrisonTriggerRadius`, or all at once when the
    /// castle falls.
    var garrison: [BattleEntityKind] = []
    var garrisonTriggerRadius: Double = 0

    // Passive hero equipment effects.

    /// Hit points healed on every attack (Vampstache).
    var healPerHit: Double = 0

    /// Each hit slows the target's attacks by this fraction for
    /// `hitSlowDuration` seconds (Frozen Arrow).
    var hitSlowFraction: Double = 0
    var hitSlowDuration: TimeInterval = 0

    /// Damage per second dealt to buildings within `buildingAuraRadius`
    /// (Electro Boots).
    var buildingAuraDamagePerSecond: Double = 0
    var buildingAuraRadius: Double = 0

    /// Hit points healed every second (Electro Boots).
    var passiveHealingPerSecond: Double = 0

    /// Troops inside the hero's `auraRadius` deal this much more damage
    /// (Rage Gem).
    var auraDamageBonus: Double = 0

    init(
        displayName: String,
        role: BattleEntityRole,
        maxHitPoints: Double,
        movementSpeed: Double,
        attackDamage: Double,
        damageMultiplierAgainstWalls: Double = 1,
        minimumAttackRange: Double,
        attackRange: Double,
        attackInterval: TimeInterval,
        canMove: Bool,
        projectileKind: ProjectileKind?,
        projectileSpeed: Double,
        splashRadius: Double,
        selfDestructsOnAttack: Bool,
        damageRampMultipliers: [Double] = [1],
        destructionDamage: Double = 0,
        destructionRadius: Double = 0,
        destructionTargetLayer: AttackTargetLayer = .ground,
        startsHidden: Bool = false,
        activationRange: Double = 0,
        pushbackDistance: Double = 0,
        movementDomain: MovementDomain = .ground,
        attackTargetLayer: AttackTargetLayer = .both,
        targetingProfile: TargetingProfile?,
        heroAbility: HeroAbilityDefinition? = nil,
        siegePayload: [BattleEntityKind] = [],
        footprintSize: Double = 0
    ) {
        self.displayName = displayName
        self.role = role
        self.maxHitPoints = maxHitPoints
        self.movementSpeed = movementSpeed
        self.attackDamage = attackDamage
        self.damageMultiplierAgainstWalls = damageMultiplierAgainstWalls
        self.minimumAttackRange = minimumAttackRange
        self.attackRange = attackRange
        self.attackInterval = attackInterval
        self.canMove = canMove
        self.projectileKind = projectileKind
        self.projectileSpeed = projectileSpeed
        self.splashRadius = splashRadius
        self.selfDestructsOnAttack = selfDestructsOnAttack
        self.damageRampMultipliers = damageRampMultipliers.isEmpty
            ? [1]
            : damageRampMultipliers
        self.destructionDamage = destructionDamage
        self.destructionRadius = destructionRadius
        self.destructionTargetLayer = destructionTargetLayer
        self.startsHidden = startsHidden
        self.activationRange = activationRange
        self.pushbackDistance = pushbackDistance
        self.movementDomain = movementDomain
        self.attackTargetLayer = attackTargetLayer
        self.targetingProfile = targetingProfile
        self.heroAbility = heroAbility
        self.siegePayload = siegePayload
        self.footprintSize = max(footprintSize, 0)
    }

    /// Distance from `point` to the edge of this entity's footprint when it
    /// is centred on `center`; the plain centre distance for point entities.
    func reachDistance(
        from point: WorldPosition,
        toCenter center: WorldPosition
    ) -> Double {
        let halfSize = footprintSize / 2
        let deltaX = max(abs(point.x - center.x) - halfSize, 0)
        let deltaY = max(abs(point.y - center.y) - halfSize, 0)
        return (deltaX * deltaX + deltaY * deltaY).squareRoot()
    }

    func damageRampMultiplier(
        forConsecutiveAttack attackIndex: Int
    ) -> Double {
        damageRampMultipliers[min(
            max(attackIndex, 0),
            damageRampMultipliers.count - 1
        )]
    }

    var countsForDestruction: Bool {
        role == .defense || role == .building
    }
}

nonisolated protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition

    /// Seconds before the battle ends on time.
    var battleDuration: TimeInterval { get }
}

extension GameDataProviding {
    nonisolated var battleDuration: TimeInterval {
        60
    }
}
