import Foundation

struct WorldPosition: Equatable {
    var x: Double
    var y: Double
}

enum BattleEntityKind {
    case giant
    case cannon
}

struct BattleEntity: Identifiable {
    let id: UUID
    let kind: BattleEntityKind
    var position: WorldPosition

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition
    ) {
        self.id = id
        self.kind = kind
        self.position = position
    }
}
