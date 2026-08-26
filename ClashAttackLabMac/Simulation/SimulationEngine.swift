import Foundation

final class SimulationEngine {
    private let fixedTimeStep: TimeInterval = 1.0 / 60.0
    private let gameData: any GameDataProviding
    private let initialEntities: [BattleEntity]

    private var accumulatedTime: TimeInterval = 0
    private var attackCounts: [BattleEntityKind: Int] = [:]

    private(set) var entities: [BattleEntity]
    private(set) var status: SimulationStatus = .ready
    private(set) var elapsedTime: TimeInterval = 0

    init(
        entities: [BattleEntity],
        gameData: any GameDataProviding
    ) {
        self.initialEntities = entities
        self.entities = entities
        self.gameData = gameData
        reset()
    }

    func advance(by deltaTime: TimeInterval) {
        guard deltaTime > 0 else {
            return
        }

        if case .ready = status {
            status = .running
        }

        guard case .running = status else {
            return
        }

        accumulatedTime += min(deltaTime, 0.25)

        while accumulatedTime >= fixedTimeStep {
            tick(deltaTime: fixedTimeStep)
            accumulatedTime -= fixedTimeStep

            if case .finished = status {
                break
            }
        }
    }

    func reset() {
        entities = initialEntities.map { entity in
            var resetEntity = entity
            resetEntity.hitPoints = gameData.definition(for: entity.kind).maxHitPoints
            resetEntity.attackCooldown = 0
            return resetEntity
        }

        accumulatedTime = 0
        elapsedTime = 0
        attackCounts = [:]
        status = .ready
    }

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        gameData.definition(for: kind)
    }

    func healthFraction(for entity: BattleEntity) -> Double {
        let maximum = definition(for: entity.kind).maxHitPoints
        guard maximum > 0 else {
            return 0
        }

        return max(0, min(entity.hitPoints / maximum, 1))
    }

    private func tick(deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        reduceCooldowns(by: deltaTime)

        guard
            let giantIndex = entities.firstIndex(where: { $0.kind == .giant && $0.isAlive }),
            let cannonIndex = entities.firstIndex(where: { $0.kind == .cannon && $0.isAlive })
        else {
            finishIfNeeded()
            return
        }

        let giant = entities[giantIndex]
        let cannon = entities[cannonIndex]
        let distance = distance(from: giant.position, to: cannon.position)

        var pendingDamage: [UUID: Double] = [:]

        performAttackIfPossible(
            attackerIndex: cannonIndex,
            target: giant,
            distance: distance,
            pendingDamage: &pendingDamage
        )

        if distance <= definition(for: .giant).attackRange {
            performAttackIfPossible(
                attackerIndex: giantIndex,
                target: cannon,
                distance: distance,
                pendingDamage: &pendingDamage
            )
        } else {
            moveGiant(
                at: giantIndex,
                toward: cannon.position,
                distance: distance,
                deltaTime: deltaTime
            )
        }

        apply(pendingDamage)
        finishIfNeeded()
    }

    private func reduceCooldowns(by deltaTime: TimeInterval) {
        for index in entities.indices where entities[index].isAlive {
            entities[index].attackCooldown = max(
                0,
                entities[index].attackCooldown - deltaTime
            )
        }
    }

    private func performAttackIfPossible(
        attackerIndex: Int,
        target: BattleEntity,
        distance: Double,
        pendingDamage: inout [UUID: Double]
    ) {
        let attacker = entities[attackerIndex]
        let definition = definition(for: attacker.kind)

        guard
            attacker.isAlive,
            target.isAlive,
            distance <= definition.attackRange,
            attacker.attackCooldown <= 0
        else {
            return
        }

        pendingDamage[target.id, default: 0] += definition.attackDamage
        entities[attackerIndex].attackCooldown = definition.attackInterval
        attackCounts[attacker.kind, default: 0] += 1
    }

    private func moveGiant(
        at index: Int,
        toward target: WorldPosition,
        distance: Double,
        deltaTime: TimeInterval
    ) {
        let definition = definition(for: .giant)

        guard definition.canMove, distance > 0 else {
            return
        }

        let current = entities[index].position
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let remainingDistance = max(0, distance - definition.attackRange)
        let travel = min(definition.movementSpeed * deltaTime, remainingDistance)

        entities[index].position.x += (deltaX / distance) * travel
        entities[index].position.y += (deltaY / distance) * travel
    }

    private func apply(_ pendingDamage: [UUID: Double]) {
        for index in entities.indices {
            let damage = pendingDamage[entities[index].id, default: 0]
            entities[index].hitPoints = max(0, entities[index].hitPoints - damage)
        }
    }

    private func finishIfNeeded() {
        let giant = entities.first(where: { $0.kind == .giant })
        let cannon = entities.first(where: { $0.kind == .cannon })
        let giantAlive = giant?.isAlive == true
        let cannonAlive = cannon?.isAlive == true

        guard !giantAlive || !cannonAlive else {
            return
        }

        let winner: BattleWinner

        switch (giantAlive, cannonAlive) {
        case (true, false):
            winner = .giant
        case (false, true):
            winner = .cannon
        default:
            winner = .draw
        }

        status = .finished(
            SimulationResult(
                winner: winner,
                elapsedTime: elapsedTime,
                giantRemainingHitPoints: giant?.hitPoints ?? 0,
                cannonRemainingHitPoints: cannon?.hitPoints ?? 0,
                giantAttackCount: attackCounts[.giant, default: 0],
                cannonAttackCount: attackCounts[.cannon, default: 0]
            )
        )
    }

    private func distance(
        from first: WorldPosition,
        to second: WorldPosition
    ) -> Double {
        let deltaX = second.x - first.x
        let deltaY = second.y - first.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}
