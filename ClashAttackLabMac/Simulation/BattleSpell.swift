import Foundation

/// Spell categories currently supported by the prototype battle engine.
nonisolated enum BattleSpellKind: Hashable, Codable, CaseIterable {
    case heal
    case rage
    case freeze
    case lightning
    case earthquake
}

/// Separates documented spell behavior from temporary tuning values.
nonisolated struct SpellDefinition {
    let displayName: String
    let radius: Double
    let duration: TimeInterval
    let healingPerSecond: Double
    let instantDamage: Double
    let damageMultiplier: Double
    let movementSpeedMultiplier: Double
    let attackSpeedMultiplier: Double
    let disablesDefenses: Bool
    let behaviorEvidence: MechanicEvidence
    let tuningEvidence: MechanicEvidence

    /// Extra instant damage as a fraction of each target's maximum hit
    /// points, as dealt by the real Earthquake Spell.
    var maxHitPointDamageFraction: Double = 0

    /// Flat movement speed bonus in world units per second, added on top of
    /// each troop's own speed, as granted by the real Rage Spell.
    var movementSpeedBonus: Double = 0

    var dealsInstantDamage: Bool {
        instantDamage > 0 || maxHitPointDamageFraction > 0
    }

    func impactDamage(forMaxHitPoints maxHitPoints: Double) -> Double {
        instantDamage + maxHitPointDamageFraction * maxHitPoints
    }
}

/// Runtime spell zone. Its identifier matches the scheduled spell order.
nonisolated struct ActiveBattleSpell: Identifiable {
    let id: UUID
    let kind: BattleSpellKind
    let position: WorldPosition
    var remainingDuration: TimeInterval
}

nonisolated struct CombatModifiers {
    let damage: Double
    let movementSpeed: Double
    let attackSpeed: Double
    let attackRange: Double

    static let neutral = CombatModifiers(
        damage: 1,
        movementSpeed: 1,
        attackSpeed: 1,
        attackRange: 1
    )
}
