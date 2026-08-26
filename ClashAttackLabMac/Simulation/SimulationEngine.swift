import Foundation

final class SimulationEngine {
    private let fixedTimeStep: TimeInterval = 1.0 / 60.0
    private let gameData: any GameDataProviding
    private let initialEntities: [BattleEntity]

    private var accumulatedTime: TimeInterval = 0
    private var attackCounts: [BattleEntityRole: Int] = [:]

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
            resetEntity.currentTargetID = nil
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

        let troopIndices = livingIndices(with: .troop)
        let defenseIndices = livingIndices(with: .defense)

        guard !troopIndices.isEmpty, !defenseIndices.isEmpty else {
            finishIfNeeded()
            return
        }

        var pendingDamage: [UUID: Double] = [:]

        for defenseIndex in defenseIndices {
            act(
                entityAt: defenseIndex,
                possibleTargets: troopIndices,
                deltaTime: deltaTime,
                pendingDamage: &pendingDamage
            )
        }

        for troopIndex in troopIndices {
            act(
                entityAt: troopIndex,
                possibleTargets: defenseIndices,
                deltaTime: deltaTime,
                pendingDamage: &pendingDamage
            )
        }

        apply(pendingDamage)
        clearTargetsPointingToDestroyedEntities()
        finishIfNeeded()
    }

    private func act(
        entityAt attackerIndex: Int,
        possibleTargets: [Int],
        deltaTime: TimeInterval,
        pendingDamage: inout [UUID: Double]
    ) {
        guard entities[attackerIndex].isAlive else {
            return
        }

        let attackerDefinition = definition(for: entities[attackerIndex].kind)
        let targetIndex = resolveTarget(
            for: attackerIndex,
            among: possibleTargets,
            acquisitionRange: attackerDefinition.role == .defense
                ? attackerDefinition.attackRange
                : nil
        )

        guard let targetIndex else {
            entities[attackerIndex].currentTargetID = nil
            return
        }

        let distanceToTarget = distance(
            from: entities[attackerIndex].position,
            to: entities[targetIndex].position
        )

        if distanceToTarget <= attackerDefinition.attackRange {
            performAttackIfPossible(
                attackerIndex: attackerIndex,
                targetIndex: targetIndex,
                pendingDamage: &pendingDamage
            )
        } else if attackerDefinition.canMove {
            move(
                entityAt: attackerIndex,
                toward: entities[targetIndex].position,
                stoppingAt: attackerDefinition.attackRange,
                distance: distanceToTarget,
                deltaTime: deltaTime
            )
        }
    }

    /// Approximation: an entity keeps a valid target until it is destroyed.
    /// When a new target is needed, the nearest eligible one is selected.
    private func resolveTarget(
        for attackerIndex: Int,
        among candidateIndices: [Int],
        acquisitionRange: Double?
    ) -> Int? {
        if
            let lockedID = entities[attackerIndex].currentTargetID,
            let lockedIndex = candidateIndices.first(where: {
                entities[$0].id == lockedID && entities[$0].isAlive
            })
        {
            let lockedDistance = distance(
                from: entities[attackerIndex].position,
                to: entities[lockedIndex].position
            )

            if acquisitionRange == nil || lockedDistance <= acquisitionRange! {
                return lockedIndex
            }
        }

        let nearest = candidateIndices
            .filter { candidateIndex in
                guard entities[candidateIndex].isAlive else {
                    return false
                }

                guard let acquisitionRange else {
                    return true
                }

                return distance(
                    from: entities[attackerIndex].position,
                    to: entities[candidateIndex].position
                ) <= acquisitionRange
            }
            .min { firstIndex, secondIndex in
                distance(
                    from: entities[attackerIndex].position,
                    to: entities[firstIndex].position
                ) < distance(
                    from: entities[attackerIndex].position,
                    to: entities[secondIndex].position
                )
            }

        entities[attackerIndex].currentTargetID = nearest.map {
            entities[$0].id
        }

        return nearest
    }

    private func performAttackIfPossible(
        attackerIndex: Int,
        targetIndex: Int,
        pendingDamage: inout [UUID: Double]
    ) {
        let attacker = entities[attackerIndex]
        let attackerDefinition = definition(for: attacker.kind)

        guard attacker.attackCooldown <= 0 else {
            return
        }

        pendingDamage[entities[targetIndex].id, default: 0] +=
            attackerDefinition.attackDamage
        entities[attackerIndex].attackCooldown =
            attackerDefinition.attackInterval
        attackCounts[attackerDefinition.role, default: 0] += 1
    }

    private func move(
        entityAt index: Int,
        toward target: WorldPosition,
        stoppingAt range: Double,
        distance: Double,
        deltaTime: TimeInterval
    ) {
        guard distance > 0 else {
            return
        }

        let definition = definition(for: entities[index].kind)
        let current = entities[index].position
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let remainingDistance = max(0, distance - range)
        let travel = min(definition.movementSpeed * deltaTime, remainingDistance)

        entities[index].position.x += (deltaX / distance) * travel
        entities[index].position.y += (deltaY / distance) * travel
    }

    private func reduceCooldowns(by deltaTime: TimeInterval) {
        for index in entities.indices where entities[index].isAlive {
            entities[index].attackCooldown = max(
                0,
                entities[index].attackCooldown - deltaTime
            )
        }
    }

    private func apply(_ pendingDamage: [UUID: Double]) {
        for index in entities.indices {
            let damage = pendingDamage[entities[index].id, default: 0]
            entities[index].hitPoints = max(0, entities[index].hitPoints - damage)
        }
    }

    private func clearTargetsPointingToDestroyedEntities() {
        let livingIDs = Set(
            entities
                .filter(\.isAlive)
                .map(\.id)
        )

        for index in entities.indices {
            if
                let targetID = entities[index].currentTargetID,
                !livingIDs.contains(targetID)
            {
                entities[index].currentTargetID = nil
            }
        }
    }

    private func livingIndices(with role: BattleEntityRole) -> [Int] {
        entities.indices.filter { index in
            entities[index].isAlive &&
                definition(for: entities[index].kind).role == role
        }
    }

    private func finishIfNeeded() {
        let survivingTroops = livingIndices(with: .troop).count
        let survivingDefenses = livingIndices(with: .defense).count

        guard survivingTroops == 0 || survivingDefenses == 0 else {
            return
        }

        let winner: BattleWinner

        switch (survivingTroops, survivingDefenses) {
        case (let troops, 0) where troops > 0:
            winner = .attackers
        case (0, let defenses) where defenses > 0:
            winner = .defenses
        default:
            winner = .draw
        }

        status = .finished(
            SimulationResult(
                winner: winner,
                elapsedTime: elapsedTime,
                survivingTroops: survivingTroops,
                survivingDefenses: survivingDefenses,
                troopAttackCount: attackCounts[.troop, default: 0],
                defenseAttackCount: attackCounts[.defense, default: 0]
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
