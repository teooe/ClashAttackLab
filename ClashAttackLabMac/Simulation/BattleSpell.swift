import Foundation

/// Spell categories currently supported by the prototype battle engine.
nonisolated enum BattleSpellKind: Hashable, Codable, CaseIterable {
    case heal
    case rage
    case freeze
    case lightning
    case earthquake
    case jump
    case invisibility
    case haste
    case poison
    case overgrowth
    case iceBlock
    case skeletonSpell
    case batSpell
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

    /// Ground troops inside the spell cross walls (Jump Spell).
    var letsTroopsJumpWalls = false

    /// Defenses inside the spell cannot be targeted by troops
    /// (Invisibility Spell).
    var hidesDefenses = false

    /// Clan Castle reinforcements inside the spell take this much damage
    /// per second once the cloud is fully grown, and move and attack at
    /// these fractions of their speed (Poison Spell).
    var defenderDamagePerSecond: Double = 0
    var defenderSpeedMultiplier: Double = 1
    var defenderAttackSpeedMultiplier: Double = 1

    /// Buildings inside are trapped: defenses stop attacking and troops
    /// ignore them until the spell ends (Overgrowth Spell).
    var entanglesBuildings = false

    /// Troops inside when the spell lands are encased: they cannot move
    /// or attack and take `troopDamageReduction` less damage
    /// (Ice Block Spell).
    var encasesTroops = false
    var troopDamageReduction: Double = 0

    /// Troops summoned where the spell lands (Skeleton and Bat Spells).
    var summonedTroop: BattleEntityKind?
    var summonCount = 0

    /// Seconds the cloud takes to reach its full damage.
    var defenderDamageRampTime: TimeInterval = 0

    /// The game only says the poison grows "with increasing severity";
    /// a linear ramp over this many seconds is an estimate.
    static let poisonRampTime: TimeInterval = 4

    var affectsDefenders: Bool {
        defenderDamagePerSecond > 0 || defenderSpeedMultiplier < 1 ||
            defenderAttackSpeedMultiplier < 1
    }

    /// Damage per second dealt `age` seconds after the cast.
    func defenderDamagePerSecond(atAge age: TimeInterval) -> Double {
        guard defenderDamageRampTime > 0 else {
            return defenderDamagePerSecond
        }
        return defenderDamagePerSecond * min(1, max(0, age) / defenderDamageRampTime)
    }

    /// Changes troop speed or damage while they stand inside the spell
    /// (Rage, Haste).
    var boostsTroops: Bool {
        movementSpeedBonus > 0 || damageMultiplier > 1 ||
            movementSpeedMultiplier > 1 || attackSpeedMultiplier > 1
    }

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
