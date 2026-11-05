import Foundation
import Testing
@testable import ClashAttackLabMac

struct RecallSpellTests {
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
    func recallUsesRealValues() throws {
        let data = try referenceData()
        let recall = data.spellDefinition(for: .recall)
        #expect(recall.displayName == "Richiamo")
        #expect(recall.radius == 5 * data.tileSize)
        #expect(recall.recallCapacity == 113)
        #expect(ArmyConfiguration.spellKinds.contains(.recall))

        let rules = ArmyCapacityRules.real(townHall: 17, catalog: data.catalog)
        #expect(rules.housing(for: .recall) == 2)
    }

    // MARK: Battle

    @Test
    func recalledTroopComesBackWithTheHitPointsItHadLeft() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let giant = DeploymentOrder(kind: .giant, position: position(column: 20, row: 25), deploymentTime: 0)
        // Back far from the cannon, so nothing hits it once it returns.
        let back = DeploymentOrder(
            kind: .giant,
            position: position(column: 5, row: 5),
            deploymentTime: 6,
            recalledFrom: giant.entityID
        )
        let plan = AttackPlan(
            name: "Richiamo",
            deployments: [giant, back],
            spellDeployments: [
                SpellDeploymentOrder(kind: .recall, position: position(column: 22, row: 25), deploymentTime: 4)
            ]
        )
        #expect(plan.armyConfiguration[troop: .giant] == 1)

        let run = engine([cannon, storage], plan, gameData: data)
        advance(run, seconds: 3.9)
        let before = try #require(run.entities.first { $0.id == giant.entityID })
        let full = data.definition(for: .giant).maxHitPoints
        #expect(before.hitPoints < full)

        advance(run, seconds: 1)
        #expect(!run.entities.contains { $0.id == giant.entityID })

        advance(run, seconds: 1.2)
        let returned = try #require(run.entities.first { $0.id == giant.entityID })
        #expect(returned.isAlive)
        #expect(returned.hitPoints <= before.hitPoints)
        #expect(returned.hitPoints < full)
        #expect(hypot(returned.position.x - back.position.x, returned.position.y - back.position.y) < grid.cellSize * 2)
    }

    @Test
    func recallStopsAtItsCapacityAndLeavesSiegeMachines() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let spot = position(column: 10, row: 10)
        let dragons = (0..<7).map { _ in
            DeploymentOrder(kind: .dragon, position: spot, deploymentTime: 0)
        }
        let wagon = DeploymentOrder(kind: .skyWagon, position: spot, deploymentTime: 0)
        let plan = AttackPlan(
            name: "Capienza",
            deployments: dragons + [wagon],
            spellDeployments: [SpellDeploymentOrder(kind: .recall, position: spot, deploymentTime: 0.1)]
        )
        let run = engine([storage], plan, gameData: data)
        advance(run, seconds: 0.3)

        let housing = data.definition(for: .dragon).housingSpace
        let capacity = data.spellDefinition(for: .recall).recallCapacity
        let left = run.entities.filter { $0.kind == .dragon }.count
        #expect(left == dragons.count - capacity / housing)
        #expect(run.entities.contains { $0.id == wagon.entityID })
    }

    @Test
    func instructionsSayWhenARecalledTroopComesBack() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 17))
        let base = arena.makeBaseEntities(layout: .fortress)
        let champion = DeploymentOrder(kind: .royalChampion, position: position(column: 2, row: 40), deploymentTime: 0)
        let back = DeploymentOrder(
            kind: .royalChampion,
            position: position(column: 2, row: 20),
            deploymentTime: 60,
            recalledFrom: champion.entityID
        )
        let text = PlanInstructions(
            navigationGrid: arena.navigationGrid,
            base: base,
            gameData: arena.gameData
        ).text(for: AttackPlan(name: "Richiamo", deployments: [champion, back]))

        #expect(text.contains("Campionessa reale di nuovo in campo dal Richiamo"))
    }
}
