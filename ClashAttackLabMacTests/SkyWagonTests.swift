import Foundation
import Testing
@testable import ClashAttackLabMac

/// Real Town Hall 17 data with chosen kinds reduced to 1 hit point.
private struct OneHitGameData: GameDataProviding {
    let base: ReferenceGameData
    let fragile: Set<BattleEntityKind>

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        var definition = base.definition(for: kind)
        if fragile.contains(kind) {
            definition.maxHitPoints = 1
        }
        return definition
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        base.spellDefinition(for: kind)
    }

    var battleDuration: TimeInterval {
        base.battleDuration
    }
}

struct SkyWagonTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData() throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 17)
        )
    }

    private func engine(
        _ entities: [BattleEntity],
        _ plan: AttackPlan,
        gameData: any GameDataProviding
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: plan,
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        return engine
    }

    private func advance(_ engine: SimulationEngine, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
    }

    // MARK: Data

    @Test
    func skyWagonUsesRealValues() throws {
        let data = try referenceData()
        let wagon = data.definition(for: .skyWagon)

        #expect(wagon.maxHitPoints == 4_000)
        #expect(wagon.movementDomain == .air)
        #expect(wagon.attackInterval == 8)
        #expect(wagon.attackRange == 5.5 * data.tileSize)
        #expect(wagon.barrelCount == 5)
        #expect(wagon.barrelPayload.filter { $0 == .minion }.count == 4)
        #expect(wagon.barrelPayload.filter { $0 == .balloon }.count == 1)
        #expect(wagon.barrelPayload.filter { $0 == .babyDragon }.count == 1)
        #expect(BattleEntityKind.siegeMachineKinds.contains(.skyWagon))

        let minion = data.definition(for: .minion)
        #expect(minion.maxHitPoints == 130)
        #expect(minion.movementDomain == .air)
        #expect(BattleEntityKind.spawnedTroops.contains(.minion))
    }

    // MARK: Battle

    @Test
    func skyWagonDropsBarrelsOfAirTroopsOnDefenses() throws {
        let data = try referenceData()
        // A ground-only cannon cannot shoot the flying wagon.
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let wagon = DeploymentOrder(kind: .skyWagon, position: position(column: 15, row: 25), deploymentTime: 0)
        let run = engine([cannon, storage], AttackPlan(name: "Carro", deployments: [wagon]), gameData: data)
        advance(run, seconds: 12)

        let barrel = data.definition(for: .skyWagon).barrelPayload
        let minions = run.entities.filter { $0.kind == .minion }.count
        #expect(minions >= barrel.filter { $0 == .minion }.count)
        #expect(minions % barrel.filter { $0 == .minion }.count == 0)
        #expect(run.entities.contains { $0.kind == .babyDragon })
        #expect(run.entities.contains { $0.kind == .balloon })
    }

    @Test
    func clanCastleTroopsComeOutWhereTheWagonFalls() throws {
        let data = OneHitGameData(base: try referenceData(), fragile: [.skyWagon])
        let airDefense = BattleEntity(kind: .airDefense, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let wagon = DeploymentOrder(kind: .skyWagon, position: position(column: 18, row: 25), deploymentTime: 0)
        // The riders' own spot and time are ignored while they ride.
        let riders = [BattleEntityKind.dragon, .dragon, .babyDragon].map {
            DeploymentOrder(
                kind: $0,
                position: position(column: 2, row: 2),
                deploymentTime: 0,
                carrierID: wagon.entityID
            )
        }
        let plan = AttackPlan(name: "Carro", deployments: [wagon] + riders)
        let run = engine([airDefense, storage], plan, gameData: data)

        // Step until the riders appear, then look at them at once.
        var ticks = 0
        while ticks < 6 * 60, !riders.allSatisfy({ rider in run.entities.contains { $0.id == rider.entityID } }) {
            if run.entities.contains(where: { $0.id == wagon.entityID && $0.isAlive }) {
                #expect(!run.entities.contains { $0.kind == .dragon })
            }
            run.advance(by: 1.0 / 60.0)
            ticks += 1
        }

        let fallen = try #require(run.entities.first { $0.id == wagon.entityID })
        #expect(!fallen.isAlive)
        for rider in riders {
            let troop = try #require(run.entities.first { $0.id == rider.entityID }, "\(rider.kind)")
            let gap = hypot(troop.position.x - fallen.position.x, troop.position.y - fallen.position.y)
            // At the wreck, far from the order's own corner.
            #expect(gap < grid.cellSize * 2, "\(rider.kind) \(gap)")
        }
        #expect(run.deployedTroopCount >= 4)
    }

    @Test
    func ridersWithoutTheirMachineDeployAsUsual() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let dragon = DeploymentOrder(
            kind: .dragon,
            position: position(column: 10, row: 10),
            deploymentTime: 0,
            carrierID: UUID()
        )
        let run = engine([storage], AttackPlan(name: "Senza carro", deployments: [dragon]), gameData: data)
        advance(run, seconds: 0.1)
        #expect(run.entities.contains { $0.id == dragon.entityID })
    }

    @Test
    func instructionsListTheRidersInsideTheWagon() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 17))
        let base = arena.makeBaseEntities(layout: .fortress)
        let wagon = DeploymentOrder(kind: .skyWagon, position: position(column: 2, row: 20), deploymentTime: 5)
        let rider = DeploymentOrder(
            kind: .dragon,
            position: position(column: 2, row: 20),
            deploymentTime: 5,
            carrierID: wagon.entityID
        )
        let text = PlanInstructions(
            navigationGrid: arena.navigationGrid,
            base: base,
            gameData: arena.gameData
        ).text(for: AttackPlan(name: "Carro", deployments: [wagon, rider]))

        #expect(text.contains("Nel Carro volante le truppe del Castello: 1 × Drago"))
        #expect(!text.contains("] Drago"))
    }
}
