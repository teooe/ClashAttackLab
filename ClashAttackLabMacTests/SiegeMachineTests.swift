import Foundation
import Testing
@testable import ClashAttackLabMac

/// Real Town Hall 15 data with one troop reduced to 1 hit point.
private struct OneHitData: GameDataProviding {
    let base: ReferenceGameData
    let fragile: BattleEntityKind

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        var definition = base.definition(for: kind)
        if kind == fragile {
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

struct SiegeMachineTests {
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

    private func run(
        _ entities: [BattleEntity],
        _ deployments: [DeploymentOrder],
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Assedio", deployments: deployments),
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
        return engine
    }

    // MARK: Data and army rules

    @Test
    func townHall15SiegeMachinesUseTheRealValues() throws {
        let data = try referenceData()
        let blimp = data.definition(for: .battleBlimp)
        let flinger = data.definition(for: .flameFlinger)
        let barracks = data.definition(for: .siegeBarracks)

        #expect(blimp.maxHitPoints == 5_000)
        #expect(blimp.attackDamage == 390)
        #expect(blimp.destructionDamage == 1_100)
        #expect(blimp.movementDomain == .air)
        #expect(blimp.targetingProfile?.preference == .townHall)

        #expect(flinger.attackRange == 11 * 40)
        #expect(flinger.hitPointDecayPerSecond == 17)
        #expect(flinger.burstShotCount == 3)

        #expect(barracks.releasesPayloadOnDeploy)
        #expect(barracks.siegePayload == [.pekka] + Array(repeating: .wizard, count: 11))
        #expect(abs(barracks.hitPointDecayPerSecond - 4_500.0 / 30) < 1e-9)
    }

    @Test
    func armiesTakeOneSiegeMachineOutsideTheCamps() throws {
        let rules = ArmyCapacityRules.real(townHall: 15, catalog: try ReferenceGameCatalog.loadBundled())
        for kind in BattleEntityKind.advancedSiegeMachines {
            #expect(rules.allows(kind), "\(kind)")
            #expect(rules.housing(for: kind) == 0, "\(kind)")
            #expect(ArmyConfiguration.troopKinds.contains(kind))
        }

        var army = ArmyConfiguration.realDefault(for: rules)
        #expect(army.wallWreckers == 1)
        army.wallWreckers = 0
        army[troop: .battleBlimp] = 1
        #expect(army.isValid(under: rules))
        army[troop: .siegeBarracks] = 1
        #expect(army.validationMessage(under: rules) == "Puoi usare una sola macchina d’assedio.")
    }

    // MARK: Battle

    @Test
    func siegeBarracksLetTheirTroopsOutAtOnceAndWearOut() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 25))
        let barracks = DeploymentOrder(kind: .siegeBarracks, position: position(column: 20, row: 25), deploymentTime: 0)
        let engine = run([storage], [barracks], gameData: data, seconds: 2)

        #expect(engine.releasedPayloadTroopCount == 12)
        #expect(engine.entities.filter { $0.kind == .pekka }.count == 1)
        #expect(engine.entities.filter { $0.kind == .wizard }.count == 11)
        let standing = try #require(engine.entities.first { $0.id == barracks.entityID })
        #expect(abs(standing.hitPoints - (4_500 - 150 * 2)) < 1)
    }

    @Test
    func aWornOutBarracksDoesNotReleaseItsTroopsTwice() throws {
        let data = OneHitData(base: try referenceData(), fragile: .siegeBarracks)
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 25))
        let barracks = DeploymentOrder(kind: .siegeBarracks, position: position(column: 20, row: 25), deploymentTime: 0)
        let engine = run([storage], [barracks], gameData: data, seconds: 0.5)

        let worn = try #require(engine.entities.first { $0.id == barracks.entityID })
        #expect(!worn.isAlive)
        #expect(engine.releasedPayloadTroopCount == 12)
    }

    @Test
    func flameFlingersBurnOut() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 25))
        let flinger = DeploymentOrder(kind: .flameFlinger, position: position(column: 5, row: 25), deploymentTime: 0)
        let engine = run([storage], [flinger], gameData: data, seconds: 10)

        let machine = try #require(engine.entities.first { $0.id == flinger.entityID })
        let expected = data.definition(for: .flameFlinger).maxHitPoints - 17 * 10
        #expect(abs(machine.hitPoints - expected) < 1)
    }

    @Test
    func fallingBlimpsAndGolemsBurstOnBuildings() throws {
        for kind in [BattleEntityKind.battleBlimp, .golem] {
            let base = try referenceData()
            let data = OneHitData(base: base, fragile: kind)
            let burst = base.definition(for: kind).destructionDamage
            #expect(burst > 0, "\(kind)")

            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
            let killer = BattleEntity(
                kind: kind == .golem ? .cannon : .airDefense,
                position: position(column: 25, row: 30)
            )
            let attacker = DeploymentOrder(kind: kind, position: position(column: 23, row: 25), deploymentTime: 0)
            let engine = run([storage, killer], [attacker], gameData: data, seconds: 2)

            let fallen = try #require(engine.entities.first { $0.id == attacker.entityID })
            #expect(!fallen.isAlive, "\(kind)")
            let hit = try #require(engine.entities.first { $0.id == storage.id })
            let loss = base.definition(for: .goldStorage).maxHitPoints - hit.hitPoints
            #expect(loss >= burst - 1e-6, "\(kind)")
        }
    }
}

struct LogLauncherTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    @Test
    func logsSmashTheWallsInTheirPath() throws {
        let data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        let launcherDefinition = data.definition(for: .logLauncher)
        #expect(launcherDefinition.attackDamage == 600)
        #expect(launcherDefinition.damageMultiplierAgainstWalls == 4)
        #expect(launcherDefinition.hitPointDecayPerSecond == 156)
        #expect(launcherDefinition.rollingLogLength == 10 * 40)

        let townHall = BattleEntity(kind: .townHall, position: position(column: 28, row: 25))
        let walls = (22...28).map {
            BattleEntity(kind: .wall, position: position(column: 20, row: $0))
        }
        let launcher = DeploymentOrder(kind: .logLauncher, position: position(column: 12, row: 25), deploymentTime: 0)
        let engine = SimulationEngine(
            entities: [townHall] + walls,
            attackPlan: AttackPlan(name: "Tronchi", deployments: [launcher]),
            gameData: data,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<(60 * 4) {
            engine.advance(by: 1.0 / 60.0)
        }

        // Two logs by now: at the start and three seconds later.
        let wallHitPoints = data.definition(for: .wall).maxHitPoints
        let inPath = try #require(engine.entities.first { $0.id == walls[3].id })
        #expect(wallHitPoints - inPath.hitPoints >= min(wallHitPoints, 2 * 2_400) - 1e-6)
        let aside = try #require(engine.entities.first { $0.id == walls[0].id })
        #expect(aside.hitPoints == wallHitPoints)

        let machine = try #require(engine.entities.first { $0.id == launcher.entityID })
        #expect(machine.position.x > launcher.position.x)
        if inPath.isAlive {
            // A standing wall stops the crawl.
            #expect(machine.position.x < inPath.position.x - grid.cellSize / 2)
        }
    }
}
