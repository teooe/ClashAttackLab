import Foundation
import Testing
@testable import ClashAttackLabMac

/// Real data with one kind brought down to 1 hit point.
private struct FrailData: GameDataProviding {
    let base: ReferenceGameData
    let frail: BattleEntityKind

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        var definition = base.definition(for: kind)
        if kind == frail {
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

struct PetTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData(
        pets: [BattleEntityKind: BattleEntityKind] = [:],
        equipment: [BattleEntityKind: [HeroEquipmentKind]] = [:]
    ) throws -> ReferenceGameData {
        var data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        data.heroPets = pets
        data.heroEquipment = equipment
        return data
    }

    private func run(
        _ entities: [BattleEntity],
        _ deployments: [DeploymentOrder],
        abilities: [HeroAbilityOrder] = [],
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Famigli", deployments: deployments, heroAbilityOrders: abilities),
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
    func townHall15PetsUseTheRealValues() throws {
        let data = try referenceData()
        #expect(data.definition(for: .frosty).maxHitPoints == 3_300)
        #expect(data.definition(for: .frosty).attackDamage == 156)
        #expect(data.definition(for: .phoenix).reviveDuration == 8)
        #expect(data.definition(for: .electroOwl).chainTargetCount == 2)
        #expect(abs(data.definition(for: .electroOwl).chainDamageMultiplier - 0.8) < 1e-9)
        #expect(data.definition(for: .unicorn).heroHealingPerSecond == 70)
        #expect(data.definition(for: .healer).healingPerSecond == 76)
        #expect(data.definition(for: .healer).heroHealingPerSecond == 68)
        for pet in BattleEntityKind.petKinds {
            #expect(data.definition(for: pet).followsOwner, "\(pet)")
            #expect(!ArmyConfiguration.troopKinds.contains(pet))
        }
        #expect(BattleEntityKind.defaultPets[.archerQueen] == .frosty)
    }

    @Test
    func petsComeOutWithTheirHero() throws {
        let data = try referenceData(pets: [.royalChampion: .unicorn])
        #expect(data.definition(for: .royalChampion).pet == .unicorn)
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 30, row: 25))
        let champion = DeploymentOrder(kind: .royalChampion, position: position(column: 20, row: 25), deploymentTime: 0)
        let engine = run([storage], [champion], gameData: data, seconds: 0.2)

        let unicorn = try #require(engine.entities.first { $0.kind == .unicorn })
        #expect(unicorn.ownerID == champion.entityID)
        #expect(engine.deployedTroopCount == 2)
    }

    @Test
    func theUnicornHealsItsHero() throws {
        func championHitPoints(unicorn: Bool) throws -> Double {
            let data = try referenceData(pets: unicorn ? [.royalChampion: .unicorn] : [:])
            let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
            let champion = DeploymentOrder(kind: .royalChampion, position: position(column: 19, row: 25), deploymentTime: 0)
            let engine = run([cannon], [champion], gameData: data, seconds: 4)
            return try #require(engine.entities.first { $0.id == champion.entityID }).hitPoints
        }
        #expect(try championHitPoints(unicorn: true) > championHitPoints(unicorn: false))
    }

    @Test
    func theOwlStrikesWhatItsHeroAttacks() throws {
        func storageLoss(owl: Bool) throws -> Double {
            let data = try referenceData(pets: owl ? [.grandWarden: .electroOwl] : [:])
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
            let warden = DeploymentOrder(kind: .grandWarden, position: position(column: 20, row: 25), deploymentTime: 0)
            let engine = run([storage], [warden], gameData: data, seconds: 3)
            let hit = try #require(engine.entities.first { $0.id == storage.id })
            return data.definition(for: .goldStorage).maxHitPoints - hit.hitPoints
        }
        #expect(try storageLoss(owl: true) > storageLoss(owl: false))
    }

    @Test
    func thePhoenixSavesItsHeroOnce() throws {
        func dukeSurvives(phoenix: Bool) throws -> (alive: Bool, hatched: Bool) {
            let base = try referenceData(pets: phoenix ? [.dragonDuke: .phoenix] : [:])
            let data = FrailData(base: base, frail: .dragonDuke)
            let airDefense = BattleEntity(kind: .airDefense, position: position(column: 25, row: 25))
            let duke = DeploymentOrder(kind: .dragonDuke, position: position(column: 19, row: 25), deploymentTime: 0)
            let engine = run([airDefense], [duke], gameData: data, seconds: 2)
            let hero = try #require(engine.entities.first { $0.id == duke.entityID })
            let hatched = engine.entities.contains { $0.kind == .phoenix && !$0.isDormant }
            return (hero.isAlive, hatched)
        }
        let saved = try dukeSurvives(phoenix: true)
        #expect(saved.alive)
        #expect(saved.hatched)
        #expect(try !dukeSurvives(phoenix: false).alive)
    }

    @Test
    func theHealerPuppetSummonsHealersForTheQueen() throws {
        let data = try referenceData(equipment: [.archerQueen: [.healerPuppet]])
        let puppet = try #require(data.definition(for: .archerQueen).heroAbility)
        #expect(puppet.summonedTroop == .healer)
        #expect(puppet.summonCount == 3)

        let storage = BattleEntity(kind: .goldStorage, position: position(column: 30, row: 25))
        let queen = DeploymentOrder(kind: .archerQueen, position: position(column: 20, row: 25), deploymentTime: 0)
        let engine = run(
            [storage],
            [queen],
            abilities: [HeroAbilityOrder(entityID: queen.entityID, activationTime: 0.1)],
            gameData: data,
            seconds: 0.5
        )
        let healers = engine.entities.filter { $0.kind == .healer }
        #expect(healers.count == 3)
        #expect(healers.allSatisfy { $0.ownerID == queen.entityID })
    }
}
