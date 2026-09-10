import Foundation

final class SimulationEngine {
    private let fixedTimeStep: TimeInterval = 1.0 / 60.0
    private let timeLimit: TimeInterval = 60
    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid
    private let pathfinder: AStarPathfinder
    private let targetSelectionSystem: TargetSelectionSystem
    private let scoringSystem: BaseScoringSystem
    private var initialEntities: [BattleEntity]
    private var attackPlan: AttackPlan

    private var accumulatedTime: TimeInterval = 0
    private var attackCounts: [BattleEntityRole: Int] = [:]
    private var movementPaths: [UUID: [WorldPosition]] = [:]
    private var pendingDeployments: [DeploymentOrder] = []
    private var pendingSpellDeployments: [SpellDeploymentOrder] = []

    private(set) var entities: [BattleEntity]
    private(set) var projectiles: [BattleProjectile] = []
    private(set) var activeSpells: [ActiveBattleSpell] = []
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

    var livingTroopCount: Int {
        livingIndices(with: .troop).count
    }

    var pendingSpellCount: Int {
        pendingSpellDeployments.count
    }

    var deployedSpellCount: Int {
        attackPlan.spellDeployments.count -
            pendingSpellDeployments.count
    }

    var pendingSpellIDs: Set<UUID> {
        Set(pendingSpellDeployments.map(\.id))
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
            resetEntity.heroAbilityRemaining = 0
            resetEntity.heroAbilityUsed = false
            resetEntity.currentTargetID = nil
            resetEntity.blockingWallID = nil
            return resetEntity
        }

