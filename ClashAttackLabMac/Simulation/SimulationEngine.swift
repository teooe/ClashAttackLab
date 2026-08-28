import Foundation

final class SimulationEngine {
    private let fixedTimeStep: TimeInterval = 1.0 / 60.0
    private let timeLimit: TimeInterval = 60
    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid
    private let pathfinder: AStarPathfinder
    private let targetSelectionSystem: TargetSelectionSystem
    private let scoringSystem: BaseScoringSystem
    private let initialEntities: [BattleEntity]
    private let attackPlan: AttackPlan

    private var accumulatedTime: TimeInterval = 0
    private var attackCounts: [BattleEntityRole: Int] = [:]
    private var movementPaths: [UUID: [WorldPosition]] = [:]
    private var pendingDeployments: [DeploymentOrder] = []

    private(set) var entities: [BattleEntity]
    private(set) var status: SimulationStatus = .ready
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var score: BaseScoreSnapshot = .zero

    var remainingTime: TimeInterval {
        max(0, timeLimit - elapsedTime)
    }

    var pendingDeploymentCount: Int {
        pendingDeployments.count
    }

    var deployedTroopCount: Int {
        attackPlan.deployments.count - pendingDeployments.count
    }

    init(
        entities: [BattleEntity],
        attackPlan: AttackPlan,
        gameData: any GameDataProviding,
        navigationGrid: NavigationGrid,
        pathfinder: AStarPathfinder = AStarPathfinder(),
        targetSelectionSystem: TargetSelectionSystem? = nil,
        scoringSystem: BaseScoringSystem = BaseScoringSystem()
    ) {
        self.initialEntities = entities
        self.entities = entities
        self.attackPlan = attackPlan
        self.gameData = gameData
        self.navigationGrid = navigationGrid
        self.pathfinder = pathfinder
        self.targetSelectionSystem =
            targetSelectionSystem ??
            TargetSelectionSystem(pathfinder: pathfinder)
        self.scoringSystem = scoringSystem
        reset()
    }

    func advance(by deltaTime: TimeInterval) {
        guard deltaTime > 0 else {
            return
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

    func start() {
        switch status {
        case .ready, .paused:
            status = .running
        case .running, .finished:
            break
        }
    }

    func togglePause() {
        switch status {
        case .running:
            status = .paused
        case .paused:
            status = .running
        case .ready, .finished:
            break
        }
    }

    func reset() {
        entities = initialEntities.map { entity in
            var resetEntity = entity
            resetEntity.hitPoints =
                gameData.definition(for: entity.kind).maxHitPoints
            resetEntity.attackCooldown = 0
            resetEntity.currentTargetID = nil
            resetEntity.blockingWallID = nil
            return resetEntity
        }

        accumulatedTime = 0
        elapsedTime = 0
        attackCounts = [:]
        movementPaths = [:]
        pendingDeployments = attackPlan.orderedDeployments
        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )
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
        deployScheduledTroops()

        if elapsedTime >= timeLimit {
            finish(timeExpired: true)
            return
        }

        reduceCooldowns(by: deltaTime)

        let troopIndices = livingIndices(with: .troop)
        let defenseIndices = livingIndices(with: .defense)
        let buildingIndices = livingIndices(with: .building)
        let objectiveIndices = defenseIndices + buildingIndices

        guard !objectiveIndices.isEmpty else {
            finish(timeExpired: false)
            return
        }

        guard !troopIndices.isEmpty else {
            if pendingDeployments.isEmpty {
                finish(timeExpired: false)
            }
            return
        }

        var pendingDamage: [UUID: Double] = [:]

        for defenseIndex in defenseIndices {
            actDefense(
                at: defenseIndex,
                possibleTargets: troopIndices,
                pendingDamage: &pendingDamage
            )
        }

        for troopIndex in troopIndices {
            actTroop(
                at: troopIndex,
                possibleObjectives: objectiveIndices,
                deltaTime: deltaTime,
                pendingDamage: &pendingDamage
            )
        }

        apply(pendingDamage)
        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )
        clearInvalidTargets()
        finishIfNeeded()
    }

    private func deployScheduledTroops() {
        while
            let next = pendingDeployments.first,
            next.deploymentTime <= elapsedTime
        {
            let definition = definition(for: next.kind)
            entities.append(
                BattleEntity(
                    id: next.entityID,
                    kind: next.kind,
                    position: next.position,
                    hitPoints: definition.maxHitPoints
                )
            )
            pendingDeployments.removeFirst()
        }
    }

