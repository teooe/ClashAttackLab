import Foundation

/// Prototype layout used to validate route choice, deployment and scoring.
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

    static func wallCoordinates() -> Set<GridCoordinate> {
        var walls: Set<GridCoordinate> = []

        for row in 2...13 {
            walls.insert(GridCoordinate(column: 11, row: row))
        }

        for column in 15...21 where column != 18 {
            walls.insert(GridCoordinate(column: column, row: 10))
        }

        return walls
    }

    static func makeBaseEntities(
        navigationGrid: NavigationGrid
    ) -> [BattleEntity] {
        var entities = [
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 3)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 13)
                )
            ),
            BattleEntity(
                kind: .archerTower,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 19, row: 4)
                )
            ),
            BattleEntity(
                kind: .archerTower,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 19, row: 12)
                )
            ),
            BattleEntity(
                kind: .mortar,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 18, row: 8)
                )
            ),
            BattleEntity(
                kind: .townHall,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 22, row: 8)
                )
            ),
            BattleEntity(
                kind: .goldStorage,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 7)
                )
            ),
            BattleEntity(
                kind: .goldStorage,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 12)
                )
            )
        ]

        entities += wallCoordinates().map {
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
        navigationGrid: NavigationGrid
    ) -> [AttackPlan] {
        AttackPlanGenerator(
            navigationGrid: navigationGrid
        ).generate()
    }
}