        accumulatedTime = 0
        elapsedTime = 0
        attackCounts = [:]
        movementPaths = [:]
        projectiles = []
        activeSpells = []
        pendingDeployments = attackPlan.orderedDeployments
        pendingSpellDeployments =
            attackPlan.orderedSpellDeployments
        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )
        status = .ready
    }

    func loadAttackPlan(_ attackPlan: AttackPlan) {
        self.attackPlan = attackPlan
        reset()
    }

    func loadScenario(
        entities: [BattleEntity],
        attackPlan: AttackPlan
    ) {
        initialEntities = entities
        self.attackPlan = attackPlan
        reset()
    }

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        gameData.definition(for: kind)
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        gameData.spellDefinition(for: kind)
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
        deployScheduledSpells()
        applyHealingSpells(by: deltaTime)

        defer {
            advanceActiveSpells(by: deltaTime)
            advanceHeroAbilities(by: deltaTime)
        }

        if elapsedTime >= timeLimit {
            finish(reason: .timeExpired)
            return
        }

        reduceCooldowns(by: deltaTime)
        activateHeroAbilities()

        var pendingDamage: [UUID: Double] = [:]
        advanceProjectiles(
            by: deltaTime,
            pendingDamage: &pendingDamage
        )
        apply(pendingDamage)
        pendingDamage.removeAll(keepingCapacity: true)
        clearInvalidTargets()

        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )

        let troopIndices = livingIndices(with: .troop)
        let defenseIndices = livingIndices(with: .defense)
        let buildingIndices = livingIndices(with: .building)
        let wallIndices = livingIndices(with: .wall)
        let objectiveIndices = defenseIndices + buildingIndices
        let troopTargetIndices = objectiveIndices + wallIndices

        guard !objectiveIndices.isEmpty else {
            finish(reason: .totalDestruction)
            return
        }

        guard !troopIndices.isEmpty else {
            if
                pendingDeployments.isEmpty &&
                !hasAttackerProjectiles
            {
                finish(reason: .armyEliminated)
            }
            return
        }

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
                possibleObjectives: troopTargetIndices,
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

    private func deployScheduledSpells() {
        while
            let next = pendingSpellDeployments.first,
            next.deploymentTime <= elapsedTime
        {
            let definition = spellDefinition(for: next.kind)
            activeSpells.append(
                ActiveBattleSpell(
                    id: next.id,
                    kind: next.kind,
                    position: next.position,
                    remainingDuration: definition.duration
                )
            )
            pendingSpellDeployments.removeFirst()
        }
    }

    private func applyHealingSpells(by deltaTime: TimeInterval) {
        let healingSpells = activeSpells.filter {
            spellDefinition(for: $0.kind).healingPerSecond > 0
        }

        guard !healingSpells.isEmpty else {
            return
        }

        for troopIndex in livingIndices(with: .troop) {
            let troopPosition = entities[troopIndex].position
            var healing = 0.0

            for spell in healingSpells {
                let definition = spellDefinition(for: spell.kind)

                if distance(
                    from: troopPosition,
                    to: spell.position
                ) <= definition.radius {
                    healing += definition.healingPerSecond * deltaTime
                }
            }

            guard healing > 0 else {
                continue
            }

            let maximum = definition(
                for: entities[troopIndex].kind
            ).maxHitPoints
            entities[troopIndex].hitPoints = min(
                maximum,
                entities[troopIndex].hitPoints + healing
            )
        }
    }

    private func activateHeroAbilities() {
        for index in livingIndices(with: .troop) {
            guard
                !entities[index].heroAbilityUsed,
                let ability = definition(
                    for: entities[index].kind
                ).heroAbility
            else {
                continue
            }

            let maximum = definition(for: entities[index].kind).maxHitPoints
            guard maximum > 0 else {
                continue
            }

            let healthFraction = entities[index].hitPoints / maximum
            guard healthFraction <= ability.activationHealthFraction else {
                continue
            }

            entities[index].heroAbilityUsed = true
            entities[index].heroAbilityRemaining = ability.duration
            entities[index].hitPoints = min(
                maximum,
                entities[index].hitPoints + ability.instantHealing
            )
        }
    }

    private func advanceHeroAbilities(by deltaTime: TimeInterval) {
        for index in entities.indices where entities[index].heroAbilityRemaining > 0 {
            entities[index].heroAbilityRemaining = max(
                0,
                entities[index].heroAbilityRemaining - deltaTime
            )
        }
    }

    private func advanceActiveSpells(by deltaTime: TimeInterval) {
        activeSpells = activeSpells.compactMap { spell in
            var updated = spell
            updated.remainingDuration -= deltaTime
            return updated.remainingDuration > 0 ? updated : nil
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
            minimumRange: definition.minimumAttackRange,
            acquisitionRange: definition.attackRange,
            targetLayer: definition.attackTargetLayer
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

        let troopDefinition = definition(for: entities[troopIndex].kind)
        let effectiveAttackRange = troopDefinition.attackRange *
            combatModifiers(for: entities[troopIndex]).attackRange
        let objectiveDistance = distance(
            from: entities[troopIndex].position,
            to: entities[objectiveIndex].position
        )

        if objectiveDistance <= effectiveAttackRange {
            movementPaths[entities[troopIndex].id] = []
            performAttackIfPossible(
                attackerIndex: troopIndex,
                targetIndex: objectiveIndex,
                pendingDamage: &pendingDamage
            )
            return
        }

        if troopDefinition.movementDomain == .air {
            movementPaths[entities[troopIndex].id] = [
                entities[objectiveIndex].position
            ]
            moveDirectly(
                entityAt: troopIndex,
                toward: entities[objectiveIndex].position,
                stoppingAt: effectiveAttackRange,
                deltaTime: deltaTime
            )
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

        if wallDistance <= troopDefinition.attackRange *
            combatModifiers(for: entities[troopIndex]).attackRange {
            performAttackIfPossible(
                attackerIndex: troopIndex,
                targetIndex: wallIndex,
                pendingDamage: &pendingDamage
            )
        } else {
            moveDirectly(
                entityAt: troopIndex,
                toward: wallPosition,
                stoppingAt: troopDefinition.attackRange *
                    combatModifiers(for: entities[troopIndex]).attackRange,
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
        minimumRange: Double,
        acquisitionRange: Double,
        targetLayer: AttackTargetLayer
    ) -> Int? {
        let defensePosition = entities[defenseIndex].position
        let layerCandidates = candidateIndices.filter { index in
            entities.indices.contains(index) &&
                targetLayer.accepts(
                    definition(for: entities[index].kind).movementDomain
                )
        }

        if
            let lockedID = entities[defenseIndex].currentTargetID,
            let lockedIndex = layerCandidates.first(where: {
                entities[$0].id == lockedID && entities[$0].isAlive
            })
        {
            let lockedDistance = distance(
                from: defensePosition,
                to: entities[lockedIndex].position
            )

            if
                lockedDistance >= minimumRange &&
                lockedDistance <= acquisitionRange
            {
                return lockedIndex
            }
        }

        let nearest = layerCandidates
            .filter {
                guard entities[$0].isAlive else {
                    return false
                }

                let candidateDistance = distance(
                    from: defensePosition,
                    to: entities[$0].position
                )
                return candidateDistance >= minimumRange &&
                    candidateDistance <= acquisitionRange
            }
            .min {
                let firstDistance = distance(
                    from: defensePosition,
                    to: entities[$0].position
                )
                let secondDistance = distance(
                    from: defensePosition,
                    to: entities[$1].position
                )

                if firstDistance == secondDistance {
                    return entities[$0].id.uuidString <
                        entities[$1].id.uuidString
                }

                return firstDistance < secondDistance
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
        let entity = entities[index]
        let modifiers = combatModifiers(for: entity)
        var remainingTravel =
            definition(for: entity.kind).movementSpeed *
            modifiers.movementSpeed *
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

        let entity = entities[index]
        let definition = definition(for: entity.kind)
        let modifiers = combatModifiers(for: entity)
        let travel = min(
            definition.movementSpeed *
                modifiers.movementSpeed *
                deltaTime,
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
        let target = entities[targetIndex]
        let attackerDefinition = definition(for: attacker.kind)
        let modifiers = combatModifiers(for: attacker)
        let attackDamage =
            attackerDefinition.attackDamage * modifiers.damage

        guard
            attacker.isAlive,
            target.isAlive,
            attacker.attackCooldown <= 0,
            attackDamage > 0
        else {
            return
        }

        if
            let projectileKind = attackerDefinition.projectileKind,
            attackerDefinition.projectileSpeed > 0
        {
            let targetDefinition = definition(for: target.kind)
            projectiles.append(
                BattleProjectile(
                    kind: projectileKind,
                    sourceEntityID: attacker.id,
                    sourceRole: attackerDefinition.role,
                    targetEntityID: target.id,
                    targetRole: targetDefinition.role,
                    position: attacker.position,
                    destination: target.position,
                    speed: attackerDefinition.projectileSpeed,
                    damage: attackDamage,
                    splashRadius: attackerDefinition.splashRadius
                )
            )
        } else if attackerDefinition.splashRadius > 0 {
            let targetRole = definition(for: target.kind).role
            queueAreaDamage(
                centeredAt: target.position,
                targetRole: targetRole,
                damage: attackDamage,
                radius: attackerDefinition.splashRadius,
                pendingDamage: &pendingDamage
            )
        } else {
            pendingDamage[target.id, default: 0] += attackDamage
        }

        if attackerDefinition.selfDestructsOnAttack {
            pendingDamage[attacker.id, default: 0] += attacker.hitPoints
        }

        entities[attackerIndex].attackCooldown =
            attackerDefinition.attackInterval /
            modifiers.attackSpeed
        attackCounts[attackerDefinition.role, default: 0] += 1
    }

    private func advanceProjectiles(
        by deltaTime: TimeInterval,
        pendingDamage: inout [UUID: Double]
    ) {
        var activeProjectiles: [BattleProjectile] = []
        activeProjectiles.reserveCapacity(projectiles.count)

        for var projectile in projectiles {
            let remainingDistance = distance(
                from: projectile.position,
                to: projectile.destination
            )
            let travelDistance = projectile.speed * deltaTime

            if
                remainingDistance <= travelDistance ||
                remainingDistance == 0
            {
                resolveImpact(
                    of: projectile,
                    pendingDamage: &pendingDamage
                )
                continue
            }

            let ratio = travelDistance / remainingDistance
            projectile.position.x +=
                (projectile.destination.x - projectile.position.x) * ratio
            projectile.position.y +=
                (projectile.destination.y - projectile.position.y) * ratio
            activeProjectiles.append(projectile)
        }

        projectiles = activeProjectiles
    }

    private func resolveImpact(
        of projectile: BattleProjectile,
        pendingDamage: inout [UUID: Double]
    ) {
        if projectile.splashRadius > 0 {
            queueAreaDamage(
                centeredAt: projectile.destination,
                targetRole: projectile.targetRole,
                damage: projectile.damage,
                radius: projectile.splashRadius,
                pendingDamage: &pendingDamage
            )
            return
        }

        guard
            let targetIndex = entities.indices.first(where: {
                entities[$0].id == projectile.targetEntityID &&
                    entities[$0].isAlive
            })
        else {
            return
        }

        pendingDamage[entities[targetIndex].id, default: 0] +=
            projectile.damage
    }

    private func queueAreaDamage(
        centeredAt center: WorldPosition,
        targetRole: BattleEntityRole,
        damage: Double,
        radius: Double,
        pendingDamage: inout [UUID: Double]
    ) {
        for index in entities.indices where entities[index].isAlive {
            let entityRole = definition(for: entities[index].kind).role

            guard
                entityRole == targetRole,
                distance(
                    from: entities[index].position,
                    to: center
                ) <= radius
            else {
                continue
            }

            pendingDamage[entities[index].id, default: 0] += damage
        }
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

    private var hasAttackerProjectiles: Bool {
        projectiles.contains { $0.sourceRole == .troop }
    }

    private func finishIfNeeded() {
        let survivingTroops = livingIndices(with: .troop).count
        let remainingObjectives =
            livingIndices(with: .defense).count +
            livingIndices(with: .building).count

        if
            remainingObjectives == 0 ||
            (
                survivingTroops == 0 &&
                pendingDeployments.isEmpty &&
                !hasAttackerProjectiles
            )
        {
            let reason: SimulationFinishReason =
                remainingObjectives == 0
                    ? .totalDestruction
                    : .armyEliminated
            finish(reason: reason)
        }
    }

    private func finish(reason: SimulationFinishReason) {
        guard case .running = status else {
            return
        }

        score = scoringSystem.calculate(
            entities: entities,
            gameData: gameData
        )

        let survivingTroops = livingIndices(with: .troop).count
        let survivingDefenses = livingIndices(with: .defense).count
        let metrics = makeSummaryMetrics(
            survivingTroops: survivingTroops
        )
        projectiles = []
        let winner: BattleWinner =
            score.destructionPercentage >= 100
                ? .attackers
                : .defenses

        status = .finished(
            SimulationResult(
                winner: winner,
                elapsedTime: min(elapsedTime, timeLimit),
                timeExpired: reason == .timeExpired,
                finishReason: reason,
                deployedTroops: deployedTroopCount,
                survivingTroops: survivingTroops,
                survivingDefenses: survivingDefenses,
                troopAttackCount: attackCounts[.troop, default: 0],
                defenseAttackCount: attackCounts[.defense, default: 0],
                score: score,
                metrics: metrics
            )
        )
    }

    private func makeSummaryMetrics(
        survivingTroops: Int
    ) -> BattleSummaryMetrics {
        var damageToBase = 0.0
        var hitPointsLostByArmy = 0.0
        var destroyedWalls = 0

        for entity in entities {
            let entityDefinition = definition(for: entity.kind)
            let lostHitPoints = max(
                0,
                entityDefinition.maxHitPoints - entity.hitPoints
            )

            if entityDefinition.role == .troop {
                hitPointsLostByArmy += lostHitPoints
            } else {
                damageToBase += lostHitPoints
            }

            if
                entityDefinition.role == .wall &&
                !entity.isAlive
            {
                destroyedWalls += 1
            }
        }

        return BattleSummaryMetrics(
            damageToBase: damageToBase,
            hitPointsLostByArmy: hitPointsLostByArmy,
            troopsLost: max(0, deployedTroopCount - survivingTroops),
            destroyedWalls: destroyedWalls,
            spellsCast: deployedSpellCount
        )
    }

    private func combatModifiers(
        for entity: BattleEntity
    ) -> CombatModifiers {
        guard definition(for: entity.kind).role == .troop else {
            return .neutral
        }

        var damage = 1.0
        var movementSpeed = 1.0
        var attackSpeed = 1.0
        var attackRange = 1.0

        if
            entity.heroAbilityIsActive,
            let ability = definition(for: entity.kind).heroAbility
        {
            damage = max(damage, ability.damageMultiplier)
            movementSpeed = max(
                movementSpeed,
                ability.movementSpeedMultiplier
            )
            attackSpeed = max(
                attackSpeed,
                ability.attackSpeedMultiplier
            )
            attackRange = max(
                attackRange,
                ability.attackRangeMultiplier
            )
        }

        for spell in activeSpells where spell.kind == .rage {
            let spellData = spellDefinition(for: spell.kind)

            guard distance(
                from: entity.position,
                to: spell.position
            ) <= spellData.radius else {
                continue
            }

            damage = max(damage, spellData.damageMultiplier)
            movementSpeed = max(
                movementSpeed,
                spellData.movementSpeedMultiplier
            )
            attackSpeed = max(
                attackSpeed,
                spellData.attackSpeedMultiplier
            )
        }

        return CombatModifiers(
            damage: damage,
            movementSpeed: movementSpeed,
            attackSpeed: attackSpeed,
            attackRange: attackRange
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