    private func actDefense(
        at defenseIndex: Int,
        possibleTargets: [Int],
        pendingDamage: inout [UUID: Double]
    ) {
        let definition = definition(for: entities[defenseIndex].kind)
        let targetIndex = resolveDefenseTarget(
            for: defenseIndex,
            among: possibleTargets,
            acquisitionRange: definition.attackRange
        )

        guard let targetIndex else {
            return
        }

        performAttackIfPossible(
            attackerIndex: defenseIndex,
            targetIndex: targetIndex,
            pendingDamage: &pendingDamage
        )
    }

    private func actTroop(
        at troopIndex: Int,
        possibleObjectives: [Int],
        deltaTime: TimeInterval,
        pendingDamage: inout [UUID: Double]
    ) {
        let objectiveIndex = resolveTroopObjective(
            for: troopIndex,
            among: possibleObjectives
        )

        guard let objectiveIndex else {
            return
        }

        if
            let blockingWallIndex = livingIndex(
                withID: entities[troopIndex].blockingWallID,
                role: .wall
            )
        {
            handleBlockingWall(
                troopIndex: troopIndex,
                wallIndex: blockingWallIndex,
                deltaTime: deltaTime,
                pendingDamage: &pendingDamage
            )
            return
        }

        let troopDefinition = definition(for: entities[troopIndex].kind)
        let objectiveDistance = distance(
            from: entities[troopIndex].position,
            to: entities[objectiveIndex].position
        )

        if objectiveDistance <= troopDefinition.attackRange {
            movementPaths[entities[troopIndex].id] = []
            performAttackIfPossible(
                attackerIndex: troopIndex,
                targetIndex: objectiveIndex,
                pendingDamage: &pendingDamage
            )
            return
        }

        ensurePath(
            for: troopIndex,
            to: entities[objectiveIndex].position
        )

        guard
            let nextWaypoint = movementPaths[
                entities[troopIndex].id,
                default: []
            ].first
        else {
            return
        }

        if let wallIndex = livingWallIndex(at: nextWaypoint) {
            entities[troopIndex].blockingWallID = entities[wallIndex].id
            handleBlockingWall(
                troopIndex: troopIndex,
                wallIndex: wallIndex,
                deltaTime: deltaTime,
                pendingDamage: &pendingDamage
            )
        } else {
            moveAlongPath(
                entityAt: troopIndex,
                stoppingAt: troopDefinition.attackRange,
                targetPosition: entities[objectiveIndex].position,
                deltaTime: deltaTime
            )
        }
    }

    private func handleBlockingWall(
        troopIndex: Int,
        wallIndex: Int,
        deltaTime: TimeInterval,
        pendingDamage: inout [UUID: Double]
    ) {
        let troopDefinition = definition(for: entities[troopIndex].kind)
        let wallPosition = entities[wallIndex].position
        let wallDistance = distance(
            from: entities[troopIndex].position,
            to: wallPosition
        )

        if wallDistance <= troopDefinition.attackRange {
            performAttackIfPossible(
                attackerIndex: troopIndex,
                targetIndex: wallIndex,
                pendingDamage: &pendingDamage
            )
        } else {
            moveDirectly(
                entityAt: troopIndex,
                toward: wallPosition,
                stoppingAt: troopDefinition.attackRange,
                deltaTime: deltaTime
            )
        }
    }

    private func resolveTroopObjective(
        for troopIndex: Int,
        among candidateIndices: [Int]
    ) -> Int? {
        let decision = targetSelectionSystem.selectTroopObjective(
            for: troopIndex,
            among: candidateIndices,
            entities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid,
            breakableCells: livingWallCells(),
            breakableTraversalCost: estimatedWallTraversalCost(
                for: entities[troopIndex].kind
            )
        )

        guard let decision else {
            entities[troopIndex].currentTargetID = nil
            movementPaths[entities[troopIndex].id] = []
            return nil
        }

        entities[troopIndex].currentTargetID =
            entities[decision.targetIndex].id

        if let replacementPath = decision.replacementPath {
            movementPaths[entities[troopIndex].id] = replacementPath
        }

        return decision.targetIndex
    }

