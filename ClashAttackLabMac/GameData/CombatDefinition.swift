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
}

nonisolated struct TargetingProfile {
    let preference: TargetPreference
    let evidence: MechanicEvidence
}

nonisolated struct CombatDefinition {
    let displayName: String
    let role: BattleEntityRole
    let maxHitPoints: Double
    let movementSpeed: Double
    let attackDamage: Double
    let minimumAttackRange: Double
    let attackRange: Double
    let attackInterval: TimeInterval
    let canMove: Bool
    let projectileKind: ProjectileKind?
    let projectileSpeed: Double
    let splashRadius: Double
    let selfDestructsOnAttack: Bool

    /// Ground troops navigate with A*. Air troops fly directly over walls.
    let movementDomain: MovementDomain = .ground

    /// Defines which troop movement domains a defense can acquire.
    let attackTargetLayer: AttackTargetLayer = .both

    /// Nil for entities that do not choose offensive building targets.
    let targetingProfile: TargetingProfile?

    var countsForDestruction: Bool {
        role == .defense || role == .building
    }
}

nonisolated protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition
}
