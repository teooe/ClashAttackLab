import Foundation
import CryptoKit

nonisolated struct WorldPosition: Equatable, Codable {
    var x: Double
    var y: Double
}

nonisolated enum BattleEntityKind: Hashable, Codable {
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
    case airDefense
    case townHall
    case goldStorage
    case wall
}

nonisolated struct BattleEntity: Identifiable {
    let id: UUID
    let kind: BattleEntityKind
    var position: WorldPosition
    var hitPoints: Double
    var attackCooldown: TimeInterval
    var heroAbilityRemaining: TimeInterval
    var heroAbilityUsed: Bool

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
