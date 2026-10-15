import Foundation
import Testing
@testable import ClashAttackLabMac

struct HeroEquipmentTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func catalog() throws -> ReferenceGameCatalog {
        try ReferenceGameCatalog.loadBundled()
    }

    private func referenceData(
        equipment: [BattleEntityKind: [HeroEquipmentKind]] = [:]
    ) throws -> ReferenceGameData {
        var data = ReferenceGameData(
            catalog: try catalog(),
            profile: ReferenceLevelProfile(townHall: 15)
        )
        data.heroEquipment = equipment
        return data
    }

    private func stats(_ piece: HeroEquipmentKind, in data: ReferenceGameData) throws -> ReferenceEquipmentLevel {
        let entry = try #require(data.catalog.equipment?[piece.referenceKey])
        return try #require(entry.stats(atLevel: data.equipmentLevel(of: piece, entry: entry)))
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
            attackPlan: AttackPlan(
                name: "Equipaggiamento",
                deployments: deployments,
                heroAbilityOrders: abilities
            ),
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
        return engine
    }

    // MARK: Catalog

    @Test
    func everyPieceIsInTheCatalogForItsHero() throws {
        let catalog = try catalog()
        for piece in HeroEquipmentKind.allCases {
            let entry = try #require(catalog.equipment?[piece.referenceKey], "\(piece)")
            #expect(entry.hero == piece.hero.referenceKey, "\(piece)")
            #expect(!entry.levels.isEmpty)
        }
        for (hero, pieces) in HeroEquipmentKind.defaultLoadouts {
            #expect(pieces.count == HeroEquipmentKind.piecesPerHero)
            #expect(pieces.allSatisfy { $0.hero == hero })
        }
    }

    @Test
    func theBlacksmithCapsLevelsAtTownHall15() throws {
        let data = try referenceData()
        let caps = try #require(data.catalog.equipmentLevelCaps)
        #expect(caps.cap(epic: false, townHall: 15) == 18)
        #expect(caps.cap(epic: true, townHall: 15) == 24)

        let gauntlet = try #require(data.catalog.equipment?["giantGauntlet"])
        let tome = try #require(data.catalog.equipment?["eternalTome"])
        #expect(data.equipmentLevel(of: .giantGauntlet, entry: gauntlet) == 24)
        #expect(data.equipmentLevel(of: .eternalTome, entry: tome) == 18)

        var profile = ReferenceLevelProfile(townHall: 15)
        profile.equipmentLevels[.giantGauntlet] = 10
        let chosen = ReferenceGameData(catalog: data.catalog, profile: profile)
        #expect(chosen.equipmentLevel(of: .giantGauntlet, entry: gauntlet) == 10)
    }

    @Test
    func missingFieldsKeepTheLastListedValue() throws {
        let entry = try #require(try catalog().equipment?["spikyBall"])
        let listed = entry.levels.filter { $0.hitpointIncrease != nil }
        let gap = try #require(entry.levels.first { level in
            level.hitpointIncrease == nil && listed.contains { $0.level < level.level }
        })
        let previous = try #require(listed.last { $0.level < gap.level })
        #expect(entry.stats(atLevel: gap.level)?.hitpointIncrease == previous.hitpointIncrease)
    }

    // MARK: Hero stats

    @Test
    func passiveStatsAddToTheHero() throws {
        let plain = try referenceData()
        let equipped = try referenceData(equipment: [.barbarianKing: [.giantGauntlet, .spikyBall]])
        let base = plain.definition(for: .barbarianKing)
        let king = equipped.definition(for: .barbarianKing)
        let gauntlet = try stats(.giantGauntlet, in: equipped)
        let ball = try stats(.spikyBall, in: equipped)

        let hitPoints = (gauntlet.hitpointIncrease ?? 0) + (ball.hitpointIncrease ?? 0)
        let dps = (gauntlet.dpsIncrease ?? 0) + (ball.dpsIncrease ?? 0)
        #expect(abs(king.maxHitPoints - (base.maxHitPoints + hitPoints)) < 1e-6)
        #expect(abs(king.attackDamage - (base.attackDamage + dps * base.attackInterval)) < 1e-6)

        let ability = try #require(king.heroAbility)
        #expect(ability.displayName.contains("Guanto gigante"))
        #expect(ability.displayName.contains("Palla chiodata"))
        #expect(ability.duration == gauntlet.abilityDuration)
        #expect(abs(ability.incomingDamageReduction - (gauntlet.incomingDamageReduction ?? 0) / 100) < 1e-9)
        #expect(ability.strikeTargetCount == ball.numberOfTargets)
        #expect(ability.strikeDamage == ball.projectileDamagePerTarget)
        #expect(ability.strikesAnyBuilding)
    }

    @Test
    func attackSpeedPiecesShortenTheAttackInterval() throws {
        let plain = try referenceData().definition(for: .barbarianKing)
        let data = try referenceData(equipment: [.barbarianKing: [.vampstache]])
        let king = data.definition(for: .barbarianKing)
        let vampstache = try stats(.vampstache, in: data)

        let increase = try #require(vampstache.attackSpeedIncrease)
        #expect(abs(king.attackInterval - plain.attackInterval / (1 + increase / 100)) < 1e-9)
        #expect(king.healPerHit == vampstache.healPerHit)
    }

    @Test
    func onlyTheRealArenaEquipsHeroesByDefault() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let plain = try referenceData().definition(for: .royalChampion)
        let champion = arena.gameData.definition(for: .royalChampion)

        #expect(champion.maxHitPoints > plain.maxHitPoints)
        #expect(champion.buildingAuraDamagePerSecond > 0)
        #expect(champion.heroAbility?.boostedAttackCount ?? 0 > 0)
        #expect(plain.buildingAuraDamagePerSecond == 0)
        // A piece for another hero is ignored.
        let wrong = try referenceData(equipment: [.archerQueen: [.giantGauntlet]])
        let bareQueen = try referenceData().definition(for: .archerQueen)
        #expect(wrong.definition(for: .archerQueen).maxHitPoints == bareQueen.maxHitPoints)
    }

    // MARK: Battle

    @Test
    func invisibleQueensAreIgnoredByDefenses() throws {
        let data = try referenceData(equipment: [.archerQueen: [.invisibilityVial]])
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        // She turns invisible out of the Cannon's reach, then walks in.
        let queen = DeploymentOrder(kind: .archerQueen, position: position(column: 10, row: 25), deploymentTime: 0)
        let engine = run(
            [cannon],
            [queen],
            abilities: [HeroAbilityOrder(entityID: queen.entityID, activationTime: 0)],
            gameData: data,
            seconds: 6
        )

        let hero = try #require(engine.entities.first { $0.id == queen.entityID })
        #expect(data.definition(for: .archerQueen).heroAbility?.invisibilityDuration ?? 0 > 6)
        #expect(hero.hitPoints == data.definition(for: .archerQueen).maxHitPoints)
        let target = try #require(engine.entities.first { $0.id == cannon.id })
        #expect(target.hitPoints < data.definition(for: .cannon).maxHitPoints)
    }

    @Test
    func frozenArrowsSlowTheirTarget() throws {
        let data = try referenceData(equipment: [.archerQueen: [.frozenArrow]])
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let queen = DeploymentOrder(kind: .archerQueen, position: position(column: 19, row: 25), deploymentTime: 0)
        let engine = run([cannon], [queen], gameData: data, seconds: 3)

        let target = try #require(engine.entities.first { $0.id == cannon.id })
        #expect(target.slowRemaining > 0)
        #expect(target.slowFraction == data.definition(for: .archerQueen).hitSlowFraction)
        #expect(target.slowFraction > 0)
    }

    @Test
    func electroBootsBurnNearbyBuildings() throws {
        func storageLoss(boots: Bool) throws -> Double {
            let data = try referenceData(equipment: boots ? [.royalChampion: [.electroBoots]] : [:])
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 26))
            let other = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 30))
            let champion = DeploymentOrder(kind: .royalChampion, position: position(column: 21, row: 30), deploymentTime: 0)
            let engine = run([storage, other], [champion], gameData: data, seconds: 3)
            let hit = try #require(engine.entities.first { $0.id == storage.id })
            return data.definition(for: .goldStorage).maxHitPoints - hit.hitPoints
        }
        // The Champion attacks the other storage; only the aura reaches
        // this one, about four tiles away.
        #expect(try storageLoss(boots: false) == 0)
        #expect(try storageLoss(boots: true) > 0)
    }

    @Test
    func theGauntletCutsIncomingDamage() throws {
        func kingLoss(gauntlet: Bool) throws -> Double {
            let data = try referenceData(equipment: gauntlet ? [.barbarianKing: [.giantGauntlet]] : [:])
            // The bomb lies on the way, so the ability is already running.
            let bomb = BattleEntity(kind: .bomb, position: position(column: 21, row: 25))
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 35, row: 25))
            let king = DeploymentOrder(kind: .barbarianKing, position: position(column: 18, row: 25), deploymentTime: 0)
            let engine = run(
                [bomb, storage],
                [king],
                abilities: [HeroAbilityOrder(entityID: king.entityID, activationTime: 0)],
                gameData: data,
                seconds: 3
            )
            let hero = try #require(engine.entities.first { $0.id == king.entityID })
            return data.definition(for: .barbarianKing).maxHitPoints - hero.hitPoints
        }
        let plain = try kingLoss(gauntlet: false)
        #expect(plain > 0)
        #expect(try kingLoss(gauntlet: true) < plain)
    }

    @Test
    func fireballStrikesTheHeroTargetAndSplashes() throws {
        let data = try referenceData(equipment: [.grandWarden: [.fireball]])
        let fireball = try stats(.fireball, in: data)
        let first = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 25))
        let second = BattleEntity(kind: .goldStorage, position: position(column: 25, row: 28))
        let warden = DeploymentOrder(kind: .grandWarden, position: position(column: 22, row: 25), deploymentTime: 0)
        let engine = run(
            [first, second],
            [warden],
            abilities: [HeroAbilityOrder(entityID: warden.entityID, activationTime: 0.05)],
            gameData: data,
            seconds: 0.2
        )
        let storage = data.definition(for: .goldStorage).maxHitPoints
        let damage = try #require(fireball.projectileDamage)
        for id in [first.id, second.id] {
            let building = try #require(engine.entities.first { $0.id == id })
            #expect(storage - building.hitPoints >= min(damage, storage) - 1e-6)
        }
    }
}

