import Foundation

nonisolated struct TargetSelectionDecision {
    let targetIndex: Int

    /// Nil means that the troop can keep its current path.
    let replacementPath: [WorldPosition]?
}

/// Chooses troop objectives without knowing anything about rendering.
///
/// Rules currently modeled:
/// - Ground troops compare weighted A* routes and may choose a breccia.
/// - Air troops compare direct distance and fly over walls.
/// - A selected objective stays locked until it becomes invalid.
/// - Target preferences remain prototype inputs unless separately documented.
nonisolated struct TargetSelectionSystem {
    private let pathfinder: AStarPathfinder

    init(pathfinder: AStarPathfinder = AStarPathfinder()) {
        self.pathfinder = pathfinder
    }

    func selectTroopObjective(
        for troopIndex: Int,
        among candidateIndices: [Int],
        entities: [BattleEntity],
        gameData: any GameDataProviding,
        navigationGrid: NavigationGrid,
        breakableCells: Set<GridCoordinate>,
        breakableTraversalCost: Double
    ) -> TargetSelectionDecision? {
        guard entities.indices.contains(troopIndex) else {
            return nil
        }

        let troop = entities[troopIndex]
        let troopDefinition = gameData.definition(for: troop.kind)
        let preference =
            troopDefinition.targetingProfile?.preference ?? .anyBuilding
        let eligibleIndices = eligibleObjectives(
            from: candidateIndices,
            preference: preference,
            entities: entities,
            gameData: gameData
        )

        guard !eligibleIndices.isEmpty else {
            return nil
        }

        if
            let lockedID = troop.currentTargetID,
            let lockedIndex = eligibleIndices.first(where: {
                entities[$0].id == lockedID && entities[$0].isAlive
            })
        {
            return TargetSelectionDecision(
                targetIndex: lockedIndex,
                replacementPath: nil
            )
        }

        if troopDefinition.movementDomain == .air {
            return directFlightDecision(
                from: troop,
                among: eligibleIndices,
                entities: entities
            )
        }

        let routedIndices = navigationGrid.isLarge
            ? nearestIndices(
                eligibleIndices,
                to: troop.position,
                entities: entities,
                limit: Self.largeGridCandidateLimit
            )
            : eligibleIndices

        let reachableTargets = routedIndices.compactMap { index in
            pathfinder.findPath(
                from: troop.position,
                to: entities[index].position,
                in: navigationGrid,
                breakableCells: breakableCells,
                breakableTraversalCost: breakableTraversalCost
            ).map { result in
                (
                    targetIndex: index,
                    pathfinding: result
                )
            }
        }

        let best = reachableTargets.min { first, second in
            if first.pathfinding.totalCost == second.pathfinding.totalCost {
                return entities[first.targetIndex].id.uuidString <
                    entities[second.targetIndex].id.uuidString
            }

            return first.pathfinding.totalCost <
                second.pathfinding.totalCost
        }

        guard let best else {
            return nil
        }

        return TargetSelectionDecision(
            targetIndex: best.targetIndex,
            replacementPath: best.pathfinding.waypoints
        )
    }

    /// On large grids only the nearest buildings are compared by route,
    /// which mirrors how troops pick nearby targets and bounds A* work.
    static let largeGridCandidateLimit = 6

    private func nearestIndices(
        _ indices: [Int],
        to position: WorldPosition,
        entities: [BattleEntity],
        limit: Int
    ) -> [Int] {
        guard indices.count > limit else {
            return indices
        }
        return Array(indices.sorted { first, second in
            let firstDistance = directDistance(
                from: position,
                to: entities[first].position
            )
            let secondDistance = directDistance(
                from: position,
                to: entities[second].position
            )
            if firstDistance == secondDistance {
                return entities[first].id.uuidString <
                    entities[second].id.uuidString
            }
            return firstDistance < secondDistance
        }.prefix(limit))
    }

    private func directFlightDecision(
        from troop: BattleEntity,
        among eligibleIndices: [Int],
        entities: [BattleEntity]
    ) -> TargetSelectionDecision? {
        let best = eligibleIndices.min { first, second in
            let firstDistance = directDistance(
                from: troop.position,
                to: entities[first].position
            )
            let secondDistance = directDistance(
                from: troop.position,
                to: entities[second].position
            )

            if firstDistance == secondDistance {
                return entities[first].id.uuidString <
                    entities[second].id.uuidString
            }

            return firstDistance < secondDistance
        }

        guard let best else {
            return nil
        }

        return TargetSelectionDecision(
            targetIndex: best,
            replacementPath: [entities[best].position]
        )
    }

    private func eligibleObjectives(
        from candidateIndices: [Int],
        preference: TargetPreference,
        entities: [BattleEntity],
        gameData: any GameDataProviding
    ) -> [Int] {
        let livingCandidates = candidateIndices.filter {
            entities.indices.contains($0) && entities[$0].isAlive
        }

        let buildings = livingCandidates.filter {
            let role = gameData.definition(for: entities[$0].kind).role
            return role == .defense || role == .building
        }

        switch preference {
        case .defenses:
            let defenses = buildings.filter {
                gameData.definition(for: entities[$0].kind).role == .defense
            }

            return defenses.isEmpty ? buildings : defenses

        case .anyBuilding:
            return buildings

        case .walls:
            let walls = livingCandidates.filter {
                gameData.definition(for: entities[$0].kind).role == .wall
            }

            return walls.isEmpty ? buildings : walls

        case .townHall:
            let townHalls = buildings.filter {
                entities[$0].kind == .townHall
            }

            return townHalls.isEmpty ? buildings : townHalls
        }
    }

    private func directDistance(
        from first: WorldPosition,
        to second: WorldPosition
    ) -> Double {
        let deltaX = second.x - first.x
        let deltaY = second.y - first.y
        return (deltaX * deltaX + deltaY * deltaY).squareRoot()
    }
}
