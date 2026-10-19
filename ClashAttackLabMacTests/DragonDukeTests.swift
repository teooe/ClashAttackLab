import Foundation
import Testing
@testable import ClashAttackLabMac

struct DragonDukeTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData(
        equipment: [BattleEntityKind: [HeroEquipmentKind]] = [:]
    ) throws -> ReferenceGameData {
        var data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        data.heroEquipment = equipment
        return data
    }

    private func run(
        _ entities: [BattleEntity],
        _ deployments: [DeploymentOrder],
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Duca", deployments: deployments),
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
    func townHall15DukeUsesTheRealValues() throws {
        let data = try referenceData()
        let duke = data.definition(for: .dragonDuke)

        #expect(duke.maxHitPoints == 9_775)
        #expect(duke.attackDamage == 408)
        #expect(duke.movementDomain == .air)
        #expect(duke.attackRange == 1.25 * 40)
        #expect(BattleEntityKind.dragonDuke.isHero)

        let rules = ArmyCapacityRules.real(townHall: 15, catalog: data.catalog)
        #expect(rules.allows(.dragonDuke))
        #expect(rules.housing(for: .dragonDuke) == 0)
        #expect(!ArmyCapacityRules.real(townHall: 14, catalog: data.catalog).allows(.dragonDuke))
    }

    @Test
    func fireHeartAndRevengeDeckEquipTheDuke() throws {
        let plain = try referenceData().definition(for: .dragonDuke)
        let data = try referenceData(equipment: [.dragonDuke: [.fireHeart, .revengeDeck]])
        let duke = data.definition(for: .dragonDuke)

        #expect(duke.maxHitPoints > plain.maxHitPoints)
        #expect(duke.passiveHealingPerSecond > 0)
        #expect(duke.destructionDamage == 3_000)
        #expect(duke.destructionRadius == 4 * 40)
        #expect(duke.counterDamage > 0)
        #expect(duke.counterRange == 25 * 40)
        #expect(duke.counterCooldown == 0.8)
        #expect(HeroEquipmentKind.defaultLoadouts[.dragonDuke] == [.fireHeart, .revengeDeck])
    }

    @Test
    func theRevengeDeckHitsBackAtShootingDefenses() throws {
        func defenseLoss(deck: Bool) throws -> Double {
            let data = try referenceData(equipment: deck ? [.dragonDuke: [.revengeDeck]] : [:])
            // The Air Defense shoots the Duke from out of his reach.
            let airDefense = BattleEntity(kind: .airDefense, position: position(column: 25, row: 25))
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 10))
            let duke = DeploymentOrder(kind: .dragonDuke, position: position(column: 25, row: 17), deploymentTime: 0)
            let engine = run([airDefense, storage], [duke], gameData: data, seconds: 3)
            let hit = try #require(engine.entities.first { $0.id == airDefense.id })
            return data.definition(for: .airDefense).maxHitPoints - hit.hitPoints
        }
        #expect(try defenseLoss(deck: false) == 0)
        #expect(try defenseLoss(deck: true) > 0)
    }

    @Test
    func aLonelyBabyDragonThrowsATantrum() throws {
        let data = try referenceData()
        let baby = data.definition(for: .babyDragon)
        #expect(baby.tantrumDamageMultiplier == 2)
        #expect(baby.tantrumRadius > 0)
        #expect(baby.movementDomain == .air)

        func storageLoss(withCompany: Bool) throws -> Double {
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
            var deployments = [
                DeploymentOrder(kind: .babyDragon, position: position(column: 21, row: 25), deploymentTime: 0)
            ]
            if withCompany {
                // A Balloon keeps it calm but cannot reach the storage in time.
                deployments.append(
                    DeploymentOrder(kind: .balloon, position: position(column: 19, row: 25), deploymentTime: 0)
                )
            }
            let engine = run([storage], deployments, gameData: data, seconds: 1.5)
            let hit = try #require(engine.entities.first { $0.id == storage.id })
            return data.definition(for: .goldStorage).maxHitPoints - hit.hitPoints
        }
        let calm = try storageLoss(withCompany: true)
        let angry = try storageLoss(withCompany: false)
        #expect(calm > 0)
        #expect(angry > calm)
    }
}
