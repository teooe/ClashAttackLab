import Foundation
import Testing
@testable import ClashAttackLabMac

/// Real Town Hall 15 data with chosen troops reduced to 1 hit point, so a
/// single shot kills them.
private struct FragileGameData: GameDataProviding {
    let base: ReferenceGameData
    let fragile: Set<BattleEntityKind>

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        var definition = base.definition(for: kind)
        if fragile.contains(kind) {
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

struct SpawnedTroopsTests {
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
        gameData: any GameDataProviding,
        seconds: Double
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Prova", deployments: deployments),
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
        return engine
    }

    // MARK: Data

    @Test
    func golemSplitsIntoGolemitesWithAFifthOfItsStats() throws {
        let data = try referenceData()
        let golem = data.definition(for: .golem)
        let golemite = data.definition(for: .golemite)

        #expect(golem.maxHitPoints == 8_800)
        #expect(golem.siegePayload == [.golemite, .golemite, .golemite])
        #expect(golemite.maxHitPoints == 1_760)
        #expect(abs(golemite.attackDamage - golem.attackDamage / 5) < 1e-9)
        #expect(golemite.movementDomain == .ground)
        #expect(golemite.role == .troop)
    }

    @Test
    func lavaHoundReleasesEighteenFlyingPups() throws {
        let data = try referenceData()
        let hound = data.definition(for: .lavaHound)
        let pup = data.definition(for: .lavaPup)

        #expect(hound.siegePayload == Array(repeating: .lavaPup, count: 18))
        #expect(pup.movementDomain == .air)
        #expect(pup.maxHitPoints > 0)
        #expect(pup.attackDamage > 0)
    }

    @Test
    func spawnedTroopsCannotBeTrained() {
        for kind in BattleEntityKind.spawnedTroops {
            #expect(!ArmyConfiguration.troopKinds.contains(kind), "\(kind)")
        }
    }

    // MARK: Battle

    @Test
    func aDeadGolemLeavesThreeGolemitesOnTheField() throws {
        let data = FragileGameData(base: try referenceData(), fragile: [.golem])
        let cannon = BattleEntity(kind: .cannon, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 35, row: 25))
        let golem = DeploymentOrder(kind: .golem, position: position(column: 18, row: 25), deploymentTime: 0)
        let engine = run([cannon, storage], [golem], gameData: data, seconds: 6)

        #expect(engine.releasedPayloadTroopCount == 3)
        let golemites = engine.entities.filter { $0.kind == .golemite }
        #expect(golemites.count == 3)
        #expect(golemites.contains { $0.hitPoints > 0 })
        #expect(golemites.allSatisfy { $0.hitPoints <= 1_760 })
    }

    @Test
    func aDeadLavaHoundLeavesEighteenPups() throws {
        let data = FragileGameData(base: try referenceData(), fragile: [.lavaHound])
        let airDefense = BattleEntity(kind: .airDefense, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 35, row: 25))
        let hound = DeploymentOrder(kind: .lavaHound, position: position(column: 18, row: 25), deploymentTime: 0)
        let engine = run([airDefense, storage], [hound], gameData: data, seconds: 6)

        #expect(engine.releasedPayloadTroopCount == 18)
        #expect(engine.entities.filter { $0.kind == .lavaPup }.count == 18)
    }

    @Test
    func wardenAuraReducesDamageToNearbyTroops() throws {
        let data = try referenceData()
        let reduction = data.definition(for: .grandWarden).auraDamageReduction
        #expect(reduction > 0)

        func giantDamage(withWarden: Bool) throws -> Double {
            let bomb = BattleEntity(kind: .bomb, position: position(column: 18, row: 25))
            let storage = BattleEntity(kind: .goldStorage, position: position(column: 35, row: 25))
            var deployments = [
                DeploymentOrder(kind: .giant, position: position(column: 18, row: 25), deploymentTime: 0)
            ]
            if withWarden {
                deployments.append(
                    DeploymentOrder(kind: .grandWarden, position: position(column: 18, row: 25), deploymentTime: 0)
                )
            }
            let engine = run([bomb, storage], deployments, gameData: data, seconds: 3)
            let giant = try #require(engine.entities.first { $0.id == deployments[0].entityID })
            return data.definition(for: .giant).maxHitPoints - giant.hitPoints
        }

        let alone = try giantDamage(withWarden: false)
        let protected = try giantDamage(withWarden: true)
        #expect(alone > 0)
        #expect(abs(protected - alone * (1 - reduction)) < 1e-6)
    }
}
