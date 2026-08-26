import Foundation

final class SimulationEngine {
    private(set) var entities: [BattleEntity]

    private let giantMovementSpeed = 90.0
    private let stoppingDistance = 72.0

    init(entities: [BattleEntity]) {
        self.entities = entities
    }

    func step(deltaTime: TimeInterval) {
        guard
            deltaTime > 0,
            let giantIndex = entities.firstIndex(where: { $0.kind == .giant }),
            let cannon = entities.first(where: { $0.kind == .cannon })
        else {
            return
        }

        let giantPosition = entities[giantIndex].position
        let deltaX = cannon.position.x - giantPosition.x
        let deltaY = cannon.position.y - giantPosition.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        guard distance > stoppingDistance else {
            return
        }

        let maximumTravel = giantMovementSpeed * deltaTime
        let travel = min(maximumTravel, distance - stoppingDistance)
        let directionX = deltaX / distance
        let directionY = deltaY / distance

        entities[giantIndex].position.x += directionX * travel
        entities[giantIndex].position.y += directionY * travel
    }
}
