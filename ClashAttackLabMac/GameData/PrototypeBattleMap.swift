import Foundation

/// Prototype layout used to validate route choice, deployment and scoring.
enum PrototypeBattleMap {
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

    static func makeAttackPlan(
        navigationGrid: NavigationGrid
    ) -> AttackPlan {
        AttackPlan(
            name: "Assalto prototipo a ondate",
            deployments: [
                DeploymentOrder(
                    kind: .giant,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 4)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    kind: .giant,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 7)
                    ),
                    deploymentTime: 2
                ),
                DeploymentOrder(
                    kind: .giant,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 11)
                    ),
                    deploymentTime: 4
                )
            ]
        )
    }
}
