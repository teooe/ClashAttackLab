import Foundation
import Testing
@testable import ClashAttackLabMac

struct BattleTimingTests {
    private let position = WorldPosition(x: 100, y: 300)

    @Test
    func orderLimitsFollowTheBattleDuration() {
        #expect(BattleTiming.prototypeLatestOrderTime == 59)
        #expect(BattleTiming.maximumOrderTime == 179)
        #expect(BattleTiming.latestOrderTime(forBattleDuration: 60) == 59)
        #expect(BattleTiming.latestOrderTime(forBattleDuration: 180) == 179)
        #expect(BattleTiming.latestOrderTime(forBattleDuration: 0) == 0)
    }

    @Test
    func manualPlansClampToTheirOwnLimit() throws {
        let troop = DeploymentOrder(kind: .giant, position: position, deploymentTime: 0)

        var prototype = ManualAttackPlan(deployments: [troop])
        prototype.updateOrderTime(id: troop.id, to: 150)
        #expect(prototype.deployments.first?.deploymentTime == 59)

        var real = ManualAttackPlan(deployments: [troop], latestOrderTime: 179)
        real.updateOrderTime(id: troop.id, to: 150)
        #expect(real.deployments.first?.deploymentTime == 150)
        real.updateOrderTime(id: troop.id, to: 500)
        #expect(real.deployments.first?.deploymentTime == 179)
    }

    @Test
    func manualHeroAbilitiesCanFireLateInARealBattle() throws {
        let hero = DeploymentOrder(kind: .archerQueen, position: position, deploymentTime: 90)
        var real = ManualAttackPlan(deployments: [hero], latestOrderTime: 179)

        #expect(real.heroDeployments.map(\.entityID) == [hero.entityID])
        real.setHeroAbilityTime(entityID: hero.entityID, to: 140)
        #expect(real.heroAbilityOrders.first?.activationTime == 140)

        // In the prototype the same hero arrives after the last order time.
        let prototype = ManualAttackPlan(deployments: [hero])
        #expect(prototype.heroDeployments.isEmpty)
    }

    @Test
    func refinerKeepsLateHeroesInsideTheRealLimit() throws {
        let grid = RealBattleMap.makeNavigationGrid()
        let hero = DeploymentOrder(kind: .barbarianKing, position: position, deploymentTime: 100)
        let late = AttackPlan(name: "Late hero", deployments: [hero])

        #expect(AttackPlanRefiner(navigationGrid: grid).heroTimingVariants(for: late).isEmpty)

        let variants = AttackPlanRefiner(
            navigationGrid: grid,
            latestOrderTime: 179
        ).heroTimingVariants(for: late)
        let times = variants.flatMap { $0.heroAbilityOrders.map(\.activationTime) }
        #expect(!variants.isEmpty)
        #expect(times.contains { $0 > 59 })
        #expect(times.allSatisfy { (100...179).contains($0) })
    }

    @Test
    func sessionUsesTheThreeMinuteLimitInRealMode() {
        let session = AttackLabSession()
        #expect(session.latestOrderTime == 59)
        #expect(session.manualPlan.latestOrderTime == 59)

        session.applyGameDataSource(.reference(townHall: 15))
        #expect(session.latestOrderTime == 179)
        #expect(session.manualPlan.latestOrderTime == 179)

        session.applyGameDataSource(.prototype)
        #expect(session.latestOrderTime == 59)
        #expect(session.manualPlan.latestOrderTime == 59)
    }

    @Test
    func importedPlansMayScheduleOrdersInTheWholeRealBattle() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = AttackPlan(
            name: "Late wave",
            deployments: [
                DeploymentOrder(
                    kind: .giant,
                    position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
                    deploymentTime: 120
                )
            ]
        )
        let data = try AttackPlanArchiveCodec.encode([plan], on: grid)
        let imported = try AttackPlanArchiveCodec.decode(data, on: grid)

        #expect(imported.first?.deployments.first?.deploymentTime == 120)
    }
}
