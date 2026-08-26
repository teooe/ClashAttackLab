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
}
