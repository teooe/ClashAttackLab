import Foundation
import Testing
@testable import ClashAttackLabMac

/// The player's Town Hall 17 attack on the transcribed TH17 Merlin base.
struct SkyWagonStrategyTests {
    private func setup() throws -> (BattleArena, [BattleEntity], ArmyConfiguration, AttackPlan) {
        let arena = try BattleArena.make(for: .reference(townHall: 17))
        let catalog = try ReferenceGameCatalog.loadBundled()
        let layout = try #require(RealBaseLayout.bundled().first { $0.name == "TH17 Merlin" })
        let base = layout.makeEntities(navigationGrid: arena.navigationGrid, catalog: catalog)
        let army = try #require(ArmyConfiguration.playerArmy(for: arena.armyRules))
        let plan = try #require(PlayerStrategyPlanner(
            navigationGrid: arena.navigationGrid,
            latestOrderTime: BattleTiming.latestOrderTime(forBattleDuration: arena.gameData.battleDuration)
        ).plan(for: army, against: base))
        return (arena, base, army, plan)
    }

    @Test
    func theTownHall17ArmyBringsTheSkyWagonAndARecall() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 17))
        let army = try #require(ArmyConfiguration.playerArmy(for: arena.armyRules))
        #expect(army[troop: .dragon] == 10)
        #expect(army[troop: .dragonRider] == 6)
        #expect(army[troop: .babyDragon] == 2)
        #expect(army[troop: .skyWagon] == 1)
        #expect(army[troop: .logLauncher] == 0)
        #expect(army[spell: .invisibility] == 10)
        #expect(army[spell: .recall] == 1)
    }

    @Test
    func theChampionGoesForTheMonolithFromACorner() throws {
        let (arena, base, army, plan) = try setup()
        let grid = arena.navigationGrid
        let monolith = try #require(base.first { $0.kind == .monolith })
        let champion = try #require(plan.orderedDeployments.first)
        #expect(champion.kind == .royalChampion)
        #expect(plan.armyConfiguration == army)

        // A corner: close to two map edges at once.
        let cell = try #require(grid.coordinate(for: champion.position))
        let toSide = min(cell.column, grid.columns - 1 - cell.column)
        let toTop = min(cell.row, grid.rows - 1 - cell.row)
        #expect(max(toSide, toTop) <= 4, "\(cell)")

        let invisibility = plan.orderedSpellDeployments.filter { $0.kind == .invisibility }
        let last = try #require(invisibility.last)
        #expect(hypot(last.position.x - monolith.position.x, last.position.y - monolith.position.y) < grid.cellSize)
        let ability = try #require(plan.heroAbilityOrders.first { $0.entityID == champion.entityID })
        #expect(ability.activationTime >= last.deploymentTime)
    }

    @Test
    func theRecallSavesTheChampionAndSheComesBackLater() throws {
        let (_, _, _, plan) = try setup()
        let champion = try #require(plan.orderedDeployments.first { $0.kind == .royalChampion })
        let recall = try #require(plan.spellDeployments.first { $0.kind == .recall })
        #expect(recall.followsEntityID == champion.entityID)
        #expect(recall.castBelowHealthFraction == PlayerStrategyPlanner.recallHealthFraction)

        let arena = try BattleArena.make(for: .reference(townHall: 17))
        let text = PlanInstructions(
            navigationGrid: arena.navigationGrid,
            base: [],
            gameData: arena.gameData
        ).text(for: plan)
        #expect(text.contains("Richiamo su Campionessa reale quando le resta circa il 30% della vita"))
        #expect(text.contains("Campionessa reale di nuovo in campo dal Richiamo"))

        let back = try #require(plan.deployments.first { $0.recalledFrom == champion.entityID })
        let dragons = try #require(plan.orderedDeployments.first { $0.kind == .dragon })
        #expect(back.deploymentTime > dragons.deploymentTime)
    }

    @Test
    func theCastleTroopsRideTheSkyWagonWithTheArmy() throws {
        let (_, _, _, plan) = try setup()
        let wagon = try #require(plan.deployments.first { $0.kind == .skyWagon })
        let riders = plan.deployments.filter { $0.carrierID == wagon.entityID }
        #expect(riders.map(\.kind).sorted { "\($0)" < "\($1)" } == [.babyDragon, .dragon, .dragon])

        // Queen fires at once; the Duke goes with the troops and keeps his
        // ability for when he is about to fall.
        let queen = try #require(plan.deployments.first { $0.kind == .archerQueen })
        let queenAbility = try #require(plan.heroAbilityOrders.first { $0.entityID == queen.entityID })
        #expect(queenAbility.activationTime - queen.deploymentTime <= 1.5)
        let duke = try #require(plan.deployments.first { $0.kind == .dragonDuke })
        #expect(!plan.heroAbilityOrders.contains { $0.entityID == duke.entityID })
        #expect(abs(duke.deploymentTime - wagon.deploymentTime) < 10)
    }

    @Test
    func thePlanSimulates() throws {
        let (arena, base, _, plan) = try setup()
        let evaluator = AttackPlanEvaluator(
            baseEntities: base,
            gameData: arena.gameData,
            navigationGrid: arena.navigationGrid
        )
        let result = try #require(evaluator.evaluate([plan]).first)
        #expect(result.result.deployedTroops > 0)
    }

    @Test
    func aFollowingSpellLandsWhenItsTroopRunsLow() throws {
        let data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 17)
        )
        let grid = RealBattleMap.makeNavigationGrid()
        func position(_ column: Int, _ row: Int) -> WorldPosition {
            grid.worldPosition(for: GridCoordinate(column: column, row: row))
        }
        let cannon = BattleEntity(kind: .cannon, position: position(25, 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(40, 40))
        let giant = DeploymentOrder(kind: .giant, position: position(20, 25), deploymentTime: 0)
        let recall = SpellDeploymentOrder(
            kind: .recall,
            position: position(2, 2),
            deploymentTime: 170,
            followsEntityID: giant.entityID,
            castBelowHealthFraction: 0.95
        )
        let engine = SimulationEngine(
            entities: [cannon, storage],
            attackPlan: AttackPlan(name: "Segui", deployments: [giant], spellDeployments: [recall]),
            gameData: data,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<(8 * 60) {
            engine.advance(by: 1.0 / 60.0)
        }
        // Cast long before its time, on the giant wherever it was.
        #expect(engine.pendingSpellCount == 0)
        #expect(!engine.entities.contains { $0.id == giant.entityID })
    }
}
