import Foundation
import Testing
@testable import ClashAttackLabMac

struct OvergrowthAndIceBlockTests {
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
        spells: [SpellDeploymentOrder],
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Prova", deployments: deployments, spellDeployments: spells),
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
        return engine
    }

    @Test
    func townHall15SpellsUseTheRealValues() throws {
        let data = try referenceData()
        let overgrowth = data.spellDefinition(for: .overgrowth)
        let ice = data.spellDefinition(for: .iceBlock)

        #expect(overgrowth.entanglesBuildings)
        #expect(overgrowth.radius == 6 * 40)
        #expect(overgrowth.duration == 24)
        #expect(ice.encasesTroops)
        #expect(abs(ice.troopDamageReduction - 0.9) < 1e-9)
        #expect(ice.duration == 7)
        #expect(ice.radius == 5 * 40)

        let rules = ArmyCapacityRules.real(townHall: 15, catalog: data.catalog)
        #expect(rules.allows(.overgrowth))
        #expect(rules.allows(.iceBlock))
        #expect(rules.housing(for: .overgrowth) == 2)
    }

    @Test
    func overgrowthSilencesDefensesAndHidesThem() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 38))

        func battle(overgrown: Bool) throws -> (giantLoss: Double, cannonLoss: Double) {
            let giant = DeploymentOrder(kind: .giant, position: position(column: 20, row: 25), deploymentTime: 0)
            let spells = overgrown
                ? [SpellDeploymentOrder(kind: .overgrowth, position: cannon.position, deploymentTime: 0)]
                : []
            let engine = run([cannon, storage], [giant], spells: spells, gameData: data, seconds: 5)
            let walker = try #require(engine.entities.first { $0.id == giant.entityID })
            let gun = try #require(engine.entities.first { $0.id == cannon.id })
            return (
                data.definition(for: .giant).maxHitPoints - walker.hitPoints,
                data.definition(for: .cannon).maxHitPoints - gun.hitPoints
            )
        }

        let open = try battle(overgrown: false)
        let trapped = try battle(overgrown: true)
        #expect(open.giantLoss > 0)
        #expect(open.cannonLoss > 0)
        // The trapped Cannon neither shoots nor gets hit.
        #expect(trapped.giantLoss == 0)
        #expect(trapped.cannonLoss == 0)
    }

    @Test
    func iceBlockHoldsTroopsAndStopsMostDamage() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))

        func battle(iced: Bool) throws -> (loss: Double, moved: Double) {
            let start = position(column: 19, row: 25)
            let giant = DeploymentOrder(kind: .giant, position: start, deploymentTime: 0)
            let spells = iced
                ? [SpellDeploymentOrder(kind: .iceBlock, position: start, deploymentTime: 0)]
                : []
            let engine = run([cannon], [giant], spells: spells, gameData: data, seconds: 3)
            let walker = try #require(engine.entities.first { $0.id == giant.entityID })
            return (
                data.definition(for: .giant).maxHitPoints - walker.hitPoints,
                hypot(walker.position.x - start.x, walker.position.y - start.y)
            )
        }

        let plain = try battle(iced: false)
        let iced = try battle(iced: true)
        #expect(plain.moved > 0)
        #expect(iced.moved == 0)
        #expect(plain.loss > 0)
        #expect(iced.loss < plain.loss)
    }

    @Test
    func plansSmotherTheStrongestDefenseWithOvergrowth() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let base = arena.makeBaseEntities(layout: .fortress)
        let eagle = try #require(base.first { $0.kind == .eagleArtillery })
        var army = arena.defaultArmy
        army[spell: .rage] -= 1
        army[spell: .overgrowth] = 1
        #expect(army.isValid(under: arena.armyRules))
        let plan = try #require(AttackPlanGenerator(
            navigationGrid: arena.navigationGrid,
            armyConfiguration: army,
            baseEntities: base,
            gameData: arena.gameData,
            armyRules: arena.armyRules
        ).generate().first)
        let overgrowth = try #require(plan.spellDeployments.first { $0.kind == .overgrowth })

        #expect(overgrowth.position == eagle.position)
        #expect(AttackPlanGenerator.overgrowthTarget(in: base)?.id == eagle.id)
    }
}
