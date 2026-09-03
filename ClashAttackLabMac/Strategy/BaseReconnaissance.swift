import Foundation

/// One possible left-side deployment lane, evaluated with the same A* route
/// model used by the simulation for ground troops.
nonisolated struct DeploymentLaneAssessment: Identifiable {
    let row: Int
    let label: String
    let firstTargetName: String
    let pathCost: Double
    let wallCrossings: Int
    let pressureScore: Double

    var id: Int {
        row
    }

    var routeScore: Double {
        pathCost + Double(wallCrossings) * 200 + pressureScore * 25
    }
}


/// Explainable base reconnaissance for the current prototype layout.
///
/// It is deliberately a planning heuristic, not a claim about the proprietary
/// targeting implementation of Clash of Clans. Route distances themselves
/// come from the app's real A* navigation model.
nonisolated struct BaseReconnaissance {
    let layout: PrototypeBaseLayout
    let lanes: [DeploymentLaneAssessment]

    var recommendedLane: DeploymentLaneAssessment? {
        lanes.min { first, second in
            if first.routeScore == second.routeScore {
                return first.row < second.row
            }

            return first.routeScore < second.routeScore
        }
    }

    var recommendationText: String {
        guard let lane = recommendedLane else {
            return "Nessuna corsia raggiungibile."
        }

        return "\(lane.label): primo bersaglio \(lane.firstTargetName), percorso stimato \(Int(lane.pathCost.rounded())) e \(lane.wallCrossings) muri da attraversare."
    }
}


nonisolated struct BaseReconnaissanceSystem {
    private let navigationGrid: NavigationGrid
    private let gameData: GameDataProviding
    private let pathfinder = AStarPathfinder()

    init(
        navigationGrid: NavigationGrid,
        gameData: GameDataProviding
    ) {
        self.navigationGrid = navigationGrid
        self.gameData = gameData
    }

    func analyze(
        entities: [BattleEntity],
        layout: PrototypeBaseLayout
    ) -> BaseReconnaissance {
        let wallCells = Set(
            entities
                .filter { $0.kind == .wall }
                .compactMap {
                    navigationGrid.coordinate(for: $0.position)
                }
        )
        let defenses = entities.filter {
            gameData.definition(for: $0.kind).role == .defense
        }

        let lanes = laneDefinitions.compactMap { lane in
            assess(
                lane: lane,
                defenses: defenses,
                wallCells: wallCells
            )
        }

        return BaseReconnaissance(
            layout: layout,
            lanes: lanes
        )
    }

    private var laneDefinitions: [(row: Int, label: String)] {
        [
            (3, "Corsia alta"),
            (6, "Corsia medio-alta"),
            (8, "Corsia centrale"),
            (10, "Corsia medio-bassa"),
            (13, "Corsia bassa")
        ]
    }

    private func assess(
        lane: (row: Int, label: String),
        defenses: [BattleEntity],
        wallCells: Set<GridCoordinate>
    ) -> DeploymentLaneAssessment? {
        let start = navigationGrid.worldPosition(
            for: GridCoordinate(column: 1, row: lane.row)
        )
        let wallTraversalCost = estimatedWallTraversalCost()

        let routes = defenses.compactMap {
            defense -> (entity: BattleEntity, path: PathfindingResult)? in
            guard let path = pathfinder.findPath(
                from: start,
                to: defense.position,
                in: navigationGrid,
                breakableCells: wallCells,
                breakableTraversalCost: wallTraversalCost
            ) else {
                return nil
            }

            return (defense, path)
        }

        guard let selected = routes.min(by: {
            if $0.path.totalCost == $1.path.totalCost {
                return $0.entity.id.uuidString < $1.entity.id.uuidString
            }

            return $0.path.totalCost < $1.path.totalCost
        }) else {
            return nil
        }

        let wallCrossings = selected.path.waypoints.reduce(0) {
            count,
            waypoint in
            guard let coordinate = navigationGrid.coordinate(for: waypoint) else {
                return count
            }

            return count + (wallCells.contains(coordinate) ? 1 : 0)
        }

        return DeploymentLaneAssessment(
            row: lane.row,
            label: lane.label,
            firstTargetName: gameData.definition(
                for: selected.entity.kind
            ).displayName,
            pathCost: selected.path.totalCost,
            wallCrossings: wallCrossings,
            pressureScore: defensivePressure(
                from: start,
                defenses: defenses
            )
        )
    }

    private func defensivePressure(
        from deploymentPosition: WorldPosition,
        defenses: [BattleEntity]
    ) -> Double {
        defenses.reduce(0) { score, defense in
            let definition = gameData.definition(for: defense.kind)

            guard definition.attackTargetLayer.accepts(.ground) else {
                return score
            }

            let horizontal = defense.position.x - deploymentPosition.x
            let vertical = defense.position.y - deploymentPosition.y
            let distance = sqrt(
                horizontal * horizontal + vertical * vertical
            )
            let scaledDistance = max(
                navigationGrid.cellSize,
                distance
            )

            return score +
                definition.attackDamage * navigationGrid.cellSize /
                scaledDistance
        }
    }

    private func estimatedWallTraversalCost() -> Double {
        let troop = gameData.definition(for: .giant)
        let wall = gameData.definition(for: .wall)

        guard troop.attackDamage > 0 else {
            return .infinity
        }

        let attacksNeeded = ceil(wall.maxHitPoints / troop.attackDamage)
        return attacksNeeded *
            troop.attackInterval *
            troop.movementSpeed
    }
}
