import Foundation

final class SimulationEngine {
    private let fixedTimeStep: TimeInterval = 1.0 / 60.0
    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid
    private let pathfinder: AStarPathfinder
    private let initialEntities: [BattleEntity]

    private var accumulatedTime: TimeInterval = 0
    private var attackCounts: [BattleEntityRole: Int] = [:]
    private var movementPaths: [UUID: [WorldPosition]] = [:]

    private(set) var entities: [BattleEntity]
    private(set) var status: SimulationStatus = .ready
    private(set) var elapsedTime: TimeInterval = 0

    init(
        entities: [BattleEntity],
        gameData: any GameDataProviding,
        navigationGrid: NavigationGrid,
        pathfinder: AStarPathfinder = AStarPathfinder()
    ) {
        self.initialEntities = entities
        self.entities = entities
        self.gameData = gameData
        self.navigationGrid = navigationGrid
        self.pathfinder = pathfinder
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
        movementPaths = [:]
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

    func movementPath(for entityID: UUID) -> [WorldPosition] {
        movementPaths[entityID, default: []]
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
            movementPaths[entities[attackerIndex].id] = []
            return
        }

        let distanceToTarget = distance(
            from: entities[attackerIndex].position,
            to: entities[targetIndex].position
        )

        if distanceToTarget <= attackerDefinition.attackRange {
            movementPaths[entities[attackerIndex].id] = []
            performAttackIfPossible(
                attackerIndex: attackerIndex,
                targetIndex: targetIndex,
                pendingDamage: &pendingDamage
            )
        } else if attackerDefinition.canMove {
            ensurePath(
                for: attackerIndex,
                to: entities[targetIndex].position
            )
            moveAlongPath(
                entityAt: attackerIndex,
                stoppingAt: attackerDefinition.attackRange,
                targetPosition: entities[targetIndex].position,
                deltaTime: deltaTime
            )
        }
    }

    /// Approximation: troops keep a valid target until it is destroyed.
    /// New troop targets are ranked by reachable A* route cost.
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

        let attackerDefinition = definition(for: entities[attackerIndex].kind)
        let selected: Int?

        if attackerDefinition.role == .troop {
            let reachableTargets = candidateIndices.compactMap { index in
                pathfinder.findPath(
                    from: entities[attackerIndex].position,
                    to: entities[index].position,
                    in: navigationGrid
                ).map { result in
                    (index: index, result: result)
                }
            }

            let best = reachableTargets.min {
                $0.result.totalCost < $1.result.totalCost
            }
            selected = best?.index

            if let best {
                movementPaths[entities[attackerIndex].id] =
                    best.result.waypoints
            }
        } else {
            selected = candidateIndices
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
        }

        entities[attackerIndex].currentTargetID = selected.map {
            entities[$0].id
        }

        return selected
    }

    private func ensurePath(
        for entityIndex: Int,
        to targetPosition: WorldPosition
    ) {
        let entityID = entities[entityIndex].id

        guard movementPaths[entityID, default: []].isEmpty else {
            return
        }

        movementPaths[entityID] = pathfinder.findPath(
            from: entities[entityIndex].position,
            to: targetPosition,
            in: navigationGrid
        )?.waypoints ?? []
    }

    private func moveAlongPath(
        entityAt index: Int,
        stoppingAt range: Double,
        targetPosition: WorldPosition,
        deltaTime: TimeInterval
    ) {
        let entityID = entities[index].id
        var path = movementPaths[entityID, default: []]
        var remainingTravel =
            definition(for: entities[index].kind).movementSpeed * deltaTime

        while remainingTravel > 0, let waypoint = path.first {
            let currentPosition = entities[index].position
            let distanceToTarget = distance(
                from: currentPosition,
                to: targetPosition
            )

            guard distanceToTarget > range else {
                path = []
                break
            }

            let distanceToWaypoint = distance(
                from: currentPosition,
                to: waypoint
            )

            if distanceToWaypoint <= remainingTravel {
                entities[index].position = waypoint
                remainingTravel -= distanceToWaypoint
                path.removeFirst()
            } else if distanceToWaypoint > 0 {
                let ratio = remainingTravel / distanceToWaypoint
                entities[index].position.x +=
                    (waypoint.x - currentPosition.x) * ratio
                entities[index].position.y +=
                    (waypoint.y - currentPosition.y) * ratio
                remainingTravel = 0
            } else {
                path.removeFirst()
            }
        }

        movementPaths[entityID] = path
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
                movementPaths[entities[index].id] = []
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
