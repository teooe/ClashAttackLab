import Foundation
import Testing
@testable import ClashAttackLabMac

struct PlayerStrategyPlannerTests {
    private func setup() throws -> (BattleArena, [BattleEntity], ArmyConfiguration, AttackPlan) {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let base = arena.makeBaseEntities(layout: .fortress)
        let army = try #require(ArmyConfiguration.playerArmy(for: arena.armyRules))
        let plan = try #require(PlayerStrategyPlanner(
            navigationGrid: arena.navigationGrid,
            latestOrderTime: BattleTiming.latestOrderTime(forBattleDuration: arena.gameData.battleDuration)
        ).plan(for: army, against: base))
        return (arena, base, army, plan)
    }

    @Test
    func theChampionOpensOnTheEagleUnderInvisibility() throws {
        let (arena, base, army, plan) = try setup()
        let grid = arena.navigationGrid
        let eagle = try #require(base.first { $0.kind == .eagleArtillery })
        let first = try #require(plan.orderedDeployments.first)

        #expect(plan.name == PlayerStrategyPlanner.planName)
        #expect(first.kind == .royalChampion)
        #expect(first.deploymentTime == 0)
        #expect(plan.armyConfiguration == army)

        let invisibility = plan.orderedSpellDeployments.filter { $0.kind == .invisibility }
        #expect(invisibility.count == 12)
        for (earlier, later) in zip(invisibility, invisibility.dropFirst()) {
            #expect(abs(later.deploymentTime - earlier.deploymentTime - PlayerStrategyPlanner.invisibilityInterval) < 1e-9)
        }
        let last = try #require(invisibility.last)
        #expect(hypot(last.position.x - eagle.position.x, last.position.y - eagle.position.y) < grid.cellSize)

        // Her ability fires once the spells run out.
        let ability = try #require(plan.heroAbilityOrders.first { $0.entityID == first.entityID })
        #expect(ability.activationTime > last.deploymentTime)
    }

    @Test
    func heroesAndTroopsFollowInThePlayersOrder() throws {
        let (arena, _, _, plan) = try setup()
        let grid = arena.navigationGrid
        let latest = BattleTiming.latestOrderTime(forBattleDuration: arena.gameData.battleDuration)
        func time(of kind: BattleEntityKind) throws -> TimeInterval {
            try #require(plan.deployments.first { $0.kind == kind }).deploymentTime
        }

        let champion = try time(of: .royalChampion)
        let queen = try time(of: .archerQueen)
        let dragons = try time(of: .dragon)
        let warden = try time(of: .grandWarden)
        let duke = try time(of: .dragonDuke)
        #expect(champion < queen)
        #expect(queen < dragons)
        #expect(dragons <= warden)
        #expect(warden < duke)

        for order in plan.deployments {
            let cell = try #require(grid.coordinate(for: order.position))
            #expect(grid.isDeploymentCell(cell), "\(order.kind) at \(cell)")
            #expect((0...latest).contains(order.deploymentTime))
        }
        for spell in plan.spellDeployments {
            #expect((0...latest).contains(spell.deploymentTime))
        }
    }

    @Test
    func theStrategySimulatesAndLeadsTheSearch() throws {
        let (arena, base, _, plan) = try setup()
        let evaluator = AttackPlanEvaluator(
            baseEntities: base,
            gameData: arena.gameData,
            navigationGrid: arena.navigationGrid
        )
        let result = try #require(evaluator.evaluate([plan]).first)
        #expect(result.result.deployedTroops > 0)

        let session = AttackLabSession()
        session.applyGameDataSource(.reference(townHall: 15))
        if let army = ArmyConfiguration.playerArmy(for: session.armyRules) {
            session.applyArmyConfiguration(army)
        }
        let loaded = try #require(session.loadPlayerStrategy())
        #expect(loaded.name == PlayerStrategyPlanner.planName)
        #expect(session.selectedPlanID == loaded.id)
    }

    @Test
    func plansCountTheNewSiegeMachines() {
        let plan = AttackPlan(
            name: "Assedio",
            deployments: [
                DeploymentOrder(kind: .logLauncher, position: WorldPosition(x: 0, y: 0), deploymentTime: 0)
            ]
        )
        #expect(plan.armyConfiguration[troop: .logLauncher] == 1)
    }
}
