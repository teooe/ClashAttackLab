import Foundation
import Testing
@testable import ClashAttackLabMac

struct ReferenceGameDataTests {
    private static let allEntityKinds: [BattleEntityKind] = [
        .giant, .barbarian, .archer, .wallBreaker, .wizard, .balloon,
        .dragon, .barbarianKing, .archerQueen, .wallWrecker, .stoneSlammer,
        .cannon, .archerTower, .mortar, .wizardTower, .infernoTower,
        .bombTower, .hiddenTesla, .giantBomb, .airBomb, .airSweeper,
        .airDefense, .townHall, .goldStorage, .wall
    ]

    private static let allSpellKinds: [BattleSpellKind] = [
        .heal, .rage, .freeze, .lightning, .earthquake
    ]

    private func referenceData(
        townHall: Int,
        unitLevels: [BattleEntityKind: Int] = [:]
    ) throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(
                townHall: townHall,
                unitLevels: unitLevels
            )
        )
    }

    private func isClose(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 1e-9
    }

    @Test
    func bundledCatalogCoversEveryModeledEntityAndSpell() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()

        #expect(catalog.source.package == "clash-of-clans-data")
        for kind in Self.allEntityKinds {
            let unit = try #require(catalog.unit(for: kind))
            #expect(!unit.levels.isEmpty)
        }
        for kind in Self.allSpellKinds {
            let spell = try #require(catalog.spell(for: kind))
            #expect(!spell.levels.isEmpty)
        }
    }

    @Test
    func townHallSelectsHighestUnlockedLevel() throws {
        let data = try referenceData(townHall: 1)
        let cannon = data.definition(for: .cannon)

        #expect(data.level(for: .cannon) == 2)
        #expect(cannon.maxHitPoints == 360)
        #expect(cannon.attackDamage == 8)
        #expect(cannon.attackInterval == 0.8)
        #expect(cannon.attackRange == 9 * 40)
    }

    @Test
    func lockedUnitsFallBackToTheirFirstLevel() throws {
        let data = try referenceData(townHall: 1)

        #expect(data.level(for: .dragon) == 1)
        #expect(data.definition(for: .dragon).maxHitPoints == 1_900)
    }

    @Test
    func explicitLevelOverridesTheTownHallDefault() throws {
        let data = try referenceData(townHall: 18, unitLevels: [.giant: 1])

        #expect(data.level(for: .giant) == 1)
        #expect(data.definition(for: .giant).maxHitPoints == 400)
        #expect(data.definition(for: .barbarian).maxHitPoints == 310)
    }

    @Test
    func troopUnitsConvertIntoWorldUnits() throws {
        let barbarian = try referenceData(townHall: 18)
            .definition(for: .barbarian)

        #expect(barbarian.maxHitPoints == 310)
        #expect(barbarian.attackDamage == 51)
        // Speed 18 is 2.25 tiles per second on 40-unit tiles.
        #expect(isClose(barbarian.movementSpeed, 90))
        // 0.4 tiles of reach plus one tile of contact padding.
        #expect(isClose(barbarian.attackRange, 56))
        #expect(barbarian.targetingProfile?.preference == .anyBuilding)
    }

    @Test
    func heroesFollowHeroHallCapsAndRealAbilityHealing() throws {
        let data = try referenceData(townHall: 8)
        let queen = data.definition(for: .archerQueen)

        #expect(data.level(for: .archerQueen) == 10)
        #expect(queen.maxHitPoints == 699)
        #expect(queen.heroAbility?.instantHealing == 145)
    }

    @Test
    func siegeAndWallBreakerWallMultipliers() throws {
        let data = try referenceData(townHall: 16)

        #expect(data.definition(for: .wallWrecker).damageMultiplierAgainstWalls == 10)
        #expect(data.definition(for: .wallBreaker).damageMultiplierAgainstWalls == 40)
    }

    @Test
    func defensesTrapsAndBuildingsUseRealValues() throws {
        let data = try referenceData(townHall: 12)
        let mortar = data.definition(for: .mortar)
        let giantBomb = data.definition(for: .giantBomb)

        #expect(mortar.maxHitPoints == 1_500)
        #expect(mortar.attackDamage == 190)
        #expect(mortar.minimumAttackRange == 4 * 40)
        #expect(mortar.splashRadius == 1.5 * 40)
        #expect(giantBomb.role == .trap)
        #expect(giantBomb.destructionDamage == 275)
        #expect(giantBomb.destructionRadius == 4 * 40)
        #expect(giantBomb.activationRange == 2 * 40)
        #expect(data.definition(for: .airSweeper).pushbackDistance == 4 * 40)
        #expect(data.definition(for: .wall).maxHitPoints == 8_000)
        #expect(data.definition(for: .townHall).maxHitPoints == 7_500)
    }

    @Test
    func infernoTowerRampsThroughRealHeatStages() throws {
        let inferno = try referenceData(townHall: 10)
            .definition(for: .infernoTower)

        #expect(isClose(inferno.attackDamage, 5.12))
        #expect(inferno.attackInterval == 0.128)
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 0), 1))
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 11), 1))
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 12), 3))
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 39), 3))
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 40), 30))
        #expect(isClose(inferno.damageRampMultiplier(forConsecutiveAttack: 500), 30))
    }

    @Test
    func spellsUseRealStrength() throws {
        let data = try referenceData(townHall: 18)
        let rage = data.spellDefinition(for: .rage)
        let heal = data.spellDefinition(for: .heal)
        let lightning = data.spellDefinition(for: .lightning)
        let earthquake = data.spellDefinition(for: .earthquake)

        #expect(isClose(rage.damageMultiplier, 2.9))
        #expect(rage.movementSpeedMultiplier == 1)
        #expect(rage.attackSpeedMultiplier == 1)
        #expect(isClose(rage.movementSpeedBonus, 160))
        #expect(rage.duration == 18)
        #expect(heal.healingPerSecond == 250)
        #expect(isClose(heal.duration, 12.3))
        #expect(heal.radius == 5 * 40)
        #expect(lightning.instantDamage == 720)
        #expect(data.spellDefinition(for: .freeze).duration == 6)
        #expect(earthquake.dealsInstantDamage)
        #expect(earthquake.instantDamage == 0)
        #expect(isClose(earthquake.impactDamage(forMaxHitPoints: 1_000), 290))
    }

    @Test
    func prototypeSpellsKeepFlatDamageAndNoSpeedBonus() {
        let gameData = PrototypeGameData()
        let earthquake = gameData.spellDefinition(for: .earthquake)

        #expect(earthquake.maxHitPointDamageFraction == 0)
        #expect(earthquake.impactDamage(forMaxHitPoints: 10_000) == earthquake.instantDamage)
        #expect(gameData.spellDefinition(for: .rage).movementSpeedBonus == 0)
    }

    @Test
    func realEarthquakeRemovesAShareOfBuildingHitPoints() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let gameData = try referenceData(townHall: 18)
        let impact = grid.worldPosition(for: GridCoordinate(column: 10, row: 8))
        let storage = BattleEntity(
            kind: .goldStorage,
            position: impact,
            hitPoints: gameData.definition(for: .goldStorage).maxHitPoints
        )
        let plan = AttackPlan(
            name: "Quake",
            deployments: [
                DeploymentOrder(
                    kind: .barbarian,
                    position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
                    deploymentTime: 30
                )
            ],
            spellDeployments: [
                SpellDeploymentOrder(kind: .earthquake, position: impact, deploymentTime: 0)
            ]
        )
        let engine = SimulationEngine(
            entities: [storage],
            attackPlan: plan,
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        engine.advance(by: 0.1)

        let damaged = try #require(engine.entities.first { $0.id == storage.id })
        let maxHitPoints = gameData.definition(for: .goldStorage).maxHitPoints
        #expect(maxHitPoints == 4_300)
        #expect(isClose(maxHitPoints - damaged.hitPoints, 4_300 * 0.29))
    }

    @Test
    func engineCanSwapGameDataWhenReloadingAScenario() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let prototype = PrototypeGameData()
        let reference = try referenceData(townHall: 18)
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(for: GridCoordinate(column: 20, row: 8))
        )
        let plan = AttackPlan(name: "Empty", deployments: [])
        let engine = SimulationEngine(
            entities: [cannon],
            attackPlan: plan,
            gameData: prototype,
            navigationGrid: grid
        )
        #expect(engine.entities[0].hitPoints == prototype.definition(for: .cannon).maxHitPoints)

        engine.loadScenario(entities: [cannon], attackPlan: plan, gameData: reference)

        #expect(engine.entities[0].hitPoints == reference.definition(for: .cannon).maxHitPoints)
        #expect(engine.definition(for: .cannon).maxHitPoints == 2_250)
    }

    @Test
    func referenceSourceBuildsReferenceGameData() throws {
        let data = try GameDataSource.reference(townHall: 18).makeGameData()

        #expect(data is ReferenceGameData)
        #expect(try GameDataSource.prototype.makeGameData() is PrototypeGameData)
        #expect(GameDataSource.reference(townHall: 15).title == "Reali · Municipio 15")
    }

    @Test
    func rampExpansionHandlesSingleStage() {
        #expect(ReferenceGameData.rampMultipliers(
            stageDamage: [10],
            attackInterval: 0.5
        ) == [1])
        #expect(ReferenceGameData.rampMultipliers(
            stageDamage: [],
            attackInterval: 0.5
        ) == [1])
    }

    @Test
    func catalogDecodesMinimalJSON() throws {
        let json = """
        {
          "source": {"package": "test", "version": "1"},
          "units": {
            "cannon": {
              "name": "Cannon", "range": 9, "attackInterval": 0.8,
              "levels": [
                {"level": 1, "townHall": 1, "hitpoints": 300, "damagePerHit": 5.6},
                {"level": 2, "townHall": 3, "hitpoints": 360, "damagePerHit": 8}
              ]
            }
          },
          "spells": {}
        }
        """
        let catalog = try ReferenceGameCatalog.decode(from: Data(json.utf8))
        let data = ReferenceGameData(
            catalog: catalog,
            profile: ReferenceLevelProfile(townHall: 2)
        )

        #expect(data.definition(for: .cannon).maxHitPoints == 300)
        // Missing entries fall back to prototype values.
        #expect(
            data.definition(for: .giant).maxHitPoints ==
                PrototypeGameData().definition(for: .giant).maxHitPoints
        )
        #expect(
            data.spellDefinition(for: .rage).damageMultiplier ==
                PrototypeGameData().spellDefinition(for: .rage).damageMultiplier
        )
    }
}
