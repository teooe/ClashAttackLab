import Foundation
import Testing
@testable import ClashAttackLabMac

struct HeroesAndSpellsTests {
    private func referenceData(townHall: Int = 15) throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: townHall)
        )
    }

    private func rules(townHall: Int = 15) throws -> ArmyCapacityRules {
        ArmyCapacityRules.real(
            townHall: townHall,
            catalog: try ReferenceGameCatalog.loadBundled()
        )
    }

    private func isClose(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) < 1e-6
    }

    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func engine(
        entities: [BattleEntity],
        plan: AttackPlan,
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

    private func ring(around column: Int, _ row: Int, radius: Int) -> [BattleEntity] {
        var cells: [GridCoordinate] = []
        for offset in -radius...radius {
            for cell in [
                GridCoordinate(column: column - radius, row: row + offset),
                GridCoordinate(column: column + radius, row: row + offset),
                GridCoordinate(column: column + offset, row: row - radius),
                GridCoordinate(column: column + offset, row: row + radius)
            ] where !cells.contains(cell) {
                cells.append(cell)
            }
        }
        return cells.map {
            BattleEntity(kind: .wall, position: grid.worldPosition(for: $0))
        }
    }

    // MARK: Data and rules

    @Test
    func heroesUseRealTownHall15Values() throws {
        let data = try referenceData()
        let warden = data.definition(for: .grandWarden)
        let champion = data.definition(for: .royalChampion)

        #expect(warden.maxHitPoints == 2_329)
        #expect(warden.attackDamage == 534.6)
        #expect(warden.attackRange == 7 * 40)
        #expect(warden.heroAbility?.instantHealing == 247)
        #expect((warden.heroAbility?.protectionRadius ?? 0) > 0)
        #expect(warden.housingSpace == 25)

        #expect(champion.maxHitPoints == 3_910)
        #expect(champion.attackDamage == 636)
        #expect(champion.attackRange == 3 * 40)
        #expect(champion.targetingProfile?.preference == .defenses)
        #expect(champion.heroAbility?.strikeTargetCount == 4)
        #expect(champion.heroAbility?.instantHealing == 1_200)

        for kind in BattleEntityKind.heroKinds {
            #expect(kind.isHero)
        }
        for kind in BattleEntityKind.advancedHeroes {
            #expect(TroopStyle.style(for: kind).symbol != "?")
        }
        #expect(!BattleEntityKind.giant.isHero)
    }

    @Test
    func spellsUseRealTownHall15Values() throws {
        let data = try referenceData()
        let jump = data.spellDefinition(for: .jump)
        let invisibility = data.spellDefinition(for: .invisibility)
        let haste = data.spellDefinition(for: .haste)

        #expect(jump.letsTroopsJumpWalls)
        #expect(jump.radius == 3.5 * 40)
        #expect(jump.duration == 100)
        #expect(!jump.boostsTroops)

        #expect(invisibility.hidesDefenses)
        #expect(invisibility.radius == 4 * 40)
        #expect(invisibility.duration == 4.25)

        #expect(haste.boostsTroops)
        #expect(haste.damageMultiplier == 1)
        #expect(isClose(haste.movementSpeedBonus, 52.0 / 8 * 40))
        #expect(haste.duration == 30)

        #expect(data.spellDefinition(for: .rage).boostsTroops)
        #expect(!data.spellDefinition(for: .freeze).boostsTroops)
    }

    @Test
    func realRulesUnlockHeroesAndSpellsByTownHall() throws {
        let th15 = try rules(townHall: 15)
        let th10 = try rules(townHall: 10)

        for kind in BattleEntityKind.heroKinds {
            #expect(th15.allows(kind), "\(kind)")
            #expect(th15.housing(for: kind) == 0, "\(kind)")
        }
        for kind in ArmyConfiguration.advancedSpellKinds {
            #expect(th15.allows(kind), "\(kind)")
        }
        #expect(th15.housing(for: .jump) == 2)
        #expect(th15.housing(for: .haste) == 1)
        #expect(!th10.allows(.royalChampion))
        #expect(!th10.allows(.grandWarden))
        #expect(th10.allows(.invisibility))
    }

    @Test
    func armiesCountEveryHeroAndSpell() throws {
        let th15 = try rules(townHall: 15)
        var army = ArmyConfiguration.realDefault(for: th15)

        // Four heroes at most: the Dragon Duke stays home by default.
        for kind in BattleEntityKind.heroKinds.prefix(BattleEntityKind.maximumHeroesPerArmy) {
            #expect(army[troop: kind] == 1, "\(kind)")
        }
        #expect(army[troop: .dragonDuke] == 0)
        #expect(army.isValid(under: th15))
        army[troop: .dragonDuke] = 1
        #expect(army.validationMessage(under: th15) == "Puoi portare al massimo 4 eroi.")
        army[troop: .dragonDuke] = 0

        army[troop: .grandWarden] = 2
        #expect(army.validationMessage(under: th15) == "Puoi usare un solo esemplare per ciascun eroe.")
        army[troop: .grandWarden] = 1

        army[spell: .rage] -= 1
        army[spell: .haste] = 2
        #expect(army.spellCount(for: .haste) == 2)
        #expect(army.spellSequence.filter { $0 == .haste }.count == 2)
        #expect(army.isValid(under: th15))

        army[spell: .haste] = 0
        army[spell: .rage] += 1
        #expect(army == ArmyConfiguration.realDefault(for: th15))
    }

    @Test
    func plansRememberHeroesAndSpells() throws {
        let plan = AttackPlan(
            name: "Heroes",
            deployments: [
                DeploymentOrder(kind: .grandWarden, position: position(column: 1, row: 20), deploymentTime: 0),
                DeploymentOrder(kind: .royalChampion, position: position(column: 1, row: 22), deploymentTime: 2)
            ],
            spellDeployments: [
                SpellDeploymentOrder(kind: .jump, position: position(column: 10, row: 20), deploymentTime: 3),
                SpellDeploymentOrder(kind: .haste, position: position(column: 10, row: 22), deploymentTime: 3)
            ]
        )
        let army = plan.armyConfiguration

        #expect(army[troop: .grandWarden] == 1)
        #expect(army[troop: .royalChampion] == 1)
        #expect(army[spell: .jump] == 1)
        #expect(army[spell: .haste] == 1)
        #expect(ManualAttackPlan(deployments: plan.deployments).heroDeployments.count == 2)
    }

    @Test
    func generatedPlansCastTheNewSpells() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        var army = arena.defaultArmy
        army[spell: .rage] -= 1
        army[spell: .haste] = 1
        army[spell: .invisibility] = 1
        let plan = try #require(AttackPlanGenerator(
            navigationGrid: arena.navigationGrid,
            armyConfiguration: army,
            baseEntities: arena.makeBaseEntities(layout: .fortress),
            gameData: arena.gameData,
            armyRules: arena.armyRules
        ).generate().first)

        #expect(plan.spellDeployments.count == army.spellSequence.count)
        #expect(plan.spellDeployments.contains { $0.kind == .haste })
        #expect(plan.deployments.filter { $0.kind.isHero }.count == 4)
    }

    // MARK: Engine behaviour

    @Test
    func eternalTomeShieldsNearbyTroops() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let giant = DeploymentOrder(kind: .giant, position: position(column: 20, row: 25), deploymentTime: 0)
        let warden = DeploymentOrder(kind: .grandWarden, position: position(column: 19, row: 25), deploymentTime: 0)
        let plan = AttackPlan(
            name: "Tome",
            deployments: [giant, warden],
            heroAbilityOrders: [HeroAbilityOrder(entityID: warden.entityID, activationTime: 0.5)]
        )
        let battle = engine(entities: [cannon], plan: plan, gameData: data)

        advance(battle, seconds: 0.55)
        let shielded = try #require(battle.entities.first { $0.id == giant.entityID })
        #expect(shielded.invulnerableRemaining > 0)
        let hitPointsAtCast = shielded.hitPoints

        advance(battle, seconds: 4)
        let protected = try #require(battle.entities.first { $0.id == giant.entityID })
        #expect(protected.hitPoints == hitPointsAtCast)

        advance(battle, seconds: 5)
        let exposed = try #require(battle.entities.first { $0.id == giant.entityID })
        #expect(exposed.invulnerableRemaining == 0)
        #expect(exposed.hitPoints < hitPointsAtCast)
    }

    @Test
    func seekingShieldStrikesTheFourClosestDefenses() throws {
        let data = try referenceData()
        let towers = [15, 16, 17, 18, 19].map {
            BattleEntity(kind: .spellTower, position: position(column: $0, row: 25))
        }
        let champion = DeploymentOrder(kind: .royalChampion, position: position(column: 10, row: 25), deploymentTime: 0)
        let plan = AttackPlan(
            name: "Shield",
            deployments: [champion],
            heroAbilityOrders: [HeroAbilityOrder(entityID: champion.entityID, activationTime: 0)]
        )
        let battle = engine(entities: towers, plan: plan, gameData: data)
        advance(battle, seconds: 0.05)

        let maxHitPoints = data.definition(for: .spellTower).maxHitPoints
        let losses = towers.map { tower in
            maxHitPoints - (battle.entities.first { $0.id == tower.id }?.hitPoints ?? 0)
        }
        for index in 0..<4 {
            #expect(isClose(losses[index], 636 * 2.5), "tower \(index)")
        }
        #expect(losses[4] == 0)
    }

    @Test
    func jumpSpellLetsGroundTroopsCrossWalls() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let walls = ring(around: 25, 25, radius: 3)
        let plan = AttackPlan(
            name: "Jump",
            deployments: [
                DeploymentOrder(kind: .giant, position: position(column: 15, row: 25), deploymentTime: 0)
            ],
            spellDeployments: [
                SpellDeploymentOrder(kind: .jump, position: position(column: 22, row: 25), deploymentTime: 0)
            ]
        )
        let battle = engine(entities: [cannon] + walls, plan: plan, gameData: data)
        advance(battle, seconds: 9)

        let wallHitPoints = data.definition(for: .wall).maxHitPoints
        let hitCannon = try #require(battle.entities.first { $0.id == cannon.id })
        #expect(hitCannon.hitPoints < data.definition(for: .cannon).maxHitPoints)
        #expect(battle.entities.filter { $0.kind == .wall }.allSatisfy {
            $0.hitPoints == wallHitPoints
        })
    }

    @Test
    func invisibleDefensesCannotBeTargeted() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .cannon, position: position(column: 20, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 32, row: 25))
        let giant = DeploymentOrder(kind: .giant, position: position(column: 12, row: 25), deploymentTime: 0)
        let plan = AttackPlan(
            name: "Invisible",
            deployments: [giant],
            spellDeployments: [
                SpellDeploymentOrder(kind: .invisibility, position: cannon.position, deploymentTime: 0)
            ]
        )
        let battle = engine(entities: [cannon, storage], plan: plan, gameData: data)
        advance(battle, seconds: 0.5)

        let hidden = try #require(battle.entities.first { $0.id == giant.entityID })
        #expect(hidden.currentTargetID == storage.id)

        // Once the spell fades, the Giant goes back to the defense.
        advance(battle, seconds: 5)
        let visible = try #require(battle.entities.first { $0.id == giant.entityID })
        #expect(visible.currentTargetID == cannon.id)
    }

    @Test
    func hasteSpeedsTroopsUpWithoutExtraDamage() throws {
        let data = try referenceData()
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 45, row: 25))
        let start = position(column: 5, row: 25)

        func travelled(withHaste: Bool) throws -> Double {
            let giant = DeploymentOrder(kind: .giant, position: start, deploymentTime: 0)
            let plan = AttackPlan(
                name: "Haste",
                deployments: [giant],
                spellDeployments: withHaste
                    ? [SpellDeploymentOrder(kind: .haste, position: start, deploymentTime: 0)]
                    : []
            )
            let battle = engine(entities: [storage], plan: plan, gameData: data)
            advance(battle, seconds: 1)
            let moved = try #require(battle.entities.first { $0.id == giant.entityID })
            return moved.position.x - start.x
        }

        let normal = try travelled(withHaste: false)
        let hasted = try travelled(withHaste: true)
        #expect(normal > 0)
        #expect(hasted > normal * 2)
    }
}
