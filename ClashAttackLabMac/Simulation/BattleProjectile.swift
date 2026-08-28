import Foundation

nonisolated enum ProjectileKind: Hashable {
    case arrow
    case cannonball
    case mortarShell
    case fireball
    case bomb
    case dragonFire
    case airBolt
}

nonisolated struct BattleProjectile: Identifiable {
    let id: UUID
    let kind: ProjectileKind
    let sourceEntityID: UUID
    let sourceRole: BattleEntityRole
    let targetEntityID: UUID
    let targetRole: BattleEntityRole
    var position: WorldPosition
    let destination: WorldPosition
    let speed: Double
    let damage: Double
    let splashRadius: Double

    init(
        id: UUID = UUID(),
        kind: ProjectileKind,
        sourceEntityID: UUID,
        sourceRole: BattleEntityRole,
        targetEntityID: UUID,
        targetRole: BattleEntityRole,
        position: WorldPosition,
        destination: WorldPosition,
        speed: Double,
        damage: Double,
        splashRadius: Double
    ) {
        self.id = id
        self.kind = kind
        self.sourceEntityID = sourceEntityID
        self.sourceRole = sourceRole
        self.targetEntityID = targetEntityID
        self.targetRole = targetRole
        self.position = position
        self.destination = destination
        self.speed = speed
        self.damage = damage
        self.splashRadius = splashRadius
    }
}