    private func resolveDefenseTarget(
        for defenseIndex: Int,
        among candidateIndices: [Int],
        acquisitionRange: Double
    ) -> Int? {
        if
            let lockedID = entities[defenseIndex].currentTargetID,
            let lockedIndex = candidateIndices.first(where: {
                entities[$0].id == lockedID && entities[$0].isAlive
            }),
            distance(
                from: entities[defenseIndex].position,
                to: entities[lockedIndex].position
            ) <= acquisitionRange
        {
            return lockedIndex
        }

        let nearest = candidateIndices
            .filter {
                entities[$0].isAlive &&
                    distance(
                        from: entities[defenseIndex].position,
                        to: entities[$0].position
                    ) <= acquisitionRange
            }
            .min {
                distance(
                    from: entities[defenseIndex].position,
                    to: entities[$0].position
                ) < distance(
                    from: entities[defenseIndex].position,
                    to: entities[$1].position
                )
            }

        entities[defenseIndex].currentTargetID = nearest.map {
            entities[$0].id
        }

        return nearest
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
            in: navigationGrid,
            breakableCells: livingWallCells(),
            breakableTraversalCost: estimatedWallTraversalCost(
                for: entities[entityIndex].kind
            )
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
            definition(for: entities[index].kind).movementSpeed *
            deltaTime

        while remainingTravel > 0, let waypoint = path.first {
            let currentPosition = entities[index].position
            let distanceToObjective = distance(
                from: currentPosition,
                to: targetPosition
            )

            guard distanceToObjective > range else {
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

    private func moveDirectly(
        entityAt index: Int,
        toward target: WorldPosition,
        stoppingAt range: Double,
        deltaTime: TimeInterval
    ) {
        let current = entities[index].position
        let targetDistance = distance(from: current, to: target)

        guard targetDistance > range, targetDistance > 0 else {
            return
        }

        let definition = definition(for: entities[index].kind)
        let travel = min(
            definition.movementSpeed * deltaTime,
            targetDistance - range
        )
        let ratio = travel / targetDistance

        entities[index].position.x += (target.x - current.x) * ratio
        entities[index].position.y += (target.y - current.y) * ratio
    }

    private func performAttackIfPossible(
        attackerIndex: Int,
        targetIndex: Int,
        pendingDamage: inout [UUID: Double]
    ) {
        let attacker = entities[attackerIndex]
        let attackerDefinition = definition(for: attacker.kind)

        guard
            attacker.isAlive,
            entities[targetIndex].isAlive,
            attacker.attackCooldown <= 0,
            attackerDefinition.attackDamage > 0
        else {
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
            entities[index].hitPoints = max(
                0,
                entities[index].hitPoints - damage
            )
        }
    }

    private func clearInvalidTargets() {
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

            if
                let wallID = entities[index].blockingWallID,
                !livingIDs.contains(wallID)
            {
                entities[index].blockingWallID = nil
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

    private func livingIndex(
        withID id: UUID?,
        role: BattleEntityRole
    ) -> Int? {
        guard let id else {
            return nil
        }

        return entities.indices.first {
            entities[$0].id == id &&
                entities[$0].isAlive &&
                definition(for: entities[$0].kind).role == role
        }
    }

    private func livingWallCells() -> Set<GridCoordinate> {
        Set(
            livingIndices(with: .wall).compactMap {
                navigationGrid.coordinate(for: entities[$0].position)
            }
        )
    }

    private func livingWallIndex(at position: WorldPosition) -> Int? {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return nil
        }

        return livingIndices(with: .wall).first {
            navigationGrid.coordinate(for: entities[$0].position) ==
                coordinate
        }
    }

    private func estimatedWallTraversalCost(
        for troopKind: BattleEntityKind
    ) -> Double {
        let troop = definition(for: troopKind)
        let wall = definition(for: .wall)

        guard troop.attackDamage > 0 else {
            return .infinity
        }

        let attacksNeeded = ceil(wall.maxHitPoints / troop.attackDamage)
        let breakTime = attacksNeeded * troop.attackInterval
        return breakTime * troop.movementSpeed
    }

    private func finishIfNeeded() {
        let survivingTroops = livingIndices(with: .troop).count
        let remainingObjectives =
            livingIndices(with: .defense).count +
            livingIndices(with: .building).count

        if
            remainingObjectives == 0 ||
            (survivingTroops == 0 && pendingDeployments.isEmpty)
        {
            finish(timeExpired: false)
        }
    }

    private func finish(timeExpired: Bool) {
        guard case .running = status else {
            return
        }

        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )

        let survivingTroops = livingIndices(with: .troop).count
        let survivingDefenses = livingIndices(with: .defense).count
        let winner: BattleWinner =
            score.destructionPercentage >= 100
                ? .attackers
                : .defenses

        status = .finished(
            SimulationResult(
                winner: winner,
                elapsedTime: min(elapsedTime, timeLimit),
                timeExpired: timeExpired,
                deployedTroops: deployedTroopCount,
                survivingTroops: survivingTroops,
                survivingDefenses: survivingDefenses,
                troopAttackCount: attackCounts[.troop, default: 0],
                defenseAttackCount: attackCounts[.defense, default: 0],
                score: score
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
