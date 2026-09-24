import Foundation
import SpriteKit
import Testing
@testable import ClashAttackLabMac

struct RealBattleArenaTests {
    private static let buildingKinds: [BattleEntityKind] = [
        .cannon, .archerTower, .mortar, .wizardTower, .infernoTower,
        .bombTower, .hiddenTesla, .airSweeper, .airDefense, .goldStorage
    ] + BattleEntityKind.utilityBuildings

    private func arena(townHall: Int) throws -> BattleArena {
        try BattleArena.make(for: .reference(townHall: townHall))
    }

    /// Tiles covered by an entity, derived from its centre and footprint.
    private func tiles(
        of entity: BattleEntity,
        definition: CombatDefinition,
        grid: NavigationGrid
    ) -> [GridCoordinate] {
        let size = max(Int((definition.footprintSize / grid.cellSize).rounded()), 1)
        let firstColumn = Int(
            ((entity.position.x - grid.origin.x) / grid.cellSize -
                Double(size) / 2).rounded()
        )
        let firstRow = Int(
            ((entity.position.y - grid.origin.y) / grid.cellSize -
                Double(size) / 2).rounded()
        )
        var result: [GridCoordinate] = []
        for column in firstColumn..<(firstColumn + size) {
            for row in firstRow..<(firstRow + size) {
                result.append(GridCoordinate(column: column, row: row))
            }
        }
        return result
    }

    @Test
    func realArenaUsesTheFullVillageGrid() throws {
        let real = try arena(townHall: 16)

        #expect(real.isReal)
        #expect(real.navigationGrid.columns == 50)
        #expect(real.navigationGrid.rows == 50)
        #expect(real.navigationGrid.cellSize == 40)
        #expect(real.navigationGrid.isLarge)
        #expect(!BattleArena.prototype.isReal)
        #expect(!BattleArena.prototype.navigationGrid.isLarge)
        #expect(real.gameData.battleDuration == 180)
    }

    @Test
    func generatedBasesMatchRealCountsWithoutOverlaps() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()

