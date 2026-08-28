import Foundation

enum BattleEntityRole: Hashable {
    case troop
    case defense
    case building
    case wall
}

enum MechanicEvidence: String, Hashable {
    case documented
    case observed
    case approximation
    case prototype
}

enum TargetPreference: Hashable {
    case defenses
    case anyBuilding
}

struct TargetingProfile {
    let preference: TargetPreference
    let evidence: MechanicEvidence
}

struct CombatDefinition {
    let displayName: String
    let role: BattleEntityRole
    let maxHitPoints: Double
    let movementSpeed: Double
    let attackDamage: Double
    let attackRange: Double
    let attackInterval: TimeInterval
    let canMove: Bool

    /// Nil for entities that do not choose offensive building targets.
    let targetingProfile: TargetingProfile?

    var countsForDestruction: Bool {
        role == .defense || role == .building
    }
}

protocol GameDataProviding {
    func definition(for kind: BattleEntityKind) -> CombatDefinition
}
