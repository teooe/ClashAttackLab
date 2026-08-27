import Foundation
import Testing
@testable import ClashAttackLabMac

struct ClashAttackLabMacTests {
    @Test
    func scoringAwardsStarsAndExcludesWalls() {
        let gameData = PrototypeGameData()
        let scoring = BaseScoringSystem()
        let position = WorldPosition(x: 0, y: 0)

        var entities = [
            BattleEntity(
                kind: .townHall,
                position: position,
                hitPoints: 900
            ),
            BattleEntity(
                kind: .cannon,
                position: position,
                hitPoints: 500
            ),
            BattleEntity(
                kind: .goldStorage,
                position: position,
                hitPoints: 620
            ),
            BattleEntity(
                kind: .goldStorage,
                position: position,
                hitPoints: 620
            ),
            BattleEntity(
                kind: .wall,
                position: position,
                hitPoints: 0
            )
        ]

        var score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.totalBuildings == 4)
        #expect(score.stars == 0)
        #expect(score.destructionPercentage == 0)

        entities[1].hitPoints = 0
        entities[2].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 50)
        #expect(score.stars == 1)

        entities[0].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 75)
        #expect(score.townHallDestroyed)
        #expect(score.stars == 2)

        entities[3].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 100)
        #expect(score.stars == 3)
    }

    @Test
    func weightedPathfindingCanBreakOrAvoidAWall() throws {
        let grid = NavigationGrid(
            columns: 5,
            rows: 5,
            cellSize: 1,
            origin: WorldPosition(x: 0, y: 0),
            blockedCells: []
        )
        let pathfinder = AStarPathfinder()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 0, row: 2)
        )
        let goal = grid.worldPosition(
            for: GridCoordinate(column: 4, row: 2)
        )
        let wall = GridCoordinate(column: 2, row: 2)

        let breakingRoute = try #require(
            pathfinder.findPath(
                from: start,
                to: goal,
                in: grid,
                breakableCells: [wall],
                breakableTraversalCost: 0
            )
        )
        let breakingCoordinates = breakingRoute.waypoints.compactMap {
            grid.coordinate(for: $0)
        }
        #expect(breakingCoordinates.contains(wall))

        let detourRoute = try #require(
            pathfinder.findPath(
                from: start,
                to: goal,
                in: grid,
                breakableCells: [wall],
                breakableTraversalCost: 100
            )
        )
        let detourCoordinates = detourRoute.waypoints.compactMap {
            grid.coordinate(for: $0)
        }
        #expect(!detourCoordinates.contains(wall))
        #expect(detourRoute.totalCost < breakingRoute.totalCost + 100)
    }

    @Test
    func attackPlanOrdersDeploymentsByTime() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let lateID = UUID()
        let earlyID = UUID()
        let middleID = UUID()

        let plan = AttackPlan(
            name: "Ordine di prova",
            deployments: [
                DeploymentOrder(
                    entityID: lateID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 4)
                    ),
                    deploymentTime: 4
                ),
                DeploymentOrder(
                    entityID: earlyID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 7)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    entityID: middleID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 11)
                    ),
                    deploymentTime: 2
                )
            ]
        )

        #expect(
            plan.orderedDeployments.map(\.entityID) ==
                [earlyID, middleID, lateID]
        )
    }

    @Test
    func simulationDeploysTroopsAtScheduledTimes() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: grid
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plan
        )

        #expect(engine.pendingDeploymentCount == 3)
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.entities.filter { $0.kind == .giant }.isEmpty)

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        #expect(engine.pendingDeploymentCount == 2)
        #expect(engine.deployedTroopCount == 1)
        #expect(
            engine.entities.contains {
                $0.id == plan.orderedDeployments[0].entityID
            }
        )

        advance(engine, ticks: 125)

        #expect(engine.pendingDeploymentCount == 1)
        #expect(engine.deployedTroopCount == 2)
        #expect(
            engine.entities.contains {
                $0.id == plan.orderedDeployments[1].entityID
            }
        )

        advance(engine, ticks: 121)

        #expect(engine.pendingDeploymentCount == 0)
        #expect(engine.deployedTroopCount == 3)
        #expect(
            engine.entities.contains {
                $0.id == plan.orderedDeployments[2].entityID
            }
        )
    }

    @Test
    func pauseStopsTimeAndResetRestoresThePlan() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: grid
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plan
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)
        let timeAtPause = engine.elapsedTime

        engine.togglePause()
        advance(engine, ticks: 120)

        #expect(engine.elapsedTime == timeAtPause)
        #expect(engine.deployedTroopCount == 1)

        engine.togglePause()
        engine.advance(by: 1.0 / 60.0)

        #expect(engine.elapsedTime > timeAtPause)

        engine.reset()

        if case .ready = engine.status {
            // Stato atteso.
        } else {
            Issue.record("Il reset deve riportare la simulazione a ready.")
        }

        #expect(engine.elapsedTime == 0)
        #expect(engine.pendingDeploymentCount == 3)
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.entities.filter { $0.kind == .giant }.isEmpty)
    }

    private func makeDeploymentTestEngine(
        grid: NavigationGrid,
        plan: AttackPlan
    ) -> SimulationEngine {
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 22, row: 8)
            )
        )

        return SimulationEngine(
            entities: [townHall],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
    }

    private func advance(
        _ engine: SimulationEngine,
        ticks: Int
    ) {
        for _ in 0..<ticks {
            engine.advance(by: 1.0 / 60.0)
        }
    }
}
