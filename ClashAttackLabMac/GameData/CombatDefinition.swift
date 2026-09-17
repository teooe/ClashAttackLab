import Foundation

nonisolated enum BattleEntityRole: Hashable {
    case troop
    case defense
    case building
    case wall
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
}

nonisolated struct CombatDefinition {
    let displayName: String
    let role: BattleEntityRole
    let maxHitPoints: Double
    let movementSpeed: Double
    let attackDamage: Double
    let damageMultiplierAgainstWalls: Double
    let minimumAttackRange: Double
    let attackRange: Double
    let attackInterval: TimeInterval
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

    /// Ground troops navigate with A*. Air troops fly directly over walls.
    let movementDomain: MovementDomain

    /// Defines which troop movement domains a defense can acquire.
    let attackTargetLayer: AttackTargetLayer

    /// Nil for entities that do not choose offensive building targets.
    let targetingProfile: TargetingProfile?

    /// Nil for ordinary troops and all defensive structures.
    let heroAbility: HeroAbilityDefinition?

    /// Troops released when a siege machine is destroyed.
    let siegePayload: [BattleEntityKind]

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
        movementDomain: MovementDomain = .ground,
        attackTargetLayer: AttackTargetLayer = .both,
        targetingProfile: TargetingProfile?,
        heroAbility: HeroAbilityDefinition? = nil,
        siegePayload: [BattleEntityKind] = []
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
        self.movementDomain = movementDomain
        self.attackTargetLayer = attackTargetLayer
        self.targetingProfile = targetingProfile
        self.heroAbility = heroAbility
        self.siegePayload = siegePayload
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
}
