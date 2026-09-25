import Foundation

/// One recommended deployment lane for a troop type currently present in the army.
///
/// This is an explainable heuristic built on the simulator's actual movement
/// and targeting definitions; it is not a statement about the game’s internal AI.
nonisolated struct TroopEntryRecommendation: Identifiable {
    let kind: BattleEntityKind
    let troopName: String
    let troopCount: Int
    let movementDomain: MovementDomain
    let laneRow: Int
    let laneLabel: String
    let firstTargetName: String
    let pathCost: Double
    let wallCrossings: Int
    let defensivePressure: Double
    let score: Double

    var id: BattleEntityKind {
        kind
    }

    var routeSummary: String {
        let movementText = movementDomain == .air
            ? "volo diretto"
            : "percorso A*"

        return "\(movementText) \(Int(pathCost.rounded())) · muri \(wallCrossings) · pressione \(String(format: "%.1f", defensivePressure))"
    }
}

/// Entry recommendations for the configured army against the active base.
nonisolated struct ArmyEntryAdvice {
    let baseName: String
    let recommendations: [TroopEntryRecommendation]

    var preferredRecommendation: TroopEntryRecommendation? {
        recommendations.min { first, second in
            if first.score == second.score {
                return first.troopName < second.troopName
            }

            return first.score < second.score
        }
    }

    func recommendation(
        for kind: BattleEntityKind
    ) -> TroopEntryRecommendation? {
        recommendations.first { $0.kind == kind }
    }

    var recommendationText: String {
        guard let best = preferredRecommendation else {
            return "Nessuna corsia raggiungibile per l’esercito attuale."
        }

        return "\(best.laneLabel): ingresso iniziale suggerito per \(best.troopCount) \(best.troopName), bersaglio \(best.firstTargetName)."
    }
}

