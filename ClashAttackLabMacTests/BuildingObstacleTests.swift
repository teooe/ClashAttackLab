import Foundation
import Testing
@testable import ClashAttackLabMac

struct BuildingObstacleTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData() throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
    }

    @Test
    func heapFrontierFindsTheSameRoutesAsBefore() {
        // Optimal octile route on an open grid: 10 diagonal + 5 straight.
        let path = AStarPathfinder().findPath(
            from: position(column: 5, row: 5),
            to: position(column: 20, row: 15),
            in: grid
        )
        let cost = path?.totalCost ?? 0
        #expect(abs(cost - (10 * 2.0.squareRoot() + 5) * grid.cellSize) < 1e-6)
    }

    @Test
    func routesGoAroundObstacleCells() throws {
        var obstacles: Set<GridCoordinate> = []
        for row in 10...30 {
            obstacles.insert(GridCoordinate(column: 20, row: row))
        }
        let pathfinder = AStarPathfinder()
        let start = position(column: 15, row: 20)
        let goal = position(column: 25, row: 20)
        let open = try #require(pathfinder.findPath(from: start, to: goal, in: grid))
        let around = try #require(pathfinder.findPath(
            from: start,
            to: goal,
            in: grid,
            obstacleCells: obstacles
        ))

        #expect(around.totalCost > open.totalCost)
        for waypoint in around.waypoints {
            let cell = try #require(grid.coordinate(for: waypoint))
            #expect(!obstacles.contains(cell), "\(cell)")
        }
    }

    @Test
    func footprintCellsMatchTheBuildingTiles() {
        let threeByThree = grid.footprintCells(
            centeredAt: position(column: 20, row: 20),
            side: 3 * grid.cellSize
        )
        #expect(threeByThree.count == 9)
        #expect(threeByThree.contains(GridCoordinate(column: 19, row: 19)))
        #expect(threeByThree.contains(GridCoordinate(column: 21, row: 21)))

        // An even footprint is centred on a tile corner.
        let corner = WorldPosition(
            x: grid.origin.x + 20 * grid.cellSize,
            y: grid.origin.y + 20 * grid.cellSize
        )
        let fourByFour = grid.footprintCells(centeredAt: corner, side: 4 * grid.cellSize)
        #expect(fourByFour.count == 16)
        #expect(fourByFour.contains(GridCoordinate(column: 18, row: 18)))
        #expect(fourByFour.contains(GridCoordinate(column: 21, row: 21)))
        #expect(grid.footprintCells(centeredAt: corner, side: 0).isEmpty)
    }

    @Test
    func groundTroopsWalkAroundBuildingsInTheWay() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 20, row: 25))
        let cannon = BattleEntity(kind: .cannon, position: position(column: 27, row: 25))
        let giant = DeploymentOrder(kind: .giant, position: position(column: 12, row: 25), deploymentTime: 0)
        let engine = SimulationEngine(
            entities: [storage, cannon],
            attackPlan: AttackPlan(name: "Around", deployments: [giant]),
            gameData: data,
            navigationGrid: grid
        )
        let storageCells = grid.footprintCells(
            centeredAt: storage.position,
            side: data.definition(for: .goldStorage).footprintSize
        )
        engine.start()

        for _ in 0..<(60 * 10) {
            engine.advance(by: 1.0 / 60.0)
            if let walker = engine.entities.first(where: { $0.id == giant.entityID }),
               walker.isAlive,
               let cell = grid.coordinate(for: walker.position) {
                #expect(!storageCells.contains(cell), "Giant crossed the storage at \(cell)")
            }
        }

        let hitCannon = try #require(engine.entities.first { $0.id == cannon.id })
        #expect(hitCannon.hitPoints < data.definition(for: .cannon).maxHitPoints)
        let untouchedStorage = try #require(engine.entities.first { $0.id == storage.id })
        #expect(untouchedStorage.hitPoints == data.definition(for: .goldStorage).maxHitPoints)
    }

    @Test
    func troopsStillReachATargetWalledInByBuildings() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        var ring: [BattleEntity] = []
        for columnOffset in [-3, 0, 3] {
            for rowOffset in [-3, 0, 3] where columnOffset != 0 || rowOffset != 0 {
                ring.append(BattleEntity(
                    kind: .goldStorage,
                    position: position(column: 25 + columnOffset, row: 25 + rowOffset)
                ))
            }
        }
        let giant = DeploymentOrder(kind: .giant, position: position(column: 12, row: 25), deploymentTime: 0)
        let engine = SimulationEngine(
            entities: [cannon] + ring,
            attackPlan: AttackPlan(name: "Walled in", deployments: [giant]),
            gameData: data,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<(60 * 12) {
            engine.advance(by: 1.0 / 60.0)
        }

        let hitCannon = try #require(engine.entities.first { $0.id == cannon.id })
        #expect(hitCannon.hitPoints < data.definition(for: .cannon).maxHitPoints)
    }

    @Test
    func prototypeBuildingsStayPassable() {
        let gameData = PrototypeGameData()
        for kind in BattleEntityKind.allCases where gameData.definition(for: kind).countsForDestruction {
            #expect(gameData.definition(for: kind).footprintSize == 0, "\(kind)")
        }
    }
}