        for townHall in GameDataSource.referenceTownHalls {
            let real = try arena(townHall: townHall)
            let grid = real.navigationGrid
            let buildable = RealBattleMap.borderTiles..<(
                RealBattleMap.borderTiles + RealBattleMap.buildableTiles
            )

            for layout in PrototypeBaseLayout.allCases {
                let entities = real.makeBaseEntities(layout: layout)
                var covered: Set<GridCoordinate> = []

                for entity in entities {
                    let definition = real.gameData.definition(for: entity.kind)
                    for tile in tiles(of: entity, definition: definition, grid: grid) {
                        #expect(buildable.contains(tile.column))
                        #expect(buildable.contains(tile.row))
                        #expect(
                            covered.insert(tile).inserted,
                            "Overlap at \(tile) for \(entity.kind), TH \(townHall), \(layout)"
                        )
                    }
                }

                #expect(entities.filter { $0.kind == .townHall }.count == 1)
                for kind in Self.buildingKinds {
                    let expected = catalog.unit(for: kind)?.count(atTownHall: townHall) ?? 0
                    #expect(
                        entities.filter { $0.kind == kind }.count == expected,
                        "\(kind) count at TH \(townHall)"
                    )
                }
                let wallCount = entities.filter { $0.kind == .wall }.count
                #expect(wallCount > 0)
                #expect(
                    wallCount <= catalog.unit(for: .wall)?.count(atTownHall: townHall) ?? 0
                )
                #expect(Set(entities.map(\.id)).count == entities.count)
            }
        }
    }

    @Test
    func generatedBasesAreDeterministic() throws {
        let real = try arena(townHall: 14)
        let first = real.makeBaseEntities(layout: .corridor)
        let second = real.makeBaseEntities(layout: .corridor)

        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.position) == second.map(\.position))
        #expect(
            first.map(\.id) != real.makeBaseEntities(layout: .fortress).map(\.id)
        )
    }

    @Test
    func realArmyRulesFollowTheTownHall() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()
        let th16 = ArmyCapacityRules.real(townHall: 16, catalog: catalog)
        let th7 = ArmyCapacityRules.real(townHall: 7, catalog: catalog)

        #expect(th16.troopCapacity == 320)
        #expect(th16.spellCapacity == 11)
        #expect(th16.housing(for: .dragon) == 20)
        #expect(th16.housing(for: .balloon) == 5)
        #expect(th16.housing(for: .barbarianKing) == 0)
        #expect(th16.housing(for: .wallWrecker) == 0)
        #expect(th16.housing(for: .rage) == 2)
        #expect(th16.allows(.stoneSlammer))
        #expect(th7.troopCapacity == 200)
        #expect(!th7.allows(.archerQueen))
        #expect(!th7.allows(.wallWrecker))
        #expect(!th7.allows(.freeze))
    }

    @Test
    func defaultRealArmiesAreValidAndCompact() throws {
        for townHall in GameDataSource.referenceTownHalls {
            let real = try arena(townHall: townHall)
            let army = real.defaultArmy

            #expect(army.isValid(under: real.armyRules), "TH \(townHall)")
            #expect(army.troopCapacityUsed(under: real.armyRules) <= real.armyRules.troopCapacity)
            #expect(
                army.troopCapacityUsed(under: real.armyRules) >=
                    real.armyRules.troopCapacity - 4
            )
            #expect(army.spellCapacityUsed(under: real.armyRules) <= real.armyRules.spellCapacity)
            #expect(army.totalTroops <= 80, "TH \(townHall) army is too large")
        }

        let th16 = try arena(townHall: 16).defaultArmy
        #expect(th16.barbarianKings == 1)
        #expect(th16.archerQueens == 1)
        #expect(th16.wallWreckers == 1)
        #expect(th16.dragons > 0)
    }

    @Test
    func lockedUnitsMakeAnArmyInvalid() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()
        let th7 = ArmyCapacityRules.real(townHall: 7, catalog: catalog)
        var army = ArmyConfiguration(
            giants: 2,
            barbarians: 0,
            archers: 0,
            wallBreakers: 0,
            wizards: 0,
            healSpells: 0,
            rageSpells: 0
        )
        #expect(army.isValid(under: th7))

        army.archerQueens = 1
        #expect(!army.isValid(under: th7))
        #expect(army.validationMessage(under: th7)?.contains("non è ancora sbloccato") == true)
    }

    @Test
    func prototypeRulesKeepTheOriginalCapacity() {
        let army = ArmyConfiguration.prototypeDefault

        #expect(army.troopCapacityUsed == army.troopCapacityUsed(under: .prototype))
        #expect(army.isValid == army.isValid(under: .prototype))
        #expect(ArmyCapacityRules.prototype.troopCapacity == 30)
        #expect(ArmyCapacityRules.prototype.allows(.stoneSlammer))
    }

    @Test
    func generatedRealPlansDeployFromTheBorderInTime() throws {
        let real = try arena(townHall: 16)
        let entities = real.makeBaseEntities(layout: .fortress)
        let plans = AttackPlanGenerator(
            navigationGrid: real.navigationGrid,
            armyConfiguration: real.defaultArmy,
            baseEntities: entities,
            gameData: real.gameData,
            armyRules: real.armyRules
        ).generate()

        #expect(!plans.isEmpty)
        for plan in plans {
            #expect(plan.deployments.count == real.defaultArmy.totalTroops)
            for order in plan.deployments {
                let cell = try #require(real.navigationGrid.coordinate(for: order.position))
                #expect((0...2).contains(cell.column))
                #expect((0...59).contains(order.deploymentTime))
            }
            for order in plan.spellDeployments {
                #expect((0...59).contains(order.deploymentTime))
            }
        }
    }

    @Test
    func troopsStopAtTheFootprintEdge() throws {
        let real = try arena(townHall: 16)
        let grid = real.navigationGrid
        let cannonDefinition = real.gameData.definition(for: .cannon)
        let giantDefinition = real.gameData.definition(for: .giant)
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(for: GridCoordinate(column: 12, row: 20))
        )
        let plan = AttackPlan(
            name: "Edge",
            deployments: [
                DeploymentOrder(
                    kind: .giant,
                    position: grid.worldPosition(for: GridCoordinate(column: 2, row: 20)),
                    deploymentTime: 0
                )
            ]
        )
        let engine = SimulationEngine(
            entities: [cannon],
            attackPlan: plan,
            gameData: real.gameData,
            navigationGrid: grid
        )
        #expect(engine.remainingTime == 180)

        engine.start()
        for _ in 0..<(60 * 8) {
            engine.advance(by: 1.0 / 60.0)
        }

        let giant = try #require(engine.entities.first { $0.kind == .giant })
        let damagedCannon = try #require(engine.entities.first { $0.id == cannon.id })
        let reach = cannonDefinition.reachDistance(
            from: giant.position,
            toCenter: cannon.position
        )
        let halfSize = cannonDefinition.footprintSize / 2

        #expect(damagedCannon.hitPoints < cannonDefinition.maxHitPoints)
        #expect(reach <= giantDefinition.attackRange + 2)
        #expect(
            max(
                abs(giant.position.x - cannon.position.x),
                abs(giant.position.y - cannon.position.y)
            ) > halfSize
        )
    }

    @Test
    func sessionSwitchesToTheRealArenaAndBack() {
        let session = AttackLabSession()
        #expect(!session.isRealArena)

        session.applyGameDataSource(.reference(townHall: 16))

        #expect(session.isRealArena)
        #expect(session.gameDataSource == .reference(townHall: 16))
        #expect(session.armyConfiguration == session.defaultArmy)
        #expect(session.armyRules.troopCapacity == 320)
        #expect(session.candidatePlanCount > 0)
        #expect(session.scene.size.height > 760)

        session.applyGameDataSource(.prototype)

        #expect(!session.isRealArena)
        #expect(session.armyConfiguration == .prototypeDefault)
        #expect(session.scene.size.height == 760)
    }

    @Test
    func precomputedDataMatchesItsSource() throws {
        let source = try ReferenceGameCatalog.loadBundled()
        let reference = ReferenceGameData(
            catalog: source,
            profile: ReferenceLevelProfile(townHall: 12)
        )
        let cached = PrecomputedGameData(reference)

        for kind in BattleEntityKind.allCases {
            let expected = reference.definition(for: kind)
            let actual = cached.definition(for: kind)
            #expect(actual.maxHitPoints == expected.maxHitPoints)
            #expect(actual.attackDamage == expected.attackDamage)
            #expect(actual.attackRange == expected.attackRange)
            #expect(actual.footprintSize == expected.footprintSize)
        }
        for kind in BattleSpellKind.allCases {
            #expect(
                cached.spellDefinition(for: kind).radius ==
                    reference.spellDefinition(for: kind).radius
            )
        }
        #expect(cached.battleDuration == 180)
        #expect(PrecomputedGameData.wrapping(cached).battleDuration == 180)
    }

    @Test
    func parallelBattlesMatchSequentialResultsInOrder() async throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let base = PrototypeBattleMap.makeBaseEntities(navigationGrid: grid)
        let gameData = PrototypeGameData()
        let plans = Array(AttackPlanGenerator(navigationGrid: grid).generate().prefix(6))
        let jobs = plans.map {
            ParallelBattleRunner.Job(
                entities: base,
                plan: $0,
                gameData: gameData,
                navigationGrid: grid
            )
        }

        var progress: [Int] = []
        let parallel = try await ParallelBattleRunner.run(jobs) { progress.append($0) }
        let sequential = jobs.map { ParallelBattleRunner.simulate($0) }

        #expect(progress == Array(1...plans.count))
        #expect(parallel.count == sequential.count)
        for (first, second) in zip(parallel, sequential) {
            let first = try #require(first)
            let second = try #require(second)
            #expect(first.score.destructionPercentage == second.score.destructionPercentage)
            #expect(first.elapsedTime == second.elapsedTime)
            #expect(first.survivingTroops == second.survivingTroops)
        }
    }

    @Test
    func realBattlesRunToTheEndInTheEvaluator() async throws {
        let real = try arena(townHall: 12)
        let entities = real.makeBaseEntities(layout: .fortress)
        let plan = try #require(
            AttackPlanGenerator(
                navigationGrid: real.navigationGrid,
                armyConfiguration: real.defaultArmy,
                baseEntities: entities,
                gameData: real.gameData,
                armyRules: real.armyRules
            ).generate().first
        )
        let evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: real.gameData,
            navigationGrid: real.navigationGrid
        )

        let evaluation = try #require(try await evaluator.evaluateAsync([plan]).first)

        #expect(evaluation.result.elapsedTime <= 180)
        #expect(evaluation.result.deployedTroops > 0)
    }

    @Test
    func catalogCoversEveryEntityKind() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()
        for kind in BattleEntityKind.allCases {
            #expect(catalog.unit(for: kind) != nil, "\(kind) missing from the catalog")
        }
    }

    @Test
    func utilityBuildingsAreRealNonAttackingObjectives() throws {
        let real = try arena(townHall: 16)
        let camp = real.gameData.definition(for: .armyCamp)
        let hut = real.gameData.definition(for: .builderHut)
        let mine = real.gameData.definition(for: .goldMine)

        #expect(camp.role == .building)
        #expect(camp.countsForDestruction)
        #expect(camp.footprintSize == 4 * 40)
        #expect(hut.attackDamage == 0)
        #expect(hut.footprintSize == 2 * 40)
        #expect(mine.maxHitPoints == 1_400)
        #expect(PrototypeGameData().definition(for: .laboratory).role == .building)
        #expect(
            UtilityBuildingStyle.style(for: .laboratory).displayName == "Laboratorio"
        )

        let entities = real.makeBaseEntities(layout: .fortress)
        let scored = entities.filter {
            real.gameData.definition(for: $0.kind).countsForDestruction
        }
        #expect(scored.count >= 80)
        #expect(entities.contains { $0.kind == .clanCastle })
    }
}
