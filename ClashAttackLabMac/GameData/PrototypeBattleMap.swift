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
            name: "Assalto misto a tre ondate",
            deployments: [
                DeploymentOrder(
                    kind: .giant,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 4)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    kind: .barbarian,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 1, row: 3)
                    ),
                    deploymentTime: 0.6
                ),
                DeploymentOrder(
                    kind: .archer,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 1, row: 5)
                    ),
                    deploymentTime: 1.2
                ),
                DeploymentOrder(
                    kind: .giant,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 11)
                    ),
                    deploymentTime: 3
                ),
                DeploymentOrder(
                    kind: .barbarian,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 1, row: 12)
                    ),
                    deploymentTime: 3.6
                ),
                DeploymentOrder(
                    kind: .archer,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 1, row: 10)
                    ),
                    deploymentTime: 4.2
                ),
                DeploymentOrder(
                    kind: .barbarian,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 2, row: 7)
                    ),
                    deploymentTime: 6
                ),
                DeploymentOrder(
                    kind: .archer,
                    position: navigationGrid.worldPosition(
                        for: GridCoordinate(column: 1, row: 7)
                    ),
                    deploymentTime: 6.5
                )
            ]
        )
    }
}
