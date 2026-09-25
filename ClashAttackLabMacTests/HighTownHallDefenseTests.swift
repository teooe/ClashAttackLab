import Foundation
import Testing
@testable import ClashAttackLabMac

struct HighTownHallDefenseTests {
    private func referenceData(townHall: Int) throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: townHall)
        )
    }

    private func isClose(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 1e-6
    }

    private var grid: NavigationGrid {
        RealBattleMap.makeNavigationGrid()
    }

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func offset(_ base: WorldPosition, x: Double) -> WorldPosition {
        WorldPosition(x: base.x + x, y: base.y)
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

    // MARK: Real values

    @Test
    func townHall15DefensesUseRealValues() throws {
        let data = try referenceData(townHall: 15)
        let xBow = data.definition(for: .xBow)
        let eagle = data.definition(for: .eagleArtillery)
        let scattershot = data.definition(for: .scattershot)
        let monolith = data.definition(for: .monolith)
        let spellTower = data.definition(for: .spellTower)

        #expect(xBow.role == .defense)
        #expect(xBow.maxHitPoints == 4_400)
        #expect(xBow.attackDamage == 26.24)
        #expect(xBow.attackInterval == 0.128)
        #expect(xBow.attackRange == 11.5 * 40)
        #expect(xBow.attackTargetLayer == .both)
        #expect(xBow.footprintSize == 4 * 40)

        #expect(eagle.maxHitPoints == 5_900)
        #expect(eagle.attackDamage == 475)
        #expect(eagle.minimumAttackRange == 7 * 40)
        #expect(eagle.attackRange == 50 * 40)
        #expect(eagle.splashRadius == 0.75 * 40)
        #expect(eagle.burstShotCount == 3)
        #expect(eagle.burstReloadTime == 10)
        #expect(eagle.activationDeployedHousing == 200)

        #expect(scattershot.maxHitPoints == 5_100)
        #expect(scattershot.attackDamage == 560)
        #expect(scattershot.minimumAttackRange == 3 * 40)
        #expect(scattershot.attackRange == 10 * 40)
        #expect(scattershot.splashRadius > 0)

        #expect(monolith.maxHitPoints == 5_050)
        #expect(monolith.attackDamage == 262.5)
        #expect(isClose(monolith.targetMaxHitPointDamageFraction, 0.12))
        #expect(monolith.attackRange == 11 * 40)

        #expect(spellTower.role == .defense)
        #expect(spellTower.maxHitPoints == 3_100)
        #expect(spellTower.attackDamage == 0)
        #expect(spellTower.countsForDestruction)
    }

    @Test
    func townHall15TrapsUseRealValues() throws {
        let data = try referenceData(townHall: 15)
        let bomb = data.definition(for: .bomb)
        let spring = data.definition(for: .springTrap)
        let mine = data.definition(for: .seekingAirMine)

        #expect(bomb.role == .trap)
        #expect(bomb.destructionDamage == 155)
        #expect(bomb.destructionRadius == 3 * 40)
        #expect(bomb.activationRange == 1.5 * 40)
        #expect(bomb.trapEffect == .explosion)

        #expect(spring.destructionDamage == 1_050)
        #expect(spring.activationRange == 40)
        #expect(spring.trapEffect == .spring(capacity: 18))
        #expect(spring.destructionTargetLayer == .ground)

        #expect(mine.destructionDamage == 2_800)
        #expect(mine.activationRange == 4 * 40)
        #expect(mine.trapEffect == .strike)
        #expect(mine.destructionTargetLayer == .air)
        #expect(mine.footprintSize == 0)
        for kind: BattleEntityKind in [.bomb, .springTrap, .seekingAirMine] {
            #expect(kind.isTrap)
        }
    }

    @Test
    func builderHutsArmFromTownHall14() throws {
        let armed = try referenceData(townHall: 15).definition(for: .builderHut)
        let unarmed = try referenceData(townHall: 13).definition(for: .builderHut)

        #expect(armed.role == .defense)
        #expect(armed.attackDamage == 54)
        #expect(armed.attackRange == 7 * 40)
        #expect(armed.attackInterval == 0.4)
        #expect(unarmed.role == .building)
        #expect(unarmed.attackDamage == 0)
    }

    @Test
    func troopsCarryHousingSpaceAndHeroesWeighTwentyFive() throws {
        let data = try referenceData(townHall: 15)

        #expect(data.definition(for: .giant).housingSpace == 5)
        #expect(data.definition(for: .balloon).housingSpace == 5)
        #expect(data.definition(for: .barbarianKing).housingSpace == 25)
        #expect(data.definition(for: .archerQueen).housingSpace == 25)
    }

    // MARK: Engine behaviour

    private func eagleBattle(giants: Int) throws -> (SimulationEngine, BattleEntity) {
        let data = try referenceData(townHall: 15)
        let eagle = BattleEntity(
            kind: .eagleArtillery,
            position: position(column: 32, row: 25)
        )
        let start = position(column: 12, row: 25)
        let deployments = (0..<giants).map { _ in
            DeploymentOrder(kind: .giant, position: start, deploymentTime: 0)
        }
        return (engine(entities: [eagle], deployments: deployments, gameData: data), eagle)
    }

    @Test
    func eagleArtilleryWaitsForTwoHundredHousingSpace() throws {
        let (quiet, quietEagle) = try eagleBattle(giants: 39)
        advance(quiet, seconds: 3)

        #expect(quiet.deployedHousingSpace == 195)
        #expect(!quiet.projectiles.contains { $0.sourceEntityID == quietEagle.id })
        let idle = try #require(quiet.entities.first { $0.id == quietEagle.id })
        #expect(idle.attackCooldown == 0)
        #expect(idle.lastAttackedTargetID == nil)

        let (awake, eagle) = try eagleBattle(giants: 40)
        advance(awake, seconds: 0.1)

        #expect(awake.deployedHousingSpace == 200)
        #expect(awake.projectiles.contains { $0.sourceEntityID == eagle.id })

        // Three shells go out 0.75 s apart, then the long reload starts.
        advance(awake, seconds: 2.9)
        let reloading = try #require(awake.entities.first { $0.id == eagle.id })
        #expect(reloading.attackCooldown > 8)
        #expect(reloading.burstShotsFired == 0)
    }

    @Test
    func monolithAddsAShareOfTheTargetsMaximumHitPoints() throws {
        let data = try referenceData(townHall: 15)
        let monolith = BattleEntity(
            kind: .monolith,
            position: position(column: 25, row: 25)
        )
        let battle = engine(
            entities: [monolith],
            deployments: [
                DeploymentOrder(
                    kind: .giant,
                    position: position(column: 20, row: 25),
                    deploymentTime: 0
                )
            ],
            gameData: data
        )
        advance(battle, seconds: 0.5)

        let giantHitPoints = data.definition(for: .giant).maxHitPoints
        let giant = try #require(battle.entities.first { $0.kind == .giant })
        #expect(isClose(
            giantHitPoints - giant.hitPoints,
            262.5 + 0.12 * giantHitPoints
        ))
    }

    @Test
    func seekingAirMineHitsOnlyTheNearestAirTroop() throws {
        let data = try referenceData(townHall: 15)
        let minePosition = position(column: 20, row: 25)
        let mine = BattleEntity(kind: .seekingAirMine, position: minePosition)
        let storage = BattleEntity(
            kind: .goldStorage,
            position: position(column: 40, row: 25)
        )
        let near = DeploymentOrder(
            kind: .balloon,
            position: offset(minePosition, x: -60),
            deploymentTime: 0
        )
        let far = DeploymentOrder(
            kind: .balloon,
            position: offset(minePosition, x: -100),
            deploymentTime: 0
        )
        let battle = engine(
            entities: [mine, storage],
            deployments: [near, far],
            gameData: data
        )
        battle.advance(by: 1.0 / 60.0)

        let balloonHitPoints = data.definition(for: .balloon).maxHitPoints
        let hitBalloon = try #require(battle.entities.first { $0.id == near.entityID })
        let spared = try #require(battle.entities.first { $0.id == far.entityID })
        let triggered = try #require(battle.entities.first { $0.id == mine.id })

        #expect(!triggered.isAlive)
        #expect(hitBalloon.hitPoints == max(0, balloonHitPoints - 2_800))
        #expect(spared.hitPoints == balloonHitPoints)
    }

    @Test
    func springTrapThrowsTroopsUpToItsCapacityAndSparesHeroes() throws {
        let data = try referenceData(townHall: 15)
        let trapPosition = position(column: 20, row: 25)
        let spring = BattleEntity(kind: .springTrap, position: trapPosition)
        let storage = BattleEntity(
            kind: .goldStorage,
            position: position(column: 40, row: 25)
        )
        let giants = [4.0, 8, 12, 16].map {
            DeploymentOrder(
                kind: .giant,
                position: offset(trapPosition, x: -$0),
                deploymentTime: 0
            )
        }
        let king = DeploymentOrder(
            kind: .barbarianKing,
            position: offset(trapPosition, x: -6),
            deploymentTime: 0
        )
        let battle = engine(
            entities: [spring, storage],
            deployments: giants + [king],
            gameData: data
        )
        battle.advance(by: 1.0 / 60.0)

        func hitPoints(of order: DeploymentOrder) -> Double? {
            battle.entities.first { $0.id == order.entityID }?.hitPoints
        }
        let giantHitPoints = data.definition(for: .giant).maxHitPoints

        // Three Giants (15 housing space) fit in the capacity of 18.
        for thrown in giants.prefix(3) {
            #expect(hitPoints(of: thrown) == 0)
        }
        // The fourth no longer fits and takes the trap damage instead.
        let heavy = try #require(hitPoints(of: giants[3]))
        #expect(isClose(heavy, giantHitPoints - 1_050))
        #expect(
            hitPoints(of: king) ==
                data.definition(for: .barbarianKing).maxHitPoints
        )
    }

    @Test
    func townHall15BasesHoldTheNewDefensesAndTraps() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        for layout in PrototypeBaseLayout.allCases {
            let kinds = arena.makeBaseEntities(layout: layout).map(\.kind)
            #expect(kinds.filter { $0 == .xBow }.count == 4)
            #expect(kinds.filter { $0 == .eagleArtillery }.count == 1)
            #expect(kinds.filter { $0 == .scattershot }.count == 2)
            #expect(kinds.filter { $0 == .spellTower }.count == 2)
            #expect(kinds.filter { $0 == .monolith }.count == 1)
            #expect(kinds.filter { $0 == .springTrap }.count == 9)
            #expect(kinds.filter { $0 == .seekingAirMine }.count == 8)
            #expect(kinds.filter { $0 == .bomb }.count == 8)
        }
    }
}
