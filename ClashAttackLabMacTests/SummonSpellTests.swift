import Foundation
import Testing
@testable import ClashAttackLabMac

struct SummonSpellTests {
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
        spells: [SpellDeploymentOrder],
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Evocazione", deployments: [], spellDeployments: spells),
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
    func townHall15SpellsSummonTheRealNumberOfTroops() throws {
        let data = try referenceData()
        let skeletons = data.spellDefinition(for: .skeletonSpell)
        let bats = data.spellDefinition(for: .batSpell)

        #expect(skeletons.summonedTroop == .skeleton)
        #expect(skeletons.summonCount == 19)
        #expect(bats.summonedTroop == .bat)
        #expect(bats.summonCount == 22)
        #expect(data.definition(for: .bat).movementDomain == .air)
        #expect(data.definition(for: .bat).resourceDamageMultiplier == 0.4)
        #expect(data.definition(for: .skeleton).ignoresTraps)

        let rules = ArmyCapacityRules.real(townHall: 15, catalog: data.catalog)
        #expect(rules.allows(.skeletonSpell))
        #expect(rules.allows(.batSpell))
        #expect(rules.housing(for: .batSpell) == 1)
        for kind in [BattleEntityKind.skeleton, .bat] {
            #expect(BattleEntityKind.spawnedTroops.contains(kind))
            #expect(!ArmyConfiguration.troopKinds.contains(kind))
        }
    }

    @Test
    func skeletonsAppearWhereTheSpellLandsAndAttack() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
        let spell = SpellDeploymentOrder(kind: .skeletonSpell, position: position(column: 21, row: 25), deploymentTime: 0)
        let engine = run([storage], spells: [spell], gameData: data, seconds: 4)

        let skeletons = engine.entities.filter { $0.kind == .skeleton }
        #expect(skeletons.count == 19)
        #expect(Set(skeletons.map(\.id)).count == 19)
        #expect(engine.deployedTroopCount == 19)
        let hit = try #require(engine.entities.first { $0.id == storage.id })
        #expect(hit.hitPoints < data.definition(for: .goldStorage).maxHitPoints)
    }

    @Test
    func summonedTroopsDoNotSetOffTraps() throws {
        let data = try referenceData()
        let bomb = BattleEntity(kind: .bomb, position: position(column: 22, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
        let spell = SpellDeploymentOrder(kind: .skeletonSpell, position: position(column: 21, row: 25), deploymentTime: 0)
        let engine = run([bomb, storage], spells: [spell], gameData: data, seconds: 3)

        let trap = try #require(engine.entities.first { $0.id == bomb.id })
        #expect(trap.isAlive)
        #expect(engine.entities.filter { $0.kind == .skeleton && $0.isAlive }.count == 19)
    }

    @Test
    func batsHurtResourcesLess() throws {
        let data = try referenceData()
        func storageLoss(multiplier: Double?) throws -> Double {
            struct Tweaked: GameDataProviding {
                let base: ReferenceGameData
                let multiplier: Double?
                func definition(for kind: BattleEntityKind) -> CombatDefinition {
                    var definition = base.definition(for: kind)
                    if kind == .bat, let multiplier {
                        definition.resourceDamageMultiplier = multiplier
                    }
                    return definition
                }
                func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
                    base.spellDefinition(for: kind)
                }
                var battleDuration: TimeInterval { base.battleDuration }
            }
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
            let spell = SpellDeploymentOrder(kind: .batSpell, position: position(column: 21, row: 25), deploymentTime: 0)
            let engine = run([storage], spells: [spell], gameData: Tweaked(base: data, multiplier: multiplier), seconds: 3)
            let hit = try #require(engine.entities.first { $0.id == storage.id })
            return data.definition(for: .goldStorage).maxHitPoints - hit.hitPoints
        }
        let real = try storageLoss(multiplier: nil)
        let full = try storageLoss(multiplier: 1)
        #expect(real > 0)
        #expect(abs(real - full * 0.4) < 1e-6)
    }
}