/// Evaluates deployment lanes separately for every troop type in the army.
nonisolated struct ArmyEntryAdvisor {
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
        armyConfiguration: ArmyConfiguration,
        baseName: String
    ) -> ArmyEntryAdvice {
        let walls = Set(
            entities
                .filter { $0.kind == .wall }
                .compactMap { navigationGrid.coordinate(for: $0.position) }
        )
        let defenses = entities.filter {
            gameData.definition(for: $0.kind).role == .defense
        }

        let recommendations = troopKinds(
            in: armyConfiguration
        ).compactMap {
            makeRecommendation(
                for: $0,
                troopCount: armyConfiguration.troopCount(for: $0),
                entities: entities,
                defenses: defenses,
                walls: walls
            )
        }

        return ArmyEntryAdvice(
            baseName: baseName,
            recommendations: recommendations
        )
    }

    private func troopKinds(
        in configuration: ArmyConfiguration
    ) -> [BattleEntityKind] {
        [
            .giant,
            .barbarian,
            .archer,
            .wallBreaker,
            .wizard,
            .balloon,
            .dragon,
            .barbarianKing,
            .archerQueen,
            .wallWrecker,
            .stoneSlammer
        ].filter { configuration.troopCount(for: $0) > 0 }
    }

    private func makeRecommendation(
        for kind: BattleEntityKind,
        troopCount: Int,
        entities: [BattleEntity],
        defenses: [BattleEntity],
        walls: Set<GridCoordinate>
    ) -> TroopEntryRecommendation? {
        let troop = gameData.definition(for: kind)
        let targets = possibleTargets(
            for: troop,
            in: entities
        )
        guard !targets.isEmpty else {
            return nil
        }

        let lanes = laneDefinitions.compactMap {
            assess(
                lane: $0,
                troop: troop,
                targets: targets,
                defenses: defenses,
                walls: walls
            )
        }

        guard let best = lanes.min(by: { first, second in
            if first.score == second.score {
                return first.lane.row < second.lane.row
            }

            return first.score < second.score
        }) else {
            return nil
        }

        return TroopEntryRecommendation(
            kind: kind,
            troopName: troop.displayName,
            troopCount: troopCount,
            movementDomain: troop.movementDomain,
            laneRow: best.lane.row,
            laneLabel: best.lane.label,
            firstTargetName: gameData.definition(
                for: best.target.kind
            ).displayName,
            pathCost: best.pathCost,
            wallCrossings: best.wallCrossings,
            defensivePressure: best.pressure,
            score: best.score
        )
    }

    private func possibleTargets(
        for troop: CombatDefinition,
        in entities: [BattleEntity]
    ) -> [BattleEntity] {
        guard let profile = troop.targetingProfile else {
            return []
        }

        switch profile.preference {
        case .defenses:
            return entities.filter {
                gameData.definition(for: $0.kind).role == .defense
            }

        case .anyBuilding:
            return entities.filter {
                gameData.definition(for: $0.kind).countsForDestruction
            }

        case .walls:
            return entities.filter { $0.kind == .wall }

        case .townHall:
            let townHalls = entities.filter { $0.kind == .townHall }
            return townHalls.isEmpty
                ? entities.filter {
                    gameData.definition(for: $0.kind).countsForDestruction
                }
                : townHalls
        }
    }

    private func assess(
        lane: (row: Int, label: String),
        troop: CombatDefinition,
        targets: [BattleEntity],
        defenses: [BattleEntity],
        walls: Set<GridCoordinate>
    ) -> (
        lane: (row: Int, label: String),
        target: BattleEntity,
        pathCost: Double,
        wallCrossings: Int,
        pressure: Double,
        score: Double
    )? {
        let start = navigationGrid.worldPosition(
            for: GridCoordinate(column: 1, row: lane.row)
        )
        let wallTraversalCost = estimatedWallTraversalCost(for: troop)

        let candidates = navigationGrid.routingCandidates(
            targets,
            near: start
        ).compactMap {
            target -> (
                target: BattleEntity,
                pathCost: Double,
                wallCrossings: Int
            )? in
            switch troop.movementDomain {
            case .air:
                return (
                    target,
                    directDistance(from: start, to: target.position),
                    0
                )

            case .ground:
                guard let path = pathfinder.findPath(
                    from: start,
                    to: target.position,
                    in: navigationGrid,
                    breakableCells: walls,
                    breakableTraversalCost: wallTraversalCost
                ) else {
                    return nil
                }

                let wallCrossings = path.waypoints.reduce(0) {
                    count,
                    waypoint in
                    guard let coordinate = navigationGrid.coordinate(
                        for: waypoint
                    ) else {
                        return count
                    }

                    return count + (walls.contains(coordinate) ? 1 : 0)
                }

                return (target, path.totalCost, wallCrossings)
            }
        }

        guard let bestTarget = candidates.min(by: {
            if $0.pathCost == $1.pathCost {
                return $0.target.id.uuidString < $1.target.id.uuidString
            }

            return $0.pathCost < $1.pathCost
        }) else {
            return nil
        }

        let pressure = defensivePressure(
            at: start,
            movementDomain: troop.movementDomain,
            defenses: defenses
        )
        let score = bestTarget.pathCost +
            Double(bestTarget.wallCrossings) * 200 +
            pressure * 25

        return (
            lane,
            bestTarget.target,
            bestTarget.pathCost,
            bestTarget.wallCrossings,
            pressure,
            score
        )
    }

    private var laneDefinitions: [(row: Int, label: String)] {
        [
            (3, "Corsia alta"),
            (6, "Corsia medio-alta"),
            (8, "Corsia centrale"),
            (10, "Corsia medio-bassa"),
            (13, "Corsia bassa")
        ].map { (navigationGrid.scaledRow(fromPrototype: $0.0), $0.1) }
    }

    private func directDistance(
        from first: WorldPosition,
        to second: WorldPosition
    ) -> Double {
        let horizontal = second.x - first.x
        let vertical = second.y - first.y
        return sqrt(horizontal * horizontal + vertical * vertical)
    }

    private func defensivePressure(
        at position: WorldPosition,
        movementDomain: MovementDomain,
        defenses: [BattleEntity]
    ) -> Double {
        defenses.reduce(0) { total, defense in
            let definition = gameData.definition(for: defense.kind)
            guard definition.attackTargetLayer.accepts(movementDomain) else {
                return total
            }

            let distance = directDistance(from: position, to: defense.position)
            guard distance < definition.attackRange else {
                return total
            }

            let proximity = 1 - distance / definition.attackRange
            let dps = definition.attackDamage /
                max(0.1, definition.attackInterval)

            return total + dps * proximity
        }
    }

    private func estimatedWallTraversalCost(
        for troop: CombatDefinition
    ) -> Double {
        guard troop.attackDamage > 0 else {
            return .infinity
        }

        let wall = gameData.definition(for: .wall)
        let attacksNeeded = ceil(wall.maxHitPoints /
            (troop.attackDamage * troop.damageMultiplierAgainstWalls))

        return attacksNeeded *
            troop.attackInterval *
            troop.movementSpeed
    }
}
