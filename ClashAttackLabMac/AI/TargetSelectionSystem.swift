import Foundation

struct TargetSelectionDecision {
    let targetIndex: Int

    /// Nil means that the troop can keep its current path.
    let replacementPath: [WorldPosition]?
}

/// Chooses troop objectives without knowing anything about rendering.
///
/// Documented rule:
/// - Giants prefer defenses.
/// - Barbarians and Archers have no favorite building category.
///
/// Current approximation:
/// - Among eligible targets, the best one is the target with the lowest
///   weighted A* route cost.
/// - The target remains locked until it is destroyed or becomes invalid.
struct TargetSelectionSystem {
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
        let preference =
            gameData.definition(for: troop.kind)
                .targetingProfile?
                .preference ?? .anyBuilding
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

        let reachableTargets = eligibleIndices.compactMap { index in
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

    private func eligibleObjectives(
        from candidateIndices: [Int],
        preference: TargetPreference,
        entities: [BattleEntity],
        gameData: any GameDataProviding
    ) -> [Int] {
        let livingCandidates = candidateIndices.filter {
            entities.indices.contains($0) && entities[$0].isAlive
        }

        switch preference {
        case .defenses:
            let defenses = livingCandidates.filter {
                gameData.definition(for: entities[$0].kind).role == .defense
            }

            return defenses.isEmpty ? livingCandidates : defenses

        case .anyBuilding:
            return livingCandidates
        }
    }
}
