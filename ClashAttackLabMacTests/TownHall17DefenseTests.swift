import Foundation
import Testing
@testable import ClashAttackLabMac

/// Defenses that arrive at Town Hall 16 and 17, and the TH17 base
/// transcribed from the player's screenshots.
struct TownHall17DefenseTests {
    private func referenceData() throws -> ReferenceGameData {
        ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: 17)
        )
    }

    private var grid: NavigationGrid {
        RealBattleMap.makeNavigationGrid()
    }

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
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
    func newDefensesUseRealValues() throws {
        let data = try referenceData()
        let tile = data.tileSize

        let multiArcher = data.definition(for: .multiArcherTower)
        #expect(multiArcher.role == .defense)
        #expect(multiArcher.maxHitPoints == 5_400)
        #expect(multiArcher.attackDamage == 70)
        #expect(multiArcher.attackRange == 10 * tile)
        #expect(multiArcher.extraTargetCount == 2)
        #expect(multiArcher.attackTargetLayer == .both)

        let ricochet = data.definition(for: .ricochetCannon)
        #expect(ricochet.maxHitPoints == 6_000)
        #expect(ricochet.attackDamage == 324)
        #expect(ricochet.attackTargetLayer == .ground)
        #expect(ricochet.chainTargetCount == 2)
        #expect(abs(ricochet.chainRange - 3.5 * tile) < 1e-9)
        #expect(abs(ricochet.chainDamageMultiplier - 0.7) < 1e-9)

        let multiGear = data.definition(for: .multiGearTower)
        #expect(multiGear.maxHitPoints == 4_200)
        #expect(multiGear.attackDamage == 370)
        #expect(multiGear.attackRange == 12 * tile)
        #expect(multiGear.attackTargetLayer == .both)
    }

    // MARK: Battle

    @Test
    func multiArcherTowerShootsThreeTroopsAtOnce() throws {
        let data = try referenceData()
        let tower = BattleEntity(kind: .multiArcherTower, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let deployments = [(19, 25), (19, 27), (19, 23), (31, 25)].map {
            DeploymentOrder(kind: .giant, position: position(column: $0.0, row: $0.1), deploymentTime: 0)
        }
        let engine = run([tower, storage], deployments, gameData: data, seconds: 0.5)

        let full = data.definition(for: .giant).maxHitPoints
        let hit = deployments.filter { order in
            engine.entities.contains { $0.id == order.entityID && $0.hitPoints < full }
        }
        #expect(hit.count == 3)
    }

    @Test
    func ricochetCannonBouncesToASecondGroundTroop() throws {
        let data = try referenceData()
        let cannon = BattleEntity(kind: .ricochetCannon, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 40, row: 40))
        let deployments = [(19, 25), (19, 26)].map {
            DeploymentOrder(kind: .giant, position: position(column: $0.0, row: $0.1), deploymentTime: 0)
        }
        // One shot: the next one comes after 0.8 s.
        let engine = run([cannon, storage], deployments, gameData: data, seconds: 0.7)

        let full = data.definition(for: .giant).maxHitPoints
        let damage = deployments.compactMap { order in
            engine.entities.first { $0.id == order.entityID }.map { full - $0.hitPoints }
        }.sorted()
        let shot = data.definition(for: .ricochetCannon).attackDamage
        #expect(damage.count == 2)
        #expect(abs(damage[0] - shot * 0.7) < 1e-6)
        #expect(abs(damage[1] - shot) < 1e-6)
    }

    // MARK: Transcribed base

    @Test
    func transcribedTownHall17BaseIsUsable() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()
        let base = try #require(RealBaseLayout.bundled().first { $0.name == "TH17 Merlin" })

        #expect(base.townHall == 17)
        #expect(base.isUsable(catalog: catalog), "\(base.issues(catalog: catalog).filter(\.isError))")
        for kind in [BattleEntityKind.multiArcherTower, .ricochetCannon, .multiGearTower, .monolith, .airSweeper] {
            #expect(base.buildings.contains { $0.kind == kind }, "\(kind)")
        }
        #expect(base.buildings.filter { $0.kind == .airSweeper }.count == 2)
        #expect(base.buildings.filter { $0.kind == .wall }.count > 150)
        // Estimated hidden defenses, within the Town Hall 17 limits.
        #expect(base.buildings.filter { $0.kind == .hiddenTesla }.count == 5)
        #expect(base.buildings.filter { $0.kind == .seekingAirMine }.count == 9)
        #expect(base.buildings.filter { $0.kind == .airBomb }.count == 7)
        #expect(!base.issues(catalog: catalog).contains { $0.text.contains("permessi") && $0.text.contains("Tesla") })
    }
}
