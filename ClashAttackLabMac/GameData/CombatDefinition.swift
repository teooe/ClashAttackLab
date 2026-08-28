import Foundation

nonisolated enum BattleEntityRole: Hashable {
    case troop
    case defense
    case building
    case wall
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

    /// Nil for entities that do not choose offensive building targets.
    let targetingProfile: TargetingProfile?

    var countsForDestruction: Bool {
        role == .defense || role == .building
    }
}

nonisolated protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
}
