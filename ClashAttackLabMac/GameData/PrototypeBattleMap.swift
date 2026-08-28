import Foundation

/// Prototype layouts used to validate route choice, deployment and scoring.
nonisolated enum PrototypeBattleMap {
    static func makeNavigationGrid() -> NavigationGrid {
        NavigationGrid(
            columns: 25,
            rows: 16,
            cellSize: 40,
            origin: WorldPosition(x: 50, y: 60),
            blockedCells: []
        )
    }

    static func wallCoordinates(
        for layout: PrototypeBaseLayout = .fortress
    ) -> Set<GridCoordinate> {
        var walls: Set<GridCoordinate> = []

        switch layout {
        case .fortress:
            for row in 2...13 {
                walls.insert(GridCoordinate(column: 11, row: row))
            }

            for column in 15...21 where column != 18 {
                walls.insert(GridCoordinate(column: column, row: 10))
            }

        case .corridor:
            for row in 1...14 where row != 8 {
                walls.insert(GridCoordinate(column: 12, row: row))
            }

            for column in 15...21 where column != 18 {
                walls.insert(GridCoordinate(column: column, row: 6))
                walls.insert(GridCoordinate(column: column, row: 10))
            }

        case .doubleCore:
            for row in 2...13 where row != 8 {
                walls.insert(GridCoordinate(column: 11, row: row))
            }

            for column in 14...21 where column != 17 {
                walls.insert(GridCoordinate(column: column, row: 7))
            }

            for column in 14...21 where column != 19 {
                walls.insert(GridCoordinate(column: column, row: 11))
            }
        }

        return walls
    }

    static func makeBaseEntities(
        navigationGrid: NavigationGrid,
        layout: PrototypeBaseLayout = .fortress
    ) -> [BattleEntity] {
        let objectiveCoordinates = objectives(for: layout)
        var entities = objectiveCoordinates.map { kind, coordinate in
            BattleEntity(
                kind: kind,
                position: navigationGrid.worldPosition(for: coordinate)
            )
        }

        entities += wallCoordinates(for: layout).map {
            BattleEntity(
                kind: .wall,
                position: navigationGrid.worldPosition(for: $0)
            )
        }

        return entities
    }

    static func makeAttackPlan(
        navigationGrid: NavigationGrid
    ) -> AttackPlan {
        makeCandidateAttackPlans(
            navigationGrid: navigationGrid
        )[0]
    }

    static func makeCandidateAttackPlans(
        navigationGrid: NavigationGrid,
        armyConfiguration: ArmyConfiguration = .prototypeDefault
    ) -> [AttackPlan] {
        AttackPlanGenerator(
            navigationGrid: navigationGrid,
            armyConfiguration: armyConfiguration
        ).generate()
    }

    private static func objectives(
        for layout: PrototypeBaseLayout
    ) -> [(BattleEntityKind, GridCoordinate)] {
        switch layout {
        case .fortress:
            return [
                (.cannon, GridCoordinate(column: 16, row: 3)),
                (.cannon, GridCoordinate(column: 16, row: 13)),
                (.archerTower, GridCoordinate(column: 19, row: 4)),
                (.archerTower, GridCoordinate(column: 19, row: 12)),
                (.mortar, GridCoordinate(column: 18, row: 8)),
                (.townHall, GridCoordinate(column: 22, row: 8)),
                (.goldStorage, GridCoordinate(column: 16, row: 7)),
                (.goldStorage, GridCoordinate(column: 16, row: 12))
            ]

        case .corridor:
            return [
                (.cannon, GridCoordinate(column: 16, row: 4)),
                (.cannon, GridCoordinate(column: 16, row: 12)),
                (.archerTower, GridCoordinate(column: 20, row: 5)),
                (.archerTower, GridCoordinate(column: 20, row: 11)),
                (.mortar, GridCoordinate(column: 18, row: 8)),
                (.townHall, GridCoordinate(column: 22, row: 8)),
                (.goldStorage, GridCoordinate(column: 16, row: 7)),
                (.goldStorage, GridCoordinate(column: 16, row: 9))
            ]

        case .doubleCore:
            return [
                (.cannon, GridCoordinate(column: 15, row: 5)),
                (.cannon, GridCoordinate(column: 15, row: 11)),
                (.archerTower, GridCoordinate(column: 20, row: 3)),
                (.archerTower, GridCoordinate(column: 20, row: 13)),
                (.mortar, GridCoordinate(column: 18, row: 8)),
                (.townHall, GridCoordinate(column: 22, row: 8)),
                (.goldStorage, GridCoordinate(column: 17, row: 6)),
                (.goldStorage, GridCoordinate(column: 17, row: 10))
            ]
        }
    }
}
