import Foundation

/// Prototype layout used to validate route choice, deployment and scoring.
nonisolated enum PrototypeBattleMap {
    private struct DeploymentTemplate {
        let kind: BattleEntityKind
        let column: Int
        let deploymentTime: TimeInterval
    }

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
        let sharedEntityIDs = (0..<8).map { _ in UUID() }

        return [
            makeAttackPlan(
                name: "Fronte diviso",
                rows: [4, 3, 5, 11, 12, 10, 7, 7],
                entityIDs: sharedEntityIDs,
                navigationGrid: navigationGrid
            ),
            makeAttackPlan(
                name: "Breccia alta",
                rows: [3, 2, 4, 4, 3, 5, 4, 2],
                entityIDs: sharedEntityIDs,
                navigationGrid: navigationGrid
            ),
            makeAttackPlan(
                name: "Spinta centrale",
                rows: [8, 7, 9, 8, 7, 9, 8, 9],
                entityIDs: sharedEntityIDs,
                navigationGrid: navigationGrid
            ),
            makeAttackPlan(
                name: "Breccia bassa",
                rows: [12, 11, 13, 11, 12, 10, 12, 13],
                entityIDs: sharedEntityIDs,
                navigationGrid: navigationGrid
            )
        ]
    }

    private static func makeAttackPlan(
        name: String,
        rows: [Int],
        entityIDs: [UUID],
        navigationGrid: NavigationGrid
    ) -> AttackPlan {
        let templates = [
            DeploymentTemplate(
                kind: .giant,
                column: 2,
                deploymentTime: 0
            ),
            DeploymentTemplate(
                kind: .barbarian,
                column: 1,
                deploymentTime: 0.6
            ),
            DeploymentTemplate(
                kind: .archer,
                column: 1,
                deploymentTime: 1.2
            ),
            DeploymentTemplate(
                kind: .giant,
                column: 2,
                deploymentTime: 3
            ),
            DeploymentTemplate(
                kind: .barbarian,
                column: 1,
                deploymentTime: 3.6
            ),
            DeploymentTemplate(
                kind: .archer,
                column: 1,
                deploymentTime: 4.2
            ),
            DeploymentTemplate(
                kind: .barbarian,
                column: 2,
                deploymentTime: 6
            ),
            DeploymentTemplate(
                kind: .archer,
                column: 1,
                deploymentTime: 6.5
            )
        ]

        precondition(rows.count == templates.count)
        precondition(entityIDs.count == templates.count)

        let deployments = templates.indices.map { index in
            let template = templates[index]
            return DeploymentOrder(
                entityID: entityIDs[index],
                kind: template.kind,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: template.column,
                        row: rows[index]
                    )
                ),
                deploymentTime: template.deploymentTime
            )
        }

        return AttackPlan(
            name: name,
            deployments: deployments
        )
    }
}