struct HeroEquipmentChoiceTests {
    @Test
    func storeRoundTripsTheChoice() throws {
        let defaults = try #require(UserDefaults(suiteName: "HeroEquipmentChoiceTests-\(UUID().uuidString)"))
        #expect(HeroEquipmentStore.load(from: defaults) == HeroEquipmentKind.defaultLoadouts)

        let choice: [BattleEntityKind: [HeroEquipmentKind]] = [
            .barbarianKing: [.rageVial, .vampstache],
            .archerQueen: [],
            // Pieces of another hero are dropped on load.
            .grandWarden: [.eternalTome, .giantGauntlet]
        ]
        HeroEquipmentStore.save(choice, to: defaults)
        let loaded = HeroEquipmentStore.load(from: defaults)

        #expect(loaded[.barbarianKing] == [.rageVial, .vampstache])
        #expect(loaded[.archerQueen] == [])
        #expect(loaded[.grandWarden] == [.eternalTome])
        #expect(loaded[.royalChampion] == nil)
    }

    @Test
    func sessionRebuildsTheArenaWithTheChosenEquipment() {
        let session = AttackLabSession()
        let original = session.heroEquipment
        defer { session.applyHeroEquipment(original) }

        session.applyGameDataSource(.reference(townHall: 15))
        let choice: [BattleEntityKind: [HeroEquipmentKind]] = [
            .barbarianKing: [.rageVial, .vampstache]
        ]
        session.applyHeroEquipment(choice)

        #expect(session.heroEquipment == choice)
        #expect(session.arenaHeroEquipment == choice)
        #expect(session.candidatePlanCount > 0)
    }
}
