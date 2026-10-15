import Foundation
import Testing
@testable import ClashAttackLabMac

struct TownHall15TroopTests {
    private func referenceData(townHall: Int = 15) throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: townHall)
        )
    }

    private func rules(townHall: Int = 15) throws -> ArmyCapacityRules {
        ArmyCapacityRules.real(
            townHall: townHall,
            catalog: try ReferenceGameCatalog.loadBundled()
        )
    }

    private func isClose(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 1e-6
    }

    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func engine(
        entities: [BattleEntity],
        deployments: [DeploymentOrder],
        gameData: any GameDataProviding
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Test", deployments: deployments),
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
    func advancedTroopsUseRealTownHall15Values() throws {
        let data = try referenceData()
        let hog = data.definition(for: .hogRider)
        let miner = data.definition(for: .miner)
        let electro = data.definition(for: .electroDragon)
        let hound = data.definition(for: .lavaHound)

        #expect(hog.role == .troop)
        #expect(hog.maxHitPoints == 1_230)
        #expect(hog.attackDamage == 200)
        #expect(isClose(hog.movementSpeed, 24.0 / 8 * 40))
        #expect(isClose(hog.attackRange, 0.6 * 40))
        #expect(hog.housingSpace == 5)
        #expect(hog.ignoresWalls)
        #expect(hog.movementDomain == .ground)
        #expect(hog.targetingProfile?.preference == .defenses)

        #expect(miner.ignoresWalls)
        #expect(miner.burrowsWhileMoving)
        #expect(miner.maxHitPoints == 1_350)

        #expect(electro.movementDomain == .air)
        #expect(electro.maxHitPoints == 5_400)
        #expect(electro.attackDamage == 1_435)
        #expect(electro.chainTargetCount == 5)
        #expect(electro.housingSpace == 30)

        #expect(hound.movementDomain == .air)
        #expect(hound.targetingProfile?.preference == .airDefenses)
        #expect(hound.maxHitPoints == 8_000)

        for kind in BattleEntityKind.advancedTroops {
            let definition = data.definition(for: kind)
            #expect(definition.role == .troop, "\(kind)")
            #expect(definition.housingSpace > 0, "\(kind)")
            #expect(TroopStyle.style(for: kind).symbol != "?", "\(kind)")
            #expect(PrototypeGameData().definition(for: kind).role == .troop)
        }
    }

    @Test
    func realRulesUnlockAdvancedTroopsByTownHall() throws {
        let th15 = try rules(townHall: 15)
        let th14 = try rules(townHall: 14)

        for kind in BattleEntityKind.advancedTroops {
            #expect(th15.allows(kind), "\(kind)")
        }
        #expect(th15.housing(for: .electroDragon) == 30)
        #expect(th15.housing(for: .miner) == 6)
        #expect(!th14.allows(.rootRider))

        var army = ArmyConfiguration(
            giants: 2,
            barbarians: 0,
            archers: 0,
            wallBreakers: 0,
            wizards: 0,
            healSpells: 0,
            rageSpells: 0
        )
        army[troop: .rootRider] = 1
        #expect(army.validationMessage(under: th14) == "Cavalcaradici non è ancora sbloccato.")
    }

    // MARK: Army

    @Test
    func troopSubscriptReadsAndWritesEveryKind() {
        var army = ArmyConfiguration.prototypeDefault
        army[troop: .hogRider] = 4
        army[troop: .giant] = 3

        #expect(army.troopCount(for: .hogRider) == 4)
        #expect(army.giants == 3)
        #expect(army.totalTroops == ArmyConfiguration.prototypeDefault.totalTroops + 4 + 1)
        #expect(army.deploymentSequence.filter { $0 == .hogRider }.count == 4)
        #expect(army.distinctTroopKindCount == ArmyConfiguration.prototypeDefault.distinctTroopKindCount + 1)

        army[troop: .hogRider] = 0
        army[troop: .giant] = ArmyConfiguration.prototypeDefault.giants
        #expect(army == ArmyConfiguration.prototypeDefault)
    }

    @Test
    func plansRememberAdvancedTroops() throws {
        let plan = AttackPlan(
            name: "Hybrid",
            deployments: [
                DeploymentOrder(kind: .hogRider, position: position(column: 1, row: 20), deploymentTime: 0),
                DeploymentOrder(kind: .hogRider, position: position(column: 1, row: 21), deploymentTime: 0),
                DeploymentOrder(kind: .miner, position: position(column: 1, row: 22), deploymentTime: 1)
            ]
        )

        #expect(plan.armyConfiguration[troop: .hogRider] == 2)
        #expect(plan.armyConfiguration[troop: .miner] == 1)
        #expect(plan.armyConfiguration.totalTroops == 3)
    }

    @Test
    func townHall15PresetsAreValidAndJoinTheSearch() throws {
        let th15 = try rules(townHall: 15)
        let presets = ArmyConfiguration.realPresets(for: th15)

        #expect(presets.count == 6)
        for preset in presets {
            #expect(preset.configuration.isValid(under: th15), "\(preset.name)")
            #expect(preset.configuration.troopCapacityUsed(under: th15) > th15.troopCapacity - 10)
        }
        let lavaLoon = try #require(presets.first { $0.name == "LavaLoon" })
        #expect(lavaLoon.configuration[troop: .lavaHound] == 2)
        #expect(lavaLoon.configuration.balloons > 30)

        let names = ArmyCompositionSearch.variants(
            from: ArmyConfiguration.realDefault(for: th15),
            rules: th15
        ).map(\.name)
        #expect(names.contains("Elettrodraghi"))
        #expect(names.contains("Ibrido Minatori e Domatori"))

        // Root Riders arrive at Town Hall 15.
        let th14Names = ArmyConfiguration.realPresets(for: try rules(townHall: 14)).map(\.name)
        #expect(!th14Names.contains("Cavalcaradici"))
        // The prototype search keeps its original variants.
        #expect(!ArmyCompositionSearch.variants(from: .prototypeDefault).map(\.name)
            .contains("LavaLoon"))
    }

    @Test
    func realDefaultArmyIsUnchangedByTheRefactor() throws {
        let th16 = try rules(townHall: 16)
        let army = ArmyConfiguration.realDefault(for: th16)

        #expect(army.wallBreakers == 6)
        #expect(army.giants == 12)
        #expect(army.advancedTroops.isEmpty)
        #expect(army.isValid(under: th16))
    }

    @Test
    func generatedPlansDeployEveryPresetTroop() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let preset = try #require(
            ArmyConfiguration.realPresets(for: arena.armyRules)
                .first { $0.name == "Ibrido Minatori e Domatori" }
        )
        let plans = AttackPlanGenerator(
            navigationGrid: arena.navigationGrid,
            armyConfiguration: preset.configuration,
            baseEntities: arena.makeBaseEntities(layout: .fortress),
            gameData: arena.gameData,
            armyRules: arena.armyRules
        ).generate()

        let plan = try #require(plans.first)
        #expect(plan.deployments.count == preset.configuration.totalTroops)
        #expect(plan.armyConfiguration[troop: .miner] == preset.configuration[troop: .miner])
    }

    // MARK: Engine behaviour

    @Test
    func hogRidersJumpOverWallsInsteadOfBreakingThem() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        var walls: [BattleEntity] = []
        for offset in -3...3 {
            for cell in [
                GridCoordinate(column: 22, row: 25 + offset),
                GridCoordinate(column: 28, row: 25 + offset),
                GridCoordinate(column: 25 + offset, row: 22),
                GridCoordinate(column: 25 + offset, row: 28)
            ] where !walls.contains(where: {
                $0.position == grid.worldPosition(for: cell)
            }) {
                walls.append(BattleEntity(kind: .wall, position: grid.worldPosition(for: cell)))
            }
        }
        let battle = engine(
            entities: [cannon] + walls,
            deployments: [
                DeploymentOrder(kind: .hogRider, position: position(column: 15, row: 25), deploymentTime: 0)
            ],
            gameData: data
        )
        advance(battle, seconds: 6)

        let wallHitPoints = data.definition(for: .wall).maxHitPoints
        let hitCannon = try #require(battle.entities.first { $0.id == cannon.id })
        #expect(hitCannon.hitPoints < data.definition(for: .cannon).maxHitPoints)
        #expect(battle.entities.filter { $0.kind == .wall }.allSatisfy {
            $0.hitPoints == wallHitPoints
        })
    }

    @Test
    func minersStayOutOfReachUntilTheySurface() throws {
        let data = try referenceData()
        let tower = BattleEntity(kind: .archerTower, position: position(column: 30, row: 25))
        let order = DeploymentOrder(
            kind: .miner,
            position: position(column: 10, row: 25),
            deploymentTime: 0
        )
        let battle = engine(entities: [tower], deployments: [order], gameData: data)
        let minerHitPoints = data.definition(for: .miner).maxHitPoints

        advance(battle, seconds: 3.5)
        let digging = try #require(battle.entities.first { $0.id == order.entityID })
        let towerRange = data.definition(for: .archerTower).attackRange
        let gap = hypot(digging.position.x - tower.position.x, digging.position.y - tower.position.y)
        #expect(gap < towerRange)
        #expect(digging.isUnderground)
        #expect(digging.hitPoints == minerHitPoints)

        advance(battle, seconds: 6)
        let surfaced = try #require(battle.entities.first { $0.id == order.entityID })
        let hitTower = try #require(battle.entities.first { $0.id == tower.id })
        #expect(!surfaced.isUnderground)
        #expect(surfaced.hitPoints < minerHitPoints)
        #expect(hitTower.hitPoints < data.definition(for: .archerTower).maxHitPoints)
    }

    @Test
    func electroDragonLightningChainsThroughFiveBuildings() throws {
        let data = try referenceData()
        let storages = [25, 28, 31, 34, 37, 40].map {
            BattleEntity(kind: .goldStorage, position: position(column: $0, row: 25))
        }
        let battle = engine(
            entities: storages,
            deployments: [
                DeploymentOrder(kind: .electroDragon, position: position(column: 18, row: 25), deploymentTime: 0)
            ],
            gameData: data
        )
        advance(battle, seconds: 3)

        let maxHitPoints = data.definition(for: .goldStorage).maxHitPoints
        let losses = storages.map { storage in
            maxHitPoints - (battle.entities.first { $0.id == storage.id }?.hitPoints ?? 0)
        }
        #expect(isClose(losses[0], 1_435))
        for link in 1...4 {
            #expect(isClose(losses[link], 1_435 * pow(0.8, Double(link))), "link \(link)")
        }
        // The sixth building is past the fifth link.
        #expect(losses[5] == 0)
    }

    @Test
    func lavaHoundsFlyToTheAirDefenseFirst() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 15, row: 25))
        let airDefense = BattleEntity(kind: .airDefense, position: position(column: 35, row: 25))
        let order = DeploymentOrder(
            kind: .lavaHound,
            position: position(column: 10, row: 25),
            deploymentTime: 0
        )
        let battle = engine(entities: [cannon, airDefense], deployments: [order], gameData: data)
        advance(battle, seconds: 0.5)

        let hound = try #require(battle.entities.first { $0.id == order.entityID })
        #expect(hound.currentTargetID == airDefense.id)
    }
}
