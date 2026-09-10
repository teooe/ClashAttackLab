import Foundation

/// Spell categories currently supported by the prototype battle engine.
nonisolated enum BattleSpellKind: Hashable, Codable {
    case heal
    case rage
    case freeze
}

/// Separates documented spell behavior from temporary tuning values.
nonisolated struct SpellDefinition {
    let displayName: String
    let radius: Double
    let duration: TimeInterval
    let healingPerSecond: Double
    let damageMultiplier: Double
    let movementSpeedMultiplier: Double
    let attackSpeedMultiplier: Double
    let disablesDefenses: Bool
    let behaviorEvidence: MechanicEvidence
    let tuningEvidence: MechanicEvidence
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
