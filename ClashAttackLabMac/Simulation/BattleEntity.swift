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
