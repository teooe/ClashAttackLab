import Foundation
import CryptoKit

nonisolated struct WorldPosition: Equatable, Codable {
    var x: Double
    var y: Double
}

nonisolated enum BattleEntityKind: Hashable, Codable, CaseIterable {
    case giant
    case barbarian
    case archer
    case wallBreaker
    case wizard
    case balloon
    case dragon
    case barbarianKing
    case archerQueen
    case wallWrecker
    case stoneSlammer
    case cannon
    case archerTower
    case mortar
    case wizardTower
    case infernoTower
    case bombTower
    case hiddenTesla
    case giantBomb
    case airBomb
    case airSweeper
    case airDefense
    case townHall
    case goldStorage
    case wall
    case goldMine
    case elixirCollector
    case darkElixirDrill
    case elixirStorage
    case darkElixirStorage
    case clanCastle
    case armyCamp
    case barracks
    case darkBarracks
    case laboratory
    case spellFactory
    case darkSpellFactory
    case workshop
    case heroHall
    case petHouse
    case blacksmith
    case builderHut
    case helperHut
    case xBow
    case eagleArtillery
    case scattershot
    case spellTower
    case monolith
    case bomb
    case springTrap
    case seekingAirMine
    case hogRider
    case valkyrie
    case golem
    case bowler
    case miner
    case pekka
    case yeti
    case rootRider
    case electroDragon
    case dragonRider
    case lavaHound
    case grandWarden
    case royalChampion
    case lavaPup
    case golemite
    case skeleton
    case bat
    case battleBlimp
    case flameFlinger
    case siegeBarracks
    case logLauncher
    case dragonDuke
    case babyDragon

    var isTrap: Bool {
        switch self {
        case .giantBomb, .airBomb, .bomb, .springTrap, .seekingAirMine:
            return true
        default:
            return false
        }
    }
}

nonisolated struct BattleEntity: Identifiable {
    let id: UUID
    let kind: BattleEntityKind
    var position: WorldPosition
    var hitPoints: Double
    var attackCooldown: TimeInterval
    var heroAbilityRemaining: TimeInterval
    var heroAbilityUsed: Bool

    /// Tracks repeated hits on one target for ramping attacks.
    var lastAttackedTargetID: UUID?
    var consecutiveAttacksOnTarget: Int

    /// Shots fired in the current burst by defenses that fire in bursts.
    var burstShotsFired = 0

    /// Seconds left of protection from all damage (Eternal Tome).
    var invulnerableRemaining: TimeInterval = 0

    /// Burrowing troops travel underground, out of reach of defenses and
    /// traps, until they surface to attack.
    var isUnderground = false

    /// Clan Castle reinforcement fighting for the base. Defenders are
    /// troops by kind but are never part of the attacking army.
    var isDefender = false

    /// Seconds defenses still cannot see this troop (Invisibility Vial).
    var invisibleRemaining: TimeInterval = 0

    /// Attacks left with the hero's bonus damage and reach (Rocket Spear).
    var boostedAttacksRemaining = 0

    /// Seconds and strength of a slow on this entity's attacks
    /// (Frozen Arrow).
    var slowRemaining: TimeInterval = 0
    var slowFraction: Double = 0

    /// Seconds left inside an Ice Block, and the share of damage the ice
    /// stops.
    var encasedRemaining: TimeInterval = 0
    var encasedDamageReduction: Double = 0

    /// Seconds before the hero can strike back again (Revenge Deck).
    var counterCooldownRemaining: TimeInterval = 0

    /// Hidden defenses cannot attack or be targeted before activation.
    var isRevealed: Bool

    /// Main building selected through target-selection rules.
    var currentTargetID: UUID?

    /// Temporary wall that blocks the route to the main target.
    var blockingWallID: UUID?

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition,
        hitPoints: Double = 0,
        attackCooldown: TimeInterval = 0,
        heroAbilityRemaining: TimeInterval = 0,
        heroAbilityUsed: Bool = false,
        lastAttackedTargetID: UUID? = nil,
        consecutiveAttacksOnTarget: Int = 0,
        isRevealed: Bool = true,
        currentTargetID: UUID? = nil,
        blockingWallID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.hitPoints = hitPoints
        self.attackCooldown = attackCooldown
        self.heroAbilityRemaining = heroAbilityRemaining
        self.heroAbilityUsed = heroAbilityUsed
        self.lastAttackedTargetID = lastAttackedTargetID
        self.consecutiveAttacksOnTarget = consecutiveAttacksOnTarget
        self.isRevealed = isRevealed
        self.currentTargetID = currentTargetID
        self.blockingWallID = blockingWallID
    }

    var isAlive: Bool {
        hitPoints > 0
    }

    var heroAbilityIsActive: Bool {
        heroAbilityRemaining > 0
    }
}


/// Stable identity for generated fixtures and plan slots. Saved/custom IDs
/// retain their existing values; this namespace applies only to generation.
nonisolated enum SimulationIdentity {
    static func make(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(
            "ClashAttackLab.generated.v1:\(key)".utf8
        )))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
