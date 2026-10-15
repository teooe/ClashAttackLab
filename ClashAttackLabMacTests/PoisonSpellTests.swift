import Foundation
import Testing
@testable import ClashAttackLabMac

struct PoisonSpellTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData(troops: [BattleEntityKind]? = nil) throws -> ReferenceGameData {
        var data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        data.clanCastleTroops = troops
        return data
    }

    @Test
    func townHall15PoisonUsesTheRealValues() throws {
        let poison = try referenceData().spellDefinition(for: .poison)

        #expect(poison.defenderDamagePerSecond == 320)
        #expect(abs(poison.defenderSpeedMultiplier - 0.52) < 1e-9)
        #expect(abs(poison.defenderAttackSpeedMultiplier - 0.3) < 1e-9)
        #expect(poison.radius == 4 * 40)
        #expect(poison.duration == 16)
        #expect(!poison.boostsTroops)
        #expect(!poison.dealsInstantDamage)
    }

    @Test
    func cloudDamageGrowsUntilItIsFull() throws {
        let poison = try referenceData().spellDefinition(for: .poison)
        let ramp = poison.defenderDamageRampTime

        #expect(ramp > 0)
        #expect(poison.defenderDamagePerSecond(atAge: 0) == 0)
        #expect(abs(poison.defenderDamagePerSecond(atAge: ramp / 2) - 160) < 1e-9)
        #expect(poison.defenderDamagePerSecond(atAge: ramp * 3) == 320)
    }

    @Test
    func realArmiesBringOnePoison() throws {
        let rules = ArmyCapacityRules.real(
            townHall: 15,
            catalog: try ReferenceGameCatalog.loadBundled()
        )
        let army = ArmyConfiguration.realDefault(for: rules)

        #expect(rules.allows(.poison))
        #expect(army[spell: .poison] == 1)
        #expect(army.isValid(under: rules))
        #expect(ArmyConfiguration.prototypeDefault[spell: .poison] == 0)
    }

    @Test
    func poisonHurtsAndSlowsOnlyTheReinforcements() throws {
        let data = try referenceData(troops: Array(repeating: .barbarian, count: 4))
        let castle = BattleEntity(kind: .clanCastle, position: position(column: 25, row: 25))

        func battle(poisoned: Bool) throws -> (defenderLoss: Double, giantLoss: Double) {
            let giant = DeploymentOrder(kind: .giant, position: position(column: 21, row: 25), deploymentTime: 0)
            let spells = poisoned
                ? [SpellDeploymentOrder(kind: .poison, position: castle.position, deploymentTime: 0)]
                : []
            let engine = SimulationEngine(
                entities: [castle],
                attackPlan: AttackPlan(name: "Veleno", deployments: [giant], spellDeployments: spells),
                gameData: data,
                navigationGrid: grid
            )
            engine.start()
            for _ in 0..<(60 * 4) {
                engine.advance(by: 1.0 / 60.0)
            }
            let barbarian = data.definition(for: .barbarian).maxHitPoints
            let defenderLoss = engine.entities.filter(\.isDefender).reduce(0) {
                $0 + (barbarian - $1.hitPoints)
            }
            let survivor = try #require(engine.entities.first { $0.id == giant.entityID })
            return (defenderLoss, data.definition(for: .giant).maxHitPoints - survivor.hitPoints)
        }

        let clean = try battle(poisoned: false)
        let poisoned = try battle(poisoned: true)
        // Giants ignore reinforcements, so only the cloud hurts them.
        #expect(clean.defenderLoss == 0)
        #expect(poisoned.defenderLoss > 0)
        // Slower Barbarians hit the Giant less.
        #expect(clean.giantLoss > 0)
        #expect(poisoned.giantLoss < clean.giantLoss)
    }

    @Test
    func generatedPlansDropThePoisonOnTheClanCastle() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let base = arena.makeBaseEntities(layout: .fortress)
        let castle = try #require(base.first { $0.kind == .clanCastle })
        let plan = try #require(AttackPlanGenerator(
            navigationGrid: arena.navigationGrid,
            armyConfiguration: arena.defaultArmy,
            baseEntities: base,
            gameData: arena.gameData,
            armyRules: arena.armyRules
        ).generate().first)
        let poison = try #require(plan.spellDeployments.first { $0.kind == .poison })

        #expect(poison.position == castle.position)
    }
}

struct FrozenReinforcementTests {
    @Test
    func freezeStopsTheReinforcementsToo() throws {
        let grid = RealBattleMap.makeNavigationGrid()
        var data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        data.clanCastleTroops = Array(repeating: .barbarian, count: 4)
        let castle = BattleEntity(
            kind: .clanCastle,
            position: grid.worldPosition(for: GridCoordinate(column: 25, row: 25))
        )

        func giantLoss(frozen: Bool) throws -> Double {
            let giant = DeploymentOrder(
                kind: .giant,
                position: grid.worldPosition(for: GridCoordinate(column: 21, row: 25)),
                deploymentTime: 0
            )
            let spells = frozen
                ? [SpellDeploymentOrder(kind: .freeze, position: castle.position, deploymentTime: 0)]
                : []
            let engine = SimulationEngine(
                entities: [castle],
                attackPlan: AttackPlan(name: "Gelo", deployments: [giant], spellDeployments: spells),
                gameData: data,
                navigationGrid: grid
            )
            engine.start()
            for _ in 0..<(60 * 3) {
                engine.advance(by: 1.0 / 60.0)
            }
            let survivor = try #require(engine.entities.first { $0.id == giant.entityID })
            return data.definition(for: .giant).maxHitPoints - survivor.hitPoints
        }

        #expect(data.spellDefinition(for: .freeze).duration > 3)
        #expect(try giantLoss(frozen: false) > 0)
        #expect(try giantLoss(frozen: true) == 0)
    }
}
